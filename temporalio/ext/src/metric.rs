use std::{any::Any, sync::Arc, time::Duration};

use magnus::{
    class, function,
    gc::register_mark_object,
    method,
    prelude::*,
    r_hash::ForEach,
    value::{IntoId, Lazy, Qfalse, Qtrue},
    DataTypeFunctions, Error, Float, Integer, RClass, RHash, RModule, RString, Ruby, StaticSymbol,
    Symbol, TryConvert, TypedData, Value,
};
use temporal_sdk_core_api::telemetry::metrics::{
    self, BufferInstrumentRef, CustomMetricAttributes, MetricEvent,
};

use crate::{error, id, runtime::Runtime, util::SendSyncBoxValue, ROOT_MOD};

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let class = root_mod.define_class("Metric", class::object())?;
    class.define_singleton_method("new", function!(Metric::new, 6))?;
    class.define_method("record_value", method!(Metric::record_value, 2))?;

    let inner_class = class.define_class("Meter", class::object())?;
    inner_class.define_singleton_method("new", function!(MetricMeter::new, 1))?;
    inner_class.define_method(
        "default_attributes",
        method!(MetricMeter::default_attributes, 0),
    )?;

    let inner_class = class.define_class("Attributes", class::object())?;
    inner_class.define_method(
        "with_additional",
        method!(MetricAttributes::with_additional, 1),
    )?;

    Ok(())
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(class = "Temporalio::Internal::Bridge::Metric", free_immediately)]
pub struct Metric {
    instrument: Arc<dyn Instrument>,
}

impl Metric {
    pub fn new(
        meter: &MetricMeter,
        metric_type: Symbol,
        name: String,
        description: Option<String>,
        unit: Option<String>,
        value_type: Symbol,
    ) -> Result<Metric, Error> {
        let ruby = Ruby::get().expect("Ruby not available");
        let counter = id!("counter");
        let histogram = id!("histogram");
        let gauge = id!("gauge");
        let integer = id!("integer");
        let float = id!("float");
        let duration = id!("duration");

        let params = build_metric_parameters(name, description, unit);
        let metric_type = metric_type.into_id_with(&ruby);
        let value_type = value_type.into_id_with(&ruby);
        let instrument: Arc<dyn Instrument> = if metric_type == counter {
            if value_type != integer {
                return Err(error!(
                    "Unrecognized value type for counter, must be :integer"
                ));
            }
            Arc::new(meter.core.inner.counter(params))
        } else if metric_type == histogram {
            if value_type == integer {
                Arc::new(meter.core.inner.histogram(params))
            } else if value_type == float {
                Arc::new(meter.core.inner.histogram_f64(params))
            } else if value_type == duration {
                Arc::new(meter.core.inner.histogram_duration(params))
            } else {
                return Err(error!(
                    "Unrecognized value type for histogram, must be :integer, :float, or :duration"
                ));
            }
        } else if metric_type == gauge {
            if value_type == integer {
                Arc::new(meter.core.inner.gauge(params))
            } else if value_type == float {
                Arc::new(meter.core.inner.gauge_f64(params))
            } else {
                return Err(error!(
                    "Unrecognized value type for gauge, must be :integer or :float"
                ));
            }
        } else {
            return Err(error!(
                "Unrecognized instrument type, must be :counter, :histogram, or :gauge"
            ));
        };
        Ok(Metric { instrument })
    }

    pub fn record_value(&self, value: Value, attrs: &MetricAttributes) -> Result<(), Error> {
        self.instrument.record_value(value, &attrs.core)
    }
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Metric::Meter",
    free_immediately
)]
pub struct MetricMeter {
    core: metrics::TemporalMeter,
    default_attributes: metrics::MetricAttributes,
}

impl MetricMeter {
    pub fn new(runtime: &Runtime) -> Result<Option<MetricMeter>, Error> {
        Ok(runtime
            .handle
            .core
            .telemetry()
            .get_metric_meter()
            .map(|core| {
                let default_attributes = core.inner.new_attributes(core.default_attribs.clone());
                MetricMeter {
                    core,
                    default_attributes,
                }
            }))
    }

    pub fn default_attributes(&self) -> Result<MetricAttributes, Error> {
        Ok(MetricAttributes {
            core: self.default_attributes.clone(),
            core_meter: self.core.clone(),
        })
    }
}

#[derive(DataTypeFunctions, TypedData)]
#[magnus(
    class = "Temporalio::Internal::Bridge::Metric::Attributes",
    free_immediately
)]
pub struct MetricAttributes {
    core: metrics::MetricAttributes,
    core_meter: metrics::TemporalMeter,
}

impl MetricAttributes {
    pub fn with_additional(&self, attrs: RHash) -> Result<MetricAttributes, Error> {
        let attributes = metric_key_values(attrs)?;
        let core = self
            .core_meter
            .inner
            .extend_attributes(self.core.clone(), metrics::NewAttributes { attributes });
        Ok(MetricAttributes {
            core,
            core_meter: self.core_meter.clone(),
        })
    }
}

