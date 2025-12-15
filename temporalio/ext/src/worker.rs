use std::{
    cell::RefCell,
    collections::{HashMap, HashSet},
    marker::PhantomData,
    sync::Arc,
    time::Duration,
};

use crate::{
    ROOT_MOD,
    client::Client,
    enter_sync, error, id, lazy_id, new_error,
    runtime::{AsyncCommand, Runtime, RuntimeHandle},
    util::{AsyncCallback, SendSyncBoxValue, Struct},
};
use futures::{StreamExt, stream::BoxStream};
use futures::{future, stream};
use magnus::{
    DataTypeFunctions, Error, Exception, IntoValue, RArray, RClass, RModule, RString, RTypedData,
    Ruby, TypedData, Value,
    block::Proc,
    class, function, method,
    prelude::*,
    typed_data,
    value::{Lazy, LazyId},
};
use prost::Message;
use temporalio_common::protos::coresdk::{
    ActivityHeartbeat, ActivitySlotInfo, ActivityTaskCompletion, LocalActivitySlotInfo,
    NexusSlotInfo, WorkflowSlotInfo,
};
use temporalio_common::protos::temporal::api::history::v1::History;
use temporalio_common::protos::temporal::api::worker::v1::PluginInfo;
use temporalio_common::{
    errors::{PollError, WorkflowErrorType},
    worker::{
        PollerBehavior, SlotInfo, SlotInfoTrait, SlotKind, SlotKindType, SlotMarkUsedContext,
        SlotReleaseContext, SlotReservationContext, SlotSupplier, SlotSupplierPermit,
        WorkerDeploymentOptions, WorkerDeploymentVersion, WorkerVersioningStrategy,
    },
};
use temporalio_common::{
    protos::coresdk::workflow_completion::WorkflowActivationCompletion, worker::WorkerTaskTypes,
};
use temporalio_sdk_core::{
    ResourceBasedSlotsOptions, ResourceBasedSlotsOptionsBuilder, ResourceSlotOptions,
    SlotSupplierOptions, TunerHolder, TunerHolderOptionsBuilder, WorkerConfig, WorkerConfigBuilder,
    replay::{HistoryForReplay, ReplayWorkerInput},
};
use tokio::sync::mpsc::{Sender, UnboundedSender, channel, unbounded_channel};
use tokio_stream::wrappers::ReceiverStream;

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let class = ruby
        .get_inner(&ROOT_MOD)
        .define_class("Worker", class::object())?;
    class.define_singleton_method("new", function!(Worker::new, 2))?;
    class.define_singleton_method("async_poll_all", function!(Worker::async_poll_all, 2))?;
    class.define_singleton_method(
        "async_finalize_all",
        function!(Worker::async_finalize_all, 2),
    )?;
    class.define_method("async_validate", method!(Worker::async_validate, 1))?;
    class.define_method(
        "async_complete_activity_task",
        method!(Worker::async_complete_activity_task, 2),
    )?;
    class.define_method(
        "record_activity_heartbeat",
        method!(Worker::record_activity_heartbeat, 1),
    )?;
    class.define_method(
        "async_complete_workflow_activation",
        method!(Worker::async_complete_workflow_activation, 3),
    )?;
    class.define_method("replace_client", method!(Worker::replace_client, 1))?;
    class.define_method("initiate_shutdown", method!(Worker::initiate_shutdown, 0))?;

    let inner_class = class.define_class("WorkflowReplayer", class::object())?;
    inner_class.define_singleton_method("new", function!(WorkflowReplayer::new, 2))?;
    inner_class.define_method("push_history", method!(WorkflowReplayer::push_history, 2))?;

    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Worker", free_immediately)]
pub struct Worker {
    // This needs to be a RefCell of an Option of an Arc because we need to
    // mutably take it out of the option at finalize time but we don't have
    // a mutable reference of self at that time.
    core: RefCell<Option<Arc<temporalio_sdk_core::Worker>>>,
    runtime_handle: RuntimeHandle,
    activity: bool,
    workflow: bool,
}

#[derive(Copy, Clone)]
enum WorkerType {
    Activity,
    Workflow,
}

struct PollResult {
    worker_index: usize,
    worker_type: WorkerType,
    result: Result<Option<Vec<u8>>, String>,
}

impl Worker {
    pub fn new(client: &Client, options: Struct) -> Result<Self, Error> {
        client.runtime_handle.fork_check("create worker")?;

        enter_sync!(client.runtime_handle);

        let config = build_config(options, &client.runtime_handle)?;
        let activity =
            config.task_types.enable_local_activities || config.task_types.enable_remote_activities;
        let workflow = config.task_types.enable_workflows;

        let worker = temporalio_sdk_core::init_worker(
            &client.runtime_handle.core,
            config,
            client.core.clone().into_inner(),
        )
        .map_err(|err| error!("Failed creating worker: {}", err))?;

        Ok(Worker {
            core: RefCell::new(Some(Arc::new(worker))),
            runtime_handle: client.runtime_handle.clone(),
            activity,
            workflow,
        })
    }

