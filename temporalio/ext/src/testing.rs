use magnus::{
    class, function, method, prelude::*, value::Opaque, DataTypeFunctions, Error, Ruby, TypedData,
    Value,
};
use parking_lot::Mutex;
use temporal_sdk_core::ephemeral_server::{
    self, EphemeralExe, EphemeralExeVersion, TemporalDevServerConfigBuilder,
};

use crate::{
    error, id, new_error,
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
                if let Some(existing_path) =
                    options.member::<Option<String>>(id!("existing_path"))?
                {
                    EphemeralExe::ExistingPath(existing_path)
                } else {
                    EphemeralExe::CachedDownload {
                        version: match options.member::<String>(id!("download_version"))? {
                            ref v if v == "default" => EphemeralExeVersion::SDKDefault {
                                sdk_name: options.member(id!("sdk_name"))?,
                                sdk_version: options.member(id!("sdk_version"))?,
                            },
                            download_version => EphemeralExeVersion::Fixed(download_version),
                        },
                        dest_dir: options.member(id!("download_dest_dir"))?,
                    }
                },
            )
            .namespace(options.member::<String>(id!("namespace"))?)
            .ip(options.member::<String>(id!("ip"))?)
            .port(options.member::<Option<u16>>(id!("port"))?)
            .db_filename(options.member::<Option<String>>(id!("database_filename"))?)
            .ui(options.member(id!("namespace"))?)
            .log((
                options.member::<String>(id!("log_format"))?,
                options.member::<String>(id!("log_level"))?,
            ))
            .extra_args(options.member(id!("extra_args"))?);
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
                let _: Value = match result {
                    Ok(core) => block.call((EphemeralServer {
                        target: core.target.clone(),
                        core: Mutex::new(Some(core)),
                        runtime_handle,
                    },))?,
                    Err(err) => block.call((new_error!("Failed starting server: {}", err),))?,
                };
                Ok(())
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
                    let _: Value = match result {
                        Ok(_) => block.call((ruby.qnil(),))?,
                        Err(err) => {
                            block.call((new_error!("Failed shutting down server: {}", err),))?
                        }
                    };
                    Ok(())
                })
        }
        Ok(())
    }
}
