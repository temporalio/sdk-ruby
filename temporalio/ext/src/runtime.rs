use super::{error, id, ROOT_MOD};
use crate::util::{without_gvl, Struct};
use magnus::{
    class, function, method, prelude::*, DataTypeFunctions, Error, Ruby, TypedData, Value,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::str::FromStr;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::time::Duration;
use std::{future::Future, sync::Arc};
use temporal_sdk_core::telemetry::{build_otlp_metric_exporter, start_prometheus_metric_exporter};
use temporal_sdk_core::CoreRuntime;
use temporal_sdk_core_api::telemetry::{
    Logger, MetricTemporality, OtelCollectorOptionsBuilder, PrometheusExporterOptionsBuilder,
    TelemetryOptionsBuilder,
};
use tracing::error as log_error;
use url::Url;

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let class = ruby
        .get_inner(&ROOT_MOD)
        .define_class("Runtime", class::object())?;
    class.define_singleton_method("new", function!(Runtime::new, 1))?;
    class.define_method("run_command_loop", method!(Runtime::run_command_loop, 0))?;
    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Runtime", free_immediately)]
pub struct Runtime {
    /// Separate cloneable handle that can be referenced in other Rust objects.
    pub(crate) handle: RuntimeHandle,
    async_command_rx: Receiver<AsyncCommand>,
}

#[derive(Clone)]
pub(crate) struct RuntimeHandle {
    pub(crate) core: Arc<CoreRuntime>,
    async_command_tx: Sender<AsyncCommand>,
}

type Callback = Box<dyn FnOnce() -> Result<(), Error> + Send + 'static>;

enum AsyncCommand {
    RunCallback(Callback),
    Shutdown,
}

impl Runtime {
    pub fn new(options: Struct) -> Result<Self, Error> {
        // Build options
        let mut opts_build = TelemetryOptionsBuilder::default();
        let telemetry = options
            .child(id!("telemetry"))?
            .ok_or_else(|| error!("Missing telemetry options"))?;
        if let Some(logging) = telemetry.child(id!("logging"))? {
            opts_build.logging(
                if let Some(_forward_to) = logging.member::<Option<Value>>(id!("forward_to"))? {
                    // TODO(cretz): This
                    return Err(error!("Forwarding not yet supported"));
                } else {
                    Logger::Console {
                        filter: logging.member(id!("log_filter"))?,
                    }
                },
            );
        }
        // Set some metrics options now, but the metrics instance is late-bound
        // after CoreRuntime created since it needs Tokio runtime
        if let Some(metrics) = telemetry.child(id!("metrics"))? {
            opts_build.attach_service_name(metrics.member(id!("attach_service_name"))?);
            if let Some(prefix) = metrics.member::<Option<String>>(id!("metric_prefix"))? {
                opts_build.metric_prefix(prefix);
            }
        }
        let opts = opts_build
            .build()
            .map_err(|err| error!("Invalid telemetry options: {}", err))?;

        // Create core runtime
        let mut core = CoreRuntime::new(opts, tokio::runtime::Builder::new_multi_thread())
            .map_err(|err| error!("Failed initializing telemetry: {}", err))?;

        // Create metrics (created after Core runtime since it needs Tokio handle)
        if let Some(metrics) = telemetry.child(id!("metrics"))? {
            let _guard = core.tokio_handle().enter();
            match (metrics.child(id!("opentelemetry"))?, metrics.child(id!("prometheus"))?, metrics.child(id!("buffered_with_size"))?) {
                // Build OTel
                (Some(opentelemetry), None, None) => {
                    let mut opts_build = OtelCollectorOptionsBuilder::default();
                    opts_build.url(
                            Url::parse(&opentelemetry.member::<String>(id!("url"))?).map_err(|err| {
                                error!("Invalid OTel URL: {}", err)
                            })?).
                            use_seconds_for_durations(opentelemetry.member(id!("durations_as_seconds"))?);
                    if let Some(headers) = opentelemetry.member::<Option<HashMap<String, String>>>(id!("headers"))? {
                        opts_build.headers(headers);
                    }
                    if let Some(period) = opentelemetry.member::<Option<f64>>(id!("metric_periodicity"))? {
                        opts_build.metric_periodicity(Duration::from_secs_f64(period));
                    }
                    if opentelemetry.member::<bool>(id!("metric_temporality_delta"))? {
                        opts_build.metric_temporality(MetricTemporality::Delta);
                    }
                    if let Some(global_tags) = metrics.member::<Option<HashMap<String, String>>>(id!("global_tags"))? {
                        opts_build.global_tags(global_tags);
                    }
                    let opts = opts_build
                        .build()
                        .map_err(|err| error!("Invalid OpenTelemetry options: {}", err))?;
                    core.telemetry_mut().attach_late_init_metrics(Arc::new(build_otlp_metric_exporter(opts).map_err(
                        |err| error!("Failed building OpenTelemetry exporter: {}", err),
                    )?));
                },
                (None, Some(prom), None) => {
                    let mut opts_build = PrometheusExporterOptionsBuilder::default();
                    opts_build
                        .socket_addr(
                            SocketAddr::from_str(&prom.member::<String>(id!("bind_address"))?).map_err(|err| {
                                error!("Invalid Prometheus address: {}", err)
                            })?,
                        )
                        .counters_total_suffix(prom.member(id!("counters_total_suffix"))?)
                        .unit_suffix(prom.member(id!("unit_suffix"))?)
                        .use_seconds_for_durations(prom.member(id!("durations_as_seconds"))?);
                    if let Some(global_tags) = metrics.member::<Option<HashMap<String, String>>>(id!("global_tags"))? {
                        opts_build.global_tags(global_tags);
                    }
                    let opts = opts_build
                        .build()
                        .map_err(|err| error!("Invalid Prometheus options: {}", err))?;
                    core.telemetry_mut().attach_late_init_metrics(start_prometheus_metric_exporter(opts).map_err(
                        |err| error!("Failed building starting Prometheus exporter: {}", err),
                    )?.meter);
                },
                // TODO(cretz): Metric buffering
                (None, None, Some(_buffer_size)) => return Err(error!("Metric buffering not yet supported")),
                _ => return Err(error!("One and only one of opentelemetry, prometheus, or buffered_with_size must be set"))
            };
        }

        // Create Ruby runtime
        let (async_command_tx, async_command_rx): (Sender<AsyncCommand>, Receiver<AsyncCommand>) =
            channel();
        Ok(Self {
            handle: RuntimeHandle {
                core: Arc::new(core),
                async_command_tx,
            },
            async_command_rx,
        })
    }

    // See the ext/README.md for details on how this works
    pub fn run_command_loop(&self) {
        loop {
            let cmd = without_gvl(
                || self.async_command_rx.recv(),
                || {
                    if let Err(err) = self.handle.async_command_tx.send(AsyncCommand::Shutdown) {
                        log_error!("Unable to send shutdown command: {}", err)
                    }
                },
            );
            match cmd {
                Ok(AsyncCommand::RunCallback(callback)) => {
                    if let Err(err) = callback() {
                        log_error!("Unexpected error inside async Ruby callback: {}", err);
                    }
                }
                Ok(AsyncCommand::Shutdown) => return,
                Err(err) => {
                    // Should never happen, but we exit the loop if it does
                    log_error!("Unexpected error receiving runtime command: {}", err);
                    return;
                }
            }
        }
    }
}

impl RuntimeHandle {
    /// Spawn the given future in Tokio and then, upon complete, call the given
    /// function inside a Ruby thread. The callback inside the Ruby thread must
    /// be cheap because it is one shared Ruby thread for everything. Therefore
    /// it should be something like a queue push or a fiber scheduling. It only
    /// logs the error of the callback, so callers should consider dealing with
    /// errors themselves
    pub(crate) fn spawn<T, F>(
        &self,
        without_gvl: impl Future<Output = T> + Send + 'static,
        with_gvl: F,
    ) where
        F: FnOnce(Ruby, T) -> Result<(), Error> + Send + 'static,
        T: Send + 'static,
    {
        let async_command_tx = self.async_command_tx.clone();
        self.core.tokio_handle().spawn(async move {
            let val = without_gvl.await;
            // Ignore fail to send in rare case that the runtime/handle is
            // dropped before this Tokio future runs
            let _ = async_command_tx
                .clone()
                .send(AsyncCommand::RunCallback(Box::new(
                    move || match Ruby::get() {
                        Ok(ruby) => with_gvl(ruby, val),
                        Err(err) => {
                            log_error!("Unable to get Ruby instance in async callback: {}", err);
                            Ok(())
                        }
                    },
                )));
        });
    }
}