    // Helper that turns a worker + type into a poll stream
    fn stream_poll<'a>(
        worker: Arc<temporalio_sdk_core::Worker>,
        worker_index: usize,
        worker_type: WorkerType,
    ) -> BoxStream<'a, PollResult> {
        stream::unfold(Some(worker.clone()), move |worker| async move {
            // We return no worker so the next streamed item closes
            // the stream with a None
            if let Some(worker) = worker {
                let result = match worker_type {
                    WorkerType::Activity => {
                        match temporalio_common::Worker::poll_activity_task(&*worker).await {
                            Ok(res) => Ok(Some(res.encode_to_vec())),
                            Err(PollError::ShutDown) => Ok(None),
                            Err(err) => Err(format!("Poll error: {err}")),
                        }
                    }
                    WorkerType::Workflow => {
                        match temporalio_common::Worker::poll_workflow_activation(&*worker).await {
                            Ok(res) => Ok(Some(res.encode_to_vec())),
                            Err(PollError::ShutDown) => Ok(None),
                            Err(err) => Err(format!("Poll error: {err}")),
                        }
                    }
                };
                let shutdown_next = matches!(result, Ok(None));
                Some((
                    PollResult {
                        worker_index,
                        worker_type,
                        result,
                    },
                    // No more work if shutdown
                    if shutdown_next { None } else { Some(worker) },
                ))
            } else {
                None
            }
        })
        .boxed()
    }

    pub fn async_poll_all(workers: RArray, queue: Value) -> Result<(), Error> {
        // Get the first runtime handle
        let runtime = workers
            .entry::<typed_data::Obj<Worker>>(0)?
            .runtime_handle
            .clone();

        runtime.fork_check("use worker")?;

        // Create streams of poll calls
        let worker_streams = workers
            .into_iter()
            .enumerate()
            .flat_map(|(index, worker_val)| {
                let worker_typed_data = RTypedData::from_value(worker_val).expect("Not typed data");
                let worker_ref = worker_typed_data.get::<Worker>().expect("Not worker");
                let worker = worker_ref
                    .core
                    .borrow()
                    .as_ref()
                    .expect("Unable to borrow")
                    .clone();
                let mut streams = Vec::with_capacity(2);
                if worker_ref.activity {
                    streams.push(Self::stream_poll(
                        worker.clone(),
                        index,
                        WorkerType::Activity,
                    ));
                }
                if worker_ref.workflow {
                    streams.push(Self::stream_poll(
                        worker.clone(),
                        index,
                        WorkerType::Workflow,
                    ));
                }
                streams
            })
            .collect::<Vec<_>>();
        let mut worker_stream = stream::select_all(worker_streams);

        // Continually call the callback with the worker and the result. The result can either be:
        // * [worker index, :activity/:workflow, bytes] - poll success
        // * [worker index, :activity/:workflow, error] - poll fail
        // * [worker index, :activity/:workflow, nil] - worker shutdown
        // * [nil, nil, nil] - all pollers done
        let callback = Arc::new(AsyncCallback::from_queue(queue));
        let complete_callback = callback.clone();
        let async_command_tx = runtime.async_command_tx.clone();
        runtime.spawn(
            async move {
                // Get next item from the stream
                while let Some(poll_result) = worker_stream.next().await {
                    // Send callback to Ruby
                    let callback = callback.clone();
                    let _ = async_command_tx.send(AsyncCommand::RunCallback(Box::new(move || {
                        // Get Ruby in callback
                        let ruby = Ruby::get().expect("Ruby not available");
                        let worker_type = match poll_result.worker_type {
                            WorkerType::Activity => id!("activity"),
                            WorkerType::Workflow => id!("workflow"),
                        };
                        // Call block
                        let result: Value = match poll_result.result {
                            Ok(Some(val)) => RString::from_slice(&val).as_value(),
                            Ok(None) => ruby.qnil().as_value(),
                            Err(err) => new_error!("Poll failure: {}", err).as_value(),
                        };
                        callback.push(
                            &ruby,
                            ruby.ary_new_from_values(&[
                                poll_result.worker_index.into_value(),
                                worker_type.into_value(),
                                result,
                            ]),
                        )
                    })));
                }
            },
            move |ruby, _| {
                // Call with nil, nil, nil to say done
                complete_callback.push(
                    &ruby,
                    ruby.ary_new_from_values(&[ruby.qnil(), ruby.qnil(), ruby.qnil()]),
                )
            },
        );
        Ok(())
    }

    pub fn async_finalize_all(workers: RArray, queue: Value) -> Result<(), Error> {
        // Get the first runtime handle
        let runtime = workers
            .entry::<typed_data::Obj<Worker>>(0)?
            .runtime_handle
            .clone();

        // Take workers and call finalize on them
        let mut errs: Vec<String> = Vec::new();
        let futs = workers
            .into_iter()
            .map(|worker_val| {
                let worker_typed_data = RTypedData::from_value(worker_val).expect("Not typed data");
                let worker_ref = worker_typed_data.get::<Worker>().expect("Not worker");
                let worker = worker_ref
                    .core
                    .try_borrow_mut()
                    .map_err(|_| "Worker still in use".to_owned())
                    .and_then(|mut val| {
                        Arc::try_unwrap(val.take().unwrap()).map_err(|arc| {
                            format!("Expected 1 reference but got {}", Arc::strong_count(&arc))
                        })
                    })?;
                Ok(temporalio_common::Worker::finalize_shutdown(worker))
            })
            .filter_map(|fut_or_err| match fut_or_err {
                Ok(fut) => Some(fut),
                Err(err) => {
                    errs.push(err);
                    None
                }
            })
            .collect::<Vec<_>>();

        // Spawn the futures
        let callback = AsyncCallback::from_queue(queue);
        runtime.spawn(
            async move {
                // Run all futures and return errors
                future::join_all(futs).await;
                errs
            },
            move |ruby, errs| {
                if errs.is_empty() {
                    callback.push(&ruby, ruby.qnil())
                } else {
                    callback.push(
                        &ruby,
                        new_error!(
                            "{} worker(s) failed to finalize, reasons: {}",
                            errs.len(),
                            errs.join(", ")
                        ),
                    )
                }
            },
        );
        Ok(())
    }

    pub fn async_validate(&self, queue: Value) -> Result<(), Error> {
        let callback = AsyncCallback::from_queue(queue);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        self.runtime_handle.spawn(
            async move { temporalio_common::Worker::validate(&*worker).await },
            move |ruby, result| match result {
                Ok(()) => callback.push(&ruby, ruby.qnil()),
                Err(err) => callback.push(&ruby, new_error!("Failed validating worker: {}", err)),
            },
        );
        Ok(())
    }

    pub fn async_complete_activity_task(&self, proto: RString, queue: Value) -> Result<(), Error> {
        let callback = AsyncCallback::from_queue(queue);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        let completion = ActivityTaskCompletion::decode(unsafe { proto.as_slice() })
            .map_err(|err| error!("Invalid proto: {}", err))?;
        self.runtime_handle.spawn(
            async move {
                temporalio_common::Worker::complete_activity_task(&*worker, completion).await
            },
            move |ruby, result| match result {
                Ok(()) => callback.push(&ruby, (ruby.qnil(),)),
                Err(err) => callback.push(&ruby, (new_error!("Completion failure: {}", err),)),
            },
        );
        Ok(())
    }

    pub fn record_activity_heartbeat(&self, proto: RString) -> Result<(), Error> {
        enter_sync!(self.runtime_handle);
        let heartbeat = ActivityHeartbeat::decode(unsafe { proto.as_slice() })
            .map_err(|err| error!("Invalid proto: {}", err))?;
        let worker = self.core.borrow().as_ref().unwrap().clone();
        temporalio_common::Worker::record_activity_heartbeat(&*worker, heartbeat);
        Ok(())
    }

    pub fn async_complete_workflow_activation(
        &self,
        run_id: String,
        proto: RString,
        queue: Value,
    ) -> Result<(), Error> {
        let callback = AsyncCallback::from_queue(queue);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        let completion = WorkflowActivationCompletion::decode(unsafe { proto.as_slice() })
            .map_err(|err| error!("Invalid proto: {}", err))?;
        self.runtime_handle.spawn(
            async move {
                temporalio_common::Worker::complete_workflow_activation(&*worker, completion).await
            },
            move |ruby, result| {
                callback.push(
                    &ruby,
                    ruby.ary_new_from_values(&[
                        (-1).into_value_with(&ruby),
                        run_id.into_value_with(&ruby),
                        match result {
                            Ok(()) => ruby.qnil().into_value_with(&ruby),
                            Err(err) => {
                                new_error!("Completion failure: {}", err).into_value_with(&ruby)
                            }
                        },
                    ]),
                )
            },
        );
        Ok(())
    }

    pub fn replace_client(&self, client: &Client) -> Result<(), Error> {
        enter_sync!(self.runtime_handle);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        worker
            .replace_client(client.core.clone().into_inner())
            .map_err(|err| error!("Failed replacing client: {}", err))
    }

    pub fn initiate_shutdown(&self) -> Result<(), Error> {
        enter_sync!(self.runtime_handle);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        temporalio_common::Worker::initiate_shutdown(&*worker);
        Ok(())
    }
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Worker::WorkflowReplayer",
    free_immediately
)]
pub struct WorkflowReplayer {
    tx: Sender<HistoryForReplay>,
    runtime_handle: RuntimeHandle,
}

