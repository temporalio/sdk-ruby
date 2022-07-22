use crate::worker::Response;
use rutie::Thread;
use std::sync::Arc;
use std::sync::mpsc::{channel, Sender, Receiver};
use tokio::runtime::{Builder, Runtime as TokioRuntime};

pub struct Runtime {
    pub tokio_runtime: Arc<TokioRuntime>,
    pub callback_tx: Sender<Response>,
    callback_rx: Receiver<Response>,
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

    // This function is expected to be called from a Ruby thread
    pub fn run_callback_loop(&self) {
        let poll = || { self.callback_rx.recv() };
        let unblock = || {
            self.callback_tx.send(Response::Shutdown {}).expect("Unable to close callback loop");
        };

        while let Ok(msg) = Thread::call_without_gvl(poll, Some(unblock)) {
            match msg {
                Response::Callback(callback) => callback(),
                Response::Shutdown => break,
            }
        };
    }
}
