#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;
mod runtime;
mod worker;

use connection::{Connection, RpcParams};
use runtime::Runtime;
use rutie::{
    Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM, Thread,
    NilClass, Hash, Integer,
};
use std::collections::HashMap;
use temporal_sdk_core::{Logger, TelemetryOptionsBuilder};
use worker::{Worker, WorkerResult};

const RUNTIME_THREAD_COUNT: u8 = 2;

fn raise_bridge_exception(message: &str) {
    VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(message)));
}

fn wrap_bytes(bytes: Vec<u8>) -> RString {
    let enc = Encoding::find("ASCII-8BIT").unwrap();
    RString::from_bytes(&bytes, &enc)
}

fn unwrap_bytes(string: RString) -> Vec<u8> {
    // It is important to use the _unchecked conversion, otherwise Rutie
    // will assume incorrect encoding and screw up the encoded proto
    string.to_vec_u8_unchecked()
}

fn to_hash_map(hash: Hash) -> HashMap<String, String> {
    let mut result = HashMap::new();

    hash.each(|k, v| {
        result.insert(
            k.try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string(),
            v.try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string()
        );
    });

    result
}

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);
wrappable_struct!(Runtime, RuntimeWrapper, RUNTIME_WRAPPER);
wrappable_struct!(Worker, WorkerWrapper, WORKER_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    _rtself, // somehow compiler is sure this is unused and insists on the "_"

    fn create_connection(runtime: AnyObject, host: RString) -> AnyObject {
        let host = host.map_err(VM::raise_ex).unwrap().to_string();
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

    fn call_rpc(rpc: Symbol, request: RString, metadata: Hash, timeout: Integer) -> RString {
        let rpc = rpc.map_err(VM::raise_ex).unwrap().to_string();
        let request = unwrap_bytes(request.map_err(VM::raise_ex).unwrap());
        let metadata = to_hash_map(metadata.map_err(VM::raise_ex).unwrap());
        let timeout = timeout.map_or(None, |v| Some(v.to_u64()));

        let result = Thread::call_without_gvl(move || {
            let connection = _rtself.get_data_mut(&*CONNECTION_WRAPPER);
            let params = RpcParams {
                rpc: rpc.clone(),
                request: request.clone(),
                metadata: metadata.clone(),
                timeout_millis: timeout
            };
            connection.call(params)
        }, Some(|| {}));

        let response = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        wrap_bytes(response)
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

    fn run_callback_loop() -> NilClass {
        let runtime = _rtself.get_data_mut(&*RUNTIME_WRAPPER);
        runtime.run_callback_loop();

        NilClass::new()
    }

    fn create_worker(runtime: AnyObject, connection: AnyObject, namespace: RString, task_queue: RString) -> AnyObject {
        let namespace = namespace.map_err(VM::raise_ex).unwrap().to_string();
        let task_queue = task_queue.map_err(VM::raise_ex).unwrap().to_string();
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);
        let connection = connection.unwrap();
        let connection = connection.get_data(&*CONNECTION_WRAPPER);
        let worker = Worker::new(runtime, &connection.client, &namespace, &task_queue);

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
            ruby_callback.call(&[wrap_bytes(bytes).to_any_object()]);
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.poll_activity_task(callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_complete_activity_task(proto: RString) -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #worker_complete_activity_task without a block");
        }

        let bytes = unwrap_bytes(proto.map_err(VM::raise_ex).unwrap());
        let ruby_callback = VM::block_proc();
        let callback = move |result: WorkerResult| {
            result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();
            ruby_callback.call(&[NilClass::new().to_any_object()]);
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.complete_activity_task(bytes, callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_record_activity_heartbeat(proto: RString) -> NilClass {
        let bytes = unwrap_bytes(proto.map_err(VM::raise_ex).unwrap());
        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);

        let result = worker.record_activity_heartbeat(bytes);

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
            klass.def("run_callback_loop", run_callback_loop);
        });

        module.define_nested_class("Connection", None).define(|klass| {
            klass.def_self("connect", create_connection);
            klass.def("call", call_rpc);
        });

        module.define_nested_class("Worker", None).define(|klass| {
            klass.def_self("create", create_worker);
            klass.def("poll_activity_task", worker_poll_activity_task);
            klass.def("complete_activity_task", worker_complete_activity_task);
            klass.def("record_activity_heartbeat", worker_record_activity_heartbeat);
        });
    });
}
