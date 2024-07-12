use std::{collections::HashMap, future::Future, time::Duration};

use temporal_client::{
    ClientInitError, ClientKeepAliveConfig, ClientOptionsBuilder, ClientTlsConfig,
    ConfiguredClient, HttpConnectProxyOptions, RetryClient, RetryConfig,
    TemporalServiceClientWithMetrics, TlsConfig, WorkflowService,
};

use magnus::{
    block::Proc, class, function, method, prelude::*, scan_args, value::Opaque, DataTypeFunctions,
    Error, RString, Ruby, TypedData, Value,
};
use tonic::{metadata::MetadataKey, Status};
use url::Url;

use super::{error, new_error, ROOT_MOD};
use crate::{
    runtime::{Runtime, RuntimeHandle},
    util::Struct,
};
use std::str::FromStr;

const SERVICE_WORKFLOW: u8 = 1;
const SERVICE_OPERATOR: u8 = 2;
const SERVICE_CLOUD: u8 = 3;
const SERVICE_TEST: u8 = 4;
const SERVICE_HEALTH: u8 = 5;

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let class = root_mod.define_class("Client", class::object())?;
    class.const_set("SERVICE_WORKFLOW", SERVICE_WORKFLOW)?;
    class.const_set("SERVICE_OPERATOR", SERVICE_OPERATOR)?;
    class.const_set("SERVICE_CLOUD", SERVICE_CLOUD)?;
    class.const_set("SERVICE_TEST", SERVICE_TEST)?;
    class.const_set("SERVICE_HEALTH", SERVICE_HEALTH)?;
    class.define_singleton_method("async_new", function!(Client::async_new, 2))?;
    class.define_method("async_invoke_rpc", method!(Client::async_invoke_rpc, -1))?;

    let inner_class = class.define_class("RpcFailure", class::object())?;
    inner_class.define_method("code", method!(RpcFailure::code, 0))?;
    inner_class.define_method("message", method!(RpcFailure::message, 0))?;
    inner_class.define_method("details", method!(RpcFailure::details, 0))?;
    Ok(())
}

type CoreClient = RetryClient<ConfiguredClient<TemporalServiceClientWithMetrics>>;

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Client", free_immediately)]
pub struct Client {
    pub(crate) core: CoreClient,
    runtime_handle: RuntimeHandle,
}

macro_rules! rpc_call {
    ($client:ident, $block:ident, $call:ident, $call_name:ident) => {{
        if $call.retry {
            let mut core_client = $client.core.clone();
            let req = $call.into_request()?;
            rpc_resp(
                $client,
                $block,
                async move { core_client.$call_name(req).await },
            )
        } else {
            let mut core_client = $client.core.clone().into_inner();
            let req = $call.into_request()?;
            rpc_resp(
                $client,
                $block,
                async move { core_client.$call_name(req).await },
            )
        }
    }};
}

impl Client {
    pub fn async_new(ruby: &Ruby, runtime: &Runtime, options: Struct) -> Result<(), Error> {
        // Build options
        let mut opts_build = ClientOptionsBuilder::default();
        opts_build
            .target_url(
                Url::parse(format!("http://{}", options.aref::<String>("target_host")?).as_str())
                    .map_err(|err| error!("Failed parsing host: {}", err))?,
            )
            .client_name(options.aref::<String>("client_name")?)
            .client_version(options.aref::<String>("client_version")?)
            .headers(Some(options.aref("rpc_metadata")?))
            .api_key(options.aref("api_key")?)
            .identity(options.aref("identity")?);
        if let Some(tls) = options.child("tls")? {
            opts_build.tls_cfg(TlsConfig {
                client_tls_config: match (
                    tls.aref::<Option<RString>>("client_cert")?,
                    tls.aref::<Option<RString>>("client_private_key")?,
                ) {
                    (None, None) => None,
                    (Some(client_cert), Some(client_private_key)) => Some(ClientTlsConfig {
                        // These are unsafe because of lifetime issues, but we copy right away
                        client_cert: unsafe { client_cert.as_slice().to_vec() },
                        client_private_key: unsafe { client_private_key.as_slice().to_vec() },
                    }),
                    _ => {
                        return Err(error!(
                            "Must have both client cert and private key or neither"
                        ))
                    }
                },
                server_root_ca_cert: tls
                    .aref::<Option<RString>>("server_root_ca_cert")?
                    .map(|rstr| unsafe { rstr.as_slice().to_vec() }),
                domain: tls.aref("domain")?,
            });
        }
        let rpc_retry = options
            .child("rpc_retry")?
            .ok_or_else(|| error!("Missing rpc_retry"))?;
        opts_build.retry_config(RetryConfig {
            initial_interval: Duration::from_millis(rpc_retry.aref("initial_interval_ms")?),
            randomization_factor: rpc_retry.aref("randomization_factor")?,
            multiplier: rpc_retry.aref("multiplier")?,
            max_interval: Duration::from_millis(rpc_retry.aref("max_interval_ms")?),
            max_elapsed_time: match rpc_retry.aref::<u64>("max_elapsed_time_ms")? {
                // 0 means none
                0 => None,
                val => Some(Duration::from_millis(val)),
            },
            max_retries: rpc_retry.aref("max_retries")?,
        });
        if let Some(keep_alive) = options.child("keep_alive")? {
            opts_build.keep_alive(Some(ClientKeepAliveConfig {
                interval: Duration::from_millis(keep_alive.aref("interval_ms")?),
                timeout: Duration::from_millis(keep_alive.aref("timeout_ms")?),
            }));
        }
        if let Some(proxy) = options.child("http_connect_proxy")? {
            opts_build.http_connect_proxy(Some(HttpConnectProxyOptions {
                target_addr: proxy.aref("target_host")?,
                basic_auth: match (
                    proxy.aref::<Option<String>>("basic_auth_user")?,
                    proxy.aref::<Option<String>>("basic_auth_user")?,
                ) {
                    (None, None) => None,
                    (Some(user), Some(pass)) => Some((user, pass)),
                    _ => return Err(error!("Must have both basic auth and pass or neither")),
                },
            }));
        }
        let opts = opts_build
            .build()
            .map_err(|err| error!("Invalid client options: {}", err))?;

        // Create client
        let block = Opaque::from(ruby.block_proc()?);
        let core_runtime = runtime.handle.core.clone();
        let runtime_handle = runtime.handle.clone();
        runtime.handle.spawn(
            async move {
                let core = opts
                    .connect_no_namespace(core_runtime.telemetry().get_temporal_metric_meter())
                    .await?;
                Ok(core)
            },
            move |ruby, result: Result<CoreClient, ClientInitError>| {
                let block = ruby.get_inner(block);
                match result {
                    Ok(core) => {
                        let _: Value = block
                            .call((Client {
                                core,
                                runtime_handle,
                            },))
                            .expect("Block call failed");
                    }
                    Err(err) => {
                        let _: Value = block
                            .call((new_error!("Failed client connect: {}", err),))
                            .expect("Block call failed");
                    }
                };
            },
        );
        Ok(())
    }

