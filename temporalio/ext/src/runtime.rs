use super::{error, ROOT_MOD};
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
    /// Separate cloneable handle that can be reference in other Rust objects.
    pub(crate) handle: RuntimeHandle,
    async_command_rx: Receiver<AsyncCommand>,
}

#[derive(Clone)]
pub(crate) struct RuntimeHandle {
    pub(crate) core: Arc<CoreRuntime>,
    async_command_tx: Sender<AsyncCommand>,
}

type Callback = Box<dyn FnOnce() + Send + 'static>;

enum AsyncCommand {
    RunCallback(Callback),
    Shutdown,
}

impl Runtime {
    pub fn new(options: Struct) -> Result<Self, Error> {
        // Build options
        let mut opts_build = TelemetryOptionsBuilder::default();
        let telemetry = options
            .child("telemetry")?
            .ok_or_else(|| error!("Missing telemetry options"))?;
        if let Some(logging) = telemetry.child("logging")? {
            opts_build.logging(
                if let Some(_forward_to) = logging.aref::<Option<Value>>("forward_to")? {
                    // TODO(cretz): This
                    return Err(error!("Forwarding not yet supported"));
                } else {
                    Logger::Console {
                        filter: logging.aref("log_filter")?,
                    }
                },
            );
        }
        // Set some metrics options now, but the metrics instance is late-bound
        // after CoreRuntime created since it needs Tokio runtime
        if let Some(metrics) = telemetry.child("metrics")? {
            opts_build.attach_service_name(metrics.aref("attach_service_name")?);
            if let Some(prefix) = metrics.aref::<Option<String>>("metric_prefix")? {
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
        if let Some(metrics) = telemetry.child("metrics")? {
            let _guard = core.tokio_handle().enter();
            match (metrics.child("opentelemetry")?, metrics.child("prometheus")?, metrics.child("buffered_with_size")?) {
                // Build OTel
                (Some(opentelemetry), None, None) => {
                    let mut opts_build = OtelCollectorOptionsBuilder::default();
                    opts_build.url(
                            Url::parse(&opentelemetry.aref::<String>("url")?).map_err(|err| {
                                error!("Invalid OTel URL: {}", err)
                            })?).
                            use_seconds_for_durations(opentelemetry.aref("durations_as_seconds")?);
                    if let Some(headers) = opentelemetry.aref::<Option<HashMap<String, String>>>("headers")? {
                        opts_build.headers(headers);
                    }
                    if let Some(period) = opentelemetry.aref::<Option<u64>>("metric_periodicity_ms")? {
                        opts_build.metric_periodicity(Duration::from_millis(period));
                    }
                    if opentelemetry.aref::<bool>("metric_temporality_delta")? {
                        opts_build.metric_temporality(MetricTemporality::Delta);
                    }
                    if let Some(global_tags) = metrics.aref::<Option<HashMap<String, String>>>("global_tags")? {
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
                            SocketAddr::from_str(&prom.aref::<String>("bind_address")?).map_err(|err| {
                                error!("Invalid Prometheus address: {}", err)
                            })?,
                        )
                        .counters_total_suffix(prom.aref("counters_total_suffix")?)
                        .unit_suffix(prom.aref("unit_suffix")?)
                        .use_seconds_for_durations(prom.aref("durations_as_seconds")?);
                    if let Some(global_tags) = metrics.aref::<Option<HashMap<String, String>>>("global_tags")? {
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

    pub fn run_command_loop(&self) {
        loop {
            let cmd = without_gvl(
                || self.async_command_rx.recv(),
                || {
                    // Ignore fail since we don't properly catch panics in
                    // without_gvl right now
                    let _ = self.handle.async_command_tx.send(AsyncCommand::Shutdown);
                },
            );
            if let Ok(AsyncCommand::RunCallback(callback)) = cmd {
                // TODO(cretz): Can we trust that this call is cheap?
                // TODO(cretz): Catch and unwind here?
                callback();
            } else {
                // We break on all errors/shutdown
                break;
            }
        }
    }
}

impl RuntimeHandle {
    /// Spawn the given future in Tokio and then, upon complete, call the given
    /// function inside a Ruby thread. The callback inside the Ruby thread must
    /// be cheap because it is one shared Ruby thread for everything. Therefore
    /// it should be something like a queue push or a fiber scheduling.
    pub(crate) fn spawn<T, F>(
        &self,
        without_gvl: impl Future<Output = T> + Send + 'static,
        with_gvl: F,
    ) where
        F: FnOnce(Ruby, T) + Send + 'static,
        T: Send + 'static,
    {
        let async_command_tx = self.async_command_tx.clone();
        self.core.tokio_handle().spawn(async move {
            let val = without_gvl.await;
            // Ignore fail to send in rare case that the runtime/handle is
            // dropped before this Tokio future runs
            let _ = async_command_tx
                .clone()
                .send(AsyncCommand::RunCallback(Box::new(move || {
                    if let Ok(ruby) = Ruby::get() {
                        with_gvl(ruby, val);
                    }
                })));
        });
    }
}
