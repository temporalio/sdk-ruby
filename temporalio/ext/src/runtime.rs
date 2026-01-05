use super::{ROOT_MOD, error, id};
use crate::metric::{BufferedMetricRef, convert_metric_events};
use crate::util::{Struct, without_gvl};
use magnus::{
    DataTypeFunctions, Error, RArray, Ruby, TypedData, Value, function, method, prelude::*,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::str::FromStr;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::Duration;
use std::{future::Future, sync::Arc};
use temporalio_common::telemetry::HistogramBucketOverrides;
use temporalio_common::telemetry::{
    Logger, MetricTemporality, OtelCollectorOptionsBuilder, OtlpProtocol,
    PrometheusExporterOptionsBuilder, TelemetryOptionsBuilder, metrics::MetricCallBufferer,
};
use temporalio_sdk_core::telemetry::{
    MetricsCallBuffer, build_otlp_metric_exporter, start_prometheus_metric_exporter,
};
use temporalio_sdk_core::{CoreRuntime, RuntimeOptionsBuilder, TokioRuntimeBuilder};
use tracing::error as log_error;
use url::Url;

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let class = ruby
        .get_inner(&ROOT_MOD)
        .define_class("Runtime", ruby.class_object())?;
    class.define_singleton_method("new", function!(Runtime::new, 1))?;
    class.define_method("run_command_loop", method!(Runtime::run_command_loop, 0))?;
    class.define_method(
        "retrieve_buffered_metrics",
        method!(Runtime::retrieve_buffered_metrics, 1),
    )?;
    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Runtime", free_immediately)]
pub struct Runtime {
    /// Separate cloneable handle that can be referenced in other Rust objects.
    pub(crate) handle: RuntimeHandle,
    async_command_rx: Receiver<AsyncCommand>,
    metrics_call_buffer: Option<Arc<MetricsCallBuffer<BufferedMetricRef>>>,
}

#[derive(Clone)]
pub(crate) struct RuntimeHandle {
    pub(crate) pid: u32,
    pub(crate) core: Arc<CoreRuntime>,
    pub(crate) async_command_tx: Sender<AsyncCommand>,
}

#[macro_export]
macro_rules! enter_sync {
    ($runtime:expr) => {
        if let Some(subscriber) = $runtime.core.telemetry().trace_subscriber() {
            temporalio_sdk_core::telemetry::set_trace_subscriber_for_current_thread(subscriber);
        }
        let _guard = $runtime.core.tokio_handle().enter();
    };
}

pub(crate) type Callback = Box<dyn FnOnce() -> Result<(), Error> + Send + 'static>;

pub(crate) enum AsyncCommand {
    RunCallback(Callback),
    Shutdown,
}

impl Runtime {
    pub fn new(options: Struct) -> Result<Self, Error> {
        // Build options
        let mut telemetry_opts_build = TelemetryOptionsBuilder::default();
        let telemetry = options
            .child(id!("telemetry"))?
            .ok_or_else(|| error!("Missing telemetry options"))?;
        if let Some(logging) = telemetry.child(id!("logging"))? {
            telemetry_opts_build.logging(
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
            telemetry_opts_build.attach_service_name(metrics.member(id!("attach_service_name"))?);
            if let Some(prefix) = metrics.member::<Option<String>>(id!("metric_prefix"))? {
                telemetry_opts_build.metric_prefix(prefix);
            }
        }
        let opts = RuntimeOptionsBuilder::default()
            .telemetry_options(
                telemetry_opts_build
                    .build()
                    .map_err(|err| error!("Invalid telemetry options: {}", err))?,
            )
            .heartbeat_interval(
                options
                    .member::<Option<f64>>(id!("worker_heartbeat_interval"))?
                    .map(Duration::from_secs_f64),
            )
            .build()
            .map_err(|err| error!("Invalid runtime options: {}", err))?;

        // Create core runtime
        let mut core = CoreRuntime::new(opts, TokioRuntimeBuilder::default())
            .map_err(|err| error!("Failed initializing telemetry: {}", err))?;

        // Create metrics (created after Core runtime since it needs Tokio handle)
        let mut metrics_call_buffer = None;
        if let Some(metrics) = telemetry.child(id!("metrics"))? {
            let _guard = core.tokio_handle().enter();
            match (
                metrics.child(id!("opentelemetry"))?,
                metrics.child(id!("prometheus"))?,
                metrics.member::<Option<usize>>(id!("buffered_with_size"))?,
            ) {
                // Build OTel
                (Some(opentelemetry), None, None) => {
                    let mut opts_build = OtelCollectorOptionsBuilder::default();
                    opts_build
                        .url(
                            Url::parse(&opentelemetry.member::<String>(id!("url"))?)
                                .map_err(|err| error!("Invalid OTel URL: {}", err))?,
                        )
                        .use_seconds_for_durations(
                            opentelemetry.member(id!("durations_as_seconds"))?,
                        );
                    if let Some(headers) =
                        opentelemetry.member::<Option<HashMap<String, String>>>(id!("headers"))?
                    {
                        opts_build.headers(headers);
                    }
                    if let Some(period) =
                        opentelemetry.member::<Option<f64>>(id!("metric_periodicity"))?
                    {
                        opts_build.metric_periodicity(Duration::from_secs_f64(period));
                    }
                    if opentelemetry.member::<bool>(id!("metric_temporality_delta"))? {
                        opts_build.metric_temporality(MetricTemporality::Delta);
                    }
                    if let Some(global_tags) =
                        metrics.member::<Option<HashMap<String, String>>>(id!("global_tags"))?
                    {
                        opts_build.global_tags(global_tags);
                    }
                    if opentelemetry.member::<bool>(id!("http"))? {
                        opts_build.protocol(OtlpProtocol::Http);
                    }
                    if let Some(overrides) = opentelemetry
                        .member::<Option<HashMap<String, Vec<f64>>>>(id!(
                            "histogram_bucket_overrides"
                        ))?
                    {
                        opts_build
                            .histogram_bucket_overrides(HistogramBucketOverrides { overrides });
                    }
                    let opts = opts_build
                        .build()
                        .map_err(|err| error!("Invalid OpenTelemetry options: {}", err))?;
                    core.telemetry_mut().attach_late_init_metrics(Arc::new(
                        build_otlp_metric_exporter(opts).map_err(|err| {
                            error!("Failed building OpenTelemetry exporter: {}", err)
                        })?,
                    ));
                }
                (None, Some(prom), None) => {
                    let mut opts_build = PrometheusExporterOptionsBuilder::default();
                    opts_build
                        .socket_addr(
                            SocketAddr::from_str(&prom.member::<String>(id!("bind_address"))?)
                                .map_err(|err| error!("Invalid Prometheus address: {}", err))?,
                        )
                        .counters_total_suffix(prom.member(id!("counters_total_suffix"))?)
                        .unit_suffix(prom.member(id!("unit_suffix"))?)
                        .use_seconds_for_durations(prom.member(id!("durations_as_seconds"))?);
                    if let Some(global_tags) =
                        metrics.member::<Option<HashMap<String, String>>>(id!("global_tags"))?
                    {
                        opts_build.global_tags(global_tags);
                    }
                    if let Some(overrides) = prom.member::<Option<HashMap<String, Vec<f64>>>>(
                        id!("histogram_bucket_overrides"),
                    )? {
                        opts_build
                            .histogram_bucket_overrides(HistogramBucketOverrides { overrides });
                    }
                    let opts = opts_build
                        .build()
                        .map_err(|err| error!("Invalid Prometheus options: {}", err))?;
                    core.telemetry_mut().attach_late_init_metrics(
                        start_prometheus_metric_exporter(opts)
                            .map_err(|err| {
                                error!("Failed building starting Prometheus exporter: {}", err)
                            })?
                            .meter,
                    );
                }
                (None, None, Some(buffer_size)) => {
                    let buffer = Arc::new(MetricsCallBuffer::new(buffer_size));
                    core.telemetry_mut()
                        .attach_late_init_metrics(buffer.clone());
                    metrics_call_buffer = Some(buffer);
                }
                _ => {
                    return Err(error!(
                        "One and only one of opentelemetry, prometheus, or buffered_with_size must be set"
                    ));
                }
            };
        }

        // Create Ruby runtime
        let (async_command_tx, async_command_rx): (Sender<AsyncCommand>, Receiver<AsyncCommand>) =
            channel();
        Ok(Self {
            handle: RuntimeHandle {
                pid: std::process::id(),
                core: Arc::new(core),
                async_command_tx,
            },
            async_command_rx,
            metrics_call_buffer,
        })
    }

    // See the ext/README.md for details on how this works
    pub fn run_command_loop(&self) {
        enter_sync!(self.handle);
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

    pub fn retrieve_buffered_metrics(&self, durations_as_seconds: bool) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("Not in Ruby thread");
        let buff = self
            .metrics_call_buffer
            .clone()
            .expect("Attempting to retrieve buffered metrics without buffer");
        let updates = convert_metric_events(&ruby, buff.retrieve(), durations_as_seconds)?;
        Ok(ruby.ary_new_from_values(&updates))
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

    /// Same as spawn, but does not spawn in a background Tokio task and does not provide a
    /// non-GVL awaitable. This simply submits the callback to the Ruby thread inline and
    /// returns.
    pub(crate) fn spawn_sync_inline<F>(&self, with_gvl: F)
    where
        F: FnOnce(Ruby) -> Result<(), Error> + Send + 'static,
    {
        // Ignore fail to send in rare case that the runtime/handle is
        // dropped before this Tokio future runs
        let _ = self
            .async_command_tx
            .clone()
            .send(AsyncCommand::RunCallback(Box::new(
                move || match Ruby::get() {
                    Ok(ruby) => with_gvl(ruby),
                    Err(err) => {
                        log_error!("Unable to get Ruby instance in async callback: {}", err);
                        Ok(())
                    }
                },
            )));
    }

    pub(crate) fn fork_check(&self, action: &'static str) -> Result<(), Error> {
        if self.pid != std::process::id() {
            Err(error!(
                "Cannot {} across forks (original runtime PID is {}, current is {})",
                action,
                self.pid,
                std::process::id()
            ))
        } else {
            Ok(())
        }
    }
}