impl WorkflowReplayer {
    pub fn new(runtime: &Runtime, options: Struct) -> Result<(Self, Worker), Error> {
        enter_sync!(runtime.handle.clone());

        let (tx, rx) = channel(1);

        let core_worker = temporalio_sdk_core::init_replay_worker(ReplayWorkerInput::new(
            build_config(options, &runtime.handle)?,
            ReceiverStream::new(rx),
        ))
        .map_err(|err| error!("Failed creating worker: {}", err))?;

        Ok((
            WorkflowReplayer {
                tx,
                runtime_handle: runtime.handle.clone(),
            },
            Worker {
                core: RefCell::new(Some(Arc::new(core_worker))),
                runtime_handle: runtime.handle.clone(),
                activity: false,
                workflow: true,
            },
        ))
    }

    pub fn push_history(&self, workflow_id: String, proto: RString) -> Result<(), Error> {
        let history = History::decode(unsafe { proto.as_slice() })
            .map_err(|err| error!("Invalid proto: {}", err))?;
        let tx = self.tx.clone();
        self.runtime_handle.core.tokio_handle().spawn(async move {
            // Intentionally ignoring error here
            let _ = tx.send(HistoryForReplay::new(history, workflow_id)).await;
        });
        Ok(())
    }
}

fn build_config(options: Struct, runtime_handle: &RuntimeHandle) -> Result<WorkerConfig, Error> {
    WorkerConfigBuilder::default()
        .namespace(options.member::<String>(id!("namespace"))?)
        .task_queue(options.member::<String>(id!("task_queue"))?)
        .versioning_strategy({
            let deploy_options = options.child(id!("deployment_options"))?;
            if let Some(dopts) = deploy_options {
                let version = dopts
                    .child(id!("version"))?
                    .ok_or(error!("Worker::DeploymentOptions must set version"))?;
                WorkerVersioningStrategy::WorkerDeploymentBased(WorkerDeploymentOptions {
                    version: WorkerDeploymentVersion {
                        deployment_name: version.member::<String>(id!("deployment_name"))?,
                        build_id: version.member::<String>(id!("build_id"))?,
                    },
                    use_worker_versioning: dopts.member::<bool>(id!("use_worker_versioning"))?,
                    default_versioning_behavior: {
                        let val = dopts.member::<i32>(id!("default_versioning_behavior"))?;
                        if val == 0 {
                            None
                        } else {
                            Some(val.try_into().map_err(|_| {
                                error!("Unknown default versioning behavior: {}", val)
                            })?)
                        }
                    },
                })
            } else {
                // Ruby side should always set deployment options w/ default build ID
                return Err(error!("SDK must set Worker deployment_options"));
            }
        })
        .client_identity_override(options.member::<Option<String>>(id!("identity_override"))?)
        .max_cached_workflows(options.member::<usize>(id!("max_cached_workflows"))?)
        .workflow_task_poller_behavior({
            let poller_behavior = options
                .child(id!("workflow_task_poller_behavior"))?
                .ok_or_else(|| error!("Worker options must have workflow_task_poller_behavior"))?;
            extract_poller_behavior(poller_behavior)?
        })
        .nonsticky_to_sticky_poll_ratio(
            options.member::<f32>(id!("nonsticky_to_sticky_poll_ratio"))?,
        )
        .activity_task_poller_behavior({
            let poller_behavior = options
                .child(id!("activity_task_poller_behavior"))?
                .ok_or_else(|| error!("Worker options must have activity_task_poller_behavior"))?;
            extract_poller_behavior(poller_behavior)?
        })
        .task_types(WorkerTaskTypes {
            enable_workflows: options.member(id!("enable_workflows"))?,
            enable_local_activities: options.member(id!("enable_local_activities"))?,
            enable_remote_activities: options.member(id!("enable_remote_activities"))?,
            enable_nexus: options.member(id!("enable_nexus"))?,
        })
        .sticky_queue_schedule_to_start_timeout(Duration::from_secs_f64(
            options.member(id!("sticky_queue_schedule_to_start_timeout"))?,
        ))
        .max_heartbeat_throttle_interval(Duration::from_secs_f64(
            options.member(id!("max_heartbeat_throttle_interval"))?,
        ))
        .default_heartbeat_throttle_interval(Duration::from_secs_f64(
            options.member(id!("default_heartbeat_throttle_interval"))?,
        ))
        .max_worker_activities_per_second(
            options.member::<Option<f64>>(id!("max_worker_activities_per_second"))?,
        )
        .max_task_queue_activities_per_second(
            options.member::<Option<f64>>(id!("max_task_queue_activities_per_second"))?,
        )
        .graceful_shutdown_period(Duration::from_secs_f64(
            options.member(id!("graceful_shutdown_period"))?,
        ))
        .tuner(Arc::new(build_tuner(
            options
                .child(id!("tuner"))?
                .ok_or_else(|| error!("Missing tuner"))?,
            runtime_handle,
        )?))
        .workflow_failure_errors(
            if options.member::<bool>(id!("nondeterminism_as_workflow_fail"))? {
                HashSet::from([WorkflowErrorType::Nondeterminism])
            } else {
                HashSet::new()
            },
        )
        .workflow_types_to_failure_errors(
            options
                .member::<Vec<String>>(id!("nondeterminism_as_workflow_fail_for_types"))?
                .into_iter()
                .map(|s| (s, HashSet::from([WorkflowErrorType::Nondeterminism])))
                .collect::<HashMap<String, HashSet<WorkflowErrorType>>>(),
        )
        .plugins(
            options
                .member::<Vec<String>>(id!("plugins"))?
                .into_iter()
                .map(|name| PluginInfo {
                    name,
                    version: String::new(),
                })
                .collect::<Vec<PluginInfo>>(),
        )
        .build()
        .map_err(|err| error!("Invalid worker options: {}", err))
}

