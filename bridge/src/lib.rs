#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;
mod runtime;
mod worker;

use connection::Connection;
use once_cell::sync::OnceCell;
use runtime::Runtime;
use rutie::{
    Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM, Thread,
    NilClass
};
use std::cell::RefCell;
use std::sync::mpsc::{sync_channel, SyncSender, Receiver};
use temporal_sdk_core::{Logger, TelemetryOptionsBuilder};
use worker::{Response, Worker, WorkerResult};

const RUNTIME_THREAD_COUNT: u8 = 2;

fn raise_bridge_exception(message: &str) {
    VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(message)));
}

fn run_callback_loop(sender: SyncSender<Response>, receiver: &mut Receiver<Response>) {
    let unblock = || { sender.send(Response::Empty {}).expect("Unable to close callback loop"); };

    while let Ok(msg) = Thread::call_without_gvl(|| { receiver.recv() }, Some(unblock)) {
        match msg {
            Response::ActivityTask { bytes, callback } => callback(Ok(bytes)),
            Response::Error { error, callback } => callback(Err(error)),
            _ => panic!("Unsupported response type"),
        }
    }
}

fn start_callback_loop() -> &'static SyncSender<Response> {
    static CALLBACK_SENDER: OnceCell<SyncSender<Response>> = OnceCell::new();
    CALLBACK_SENDER.get_or_init(|| {
        let (tx, rx): (SyncSender<Response>, Receiver<Response>) = sync_channel(1);
        let rx = RefCell::new(rx);
        let return_tx = tx.clone();

        // Ruby callbacks can only be executed from a Ruby thread, therefore
        // we're using rutie::Thread here instead of the std::thread
        Thread::new(move || {
            run_callback_loop(tx.clone(), &mut rx.borrow_mut());
            NilClass::new()
        });

        return_tx
    })
}

fn wrap_bytes(bytes: &Vec<u8>) -> AnyObject {
    let enc = Encoding::find("ASCII-8BIT").unwrap();
    RString::from_bytes(bytes, &enc).to_any_object()
}

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);
wrappable_struct!(Runtime, RuntimeWrapper, RUNTIME_WRAPPER);
wrappable_struct!(Worker, WorkerWrapper, WORKER_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    rtself,

    fn create_connection(runtime: AnyObject, host: RString) -> AnyObject {
        let host = host.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);

        let result = Thread::call_without_gvl(move || {
            Connection::connect(runtime.tokio_runtime.clone(), host.clone())
        }, Some(|| {}));

        let connection = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        Module::from_existing("Temporal")
            .get_nested_module("Bridge")
            .get_nested_class("Connection")
            .wrap_data(connection, &*CONNECTION_WRAPPER)
    }

    fn call_rpc(rpc: Symbol, request: RString) -> RString {
        let rpc = rpc.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let request = request.map_err(|e| VM::raise_ex(e)).unwrap().to_string().as_bytes().to_vec();

        let result = Thread::call_without_gvl(move || {
            let connection = rtself.get_data_mut(&*CONNECTION_WRAPPER);
            connection.call(&rpc, request.clone())
        }, Some(|| {}));

        let response = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        let enc = Encoding::find("ASCII-8BIT").unwrap();
        RString::from_bytes(&response, &enc)
    }

    // TODO: Add telemetry configuration to this interface
    fn init_telemetry() -> NilClass {
        let telemetry_config = TelemetryOptionsBuilder::default()
            .tracing_filter("temporal_sdk_core=DEBUG".to_string())
            .logging(Logger::Console)
            .build()
            .map_err(|e| raise_bridge_exception(&e.to_string()))
            .unwrap();

        temporal_sdk_core::telemetry_init(&telemetry_config)
            .expect("Unable to initialize telemetry");

        NilClass::new()
    }

    fn init_runtime() -> AnyObject {
        let runtime = Runtime::new(RUNTIME_THREAD_COUNT);

        Module::from_existing("Temporal")
            .get_nested_module("Bridge")
            .get_nested_class("Runtime")
            .wrap_data(runtime, &*RUNTIME_WRAPPER)
    }

    fn create_worker(runtime: AnyObject, connection: AnyObject, namespace: RString, task_queue: RString) -> AnyObject {
        let callback_sender = start_callback_loop();
        let namespace = namespace.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let task_queue = task_queue.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);
        let connection = connection.unwrap();
        let connection = connection.get_data(&*CONNECTION_WRAPPER);
        let worker = Worker::create(runtime.tokio_runtime.clone(), &connection.client, callback_sender.clone(), &namespace, &task_queue);

        Module::from_existing("Temporal")
            .get_nested_module("Bridge")
            .get_nested_class("Worker")
            .wrap_data(worker.unwrap(), &*WORKER_WRAPPER)
    }

    fn worker_poll_activity_task() -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #poll_activity_task without a block");
        }

        let ruby_callback = VM::block_proc();

        let callback = move |result: WorkerResult| {
            let bytes = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();
            ruby_callback.call(&[wrap_bytes(&bytes)]);
        };

        let worker = rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.poll_activity_task(callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }
);

#[no_mangle]
pub extern "C" fn init_bridge() {
    Module::from_existing("Temporal").get_nested_module("Bridge").define(|module| {
        module.def_self("init_telemetry", init_telemetry);

        module.define_nested_class("Runtime", None).define(|klass| {
            klass.def_self("init", init_runtime);
        });

        module.define_nested_class("Connection", None).define(|klass| {
            klass.def_self("connect", create_connection);
            klass.def("call", call_rpc);
        });

        module.define_nested_class("Worker", None).define(|klass| {
            klass.def_self("create", create_worker);
            klass.def("poll_activity_task", worker_poll_activity_task);
        });
    });
}
