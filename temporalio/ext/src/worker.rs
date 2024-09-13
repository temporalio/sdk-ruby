use std::{cell::RefCell, sync::Arc, time::Duration};

use crate::{
    client::Client,
    error, id, new_error,
    runtime::{AsyncCommand, RuntimeHandle},
    util::Struct,
    ROOT_MOD,
};
use futures::StreamExt;
use futures::{future, stream};
use magnus::{
    class, function, method, prelude::*, typed_data, value::Opaque, DataTypeFunctions, Error,
    RArray, RString, RTypedData, Ruby, TypedData, Value,
};
use prost::Message;
use temporal_sdk_core::{
    ResourceBasedSlotsOptions, ResourceBasedSlotsOptionsBuilder, ResourceSlotOptions,
    SlotSupplierOptions, TunerHolder, TunerHolderOptionsBuilder, WorkerConfigBuilder,
};
use temporal_sdk_core_api::errors::PollActivityError;
use temporal_sdk_core_protos::coresdk::{ActivityHeartbeat, ActivityTaskCompletion};

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let class = ruby
        .get_inner(&ROOT_MOD)
        .define_class("Worker", class::object())?;
    class.define_singleton_method("new", function!(Worker::new, 2))?;
    class.define_singleton_method("async_poll_all", function!(Worker::async_poll_all, 1))?;
    class.define_singleton_method(
        "async_finalize_all",
        function!(Worker::async_finalize_all, 1),
    )?;
    class.define_method("async_validate", method!(Worker::async_validate, 0))?;
    class.define_method(
        "async_complete_activity_task",
        method!(Worker::async_complete_activity_task, 1),
    )?;
    class.define_method(
        "record_activity_heartbeat",
        method!(Worker::record_activity_heartbeat, 1),
    )?;
    class.define_method("replace_client", method!(Worker::replace_client, 1))?;
    class.define_method("initiate_shutdown", method!(Worker::initiate_shutdown, 0))?;
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
    _workflow: bool,
}

macro_rules! enter_sync {
    ($runtime:expr) => {
        if let Some(subscriber) = $runtime.core.telemetry().trace_subscriber() {
            temporal_sdk_core::telemetry::set_trace_subscriber_for_current_thread(subscriber);
        }
        let _guard = $runtime.core.tokio_handle().enter();
    };
}

enum WorkerType {
    Activity,
}

impl Worker {
    pub fn new(client: &Client, options: Struct) -> Result<Self, Error> {
        enter_sync!(client.runtime_handle);
        let activity = options.member::<bool>(id!("activity"))?;
        let _workflow = options.member::<bool>(id!("workflow"))?;
        // Build config
        let config = WorkerConfigBuilder::default()
            .namespace(options.member::<String>(id!("namespace"))?)
            .task_queue(options.member::<String>(id!("task_queue"))?)
            .worker_build_id(options.member::<String>(id!("build_id"))?)
            .client_identity_override(options.member::<Option<String>>(id!("identity_override"))?)
            .max_cached_workflows(options.member::<usize>(id!("max_cached_workflows"))?)
            .max_concurrent_wft_polls(
                options.member::<usize>(id!("max_concurrent_workflow_task_polls"))?,
            )
            .nonsticky_to_sticky_poll_ratio(
                options.member::<f32>(id!("nonsticky_to_sticky_poll_ratio"))?,
            )
            .max_concurrent_at_polls(
                options.member::<usize>(id!("max_concurrent_activity_task_polls"))?,
            )
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
            .use_worker_versioning(options.member::<bool>(id!("use_worker_versioning"))?)
            .tuner(Arc::new(build_tuner(
                options
                    .child(id!("tuner"))?
                    .ok_or_else(|| error!("Missing tuner"))?,
            )?))
            // TODO(cretz): workflow_failure_errors
            // TODO(cretz): workflow_types_to_failure_errors
            .build()
            .map_err(|err| error!("Invalid worker options: {}", err))?;

        let worker = temporal_sdk_core::init_worker(
            &client.runtime_handle.core,
            config,
            client.core.clone().into_inner(),
        )
        .map_err(|err| error!("Failed creating worker: {}", err))?;
        Ok(Worker {
            core: RefCell::new(Some(Arc::new(worker))),
            runtime_handle: client.runtime_handle.clone(),
            activity,
            _workflow,
        })
    }