fn extract_poller_behavior(poller_behavior: Struct) -> Result<PollerBehavior, Error> {
    Ok(if poller_behavior.member::<usize>(id!("initial")).is_ok() {
        PollerBehavior::Autoscaling {
            minimum: poller_behavior.member::<usize>(id!("minimum"))?,
            maximum: poller_behavior.member::<usize>(id!("maximum"))?,
            initial: poller_behavior.member::<usize>(id!("initial"))?,
        }
    } else {
        PollerBehavior::SimpleMaximum(poller_behavior.member::<usize>(id!("simple_maximum"))?)
    })
}

fn build_tuner(options: Struct, runtime_handle: &RuntimeHandle) -> Result<TunerHolder, Error> {
    let (workflow_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("workflow_slot_supplier"))?
            .ok_or_else(|| error!("Missing workflow slot options"))?,
        None,
        runtime_handle,
    )?;
    let (activity_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("activity_slot_supplier"))?
            .ok_or_else(|| error!("Missing activity slot options"))?,
        resource_slot_options,
        runtime_handle,
    )?;
    let (local_activity_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("local_activity_slot_supplier"))?
            .ok_or_else(|| error!("Missing local activity slot options"))?,
        resource_slot_options,
        runtime_handle,
    )?;

    let mut opts_build = TunerHolderOptionsBuilder::default();
    if let Some(resource_slot_options) = resource_slot_options {
        opts_build.resource_based_options(resource_slot_options);
    }
    opts_build
        .workflow_slot_options(workflow_slot_options)
        .activity_slot_options(activity_slot_options)
        .local_activity_slot_options(local_activity_slot_options)
        .build()
        .map_err(|err| error!("Failed building tuner options: {}", err))?
        .build_tuner_holder()
        .map_err(|err| error!("Failed building tuner options: {}", err))
}

