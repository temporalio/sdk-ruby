#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;

use connection::Connection;
use rutie::{Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM, Thread};

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    rtself,

    fn create_connection(host: RString) -> AnyObject {
        let host = host.map_err(|e| VM::raise_ex(e)).unwrap().to_string();

        let result = Thread::call_without_gvl(move || {
            Connection::connect(host.clone())
        }, Some(|| {}));

        let connection = result.map_err(|e| {
            VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string())))
        }).unwrap();

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

        let response = result.map_err(|e| {
            VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string())))
        }).unwrap();

        let enc = Encoding::find("ASCII-8BIT").unwrap();
        RString::from_bytes(&response, &enc)
    }
);

#[no_mangle]
pub extern "C" fn init_bridge() {
    Module::from_existing("Temporal").get_nested_module("Bridge").define(|module| {
        module.define_nested_class("Connection", None).define(|klass| {
            klass.def_self("connect", create_connection);
            klass.def("call", call_rpc);
        });
    });
}
