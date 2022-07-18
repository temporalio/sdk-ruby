use crate::connection::Client;
use once_cell::sync::OnceCell;
use prost::Message;
use std::sync::Arc;
use std::sync::mpsc::SyncSender;
use temporal_sdk_core::api::{Worker as WorkerTrait};
use temporal_sdk_core_api::worker::{WorkerConfigBuilder, WorkerConfigBuilderError};
use thiserror::Error;
use tokio::runtime::{Runtime};
use tokio::sync::{mpsc as tokio_mpsc};

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

enum Request {
    PollActivityTask {
        core_worker: Arc<temporal_sdk_core::Worker>,
        callback: WorkerCallback,
    },
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

async fn handle_request(request: Request, outer_channel: SyncSender<Response>) {
    match request {
        Request::PollActivityTask { core_worker, callback } => {
            let task = core_worker.poll_activity_task().await;

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

            outer_channel.send(response).expect("Unable to send a callback");
        },
    }
}

fn run_reactor_loop(runtime: Arc<Runtime>, mut receiver: tokio_mpsc::UnboundedReceiver<Request>, outer_sender: SyncSender<Response>) {
    runtime.block_on(async move {
        while let Some(request) = receiver.recv().await {
            tokio::spawn(handle_request(request, outer_sender.clone()));
        }
    });
}

fn reactor(runtime: Arc<Runtime>, outer_sender: SyncSender<Response>) -> &'static tokio_mpsc::UnboundedSender<Request> {
    static REACTOR: OnceCell<tokio_mpsc::UnboundedSender<Request>> = OnceCell::new();
    REACTOR.get_or_init(|| {
        let (tx, rx) = tokio_mpsc::unbounded_channel::<Request>();

        std::thread::spawn(move || run_reactor_loop(runtime, rx, outer_sender));

        tx
    })
}

#[derive(Clone)]
pub struct Worker {
    core_worker: Arc<temporal_sdk_core::Worker>,
    inner_sender: tokio_mpsc::UnboundedSender<Request>,
}

impl Worker {
    // TODO: Extend this to include full worker config
    pub fn create(runtime: Arc<Runtime>, client: &Client, callback_sender: SyncSender<Response>, namespace: &str, task_queue: &str) -> Result<Worker, WorkerError> {
        let config = WorkerConfigBuilder::default()
            .namespace(namespace)
            .task_queue(task_queue)
            .build()?;

        let core_worker = runtime.block_on(async move {
            temporal_sdk_core::init_worker(config, client.clone())
        });

        let inner_sender = reactor(runtime, callback_sender);

        return Ok(Worker {
            core_worker: Arc::new(core_worker),
            inner_sender: inner_sender.clone()
        })
    }

    pub fn poll_activity_task<F>(&self, callback: F) -> Result<(), WorkerError> where F: FnOnce(WorkerResult) + Send + 'static {
        let request = Request::PollActivityTask {
            core_worker: self.core_worker.clone(),
            callback: Box::new(callback)
        };

        self.inner_sender.send(request).map_err(|_e| WorkerError::ChannelClosed())?;

        Ok(())
    }
}