fn build_tuner_slot_options<SK: SlotKind + Send + Sync + 'static>(
    options: Struct,
    prev_slots_options: Option<ResourceBasedSlotsOptions>,
    runtime_handle: &RuntimeHandle,
) -> Result<(SlotSupplierOptions<SK>, Option<ResourceBasedSlotsOptions>), Error> {
    if let Some(slots) = options.member::<Option<usize>>(id!("fixed_size"))? {
        Ok((SlotSupplierOptions::FixedSize { slots }, prev_slots_options))
    } else if let Some(resource) = options.child(id!("resource_based"))? {
        build_tuner_resource_options(resource, prev_slots_options)
    } else if let Some(custom) = options.member::<Option<Value>>(id!("custom"))? {
        build_custom_slot_supplier(custom, runtime_handle).map(|v| (v, None))
    } else {
        Err(error!(
            "Slot supplier must be fixed size, resource based, or custom"
        ))
    }
}

fn build_tuner_resource_options<SK: SlotKind>(
    options: Struct,
    prev_slots_options: Option<ResourceBasedSlotsOptions>,
) -> Result<(SlotSupplierOptions<SK>, Option<ResourceBasedSlotsOptions>), Error> {
    let slots_options = ResourceBasedSlotsOptionsBuilder::default()
        .target_mem_usage(options.member(id!("target_mem_usage"))?)
        .target_cpu_usage(options.member(id!("target_cpu_usage"))?)
        .build()
        .map_err(|err| error!("Failed building resource slot options: {}", err))?;
    if let Some(prev_slots_options) = prev_slots_options
        && (slots_options.target_cpu_usage != prev_slots_options.target_cpu_usage
            || slots_options.target_mem_usage != prev_slots_options.target_mem_usage)
    {
        return Err(error!(
            "All resource-based slot suppliers must have the same resource-based tuner options"
        ));
    }
    Ok((
        SlotSupplierOptions::ResourceBased(ResourceSlotOptions::new(
            options.member(id!("min_slots"))?,
            options.member(id!("max_slots"))?,
            Duration::from_secs_f64(options.member(id!("ramp_throttle"))?),
        )),
        Some(slots_options),
    ))
}

fn build_custom_slot_supplier<SK: SlotKind + Send + Sync + 'static>(
    supplier: Value,
    runtime_handle: &RuntimeHandle,
) -> Result<SlotSupplierOptions<SK>, Error> {
    Ok(SlotSupplierOptions::Custom(Arc::new(CustomSlotSupplier::<
        SK,
    > {
        supplier: Arc::new(SendSyncBoxValue::new(supplier)),
        runtime_handle: runtime_handle.clone(),
        _phantom: PhantomData,
    })))
}

struct CustomSlotSupplier<SK: SlotKind> {
    supplier: Arc<SendSyncBoxValue<Value>>,
    runtime_handle: RuntimeHandle,
    _phantom: PhantomData<SK>,
}

struct CancelGuard<F: FnOnce()> {
    f: Option<F>,
}

impl<F: FnOnce()> CancelGuard<F> {
    fn new(f: F) -> Self {
        Self { f: Some(f) }
    }

    fn defuse(mut self) {
        self.f.take();
    }
}

impl<F: FnOnce()> Drop for CancelGuard<F> {
    fn drop(&mut self) {
        if let Some(f) = self.f.take() {
            f();
        }
    }
}

#[async_trait::async_trait]
impl<SK: SlotKind + Send + Sync> SlotSupplier for CustomSlotSupplier<SK> {
    type SlotKind = SK;

    async fn reserve_slot(&self, ctx: &dyn SlotReservationContext) -> SlotSupplierPermit {
        // Do this in an infinite loop until we get success (log and sleep on error)
        let ctx = SlotReserveContextHolder::new(SK::kind(), ctx);
        loop {
            match self.attempt_reserve_slot(ctx.clone()).await {
                Ok(permit) => {
                    return SlotSupplierPermit::with_user_data(Arc::new(permit));
                }
                Err(err) => {
                    log::error!("Slot reserve failed: {err}");
                    tokio::time::sleep(std::time::Duration::from_secs(1)).await
                }
            }
        }
    }

    fn try_reserve_slot(&self, ctx: &dyn SlotReservationContext) -> Option<SlotSupplierPermit> {
        let res = self.call_supplier_sync(
            lazy_id!("try_reserve_slot"),
            SlotReserveContextHolder::new(SK::kind(), ctx),
            |v| {
                if v.is_nil() {
                    None
                } else {
                    Some(SendSyncBoxValue::new(v))
                }
            },
        );
        match res {
            Ok(v) => v.map(|v| SlotSupplierPermit::with_user_data(Arc::new(v))),
            Err(err) => {
                log::error!("Slot try-reserve failed: {err}");
                None
            }
        }
    }

