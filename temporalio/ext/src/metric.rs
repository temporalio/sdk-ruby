use std::{sync::Arc, time::Duration};

use magnus::{
    class, function, method, prelude::*, r_hash::ForEach, value::{IntoId, Qfalse, Qtrue}, DataTypeFunctions, Error, Float, Integer, RHash, RString, Ruby, Symbol, TryConvert, TypedData, Value
};
use temporal_sdk_core_api::telemetry::metrics;

use crate::{error, id, runtime::Runtime, ROOT_MOD};

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
                return Err(error!("Unrecognized value type for counter, must be :integer"));
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
                return Err(error!("Unrecognized value type for histogram, must be :integer, :float, or :duration"));
            }
        } else if metric_type == gauge {
            if value_type == integer {
                Arc::new(meter.core.inner.gauge(params))
            } else if value_type == float {
                Arc::new(meter.core.inner.gauge_f64(params))
            } else {
                return Err(error!("Unrecognized value type for gauge, must be :integer or :float"));
            }
        } else {
            return Err(error!("Unrecognized instrument type, must be :counter, :histogram, or :gauge"));
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

impl Instrument for Arc<dyn metrics::Counter> {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.add(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for Arc<dyn metrics::Histogram> {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for Arc<dyn metrics::HistogramF64> {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for Arc<dyn metrics::HistogramDuration> {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        let secs = f64::try_convert(value)?;
        if secs < 0.0 {
            return Err(error!("Duration cannot be negative"))
        }
        self.record(Duration::from_secs_f64(secs), attrs);
        Ok(())
    }
}

impl Instrument for Arc<dyn metrics::Gauge> {
    fn record_value(&self, value: Value, attrs: &metrics::MetricAttributes) -> Result<(), Error> {
        self.record(TryConvert::try_convert(value)?, attrs);
        Ok(())
    }
}

impl Instrument for Arc<dyn metrics::GaugeF64> {
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
    } else if let Some(_) = Qtrue::from_value(v) {
        metrics::MetricValue::Bool(true)
    } else if let Some(_) = Qfalse::from_value(v) {
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
