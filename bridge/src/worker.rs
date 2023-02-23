use crate::connection::Client;
use crate::runtime::{Callback, Command, Runtime};
use prost::Message;
use std::sync::Arc;
use std::sync::mpsc::Sender;
use temporal_sdk_core::api::{Worker as WorkerTrait};
use temporal_sdk_core_api::errors::{PollActivityError, PollWfError};
use temporal_sdk_core_api::worker::{WorkerConfigBuilder, WorkerConfigBuilderError};
use temporal_sdk_core_protos::coresdk::{ActivityHeartbeat, ActivityTaskCompletion};
use temporal_sdk_core_protos::coresdk::workflow_completion::{WorkflowActivationCompletion};
use thiserror::Error;
use tokio::runtime::{Runtime as TokioRuntime};

#[derive(Error, Debug)]
pub enum WorkerError {
    #[error(transparent)]
    EncodeError(#[from] prost::EncodeError),

    #[error(transparent)]
    DecodeError(#[from] prost::DecodeError),

    #[error(transparent)]
    InvalidWorkerOptions(#[from] WorkerConfigBuilderError),

    #[error(transparent)]
    UnableToPollActivityTask(#[from] temporal_sdk_core::api::errors::PollActivityError),

    #[error(transparent)]
    UnableToPollWorkflowActivation(#[from] temporal_sdk_core::api::errors::PollWfError),

    #[error(transparent)]
    UnableToCompleteActivityTask(#[from] temporal_sdk_core::api::errors::CompleteActivityError),

    #[error(transparent)]
    UnableToCompleteWorkflowActivation(#[from] temporal_sdk_core::api::errors::CompleteWfError),

    #[error("Unable to send a request. Channel is closed")]
    ChannelClosed(),

    #[error("Core worker is shutting down")]
    Shutdown(),
}

pub type WorkerResult = Result<Vec<u8>, WorkerError>;

pub struct Worker {
    core_worker: Arc<temporal_sdk_core::Worker>,
    tokio_runtime: Arc<TokioRuntime>,
    callback_tx: Sender<Command>,
}

impl Worker {
    // TODO: Extend this to include full worker config
    pub fn new(runtime: &Runtime, client: &Client, namespace: &str, task_queue: &str, max_cached_workflows: u32, no_remote_activity: bool) -> Result<Worker, WorkerError> {
        let config = WorkerConfigBuilder::default()
            .namespace(namespace)
            .task_queue(task_queue)
            .worker_build_id("test-worker-build") // TODO: replace this with an actual build id
            .max_cached_workflows(usize::try_from(max_cached_workflows).unwrap())
            .no_remote_activities(no_remote_activity)
            .build()?;

        let core_worker = runtime.tokio_runtime.block_on(async move {
            temporal_sdk_core::init_worker(&runtime.core_runtime, config, client.clone())
        }).expect("Failed to initialize Core Worker");

        Ok(Worker {
            core_worker: Arc::new(core_worker),
            tokio_runtime: runtime.tokio_runtime.clone(),
            callback_tx: runtime.callback_tx.clone(),
        })
    }

    pub fn poll_activity_task<F>(&self, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        let core_worker = self.core_worker.clone();
        let callback_tx = self.callback_tx.clone();

        self.tokio_runtime.spawn(async move {
            let result = core_worker.poll_activity_task().await;

            let callback: Callback = match result {
                Ok(task) => {
                    let bytes = task.encode_to_vec();
                    Box::new(move || callback(Ok(bytes)))
                },
                Err(PollActivityError::ShutDown) => Box::new(move || callback(Err(WorkerError::Shutdown()))),
                Err(e) => Box::new(move || callback(Err(WorkerError::UnableToPollActivityTask(e))))
            };

            callback_tx.send(Command::RunCallback(callback)).expect("Unable to send a callback");
        });

        Ok(())
    }

    pub fn complete_activity_task<F>(&self, bytes: Vec<u8>, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        let core_worker = self.core_worker.clone();
        let callback_tx = self.callback_tx.clone();
        let proto = ActivityTaskCompletion::decode(&*bytes)?;

        self.tokio_runtime.spawn(async move {
            let result = core_worker.complete_activity_task(proto).await;

            let callback: Callback = match result {
                Ok(()) => Box::new(move || callback(Ok(vec!()))),
                Err(e) => Box::new(move || callback(Err(WorkerError::UnableToCompleteActivityTask(e))))
            };

            callback_tx.send(Command::RunCallback(callback)).expect("Unable to send a callback");
        });

        Ok(())
    }

    pub fn record_activity_heartbeat(&self, bytes: Vec<u8>) -> Result<(), WorkerError> {
        let proto = ActivityHeartbeat::decode(&*bytes)?;
        self.core_worker.record_activity_heartbeat(proto);

        Ok(())
    }

    pub fn poll_workflow_activation<F>(&self, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        let core_worker = self.core_worker.clone();
        let callback_tx = self.callback_tx.clone();

        self.tokio_runtime.spawn(async move {
            let result = core_worker.poll_workflow_activation().await;

            let callback: Callback = match result {
                Ok(task) => {
                    let bytes = task.encode_to_vec();
                    Box::new(move || callback(Ok(bytes)))
                },
                Err(PollWfError::ShutDown) => Box::new(move || callback(Err(WorkerError::Shutdown()))),
                Err(e) => Box::new(move || callback(Err(WorkerError::UnableToPollWorkflowActivation(e))))
            };

            callback_tx.send(Command::RunCallback(callback)).expect("Unable to send a callback");
        });

        Ok(())
    }

    pub fn complete_workflow_activation<F>(&self, bytes: Vec<u8>, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        let core_worker = self.core_worker.clone();
        let callback_tx = self.callback_tx.clone();
        let proto = WorkflowActivationCompletion::decode(&*bytes)?;

        self.tokio_runtime.spawn(async move {
            let result = core_worker.complete_workflow_activation(proto).await;

            let callback: Callback = match result {
                Ok(()) => Box::new(move || callback(Ok(vec!()))),
                Err(e) => Box::new(move || callback(Err(WorkerError::UnableToCompleteWorkflowActivation(e))))
            };

            callback_tx.send(Command::RunCallback(callback)).expect("Unable to send a callback");
        });

        Ok(())
    }

    pub fn initiate_shutdown(&self) {
        self.core_worker.initiate_shutdown();
    }

    // FIXME: Replace with finalize_shutdown()
    pub fn shutdown(&self) {
        let core_worker = self.core_worker.clone();

        self.tokio_runtime.block_on(async move {
            core_worker.shutdown().await;
        });
    }
}