trait Instrument: Send + Sync {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error>;
}

impl Instrument for metrics::Counter {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.add(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for metrics::Histogram {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for metrics::HistogramF64 {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for metrics::HistogramDuration {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        let secs = f64::try_convert(value)?;
        if secs < 0.0 {
            return Err(error!("Duration cannot be negative"));
        }
        self.record(Duration::from_secs_f64(secs), attrs);
        Ok(())
    }
}

impl Instrument for metrics::Gauge {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for metrics::GaugeF64 {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

fn build_metric_parameters(
    name: String,
    description: Option<String>,
    unit: Option<String>,
) -> metrics::MetricParameters {
    let mut build = metrics::MetricParametersBuilder::default();
    build.name(name);
    if let Some(description) = description {
        build.description(description);
    }
    if let Some(unit) = unit {
        build.unit(unit);
    }
    // Should be nothing that would fail validation here
    build.build().unwrap()
}

fn metric_key_values(hash: RHash) -> Result<Vec<metrics::MetricKeyValue>, Error> {
    let mut vals = Vec::with_capacity(hash.len());
    hash.foreach(|k: Value, v: Value| {
        vals.push(metric_key_value(k, v));
        Ok(ForEach::Continue)
    })?;
    vals.into_iter()
        .collect::<Result<Vec<metrics::MetricKeyValue>, Error>>()
}

fn metric_key_value(k: Value, v: Value) -> Result<metrics::MetricKeyValue, Error> {
    // Attribute key can be string or symbol
    let key = if let Some(k) = RString::from_value(k) {
        k.to_string()?
    } else if let Some(k) = Symbol::from_value(k) {
        k.name()?.to_string()
    } else {
        return Err(error!(
            "Invalid value type for attribute key, must be String or Symbol"
        ));
    };

    // Value can be string, bool, int, or float
    let val = if let Some(v) = RString::from_value(v) {
        metrics::MetricValue::String(v.to_string()?)
    } else if Qtrue::from_value(v).is_some() {
        metrics::MetricValue::Bool(true)
    } else if Qfalse::from_value(v).is_some() {
        metrics::MetricValue::Bool(false)
    } else if let Some(v) = Integer::from_value(v) {
        metrics::MetricValue::Int(v.to_i64()?)
    } else if let Some(v) = Float::from_value(v) {
        metrics::MetricValue::Float(v.to_f64())
    } else {
        return Err(error!(
            "Invalid value type for attribute value, must be String, Integer, Float, or boolean"
        ));
    };
    Ok(metrics::MetricKeyValue::new(key, val))
}

#[derive(Clone, Debug)]
pub struct BufferedMetricRef {
    value: Arc<SendSyncBoxValue<Value>>,
}

impl BufferInstrumentRef for BufferedMetricRef {}

#[derive(Debug)]
struct BufferedMetricAttributes {
    value: SendSyncBoxValue<RHash>,
}

impl CustomMetricAttributes for BufferedMetricAttributes {
    fn as_any(self: Arc<Self>) -> Arc<dyn Any + Send + Sync> {
        self as Arc<dyn Any + Send + Sync>
    }
}

static METRIC_BUFFER_UPDATE: Lazy<RClass> = Lazy::new(|ruby| {
    let cls = ruby
        .class_object()
        .const_get::<_, RModule>("Temporalio")
        .unwrap()
        .const_get::<_, RClass>("Runtime")
        .unwrap()
        .const_get::<_, RClass>("MetricBuffer")
        .unwrap()
        .const_get("Update")
        .unwrap();
    // Make sure class is not GC'd
    register_mark_object(cls);
    cls
});

static METRIC_BUFFER_METRIC: Lazy<RClass> = Lazy::new(|ruby| {
    let cls = ruby
        .class_object()
        .const_get::<_, RModule>("Temporalio")
        .unwrap()
        .const_get::<_, RClass>("Runtime")
        .unwrap()
        .const_get::<_, RClass>("MetricBuffer")
        .unwrap()
        .const_get("Metric")
        .unwrap();
    // Make sure class is not GC'd
    register_mark_object(cls);
    cls
});

static METRIC_KIND_COUNTER: Lazy<StaticSymbol> = Lazy::new(|ruby| ruby.sym_new("counter"));
static METRIC_KIND_GAUGE: Lazy<StaticSymbol> = Lazy::new(|ruby| ruby.sym_new("gauge"));
static METRIC_KIND_HISTOGRAM: Lazy<StaticSymbol> = Lazy::new(|ruby| ruby.sym_new("histogram"));

pub fn convert_metric_events(
    ruby: &Ruby,
    events: Vec<MetricEvent<BufferedMetricRef>>,
    durations_as_seconds: bool,
) -> Result<Vec<Value>, Error> {
    let temp: Result<Vec<Option<Value>>, Error> = events
        .into_iter()
        .map(|e| convert_metric_event(ruby, e, durations_as_seconds))
        .collect();
    Ok(temp?.into_iter().flatten().collect())
}

fn convert_metric_event(
    ruby: &Ruby,
    event: MetricEvent<BufferedMetricRef>,
    durations_as_seconds: bool,
) -> Result<Option<Value>, Error> {
    match event {
        // Create the metric and put it on the lazy ref
        MetricEvent::Create {
            params,
            populate_into,
            kind,
        } => {
            let cls = ruby.get_inner(&METRIC_BUFFER_METRIC);
            let val: Value = cls.funcall(
                "new",
                (
                    // Name
                    params.name.to_string(),
                    // Description
                    Some(params.description)
                        .filter(|s| !s.is_empty())
                        .map(|s| s.to_string()),
                    // Unit
                    if matches!(kind, metrics::MetricKind::HistogramDuration)
                        && params.unit == "duration"
                    {
                        if durations_as_seconds {
                            Some("s".to_owned())
                        } else {
                            Some("ms".to_owned())
                        }
                    } else if params.unit.is_empty() {
                        None
                    } else {
                        Some(params.unit.to_string())
                    },
                    // Kind
                    match kind {
                        metrics::MetricKind::Counter => ruby.get_inner(&METRIC_KIND_COUNTER),
                        metrics::MetricKind::Gauge | metrics::MetricKind::GaugeF64 => {
                            ruby.get_inner(&METRIC_KIND_GAUGE)
                        }
                        metrics::MetricKind::Histogram
                        | metrics::MetricKind::HistogramF64
                        | metrics::MetricKind::HistogramDuration => {
                            ruby.get_inner(&METRIC_KIND_HISTOGRAM)
                        }
                    },
                ),
            )?;
            // Put on lazy ref
            populate_into
                .set(Arc::new(BufferedMetricRef {
                    value: Arc::new(SendSyncBoxValue::new(val)),
                }))
                .map_err(|_| error!("Failed setting metric ref"))?;
            Ok(None)
        }
        // Create the attributes and put it on the lazy ref
        MetricEvent::CreateAttributes {
            populate_into,
            append_from,
            attributes,
        } => {
            // Create a hash (from existing or new)
            let hash: RHash = match append_from {
                Some(existing) => {
                    let attrs = existing
                        .get()
                        .clone()
                        .as_any()
                        .downcast::<BufferedMetricAttributes>()
                        .map_err(|_| {
                            error!("Unable to downcast to expected buffered metric attributes")
                        })?
                        .value
                        .value(ruby);
                    attrs.funcall("dup", ())?
                }
                None => ruby.hash_new_capa(attributes.len()),
            };
            // Add attributes
            for kv in attributes.into_iter() {
                match kv.value {
                    metrics::MetricValue::String(v) => hash.aset(kv.key, v)?,
                    metrics::MetricValue::Int(v) => hash.aset(kv.key, v)?,
                    metrics::MetricValue::Float(v) => hash.aset(kv.key, v)?,
                    metrics::MetricValue::Bool(v) => hash.aset(kv.key, v)?,
                };
            }
            hash.freeze();
            // Put on lazy ref
            populate_into
                .set(Arc::new(BufferedMetricAttributes {
                    value: SendSyncBoxValue::new(hash),
                }))
                .map_err(|_| error!("Failed setting metric attrs"))?;
            Ok(None)
        }
        // Convert to Ruby metric update
        MetricEvent::Update {
            instrument,
            attributes,
            update,
        } => {
            let cls = ruby.get_inner(&METRIC_BUFFER_UPDATE);
            Ok(Some(
                cls.funcall(
                    "new",
                    (
                        // Metric
                        instrument.get().clone().value.clone().value(ruby),
                        // Value
                        match update {
                            metrics::MetricUpdateVal::Duration(v) if durations_as_seconds => {
                                ruby.into_value(v.as_secs_f64())
                            }
                            metrics::MetricUpdateVal::Duration(v) => {
                                // As of this writing, https://github.com/matsadler/magnus/pull/136 not released, so we will do
                                // the logic ourselves
                                let val = v.as_millis();
                                if val <= u64::MAX as u128 {
                                    ruby.into_value(val as u64)
                                } else {
                                    ruby.module_kernel()
                                        .funcall("Integer", (val.to_string(),))
                                        .unwrap()
                                }
                            }
                            metrics::MetricUpdateVal::Delta(v) => ruby.into_value(v),
                            metrics::MetricUpdateVal::DeltaF64(v) => ruby.into_value(v),
                            metrics::MetricUpdateVal::Value(v) => ruby.into_value(v),
                            metrics::MetricUpdateVal::ValueF64(v) => ruby.into_value(v),
                        },
                        // Attributes
                        attributes
                            .get()
                            .clone()
                            .as_any()
                            .downcast::<BufferedMetricAttributes>()
                            .map_err(|_| {
                                error!("Unable to downcast to expected buffered metric attributes")
                            })?
                            .value
                            .value(ruby),
                    ),
                )?,
            ))
        }
    }
}
