use crate::worker::Response;
use std::sync::Arc;
use std::sync::mpsc::{channel, Sender, Receiver};
use tokio::runtime::{Builder, Runtime as TokioRuntime};

pub struct Runtime {
    pub tokio_runtime: Arc<TokioRuntime>,
    pub callback_tx: Sender<Response>,
    pub callback_rx: Receiver<Response>,
}

impl Runtime {
    pub fn new(thread_count: u8) -> Self {
        let (tx, rx): (Sender<Response>, Receiver<Response>) = channel();
        let tokio_runtime = Arc::new(
            Builder::new_multi_thread()
                .worker_threads(thread_count.into())
                .enable_all()
                .thread_name("core")
                .build()
                .expect("Unable to start a runtime")
        );

        Runtime { tokio_runtime, callback_tx: tx, callback_rx: rx }
    }
}