    fn mark_slot_used(&self, ctx: &dyn SlotMarkUsedContext<SlotKind = Self::SlotKind>) {
        let res = self.call_supplier_sync(
            lazy_id!("mark_slot_used"),
            SlotMarkUsedContextHolder::new(ctx),
            |_| (),
        );
        if let Err(err) = res {
            log::error!("Mark slot used failed: {err}");
        }
    }

    fn release_slot(&self, ctx: &dyn SlotReleaseContext<SlotKind = Self::SlotKind>) {
        let res = self.call_supplier_sync(
            lazy_id!("release_slot"),
            SlotReleaseContextHolder::new(ctx),
            |_| (),
        );
        if let Err(err) = res {
            log::error!("Mark slot used failed: {err}");
        }
    }
}

impl<SK: SlotKind> CustomSlotSupplier<SK> {
    async fn attempt_reserve_slot(
        &self,
        ctx: SlotReserveContextHolder,
    ) -> Result<SendSyncBoxValue<Value>, String> {
        // Make a call with channels getting info
        let (result_tx, mut result_rx) = unbounded_channel();
        let (cancel_proc_ready_tx, mut cancel_proc_ready_rx) = unbounded_channel();
        let result_err_tx = result_tx.clone();
        self.start_supplier_call(
            lazy_id!("reserve_slot"),
            ctx,
            move |_, val| {
                let _ = result_tx.send(Ok(SendSyncBoxValue::new(val)));
            },
            move |err| {
                let _ = result_err_tx.send(Err(err));
            },
            Some(cancel_proc_ready_tx),
        );

        // Wait for cancel proc ready or result. Note, we may not get a cancel proc in the case
        // that its tx is dropped before the result tx is recorded, so we just ignore and move on.
        let (cancel_proc, result) = tokio::select! {
            cancel_proc = cancel_proc_ready_rx.recv() => (cancel_proc, None),
            result = result_rx.recv() => (None, Some(result.ok_or_else(|| "Unable to get result".to_string()))),
        };
        // If we got a result, return it
        if let Some(result) = result {
            return result.flatten();
        }

        // Now that we have a cancel proc, we can setup the guard
        let runtime_handle = self.runtime_handle.clone();
        let cancel_guard = cancel_proc.map(move |cancel_proc| {
            CancelGuard::new(move || {
                runtime_handle.spawn(async {}, move |ruby, _| {
                    // TODO(cretz): Should do this in a Ruby thread to not block main Ruby
                    // reactor loop?
                    let cancel_proc = cancel_proc.value(&ruby);
                    if let Err(err) = cancel_proc.call::<_, Value>(()) {
                        log::error!("Failed canceling: {err}");
                    }
                    Ok(())
                });
            })
        });

        // Wait for result
        let result: Result<SendSyncBoxValue<Value>, String> = result_rx
            .recv()
            .await
            .ok_or_else(|| "Unable to get result".to_string())
            .flatten();

        // Defuse guard (we don't want it to run cancel proc), and return
        if let Some(cancel_guard) = cancel_guard {
            cancel_guard.defuse();
        }
        result
    }

    fn call_supplier_sync<R: Send + 'static>(
        &self,
        method: &'static LazyId,
        ctx: impl TryIntoValue + Send + 'static,
        map_result: impl Fn(Value) -> R + Send + 'static,
    ) -> Result<R, String> {
        // Make call
        let (result_tx, result_rx) = std::sync::mpsc::channel();
        let result_err_tx = result_tx.clone();
        self.start_supplier_call(
            method,
            ctx,
            move |_, val| {
                let _ = result_tx.send(Ok(map_result(val)));
            },
            move |err| {
                let _ = result_err_tx.send(Err(err));
            },
            None,
        );

        // Wait for result. We recognize this blocks, but we expect users not to block. We cannot
        // use Tokio's blocking_recv or block_on because we're already in a Tokio runtime and so
        // they panic. We also can't use tokio::task::block_in_place because this is sometimes
        // started on a non-Tokio-started thread from a workflow context, and block_in_place fails
        // even in legitimate Tokio contexts if the thread wasn't started by Tokio. So, we just wait
        // and block this thread, but we have told users they should not block on these sync calls.
        result_rx
            .recv()
            .map_err(|err| format!("Call canceled: {err}"))
            .flatten()
    }

    fn start_supplier_call(
        &self,
        method: &'static LazyId,
        ctx: impl TryIntoValue + Send + 'static,
        on_success: impl Fn(&Ruby, Value) + Send + 'static,
        on_error: impl Fn(String) + Clone + Send + 'static, // May be called multiple times
        cancel_proc_ready_tx: Option<UnboundedSender<SendSyncBoxValue<Proc>>>,
    ) {
        // Run in Ruby. We have to use spawn_sync_inline instead of spawn here because spawn starts
        // a new Tokio task and we cannot always start a new Tokio task because we're not always in
        // a multi-threaded situation where it can be waited on.
        let supplier = self.supplier.clone();
        self.runtime_handle.spawn_sync_inline(move |ruby| {
            if let Err(err) = start_supplier_call_in_ruby(
                ruby,
                supplier,
                method,
                ctx,
                on_success,
                on_error.clone(),
                cancel_proc_ready_tx,
            ) {
                // May have already sent a result here, but it's harmless to try
                on_error(format!("Raised exception: {err}"));
            }
            Ok(())
        });
    }
}

