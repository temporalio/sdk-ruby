use std::sync::Arc;
use tokio::runtime::{Builder, Runtime as TokioRuntime};

#[derive(Clone)]
pub struct Runtime {
    pub tokio_runtime: Arc<TokioRuntime>
}

impl Runtime {
    pub fn new(thread_count: u8) -> Self {
        let tokio_runtime = Arc::new(
            Builder::new_multi_thread()
                .worker_threads(thread_count.into())
                .enable_all()
                .thread_name("core")
                .build()
                .expect("Unable to start a runtime")
        );

        Runtime { tokio_runtime }
    }
}
