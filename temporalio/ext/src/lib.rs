use magnus::{Error, ExceptionClass, RModule, Ruby, prelude::*, value::Lazy};

mod client;
mod client_rpc_generated;
mod metric;
mod runtime;
mod testing;
mod util;
mod worker;

pub static ROOT_MOD: Lazy<RModule> = Lazy::new(|ruby| {
    ruby.define_module("Temporalio")
        .expect("Module definition failed")
        .define_module("Internal")
        .expect("Module definition failed")
        .define_module("Bridge")
        .expect("Module definition failed")
});

pub static ROOT_ERR: Lazy<ExceptionClass> = Lazy::new(|ruby| {
    ruby.get_inner(&ROOT_MOD)
        .define_error("Error", ruby.exception_standard_error())
        .expect("Error definition failed")
});

#[macro_export]
macro_rules! error {
    ($($arg:expr),*) => {
        Error::new(Ruby::get().expect("Not in Ruby thread").get_inner(&$crate::ROOT_ERR), format!($($arg),*))
    };
}

#[macro_export]
macro_rules! new_error {
    ($($arg:expr),*) => {
        Ruby::get().expect("Not in Ruby thread").get_inner(&$crate::ROOT_ERR).new_instance((format!($($arg),*),)).expect("Cannot create exception")
    };
}

#[macro_export]
macro_rules! id {
    ($str:expr) => {{
        static VAL: magnus::value::LazyId = magnus::value::LazyId::new($str);
        *VAL
    }};
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    Lazy::force(&ROOT_ERR, ruby);

    client::init(ruby)?;
    metric::init(ruby)?;
    runtime::init(ruby)?;
    testing::init(ruby)?;
    worker::init(ruby)?;

    Ok(())
}
