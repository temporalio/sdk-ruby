use crate::connection::Client;
use temporal_sdk_core::api::{errors, Worker};
use temporal_sdk_core_protos::coresdk::activity_task::ActivityTask;
use thiserror::Error;
use tokio::runtime::{Runtime};
use tokio::sync::{mpsc, oneshot};
use std::sync::Arc;

pub enum Request {
    InitWorker {
      config: temporal_sdk_core::WorkerConfig,
      client: Client
    },
    PollActivityTask {
        worker: Arc<temporal_sdk_core::Worker>
    },
}

pub enum Response {
    Worker {
      worker: temporal_sdk_core::Worker
    },
    ActivityTask {
      task: ActivityTask
    }
}

#[derive(Error, Debug)]
pub enum ReactorError {
    #[error(transparent)]
    UnableToPollActivityTask(errors::PollActivityError),
}

impl std::fmt::Debug for Response {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "We have a response")
    }
}

pub type ReactorResult = Result<Response, ReactorError>;

/// A request wrapper which includes a channel for sending back the response
struct Envelope {
    request: Request,
    channel: oneshot::Sender<ReactorResult>
}

impl std::fmt::Debug for Envelope {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "We have an envelope")
    }
}

async fn handle_request(request: Request, channel: oneshot::Sender<ReactorResult>) {
    match request {
        Request::InitWorker { config, client } => {
            let worker = temporal_sdk_core::init_worker(config, client.into_inner());

            let response = Response::Worker { worker };

            channel.send(Ok(response)).expect("Reactor was unable to send a response via channel");
        },
        Request::PollActivityTask { worker } => {
            let result = (&*worker).poll_activity_task().await
                .map(|task| Response::ActivityTask { task })
                .map_err(|e| ReactorError::UnableToPollActivityTask(e));

            channel.send(result).expect("Reactor was unable to send a response via channel");
        },
    }
}

fn start_loop(runtime: Arc<Runtime>, mut receiver: mpsc::UnboundedReceiver<Envelope>) {
    runtime.block_on(async move {
        while let Some(msg) = receiver.recv().await {
            tokio::spawn(handle_request(msg.request, msg.channel));
        }
    });
}

/// Responsible for processing requests asynchronously using an event loop
/// while exposing a synchronous interface to the callers
pub struct Reactor {
    sender: mpsc::UnboundedSender<Envelope>,
}

impl Reactor {
    pub fn new(runtime: Arc<Runtime>) -> Reactor {
        let (tx, rx) = mpsc::unbounded_channel::<Envelope>();

        std::thread::spawn(move || start_loop(runtime, rx));

        Reactor { sender: tx }
    }

    pub fn process(&self, request: Request) -> ReactorResult {
        // Create a one-off channel to communicate the result back
        let (tx, rx) = oneshot::channel();
        let envelope = Envelope { request, channel: tx };

        self.sender.send(envelope).expect("The shared runtime has shut down.");

        // Block until a result is sent back (the timing is determined by the task handler)
        let response = rx.blocking_recv();

        response.expect("Error while receiving a message from the reactor")
    }
}
