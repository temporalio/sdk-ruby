use rutie::Thread;
use std::sync::Arc;
use std::sync::mpsc::{channel, Sender, Receiver};
use tokio::runtime::{Builder, Runtime as TokioRuntime};

pub type Callback = Box<dyn FnOnce() + Send + 'static>;

pub enum Command {
    RunCallback(Callback),
    Shutdown,
}

pub struct Runtime {
    pub tokio_runtime: Arc<TokioRuntime>,
    pub callback_tx: Sender<Command>,
    callback_rx: Receiver<Command>,
}

impl Runtime {
    pub fn new(thread_count: u8) -> Self {
        let (tx, rx): (Sender<Command>, Receiver<Command>) = channel();
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
        let unblock = || {
            self.callback_tx.send(Command::Shutdown {}).expect("Unable to close callback loop");
        };

        while let Ok(msg) = Thread::call_without_gvl(|| self.callback_rx.recv(), Some(unblock)) {
            match msg {
                Command::RunCallback(callback) => callback(),
                Command::Shutdown => break,
            }
        };
    }
}
