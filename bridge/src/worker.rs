use crate::connection::Client;
use crate::reactor::{Reactor, ReactorError, Request, Response};
use prost::Message;
use thiserror::Error;
use temporal_sdk_core_api::worker::{WorkerConfigBuilder, WorkerConfigBuilderError};
use tokio::runtime::{Runtime};
use std::sync::Arc;

#[derive(Error, Debug)]
pub enum WorkerError {
    #[error(transparent)]
    EncodeError(#[from] prost::EncodeError),

    #[error(transparent)]
    InvalidWorkerOptions(#[from] WorkerConfigBuilderError),

    #[error(transparent)]
    ReactorError(#[from] ReactorError),
}

pub struct Worker {
    worker: Arc<temporal_sdk_core::Worker>,
    reactor: Arc<Reactor>,
}

impl Worker {
    // TODO: Extend this to include full worker config
    pub fn create(runtime: Arc<Runtime>, client: &Client, namespace: &str, task_queue: &str) -> Result<Worker, WorkerError> {
        let reactor = Reactor::new(runtime);
        let config = WorkerConfigBuilder::default()
            .namespace(namespace)
            .task_queue(task_queue)
            .build()?;

        let request = Request::InitWorker { config, client: client.clone() };
        let response = reactor.process(request)?;

        if let Response::Worker { worker } = response {
            return Ok(Worker { worker: Arc::new(worker), reactor: Arc::new(reactor) })
        } else {
            panic!("Unexpected response type from reactor. Expected Response::Worker");
        }
    }

    pub fn poll_activity_task(&self) -> Result<Vec<u8>, WorkerError> {
        let request = Request::PollActivityTask { worker: self.worker.clone() };
        let response = self.reactor.process(request)?;

        if let Response::ActivityTask { task } = response {
            let mut bytes: Vec<u8> = Vec::with_capacity(task.encoded_len());
            task.encode(&mut bytes)?;
            return Ok(bytes)
        } else {
            panic!("Unexpected response type from reactor. Expected Response::ActivityTask");
        }
    }
}