fn start_supplier_call_in_ruby(
    ruby: Ruby,
    supplier: Arc<SendSyncBoxValue<Value>>,
    method: &'static LazyId,
    ctx: impl TryIntoValue,
    on_success: impl Fn(&Ruby, Value) + Send + 'static,
    on_error: impl Fn(String) + Send + 'static,
    cancel_proc_ready_tx: Option<UnboundedSender<SendSyncBoxValue<Proc>>>,
) -> Result<(), Error> {
    // Context
    let method = LazyId::get_inner_with(method, &ruby);
    let ctx = ctx.try_into_value(&ruby)?;

    // Put functions in options so we can take it just once in closure
    let mut on_success = Some(on_success);
    let mut on_error = Some(on_error);

    // Create proc for callback
    let proc = ruby.proc_from_fn(move |ruby, args, _block| {
        let result = args
            .first()
            .copied()
            .unwrap_or_else(|| ruby.qnil().as_value());
        // If it's an exception, that's an error, otherwise it's a success
        if let Some(err) = Exception::from_value(result) {
            if let Some(on_error) = on_error.take() {
                on_error(format!("Raised exception: {err}"));
            }
        } else if let Some(on_success) = on_success.take() {
            on_success(ruby, result);
        } else {
            log::error!("Custom slot supplier callback unexpectedly invoked multiple times");
        }
    });

    // Build arg set. If there is a cancel_proc_ready, we create a cancellation and provide it to
    // the sender.
    let mut maybe_cancellation = None;
    if let Some(cancel_proc_ready_tx) = cancel_proc_ready_tx {
        // Create cancellation and provide cancellation as second arg and send back cancel proc
        let cancellation = ruby
            .get_inner(&CANCELLATION_CLASS)
            .funcall(id!("new"), ())?;
        let cancel_proc = RArray::to_ary(cancellation)?.entry::<Value>(1)?;
        let _ = cancel_proc_ready_tx.send(SendSyncBoxValue::new(
            Proc::from_value(cancel_proc).expect("Expecting proc"),
        ));
        maybe_cancellation = Some(cancellation)
    };

    // Call custom supplier with the block, it can be a two-arg form with context or one-arg w/out
    let supplier = supplier.value(&ruby);
    if let Some(cancellation) = maybe_cancellation {
        supplier.funcall_with_block::<_, _, Value>(method, (ctx, cancellation), proc)?;
    } else {
        supplier.funcall_with_block::<_, _, Value>(method, (ctx,), proc)?;
    }
    Ok(())
}

pub static CANCELLATION_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.class_object()
        .const_get::<_, RModule>("Temporalio")
        .unwrap()
        .const_get::<_, RClass>("Cancellation")
        .unwrap()
});

pub static CUSTOM_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.class_object()
        .const_get::<_, RModule>("Temporalio")
        .unwrap()
        .const_get::<_, RClass>("Worker")
        .unwrap()
        .const_get::<_, RClass>("Tuner")
        .unwrap()
        .const_get::<_, RClass>("SlotSupplier")
        .unwrap()
        .const_get::<_, RClass>("Custom")
        .unwrap()
});

pub static RESERVE_CONTEXT_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&CUSTOM_CLASS)
        .const_get::<_, RClass>("ReserveContext")
        .unwrap()
});

pub static MARK_USED_CONTEXT_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&CUSTOM_CLASS)
        .const_get::<_, RClass>("MarkUsedContext")
        .unwrap()
});

pub static RELEASE_CONTEXT_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&CUSTOM_CLASS)
        .const_get::<_, RClass>("ReleaseContext")
        .unwrap()
});

pub static SLOT_INFO_MODULE: Lazy<RModule> = Lazy::new(|ruby| {
    ruby.get_inner(&CUSTOM_CLASS)
        .const_get::<_, RModule>("SlotInfo")
        .unwrap()
});

pub static SLOT_INFO_WORKFLOW_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&SLOT_INFO_MODULE)
        .const_get::<_, RClass>("Workflow")
        .unwrap()
});

pub static SLOT_INFO_ACTIVITY_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&SLOT_INFO_MODULE)
        .const_get::<_, RClass>("Activity")
        .unwrap()
});

pub static SLOT_INFO_LOCAL_ACTIVITY_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&SLOT_INFO_MODULE)
        .const_get::<_, RClass>("LocalActivity")
        .unwrap()
});

pub static SLOT_INFO_NEXUS_CLASS: Lazy<RClass> = Lazy::new(|ruby| {
    ruby.get_inner(&SLOT_INFO_MODULE)
        .const_get::<_, RClass>("Nexus")
        .unwrap()
});

trait TryIntoValue {
    fn try_into_value(self, ruby: &Ruby) -> Result<Value, Error>;
}

#[derive(Clone)]
struct SlotReserveContextHolder {
    slot_kind: SlotKindType,
    task_queue: String,
    worker_identity: String,
    worker_deployment_name: String,
    worker_build_id: String,
    is_sticky: bool,
}

