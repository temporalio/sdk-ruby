use std::{collections::HashMap, future::Future, marker::PhantomData, time::Duration};

use temporal_client::{
    ClientInitError, ClientKeepAliveConfig, ClientOptionsBuilder, ClientTlsConfig,
    ConfiguredClient, HttpConnectProxyOptions, RetryClient, RetryConfig,
    TemporalServiceClientWithMetrics, TlsConfig,
};

use magnus::{
    DataTypeFunctions, Error, RString, Ruby, TypedData, Value, class, function, method, prelude::*,
    scan_args,
};
use tonic::{Status, metadata::MetadataKey};
use url::Url;

use super::{ROOT_MOD, error, id, new_error};
use crate::{
    ROOT_ERR,
    runtime::{Runtime, RuntimeHandle},
    util::{AsyncCallback, Struct},
};
use std::str::FromStr;

pub(crate) const SERVICE_WORKFLOW: u8 = 1;
pub(crate) const SERVICE_OPERATOR: u8 = 2;
pub(crate) const SERVICE_CLOUD: u8 = 3;
pub(crate) const SERVICE_TEST: u8 = 4;
pub(crate) const SERVICE_HEALTH: u8 = 5;

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let class = root_mod.define_class("Client", class::object())?;
    class.const_set("SERVICE_WORKFLOW", SERVICE_WORKFLOW)?;
    class.const_set("SERVICE_OPERATOR", SERVICE_OPERATOR)?;
    class.const_set("SERVICE_CLOUD", SERVICE_CLOUD)?;
    class.const_set("SERVICE_TEST", SERVICE_TEST)?;
    class.const_set("SERVICE_HEALTH", SERVICE_HEALTH)?;
    class.define_singleton_method("async_new", function!(Client::async_new, 3))?;
    class.define_method("async_invoke_rpc", method!(Client::async_invoke_rpc, -1))?;
    class.define_method("update_metadata", method!(Client::update_metadata, 1))?;
    class.define_method("update_api_key", method!(Client::update_api_key, 1))?;

    let inner_class = class.define_error("RPCFailure", ruby.get_inner(&ROOT_ERR))?;
    inner_class.define_method("code", method!(RpcFailure::code, 0))?;
    inner_class.define_method("message", method!(RpcFailure::message, 0))?;
    inner_class.define_method("details", method!(RpcFailure::details, 0))?;

    let inner_class = class.define_class("CancellationToken", class::object())?;
    inner_class.define_singleton_method("new", function!(CancellationToken::new, 0))?;
    inner_class.define_method("cancel", method!(CancellationToken::cancel, 0))?;
    Ok(())
}

type CoreClient = RetryClient<ConfiguredClient<TemporalServiceClientWithMetrics>>;

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Client", free_immediately)]
pub struct Client {
    pub(crate) core: CoreClient,
    pub(crate) runtime_handle: RuntimeHandle,
}

#[macro_export]
macro_rules! rpc_call {
    ($client:ident, $callback:ident, $call:ident, $trait:tt, $call_name:ident) => {{
        let cancel_token = $call.cancel_token.clone();
        if $call.retry {
            let mut core_client = $client.core.clone();
            let req = $call.into_request()?;
            $crate::client::rpc_resp($client, $callback, cancel_token, async move {
                $trait::$call_name(&mut core_client, req).await
            })
        } else {
            let mut core_client = $client.core.clone().into_inner();
            let req = $call.into_request()?;
            $crate::client::rpc_resp($client, $callback, cancel_token, async move {
                $trait::$call_name(&mut core_client, req).await
            })
        }
    }};
}

