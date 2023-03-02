use crate::runtime::Runtime;
use std::sync::Arc;
use temporal_sdk_core::ephemeral_server;
use thiserror::Error;
use tokio::runtime::Runtime as TokioRuntime;

#[derive(Error, Debug)]
pub enum TestServerError {
    #[error(transparent)]
    ConfigError(#[from] ephemeral_server::TestServerConfigBuilderError),

    #[error(transparent)]
    TemporaliteConfigError(#[from] ephemeral_server::TemporaliteConfigBuilderError),

    #[error(transparent)]
    Unknown(#[from] anyhow::Error),
}

pub struct TestServer {
    core_server: ephemeral_server::EphemeralServer,
    tokio_runtime: Arc<TokioRuntime>,
}

pub struct TestServerConfig {
    pub existing_path: Option<String>,
    pub sdk_name: String,
    pub sdk_version: String,
    pub download_version: String,
    pub download_dir: Option<String>,
    pub port: Option<u16>,
    pub extra_args: Vec<String>,
}

pub struct TemporaliteConfig {
    pub existing_path: Option<String>,
    pub sdk_name: String,
    pub sdk_version: String,
    pub download_version: String,
    pub download_dir: Option<String>,
    pub namespace: String,
    pub ip: String,
    pub port: Option<u16>,
    pub database_filename: Option<String>,
    pub ui: bool,
    pub log_format: String,
    pub log_level: String,
    pub extra_args: Vec<String>,
}

impl TestServer {
    pub fn start(runtime: &Runtime, config: TestServerConfig) -> Result<TestServer, TestServerError> {
        let config: ephemeral_server::TestServerConfig = config.try_into()?;
        let core_server = runtime.tokio_runtime.block_on(config.start_server())?;

        Ok(TestServer {
            core_server,
            tokio_runtime: runtime.tokio_runtime.clone(),
        })
    }

    pub fn start_temporalite(runtime: &Runtime, config: TemporaliteConfig) -> Result<TestServer, TestServerError> {
        let config: ephemeral_server::TemporaliteConfig = config.try_into()?;
        let core_server = runtime.tokio_runtime.block_on(config.start_server())?;

        // TODO: This needs further investigation, but for some reason without a short pause here
        //       the shutdown called immediately after will end up waiting for 10 seconds before the
        //       process dies. This might be related to Core's EphemeralServer not waiting long
        //       enough for the Temporalite to start before returning back the control to the SDK.
        //       Reported here — https://github.com/temporalio/cli/issues/79.
        std::thread::sleep(std::time::Duration::from_millis(150));

        Ok(TestServer {
            core_server,
            tokio_runtime: runtime.tokio_runtime.clone(),
        })
    }

    pub fn has_test_service(&self) -> bool {
        self.core_server.has_test_service
    }

    pub fn target(&self) -> String {
        self.core_server.target.clone()
    }

    pub fn shutdown(&mut self) -> Result<(), TestServerError> {
        self.tokio_runtime.block_on(self.core_server.shutdown())?;

        Ok(())
    }
}

fn ephemeral_exe(
    existing_path: Option<String>,
    sdk_name: String,
    sdk_version: String,
    download_version: String,
    download_dir: Option<String>
) -> ephemeral_server::EphemeralExe {
    if let Some(path) = existing_path {
        ephemeral_server::EphemeralExe::ExistingPath(path)
    } else {
        let version =
            if download_version == "default" {
                    ephemeral_server::EphemeralExeVersion::SDKDefault { sdk_name, sdk_version }
            } else {
                ephemeral_server::EphemeralExeVersion::Fixed(download_version)
            };

        ephemeral_server::EphemeralExe::CachedDownload { version, dest_dir: download_dir }
    }
}

impl TryFrom<TestServerConfig> for ephemeral_server::TestServerConfig {
    type Error = ephemeral_server::TestServerConfigBuilderError;

    fn try_from(config: TestServerConfig) -> Result<Self, Self::Error> {
        ephemeral_server::TestServerConfigBuilder::default()
            .exe(ephemeral_exe(
                config.existing_path,
                config.sdk_name,
                config.sdk_version,
                config.download_version,
                config.download_dir
            ))
            .port(config.port)
            .extra_args(config.extra_args)
            .build()
    }
}

impl TryFrom<TemporaliteConfig> for ephemeral_server::TemporaliteConfig {
    type Error = ephemeral_server::TemporaliteConfigBuilderError;

    fn try_from(config: TemporaliteConfig) -> Result<Self, Self::Error> {
        ephemeral_server::TemporaliteConfigBuilder::default()
            .exe(ephemeral_exe(
                config.existing_path,
                config.sdk_name,
                config.sdk_version,
                config.download_version,
                config.download_dir
            ))
            .namespace(config.namespace)
            .ip(config.ip)
            .port(config.port)
            .db_filename(config.database_filename)
            .ui(config.ui)
            .log((config.log_format, config.log_level))
            .extra_args(config.extra_args)
            .build()
    }
}
