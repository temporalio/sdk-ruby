#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;
mod reactor;

use connection::Connection;
use once_cell::sync::OnceCell;
use rutie::{Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM, Thread};
use reactor::{Reactor, Request, Response};

fn reactor() -> &'static Reactor {
    static INSTANCE: OnceCell<Reactor> = OnceCell::new();
    INSTANCE.get_or_init(|| {
        Reactor::new(2)
    })
}

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    rtself,

    fn create_connection(host: RString) -> AnyObject {
        let host = host.map_err(|e| VM::raise_ex(e)).unwrap().to_string();

        let response = Thread::call_without_gvl(move || {
            reactor()
                .process(Request::Connect { host: host.clone() })
                .map_err(|e| VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string()))))
        }, Some(|| {}));

        if let Response::Connection { connection } = response.unwrap() {
            return
                Module::from_existing("Temporal")
                    .get_nested_module("Bridge")
                    .get_nested_class("Connection")
                    .wrap_data(connection, &*CONNECTION_WRAPPER);
        } else {
            panic!("Unexpected response type. Expected Response::Connection");
        }
    }

    fn call_rpc(rpc: Symbol, request: RString) -> RString {
        let rpc = rpc.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let request = request.map_err(|e| VM::raise_ex(e)).unwrap().to_string().as_bytes().to_vec();

        let response = Thread::call_without_gvl(move || {
            let connection = rtself.get_data(&*CONNECTION_WRAPPER);
            reactor()
                .process(Request::Rpc { connection: connection.clone(), method: rpc.clone(), bytes: request.clone() })
                .map_err(|e| VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string()))))
        }, Some(|| {}));

        if let Response::Rpc { bytes } = response.unwrap() {
            let enc = Encoding::find("ASCII-8BIT").unwrap();
            return RString::from_bytes(&bytes, &enc);
        } else {
            panic!("Unexpected response type. Expected Response::Rpc");
        }
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
