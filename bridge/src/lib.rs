#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;
mod reactor;

use connection::Connection;
use once_cell::sync::OnceCell;
use rutie::{Module, Object, Symbol, RString, Encoding, AnyObject, AnyException, Exception, VM};
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
        let response = reactor()
            .process(Request::Connect { host: host })
            .map_err(|e| VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string()))));

        if let Response::Connection { connection } = response.unwrap() {
            return
                Module::from_existing("Temporal")
                    .get_nested_module("Bridge")
                    .get_nested_class("Connection")
                    .wrap_data(connection, &*CONNECTION_WRAPPER);
        } else {
            panic!("unexpected response");
        }
    }

    fn call_rpc(rpc: Symbol, request: RString) -> RString {
        let rpc = rpc.map_err(|e| VM::raise_ex(e)).unwrap().to_string();
        let request = request.map_err(|e| VM::raise_ex(e)).unwrap().to_string().as_bytes().to_vec();

        let connection = rtself.get_data(&*CONNECTION_WRAPPER);
        let response = reactor()
            .process(Request::Rpc { connection: connection.clone(), method: rpc, bytes: request })
            .map_err(|e| VM::raise_ex(AnyException::new("Temporal::Bridge::Error", Some(&e.to_string()))));

        if let Response::Rpc { bytes }) = response.unwrap() {
            let enc = Encoding::find("UTF-8").unwrap();
            return RString::from_bytes(&bytes, &enc);
        } else {
            panic!("unexpected response");
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
