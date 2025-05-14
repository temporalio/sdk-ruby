use std::{
    cell::RefCell,
    collections::{HashMap, HashSet},
    sync::Arc,
    time::Duration,
};

use crate::{
    client::Client,
    enter_sync, error, id, new_error,
    runtime::{AsyncCommand, Runtime, RuntimeHandle},
    util::{AsyncCallback, Struct},
    ROOT_MOD,
};
use futures::{future, stream};
use futures::{stream::BoxStream, StreamExt};
use magnus::{
    class, function, method, prelude::*, typed_data, DataTypeFunctions, Error, IntoValue, RArray,
    RString, RTypedData, Ruby, TypedData, Value,
};
use prost::Message;
use temporal_sdk_core::{
    replay::{HistoryForReplay, ReplayWorkerInput},
    ResourceBasedSlotsOptions, ResourceBasedSlotsOptionsBuilder, ResourceSlotOptions,
    SlotSupplierOptions, TunerHolder, TunerHolderOptionsBuilder, WorkerConfig, WorkerConfigBuilder,
};
use temporal_sdk_core_api::{
    errors::{PollError, WorkflowErrorType},
    worker::{
        PollerBehavior, SlotKind, WorkerDeploymentOptions, WorkerDeploymentVersion,
        WorkerVersioningStrategy,
    },
};
use temporal_sdk_core_protos::coresdk::workflow_completion::WorkflowActivationCompletion;
use temporal_sdk_core_protos::coresdk::{ActivityHeartbeat, ActivityTaskCompletion};
use temporal_sdk_core_protos::temporal::api::history::v1::History;
use tokio::sync::mpsc::{channel, Sender};
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
    core: RefCell<Option<Arc<temporal_sdk_core::Worker>>>,
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
        enter_sync!(client.runtime_handle);

        let activity = options.member::<bool>(id!("activity"))?;
        let workflow = options.member::<bool>(id!("workflow"))?;

        let worker = temporal_sdk_core::init_worker(
            &client.runtime_handle.core,
            build_config(options)?,
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
        worker: Arc<temporal_sdk_core::Worker>,
        worker_index: usize,
        worker_type: WorkerType,
    ) -> BoxStream<'a, PollResult> {
        stream::unfold(Some(worker.clone()), move |worker| async move {
            // We return no worker so the next streamed item closes
            // the stream with a None
            if let Some(worker) = worker {
                let result = match worker_type {
                    WorkerType::Activity => {
                        match temporal_sdk_core_api::Worker::poll_activity_task(&*worker).await {
                            Ok(res) => Ok(Some(res.encode_to_vec())),
                            Err(PollError::ShutDown) => Ok(None),
                            Err(err) => Err(format!("Poll error: {}", err)),
                        }
                    }
                    WorkerType::Workflow => {
                        match temporal_sdk_core_api::Worker::poll_workflow_activation(&*worker)
                            .await
                        {
                            Ok(res) => Ok(Some(res.encode_to_vec())),
                            Err(PollError::ShutDown) => Ok(None),
                            Err(err) => Err(format!("Poll error: {}", err)),
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
                Ok(temporal_sdk_core_api::Worker::finalize_shutdown(worker))
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
            async move { temporal_sdk_core_api::Worker::validate(&*worker).await },
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
                temporal_sdk_core_api::Worker::complete_activity_task(&*worker, completion).await
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
        temporal_sdk_core_api::Worker::record_activity_heartbeat(&*worker, heartbeat);
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
                temporal_sdk_core_api::Worker::complete_workflow_activation(&*worker, completion)
                    .await
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
        worker.replace_client(client.core.clone().into_inner());
        Ok(())
    }

    pub fn initiate_shutdown(&self) -> Result<(), Error> {
        enter_sync!(self.runtime_handle);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        temporal_sdk_core_api::Worker::initiate_shutdown(&*worker);
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

        let core_worker = temporal_sdk_core::init_replay_worker(ReplayWorkerInput::new(
            build_config(options)?,
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

fn build_config(options: Struct) -> Result<WorkerConfig, Error> {
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
        .workflow_task_poller_behavior(PollerBehavior::SimpleMaximum(
            options.member::<usize>(id!("max_concurrent_workflow_task_polls"))?,
        ))
        .nonsticky_to_sticky_poll_ratio(
            options.member::<f32>(id!("nonsticky_to_sticky_poll_ratio"))?,
        )
        .activity_task_poller_behavior(PollerBehavior::SimpleMaximum(
            options.member::<usize>(id!("max_concurrent_activity_task_polls"))?,
        ))
        .no_remote_activities(options.member::<bool>(id!("no_remote_activities"))?)
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
        .build()
        .map_err(|err| error!("Invalid worker options: {}", err))
}

fn build_tuner(options: Struct) -> Result<TunerHolder, Error> {
    let (workflow_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("workflow_slot_supplier"))?
            .ok_or_else(|| error!("Missing workflow slot options"))?,
        None,
    )?;
    let (activity_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("activity_slot_supplier"))?
            .ok_or_else(|| error!("Missing activity slot options"))?,
        resource_slot_options,
    )?;
    let (local_activity_slot_options, resource_slot_options) = build_tuner_slot_options(
        options
            .child(id!("local_activity_slot_supplier"))?
            .ok_or_else(|| error!("Missing local activity slot options"))?,
        resource_slot_options,
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

fn build_tuner_slot_options<SK: SlotKind>(
    options: Struct,
    prev_slots_options: Option<ResourceBasedSlotsOptions>,
) -> Result<(SlotSupplierOptions<SK>, Option<ResourceBasedSlotsOptions>), Error> {
    if let Some(slots) = options.member::<Option<usize>>(id!("fixed_size"))? {
        Ok((SlotSupplierOptions::FixedSize { slots }, prev_slots_options))
    } else if let Some(resource) = options.child(id!("resource_based"))? {
        build_tuner_resource_options(resource, prev_slots_options)
    } else {
        Err(error!("Slot supplier must be fixed size or resource based"))
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
    if let Some(prev_slots_options) = prev_slots_options {
        if slots_options.target_cpu_usage != prev_slots_options.target_cpu_usage
            || slots_options.target_mem_usage != prev_slots_options.target_mem_usage
        {
            return Err(error!(
                "All resource-based slot suppliers must have the same resource-based tuner options"
            ));
        }
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