    pub fn async_poll_all(ruby: &Ruby, workers: RArray) -> Result<(), Error> {
        // Get the first runtime handle
        let runtime = workers
            .entry::<typed_data::Obj<Worker>>(0)?
            .runtime_handle
            .clone();

        // Create stream of poll calls
        // TODO(cretz): Map for workflow pollers too
        let worker_streams = workers
            .into_iter()
            .enumerate()
            .map(|(index, worker_val)| {
                let worker_typed_data = RTypedData::from_value(worker_val).expect("Not typed data");
                let worker_ref = worker_typed_data.get::<Worker>().expect("Not worker");
                if worker_ref.activity {
                    let index = index;
                    let worker = Some(
                        worker_ref
                            .core
                            .borrow()
                            .as_ref()
                            .expect("Unable to borrow")
                            .clone(),
                    );
                    Some(Box::pin(stream::unfold(worker, move |worker| async move {
                        // We return no worker so the next streamed item closes
                        // the stream with a None
                        if let Some(worker) = worker {
                            let res =
                                temporal_sdk_core_api::Worker::poll_activity_task(&*worker).await;
                            let shutdown_next = matches!(res, Err(PollActivityError::ShutDown));
                            Some((
                                (index, WorkerType::Activity, res),
                                // No more worker if shutdown
                                if shutdown_next { None } else { Some(worker) },
                            ))
                        } else {
                            None
                        }
                    })))
                } else {
                    None
                }
            })
            .filter_map(|v| v)
            .collect::<Vec<_>>();
        let mut worker_stream = stream::select_all(worker_streams);

        // Continually call the block with the worker and the result. The result can either be:
        // * [worker index, :activity/:workflow, bytes] - poll success
        // * [worker index, :activity/:workflow, error] - poll fail
        // * [worker index, :activity/:workflow, nil] - worker shutdown
        // * [nil, nil, nil] - all pollers done
        let block = Opaque::from(ruby.block_proc()?);
        let async_command_tx = runtime.async_command_tx.clone();
        runtime.spawn(
            async move {
                // Get next item from the stream
                while let Some((worker, worker_type, result)) = worker_stream.next().await {
                    // Encode result and send callback to Ruby
                    let result = result.map(|v| v.encode_to_vec());
                    let _ = async_command_tx.send(AsyncCommand::RunCallback(Box::new(move || {
                        // Get Ruby in callback
                        let ruby = Ruby::get().expect("Ruby not available");
                        let block = ruby.get_inner(block);
                        let worker_type = match worker_type {
                            WorkerType::Activity => id!("activity"),
                        };
                        // Call block
                        let _: Value = match result {
                            Ok(val) => {
                                block.call((worker, worker_type, RString::from_slice(&val)))?
                            }
                            Err(PollActivityError::ShutDown) => {
                                block.call((worker, worker_type, ruby.qnil()))?
                            }
                            Err(err) => block.call((
                                worker,
                                worker_type,
                                new_error!("Poll failure: {}", err),
                            ))?,
                        };
                        Ok(())
                    })));
                }
                ()
            },
            move |ruby, _| {
                // Call with nil, nil, nil to say done
                let _: Value = ruby.get_inner(block).call((ruby.qnil(), ruby.qnil(), ruby.qnil()))?;
                Ok(())
            },
        );
        Ok(())
    }

    pub fn async_finalize_all(ruby: &Ruby, workers: RArray) -> Result<(), Error> {
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
        let block = Opaque::from(ruby.block_proc()?);
        runtime.spawn(
            async move {
                // Run all futures and return errors
                future::join_all(futs).await;
                errs
            },
            move |ruby, errs| {
                let block = ruby.get_inner(block);
                let _: Value = if errs.len() == 0 {
                    block.call((ruby.qnil(),))?
                } else {
                    block.call((new_error!(
                        "{} worker(s) failed to finalize, reasons: {}",
                        errs.len(),
                        errs.join(", ")
                    ),))?
                };
                Ok(())
            },
        );
        Ok(())
    }

    pub fn async_validate(&self) -> Result<(), Error> {
        let ruby = Ruby::get().expect("Not in Ruby thread");
        let block = Opaque::from(ruby.block_proc()?);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        self.runtime_handle.spawn(
            async move { temporal_sdk_core_api::Worker::validate(&*worker).await },
            move |ruby, result| {
                let block = ruby.get_inner(block);
                let _: Value = match result {
                    Ok(()) => block.call((ruby.qnil(),))?,
                    Err(err) => block.call((new_error!("Failed validating worker: {}", err),))?,
                };
                Ok(())
            },
        );
        Ok(())
    }

    pub fn async_complete_activity_task(&self, proto: RString) -> Result<(), Error> {
        let ruby = Ruby::get().expect("Not in Ruby thread");
        let block = Opaque::from(ruby.block_proc()?);
        let worker = self.core.borrow().as_ref().unwrap().clone();
        let completion = ActivityTaskCompletion::decode(unsafe { proto.as_slice() })
            .map_err(|err| error!("Invalid proto: {}", err))?;
        self.runtime_handle.spawn(
            async move {
                temporal_sdk_core_api::Worker::complete_activity_task(&*worker, completion).await
            },
            move |ruby, result| {
                let block = ruby.get_inner(block);
                let _: Value = match result {
                    Ok(()) => block.call((ruby.qnil(),))?,
                    Err(err) => block.call((new_error!("Completion failure: {}", err),))?,
                };
                Ok(())
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

fn build_tuner_slot_options(
    options: Struct,
    prev_slots_options: Option<ResourceBasedSlotsOptions>,
) -> Result<(SlotSupplierOptions, Option<ResourceBasedSlotsOptions>), Error> {
    if let Some(slots) = options.member::<Option<usize>>(id!("fixed_size"))? {
        Ok((SlotSupplierOptions::FixedSize { slots }, prev_slots_options))
    } else if let Some(resource) = options.child(id!("resource_based"))? {
        build_tuner_resource_options(resource, prev_slots_options)
    } else {
        Err(error!("Slot supplier must be fixed size or resource based"))
    }
}

fn build_tuner_resource_options(
    options: Struct,
    prev_slots_options: Option<ResourceBasedSlotsOptions>,
) -> Result<(SlotSupplierOptions, Option<ResourceBasedSlotsOptions>), Error> {
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
