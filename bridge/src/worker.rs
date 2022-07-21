use crate::connection::Client;
use crate::runtime::Runtime;
use prost::Message;
use std::sync::Arc;
use std::sync::mpsc::Sender;
use temporal_sdk_core::api::{Worker as WorkerTrait};
use temporal_sdk_core_api::worker::{WorkerConfigBuilder, WorkerConfigBuilderError};
use thiserror::Error;
use tokio::runtime::{Runtime as TokioRuntime};

#[derive(Error, Debug)]
pub enum WorkerError {
    #[error(transparent)]
    EncodeError(#[from] prost::EncodeError),

    #[error(transparent)]
    InvalidWorkerOptions(#[from] WorkerConfigBuilderError),

    #[error(transparent)]
    UnableToPollActivityTask(#[from] temporal_sdk_core::api::errors::PollActivityError),

    #[error("Unable to send a request. Channel is closed")]
    ChannelClosed(),
}

pub enum Response {
    Empty,
    Error {
        error: WorkerError,
        callback: WorkerCallback,
    },
    ActivityTask {
        bytes: Vec<u8>,
        callback: WorkerCallback,
    }
}

pub type WorkerResult = Result<Vec<u8>, WorkerError>;
type WorkerCallback = Box<dyn FnOnce(WorkerResult) + Send + 'static>;

async fn poll_activity_task_async(worker: Worker, callback: WorkerCallback) {
    let task = worker.core_worker.poll_activity_task().await;

    let response = match task {
        Ok(task) => {
            let mut bytes: Vec<u8> = Vec::with_capacity(task.encoded_len());
            task.encode(&mut bytes).expect("Unable to encode activity task protobuf");

            Response::ActivityTask { bytes, callback }
        },
        Err(e) => {
            Response::Error { error: WorkerError::UnableToPollActivityTask(e), callback }
        }
    };

    worker.callback_tx.send(response).expect("Unable to send a callback");
}

#[derive(Clone)]
pub struct Worker {
    core_worker: Arc<temporal_sdk_core::Worker>,
    tokio_runtime: Arc<TokioRuntime>,
    callback_tx: Sender<Response>,
}

impl Worker {
    // TODO: Extend this to include full worker config
    pub fn create(runtime: &Runtime, client: &Client, namespace: &str, task_queue: &str) -> Result<Worker, WorkerError> {
        let config = WorkerConfigBuilder::default()
            .namespace(namespace)
            .task_queue(task_queue)
            .build()?;

        let core_worker = runtime.tokio_runtime.block_on(async move {
            temporal_sdk_core::init_worker(config, client.clone())
        });

        return Ok(Worker {
            core_worker: Arc::new(core_worker),
            tokio_runtime: runtime.tokio_runtime.clone(),
            callback_tx: runtime.callback_tx.clone(),
        })
    }

    pub fn poll_activity_task<F>(&self, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        self.tokio_runtime.spawn(
            poll_activity_task_async(self.clone(), Box::new(callback))
        );

        Ok(())
    }
}
