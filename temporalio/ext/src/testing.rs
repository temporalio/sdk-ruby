use std::time::Duration;

use magnus::{
    class, function, method, prelude::*, DataTypeFunctions, Error, Ruby, TypedData, Value,
};
use parking_lot::Mutex;
use temporal_sdk_core::ephemeral_server::{
    self, EphemeralExe, EphemeralExeVersion, TemporalDevServerConfigBuilder,
    TestServerConfigBuilder,
};

use crate::{
    error, id, new_error,
    runtime::{Runtime, RuntimeHandle},
    util::{AsyncCallback, Struct},
    ROOT_MOD,
};

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let module = root_mod.define_module("Testing")?;

    let class = module.define_class("EphemeralServer", class::object())?;
    class.define_singleton_method(
        "async_start_dev_server",
        function!(EphemeralServer::async_start_dev_server, 3),
    )?;
    class.define_singleton_method(
        "async_start_test_server",
        function!(EphemeralServer::async_start_test_server, 3),
    )?;
    class.define_method("target", method!(EphemeralServer::target, 0))?;
    class.define_method(
        "async_shutdown",
        method!(EphemeralServer::async_shutdown, 1),
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
        runtime: &Runtime,
        options: Struct,
        queue: Value,
    ) -> Result<(), Error> {
        // Build options
        let mut opts_build = TemporalDevServerConfigBuilder::default();
        opts_build
            .exe(EphemeralServer::exe_from_options(&options)?)
            .namespace(options.member::<String>(id!("namespace"))?)
            .ip(options.member::<String>(id!("ip"))?)
            .port(options.member::<Option<u16>>(id!("port"))?)
            .db_filename(options.member::<Option<String>>(id!("database_filename"))?)
            .ui(options.member(id!("ui"))?)
            .ui_port(options.member::<Option<u16>>(id!("ui_port"))?)
            .log((
                options.member::<String>(id!("log_format"))?,
                options.member::<String>(id!("log_level"))?,
            ))
            .extra_args(options.member(id!("extra_args"))?);
        let opts = opts_build
            .build()
            .map_err(|err| error!("Invalid dev server config: {}", err))?;

        // Start
        let callback = AsyncCallback::from_queue(queue);
        let runtime_handle = runtime.handle.clone();
        runtime.handle.spawn(
            async move { opts.start_server().await },
            move |ruby, result| match result {
                Ok(core) => callback.push(
                    &ruby,
                    EphemeralServer {
                        target: core.target.clone(),
                        core: Mutex::new(Some(core)),
                        runtime_handle,
                    },
                ),
                Err(err) => callback.push(&ruby, new_error!("Failed starting server: {}", err)),
            },
        );
        Ok(())
    }

    pub fn async_start_test_server(
        runtime: &Runtime,
        options: Struct,
        queue: Value,
    ) -> Result<(), Error> {
        // Build options
        let mut opts_build = TestServerConfigBuilder::default();
        opts_build
            .exe(EphemeralServer::exe_from_options(&options)?)
            .port(options.member::<Option<u16>>(id!("port"))?)
            .extra_args(options.member(id!("extra_args"))?);
        let opts = opts_build
            .build()
            .map_err(|err| error!("Invalid test server config: {}", err))?;

        // Start
        let callback = AsyncCallback::from_queue(queue);
        let runtime_handle = runtime.handle.clone();
        runtime.handle.spawn(
            async move { opts.start_server().await },
            move |ruby, result| match result {
                Ok(core) => callback.push(
                    &ruby,
                    EphemeralServer {
                        target: core.target.clone(),
                        core: Mutex::new(Some(core)),
                        runtime_handle,
                    },
                ),
                Err(err) => callback.push(&ruby, new_error!("Failed starting server: {}", err)),
            },
        );
        Ok(())
    }

    fn exe_from_options(options: &Struct) -> Result<EphemeralExe, Error> {
        if let Some(existing_path) = options.member::<Option<String>>(id!("existing_path"))? {
            Ok(EphemeralExe::ExistingPath(existing_path))
        } else {
            Ok(EphemeralExe::CachedDownload {
                version: match options.member::<String>(id!("download_version"))? {
                    ref v if v == "default" => EphemeralExeVersion::SDKDefault {
                        sdk_name: options.member(id!("sdk_name"))?,
                        sdk_version: options.member(id!("sdk_version"))?,
                    },
                    download_version => EphemeralExeVersion::Fixed(download_version),
                },
                dest_dir: options.member(id!("download_dest_dir"))?,
                ttl: options
                    .member::<Option<f64>>(id!("download_ttl"))?
                    .map(Duration::from_secs_f64),
            })
        }
    }

    pub fn target(&self) -> &str {
        &self.target
    }

    pub fn async_shutdown(&self, queue: Value) -> Result<(), Error> {
        if let Some(mut core) = self.core.lock().take() {
            let callback = AsyncCallback::from_queue(queue);
            self.runtime_handle
                .spawn(
                    async move { core.shutdown().await },
                    move |ruby, result| match result {
                        Ok(_) => callback.push(&ruby, ruby.qnil()),
                        Err(err) => {
                            callback.push(&ruby, new_error!("Failed shutting down server: {}", err))
                        }
                    },
                )
        }
        Ok(())
    }
}
