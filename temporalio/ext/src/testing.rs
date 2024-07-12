use magnus::{
    class, function, method, prelude::*, value::Opaque, DataTypeFunctions, Error, Ruby, TypedData,
    Value,
};
use parking_lot::Mutex;
use temporal_sdk_core::ephemeral_server::{
    self, EphemeralExe, EphemeralExeVersion, TemporalDevServerConfigBuilder,
};

use crate::{
    error, new_error,
    runtime::{Runtime, RuntimeHandle},
    util::Struct,
    ROOT_MOD,
};

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let module = root_mod.define_module("Testing")?;

    let class = module.define_class("EphemeralServer", class::object())?;
    class.define_singleton_method(
        "async_start_dev_server",
        function!(EphemeralServer::async_start_dev_server, 2),
    )?;
    class.define_method("target", method!(EphemeralServer::target, 0))?;
    class.define_method(
        "async_shutdown",
        method!(EphemeralServer::async_shutdown, 0),
    )?;
    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Testing::EphemeralServer",
    free_immediately
)]
pub struct EphemeralServer {
    core: Mutex<Option<ephemeral_server::EphemeralServer>>,
    target: String,
    runtime_handle: RuntimeHandle,
}

impl EphemeralServer {
    pub fn async_start_dev_server(
        ruby: &Ruby,
        runtime: &Runtime,
        options: Struct,
    ) -> Result<(), Error> {
        // Build options
        let mut opts_build = TemporalDevServerConfigBuilder::default();
        opts_build
            .exe(
                if let Some(existing_path) = options.aref::<Option<String>>("existing_path")? {
                    EphemeralExe::ExistingPath(existing_path)
                } else {
                    EphemeralExe::CachedDownload {
                        version: match options.aref::<String>("download_version")? {
                            ref v if v == "default" => EphemeralExeVersion::SDKDefault {
                                sdk_name: options.aref("sdk_name")?,
                                sdk_version: options.aref("sdk_version")?,
                            },
                            download_version => EphemeralExeVersion::Fixed(download_version),
                        },
                        dest_dir: options.aref("download_dest_dir")?,
                    }
                },
            )
            .namespace(options.aref::<String>("namespace")?)
            .ip(options.aref::<String>("ip")?)
            .port(options.aref::<Option<u16>>("port")?)
            .db_filename(options.aref::<Option<String>>("database_filename")?)
            .ui(options.aref("namespace")?)
            .log((
                options.aref::<String>("log_format")?,
                options.aref::<String>("log_level")?,
            ))
            .extra_args(options.aref("extra_args")?);
        let opts = opts_build
            .build()
            .map_err(|err| error!("Invalid Temporalite config: {}", err))?;

        // Start
        let block = Opaque::from(ruby.block_proc()?);
        let runtime_handle = runtime.handle.clone();
        runtime.handle.spawn(
            async move { opts.start_server().await },
            move |ruby, result| {
                let block = ruby.get_inner(block);
                match result {
                    Ok(core) => {
                        let _: Value = block
                            .call((EphemeralServer {
                                target: core.target.clone(),
                                core: Mutex::new(Some(core)),
                                runtime_handle,
                            },))
                            .expect("Block call failed");
                    }
                    Err(err) => {
                        let _: Value = block
                            .call((new_error!("Failed starting server: {}", err),))
                            .expect("Block call failed");
                    }
                }
            },
        );
        Ok(())
    }

    pub fn target(&self) -> &str {
        &self.target
    }

    pub fn async_shutdown(&self) -> Result<(), Error> {
        let ruby = Ruby::get().expect("Not in Ruby thread");
        if let Some(mut core) = self.core.lock().take() {
            let block = Opaque::from(ruby.block_proc()?);
            self.runtime_handle
                .spawn(async move { core.shutdown().await }, move |ruby, result| {
                    let block = ruby.get_inner(block);
                    match result {
                        Ok(_) => {
                            let _: Value = block.call((ruby.qnil(),)).expect("Block call failed");
                        }
                        Err(err) => {
                            let _: Value = block
                                .call((new_error!("Failed shutting down server: {}", err),))
                                .expect("Block call failed");
                        }
                    };
                })
        }
        Ok(())
    }
}
