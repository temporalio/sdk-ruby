use crate::connection::{Connection, ConnectionError};
use tokio::runtime::Builder;
use tokio::sync::{mpsc, oneshot};

#[derive(Debug)]
pub enum Request {
    Connect {
        host: String
    },
    Rpc {
        connection: Connection,
        method: String,
        bytes: Vec<u8>
    }
}

#[derive(Debug)]
pub enum Response {
    Empty {},
    Connection {
        connection: Connection
    },
    Rpc {
        bytes: Vec<u8>
    }
}

#[derive(Debug)]
pub enum ReactorError {
    ConnectionError(ConnectionError)
}

impl std::fmt::Display for ReactorError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ReactorError::ConnectionError(error) => write!(f, "{}", error),
        }
    }
}

impl From<ConnectionError> for ReactorError {
    fn from(err: ConnectionError) -> Self {
        ReactorError::ConnectionError(err)
    }
}

impl std::error::Error for ReactorError {}

pub type ReactorResult = Result<Response, ReactorError>;

/// A request wrapper which includes a channel for sending back the response
#[derive(Debug)]
struct Envelope {
    request: Request,
    channel: oneshot::Sender<ReactorResult>
}

async fn handle_request(request: Request, channel: oneshot::Sender<ReactorResult>) {
    match request {
        Request::Connect { host } => {
            let result = Connection::connect(host).await
                .map(|connection| { Response::Connection { connection: connection } })
                .map_err(|error| ReactorError::ConnectionError(error));

            channel.send(result);
        },
        Request::Rpc { mut connection, method, bytes } => {
            let result = connection.call(&method, bytes).await
                .map(|bytes| { Response::Rpc { bytes: bytes } })
                .map_err(|error| ReactorError::ConnectionError(error));

            channel.send(result);
        }
    }
}

fn start_loop(thread_count: usize, mut receiver: mpsc::UnboundedReceiver<Envelope>) {
    let runtime = Builder::new_multi_thread()
        .worker_threads(thread_count)
        .enable_all()
        .thread_name("core")
        .build()
        .unwrap();

    runtime.block_on(async move {
        while let Some(msg) = receiver.recv().await {
            tokio::spawn(handle_request(msg.request, msg.channel));
        }
    });
}

/// Responsible for processing requests asynchronously using an event loop
/// while exposing a synchronous interface to the callers

#[derive(Clone)]
pub struct Reactor {
    sender: mpsc::UnboundedSender<Envelope>,
}

impl Reactor {
    pub fn new(thread_count: usize) -> Reactor {
        let (tx, rx) = mpsc::unbounded_channel::<Envelope>();

        std::thread::spawn(move || start_loop(thread_count, rx));

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