impl SlotReserveContextHolder {
    fn new(slot_kind: SlotKindType, ctx: &dyn SlotReservationContext) -> Self {
        Self {
            slot_kind,
            task_queue: ctx.task_queue().to_string(),
            worker_identity: ctx.worker_identity().to_string(),
            worker_deployment_name: ctx
                .worker_deployment_version()
                .clone()
                .map(|v| v.deployment_name)
                .unwrap_or_default(),
            worker_build_id: ctx
                .worker_deployment_version()
                .clone()
                .map(|v| v.build_id)
                .unwrap_or_default(),
            is_sticky: ctx.is_sticky(),
        }
    }
}

impl TryIntoValue for SlotReserveContextHolder {
    fn try_into_value(self, ruby: &Ruby) -> Result<Value, Error> {
        ruby.get_inner(&RESERVE_CONTEXT_CLASS).funcall(
            id!("new"),
            (
                // Slot type
                match self.slot_kind {
                    SlotKindType::Workflow => id!("workflow"),
                    SlotKindType::Activity => id!("activity"),
                    SlotKindType::LocalActivity => id!("local_activity"),
                    SlotKindType::Nexus => id!("nexus"),
                },
                // Task queue
                self.task_queue,
                // Worker identity
                self.worker_identity,
                // Worker deployment name
                self.worker_deployment_name,
                // Worker build ID
                self.worker_build_id,
                // Sticky
                self.is_sticky,
            ),
        )
    }
}

struct SlotMarkUsedContextHolder {
    slot_info: SlotInfoHolder,
    permit: Option<Arc<SendSyncBoxValue<Value>>>,
}

impl SlotMarkUsedContextHolder {
    fn new<SK: SlotKind>(ctx: &dyn SlotMarkUsedContext<SlotKind = SK>) -> Self {
        Self {
            slot_info: SlotInfoHolder::new(ctx.info().downcast()),
            permit: ctx
                .permit()
                .user_data::<Arc<SendSyncBoxValue<Value>>>()
                .cloned(),
        }
    }
}

impl TryIntoValue for SlotMarkUsedContextHolder {
    fn try_into_value(self, ruby: &Ruby) -> Result<Value, Error> {
        ruby.get_inner(&MARK_USED_CONTEXT_CLASS).funcall(
            id!("new"),
            (
                // Slot info
                self.slot_info.try_into_value(ruby)?,
                // Permit
                self.permit
                    .map(|v| v.value(ruby))
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            ),
        )
    }
}

struct SlotReleaseContextHolder {
    slot_info: Option<SlotInfoHolder>,
    permit: Option<Arc<SendSyncBoxValue<Value>>>,
}

impl SlotReleaseContextHolder {
    fn new<SK: SlotKind>(ctx: &dyn SlotReleaseContext<SlotKind = SK>) -> Self {
        Self {
            slot_info: ctx.info().map(|i| SlotInfoHolder::new(i.downcast())),
            permit: ctx
                .permit()
                .user_data::<Arc<SendSyncBoxValue<Value>>>()
                .cloned(),
        }
    }
}

impl TryIntoValue for SlotReleaseContextHolder {
    fn try_into_value(self, ruby: &Ruby) -> Result<Value, Error> {
        ruby.get_inner(&RELEASE_CONTEXT_CLASS).funcall(
            id!("new"),
            (
                // Slot info
                if let Some(slot_info) = self.slot_info {
                    Some(slot_info.try_into_value(ruby)?)
                } else {
                    None
                },
                // Permit
                self.permit
                    .map(|v| v.value(ruby))
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            ),
        )
    }
}

enum SlotInfoHolder {
    Workflow(WorkflowSlotInfo),
    Activity(ActivitySlotInfo),
    LocalActivity(LocalActivitySlotInfo),
    Nexus(NexusSlotInfo),
}

impl SlotInfoHolder {
    fn new(slot_info: SlotInfo) -> Self {
        match slot_info {
            SlotInfo::Workflow(v) => SlotInfoHolder::Workflow(v.clone()),
            SlotInfo::Activity(v) => SlotInfoHolder::Activity(v.clone()),
            SlotInfo::LocalActivity(v) => SlotInfoHolder::LocalActivity(v.clone()),
            SlotInfo::Nexus(v) => SlotInfoHolder::Nexus(v.clone()),
        }
    }
}

impl TryIntoValue for SlotInfoHolder {
    fn try_into_value(self, ruby: &Ruby) -> Result<Value, Error> {
        match self {
            SlotInfoHolder::Workflow(v) => {
                ruby.get_inner(&SLOT_INFO_WORKFLOW_CLASS).funcall(
                    id!("new"),
                    (
                        // Workflow type
                        v.workflow_type,
                        // Sticky
                        v.is_sticky,
                    ),
                )
            }
            SlotInfoHolder::Activity(v) => {
                ruby.get_inner(&SLOT_INFO_ACTIVITY_CLASS).funcall(
                    id!("new"),
                    (
                        // Activity type
                        v.activity_type,
                    ),
                )
            }
            SlotInfoHolder::LocalActivity(v) => {
                ruby.get_inner(&SLOT_INFO_LOCAL_ACTIVITY_CLASS).funcall(
                    id!("new"),
                    (
                        // Activity type
                        v.activity_type,
                    ),
                )
            }
            SlotInfoHolder::Nexus(v) => ruby.get_inner(&SLOT_INFO_NEXUS_CLASS).funcall(
                id!("new"),
                (
                    // Service
                    v.service,
                    // Operation
                    v.operation,
                ),
            ),
        }
    }
}
