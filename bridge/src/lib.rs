#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;

use connection::Connection;
use once_cell::sync::OnceCell;
use rutie::{
    Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM, Thread,
    NilClass
};
use std::sync::Arc;
use tokio::runtime::{Builder, Runtime};
use temporal_sdk_core::{Logger, TelemetryOptionsBuilder};

const RUNTIME_THREAD_COUNT: u8 = 2;

fn runtime() -> &'static Arc<Runtime> {
    static INSTANCE: OnceCell<Arc<Runtime>> = OnceCell::new();
    INSTANCE.get_or_init(|| {
        Arc::new(
            Builder::new_multi_thread()
                .worker_threads(RUNTIME_THREAD_COUNT.into())
                .enable_all()
                .thread_name("core")
                .build()
                .unwrap()
        )
    })
}

fn raise_bridge_exception(message: &str) {
    VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(message)));
}

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    rtself,

    fn create_connection(host: RString) -> AnyObject {
        let host = host.map_err(|e| VM::raise_ex(e)).unwrap().to_string();

        let result = Thread::call_without_gvl(move || {
            Connection::connect(runtime().clone(), host.clone())
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
);

#[no_mangle]
pub extern "C" fn init_bridge() {
    Module::from_existing("Temporal").get_nested_module("Bridge").define(|module| {
        module.def_self("init_telemetry", init_telemetry);

        module.define_nested_class("Connection", None).define(|klass| {
            klass.def_self("connect", create_connection);
            klass.def("call", call_rpc);
        });
    });
}
