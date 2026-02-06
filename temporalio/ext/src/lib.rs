use magnus::{Error, ExceptionClass, RModule, Ruby, prelude::*, value::Lazy};

#[cfg(feature = "dhat-heap")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

#[cfg(feature = "dhat-heap")]
static DHAT_PROFILER: std::sync::Mutex<Option<dhat::Profiler>> = std::sync::Mutex::new(None);

mod client;
mod client_rpc_generated;
mod envconfig;
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

#[macro_export]
macro_rules! lazy_id {
    ($str:expr) => {{
        static VAL: magnus::value::LazyId = magnus::value::LazyId::new($str);
        &VAL
    }};
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    Lazy::force(&ROOT_ERR, ruby);

    #[cfg(feature = "dhat-heap")]
    {
        let profiler = dhat::Profiler::builder()
            .file_name("dhat-heap.json")
            .build();
        *DHAT_PROFILER.lock().unwrap() = Some(profiler);
        eprintln!("[dhat] Heap profiling enabled.");
    }

    client::init(ruby)?;
    envconfig::init(ruby)?;
    metric::init(ruby)?;
    runtime::init(ruby)?;
    testing::init(ruby)?;
    worker::init(ruby)?;

    #[cfg(feature = "dhat-heap")]
    {
        let bridge_mod = ruby.get_inner(&ROOT_MOD);
        bridge_mod
            .define_module_function("dhat_heap_stats", magnus::function!(dhat_heap_stats, 0))?;
        bridge_mod.define_module_function(
            "dhat_dump_and_stop",
            magnus::function!(dhat_dump_and_stop, 0),
        )?;
    }

    Ok(())
}

/// Print current dhat heap stats to stderr
#[cfg(feature = "dhat-heap")]
fn dhat_heap_stats() {
    let stats = dhat::HeapStats::get();
    eprintln!(
        "[dhat] curr_bytes={} curr_blocks={} total_bytes={} total_blocks={}",
        stats.curr_bytes, stats.curr_blocks, stats.total_bytes, stats.total_blocks
    );
}

/// Drop the profiler to force writing the JSON profile
#[cfg(feature = "dhat-heap")]
fn dhat_dump_and_stop() {
    let mut guard = DHAT_PROFILER.lock().unwrap();
    if let Some(profiler) = guard.take() {
        drop(profiler); // This triggers the profile write to dhat-heap.json
        eprintln!("[dhat] Profile written to dhat-heap.json");
    } else {
        eprintln!("[dhat] Profiler already stopped or not initialized");
    }
}