impl Client {
    pub fn async_new(runtime: &Runtime, options: Struct, queue: Value) -> Result<(), Error> {
        runtime.handle.fork_check("create client")?;
        // Build options
        let mut opts_build = ClientOptionsBuilder::default();
        let tls = options.child(id!("tls"))?;
        opts_build
            .target_url(
                Url::parse(
                    format!(
                        "{}://{}",
                        if tls.is_some() { "https" } else { "http" },
                        options.member::<String>(id!("target_host"))?
                    )
                    .as_str(),
                )
                .map_err(|err| error!("Failed parsing host: {}", err))?,
            )
            .client_name(options.member::<String>(id!("client_name"))?)
            .client_version(options.member::<String>(id!("client_version"))?)
            .headers(Some(options.member(id!("rpc_metadata"))?))
            .api_key(options.member(id!("api_key"))?)
            .identity(options.member::<String>(id!("identity"))?);
        if let Some(tls) = tls {
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
                        ));
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
            initial_interval: Duration::from_secs_f64(rpc_retry.member(id!("initial_interval"))?),
            randomization_factor: rpc_retry.member(id!("randomization_factor"))?,
            multiplier: rpc_retry.member(id!("multiplier"))?,
            max_interval: Duration::from_secs_f64(rpc_retry.member(id!("max_interval"))?),
            max_elapsed_time: match rpc_retry.member::<f64>(id!("max_elapsed_time"))? {
                // 0 means none
                0.0 => None,
                val => Some(Duration::from_secs_f64(val)),
            },
            max_retries: rpc_retry.member(id!("max_retries"))?,
        });
        if let Some(keep_alive) = options.child(id!("keep_alive"))? {
            opts_build.keep_alive(Some(ClientKeepAliveConfig {
                interval: Duration::from_secs_f64(keep_alive.member(id!("interval"))?),
                timeout: Duration::from_secs_f64(keep_alive.member(id!("timeout"))?),
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
        let callback = AsyncCallback::from_queue(queue);
        let core_runtime = runtime.handle.core.clone();
        let runtime_handle = runtime.handle.clone();
        runtime.handle.spawn(
            async move {
                let core = opts
                    .connect_no_namespace(core_runtime.telemetry().get_temporal_metric_meter())
                    .await?;
                Ok(core)
            },
            move |ruby, result: Result<CoreClient, ClientInitError>| match result {
                Ok(core) => callback.push(
                    &ruby,
                    Client {
                        core,
                        runtime_handle,
                    },
                ),
                Err(err) => callback.push(&ruby, new_error!("Failed client connect: {}", err)),
            },
        );
        Ok(())
    }

    pub fn async_invoke_rpc(&self, args: &[Value]) -> Result<(), Error> {
        self.runtime_handle.fork_check("use client")?;
        let args = scan_args::scan_args::<(), (), (), (), _, ()>(args)?;
        let (service, rpc, request, retry, metadata, timeout, cancel_token, queue) =
            scan_args::get_kwargs::<
                _,
                (
                    u8,
                    String,
                    RString,
                    bool,
                    Option<HashMap<String, String>>,
                    Option<f64>,
                    Option<&CancellationToken>,
                    Value,
                ),
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
                    id!("rpc_timeout"),
                    id!("rpc_cancellation_token"),
                    id!("queue"),
                ],
                &[],
            )?
            .required;
        let call = RpcCall {
            rpc,
            request: unsafe { request.as_slice() },
            retry,
            metadata,
            timeout,
            cancel_token: cancel_token.map(|c| c.token.clone()),
            _not_send_sync: PhantomData,
        };
        let callback = AsyncCallback::from_queue(queue);
        self.invoke_rpc(service, callback, call)
    }

    pub fn update_metadata(&self, headers: HashMap<String, String>) -> Result<(), Error> {
        self.core
            .get_client()
            .set_headers(headers)
            .map_err(|err| error!("Invalid headers: {}", err))
    }

    pub fn update_api_key(&self, api_key: Option<String>) {
        self.core.get_client().set_api_key(api_key);
    }
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Client::RPCFailure",
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
        if self.status.details().is_empty() {
            None
        } else {
            Some(RString::from_slice(self.status.details()))
        }
    }
}

pub(crate) struct RpcCall<'a> {
    pub rpc: String,
    pub request: &'a [u8],
    pub retry: bool,
    pub metadata: Option<HashMap<String, String>>,
    pub timeout: Option<f64>,
    pub cancel_token: Option<tokio_util::sync::CancellationToken>,

    // This RPC call contains an unsafe reference to Ruby bytes that does not
    // outlive the call, so we prevent it from being sent to another thread.
    // !Send/!Sync not yet stable: https://github.com/rust-lang/rust/issues/68318
    _not_send_sync: PhantomData<*const ()>,
}

impl RpcCall<'_> {
    pub fn into_request<P: prost::Message + Default>(self) -> Result<tonic::Request<P>, Error> {
        let proto = P::decode(self.request).map_err(|err| error!("Invalid proto: {}", err))?;
        let mut req = tonic::Request::new(proto);
        if let Some(metadata) = self.metadata {
            for (k, v) in metadata {
                req.metadata_mut().insert(
                    MetadataKey::from_str(k.as_str())
                        .map_err(|err| error!("Invalid metadata key: {}", err))?,
                    v.parse()
                        .map_err(|err| error!("Invalid metadata value: {}", err))?,
                );
            }
        }
        if let Some(timeout) = self.timeout {
            req.set_timeout(Duration::from_secs_f64(timeout));
        }
        Ok(req)
    }
}

pub(crate) fn rpc_resp<P>(
    client: &Client,
    callback: AsyncCallback,
    cancel_token: Option<tokio_util::sync::CancellationToken>,
    fut: impl Future<Output = Result<tonic::Response<P>, tonic::Status>> + Send + 'static,
) -> Result<(), Error>
where
    P: prost::Message,
    P: Default,
{
    client.runtime_handle.spawn(
        async move {
            let res = if let Some(cancel_token) = cancel_token {
                tokio::select! {
                    _ = cancel_token.cancelled() => Err(tonic::Status::new(tonic::Code::Cancelled, "<__user_canceled__>")),
                    v = fut => v,
                }
            } else {
                fut.await
            };
            res.map(|msg| msg.get_ref().encode_to_vec())
        },
        move |ruby, result| {
            match result {
                // TODO(cretz): Any reasonable way to prevent byte copy that is just going to get decoded into proto
                // object?
                Ok(val) => callback.push(&ruby, RString::from_slice(&val)),
                Err(status) => callback.push(&ruby, RpcFailure { status }),
            }
        },
    );
    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Client::CancellationToken",
    free_immediately
)]
pub struct CancellationToken {
    pub(crate) token: tokio_util::sync::CancellationToken,
}

impl CancellationToken {
    pub fn new() -> Result<Self, Error> {
        Ok(Self {
            token: tokio_util::sync::CancellationToken::new(),
        })
    }

    pub fn cancel(&self) -> Result<(), Error> {
        self.token.cancel();
        Ok(())
    }
}