    pub fn async_invoke_rpc(&self, args: &[Value]) -> Result<(), Error> {
        let args = scan_args::scan_args::<(), (), (), (), _, Proc>(args)?;
        let (service, rpc, request, retry, metadata, timeout_ms) = scan_args::get_kwargs::<
            _,
            (u8, String, RString, bool, HashMap<String, String>, u64),
            (),
            (),
        >(
            args.keywords,
            &[
                "service",
                "rpc",
                "request",
                "rpc_retry",
                "rpc_metadata",
                "rpc_timeout_ms",
            ],
            &[],
        )?
        .required;
        let call = RpcCall {
            rpc,
            request: unsafe { request.as_slice() },
            retry,
            metadata,
            timeout_ms,
        };
        let block = Opaque::from(args.block);
        match service {
            SERVICE_WORKFLOW => match call.rpc.as_str() {
                "get_workflow_execution_history" => {
                    rpc_call!(self, block, call, get_workflow_execution_history)
                }
                "start_workflow_execution" => {
                    rpc_call!(self, block, call, start_workflow_execution)
                }
                _ => Err(error!("Unknown RPC call {}", call.rpc)),
            },
            _ => Err(error!("Unknown service")),
        }
    }
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Client::RpcFailure",
    free_immediately
)]
pub struct RpcFailure {
    status: Status,
}

impl RpcFailure {
    pub fn code(&self) -> u32 {
        self.status.code() as u32
    }

    pub fn message(&self) -> &str {
        self.status.message()
    }

    pub fn details(&self) -> Option<RString> {
        if self.status.details().len() == 0 {
            None
        } else {
            Some(RString::from_slice(self.status.details()))
        }
    }
}

struct RpcCall<'a> {
    rpc: String,
    request: &'a [u8],
    retry: bool,
    metadata: HashMap<String, String>,
    timeout_ms: u64,
}

impl RpcCall<'_> {
    fn into_request<P: prost::Message + Default>(self) -> Result<tonic::Request<P>, Error> {
        let proto = P::decode(self.request).map_err(|err| error!("Invalid proto: {}", err))?;
        let mut req = tonic::Request::new(proto);
        for (k, v) in self.metadata {
            req.metadata_mut().insert(
                MetadataKey::from_str(k.as_str())
                    .map_err(|err| error!("Invalid metadata key: {}", err))?,
                v.parse()
                    .map_err(|err| error!("Invalid metadata value: {}", err))?,
            );
        }
        if self.timeout_ms > 0 {
            req.set_timeout(Duration::from_millis(self.timeout_ms));
        }
        Ok(req)
    }
}

fn rpc_resp<P>(
    client: &Client,
    block: Opaque<Proc>,
    fut: impl Future<Output = Result<tonic::Response<P>, tonic::Status>> + Send + 'static,
) -> Result<(), Error>
where
    P: prost::Message,
    P: Default,
{
    client.runtime_handle.spawn(
        async move { fut.await.map(|msg| msg.get_ref().encode_to_vec()) },
        move |ruby, result| {
            let block = ruby.get_inner(block);
            match result {
                Ok(val) => {
                    // TODO(cretz): Any reasonable way to prevent byte copy?
                    let _: Value = block
                        .call((RString::from_slice(&val),))
                        .expect("Block call failed");
                }
                Err(status) => {
                    let _: Value = block
                        .call((RpcFailure { status },))
                        .expect("Block call failed");
                }
            };
        },
    );
    Ok(())
}
