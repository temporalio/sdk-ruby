use std::{collections::HashMap, future::Future, marker::PhantomData, time::Duration};

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

use super::{error, id, new_error, ROOT_MOD};
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
                Url::parse(
                    format!("http://{}", options.member::<String>(id!("target_host"))?).as_str(),
                )
                .map_err(|err| error!("Failed parsing host: {}", err))?,
            )
            .client_name(options.member::<String>(id!("client_name"))?)
            .client_version(options.member::<String>(id!("client_version"))?)
            .headers(Some(options.member(id!("rpc_metadata"))?))
            .api_key(options.member(id!("api_key"))?)
            .identity(options.member(id!("identity"))?);
        if let Some(tls) = options.child(id!("tls"))? {
            opts_build.tls_cfg(TlsConfig {
                client_tls_config: match (
                    tls.member::<Option<RString>>(id!("client_cert"))?,
                    tls.member::<Option<RString>>(id!("client_private_key"))?,
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
                    .member::<Option<RString>>(id!("server_root_ca_cert"))?
                    .map(|rstr| unsafe { rstr.as_slice().to_vec() }),
                domain: tls.member(id!("domain"))?,
            });
        }
        let rpc_retry = options
            .child(id!("rpc_retry"))?
            .ok_or_else(|| error!("Missing rpc_retry"))?;
        opts_build.retry_config(RetryConfig {
            initial_interval: Duration::from_millis(rpc_retry.member(id!("initial_interval_ms"))?),
            randomization_factor: rpc_retry.member(id!("randomization_factor"))?,
            multiplier: rpc_retry.member(id!("multiplier"))?,
            max_interval: Duration::from_millis(rpc_retry.member(id!("max_interval_ms"))?),
            max_elapsed_time: match rpc_retry.member::<u64>(id!("max_elapsed_time_ms"))? {
                // 0 means none
                0 => None,
                val => Some(Duration::from_millis(val)),
            },
            max_retries: rpc_retry.member(id!("max_retries"))?,
        });
        if let Some(keep_alive) = options.child(id!("keep_alive"))? {
            opts_build.keep_alive(Some(ClientKeepAliveConfig {
                interval: Duration::from_millis(keep_alive.member(id!("interval_ms"))?),
                timeout: Duration::from_millis(keep_alive.member(id!("timeout_ms"))?),
            }));
        }
        if let Some(proxy) = options.child(id!("http_connect_proxy"))? {
            opts_build.http_connect_proxy(Some(HttpConnectProxyOptions {
                target_addr: proxy.member(id!("target_host"))?,
                basic_auth: match (
                    proxy.member::<Option<String>>(id!("basic_auth_user"))?,
                    proxy.member::<Option<String>>(id!("basic_auth_user"))?,
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
                let _: Value = match result {
                    Ok(core) => block.call((Client {
                        core,
                        runtime_handle,
                    },))?,
                    Err(err) => block.call((new_error!("Failed client connect: {}", err),))?,
                };
                Ok(())
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
                id!("service"),
                id!("rpc"),
                id!("request"),
                id!("rpc_retry"),
                id!("rpc_metadata"),
                id!("rpc_timeout_ms"),
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
            _not_send_sync: PhantomData,
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

    // This RPC call contains an unsafe reference to Ruby bytes that does not
    // outlive the call, so we prevent it from being sent to another thread.
    // !Send/!Sync not yet stable: https://github.com/rust-lang/rust/issues/68318
    _not_send_sync: PhantomData<*const ()>,
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
            let _: Value = match result {
                // TODO(cretz): Any reasonable way to prevent byte copy that is just going to get decoded into proto
                // object?
                Ok(val) => block.call((RString::from_slice(&val),))?,
                Err(status) => block.call((RpcFailure { status },))?,
            };
            Ok(())
        },
    );
    Ok(())
}
