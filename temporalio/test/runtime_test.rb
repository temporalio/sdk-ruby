# frozen_string_literal: true

require 'net/http'
require 'temporalio/client'
require 'temporalio/runtime'
require 'test'
require 'uri'

class RuntimeTest < Test
  def assert_metric_line(dump, metric, **required_attrs)
    lines = dump.split("\n").select do |l|
      l.start_with?("#{metric}{") && required_attrs.all? { |k, v| l.include?("#{k}=\"#{v}\"") }
    end
    assert_equal 1, lines.size
    lines.first&.split&.last
  end

  def assert_bad_call(message_includes = nil, &)
    err = assert_raises(&)
    assert_includes err.message, message_includes if message_includes
  end

  def test_metric_basics
    # In this test, we'll use Prometheus and confirm existing metrics and custom
    # ones
    prom_addr = "127.0.0.1:#{find_free_port}"
    runtime = Temporalio::Runtime.new(
      telemetry: Temporalio::Runtime::TelemetryOptions.new(
        metrics: Temporalio::Runtime::MetricsOptions.new(
          prometheus: Temporalio::Runtime::PrometheusMetricsOptions.new(
            bind_address: prom_addr
          )
        )
      )
    )

    # Create a client on this runtime and start a non-existent workflow
    conn_opts = env.client.connection.options.with(runtime:)
    client_opts = env.client.options.with(
      connection: Temporalio::Client::Connection.new(**conn_opts.to_h) # steep:ignore
    )
    client = Temporalio::Client.new(**client_opts.to_h) # steep:ignore
    client.start_workflow('bad-workflow', id: "bad-wf-#{SecureRandom.uuid}", task_queue: 'bad-task-queue')

    # Check Prometheus metrics for a count of our request
    dump = Net::HTTP.get(URI("http://#{prom_addr}/metrics"))

    assert_equal '1', assert_metric_line(dump, 'temporal_request', operation: 'StartWorkflowExecution')

    # Make a metric meter with an additional attribute or so
    meter = runtime.metric_meter.with_additional_attributes(
      { 'attr_str' => 'str-val', attr_bool: true, attr_int: 123, attr_float: 4.56 }
    )

    # Add some custom metrics
    counter_int = meter.create_metric(
      :counter, 'my-counter-int', description: 'my-counter-int-desc', unit: 'my-counter-int-unit'
    )
    histogram_int = meter.create_metric(:histogram, 'my-histogram-int')
    histogram_float = meter.create_metric(:histogram, 'my-histogram-float', value_type: :float)
    histogram_duration = meter.create_metric(:histogram, 'my-histogram-duration', value_type: :duration)
    gauge_int = meter.create_metric(:gauge, 'my-gauge-int')
    gauge_float = meter.create_metric(:gauge, 'my-gauge-float', value_type: :float)

    # Record values on them
    counter_int.record(12)
    counter_int.record(34)
    counter_int.record(56, additional_attributes: { attr_int: 234, 'another_attr' => 'another-val' })
    histogram_int.record(75)
    histogram_int.record(125)
    histogram_float.record(525.6)
    histogram_duration.record(0.6)
    gauge_int.record(23)
    gauge_float.record(24.5)

    # Check
    dump = Net::HTTP.get(URI("http://#{prom_addr}/metrics"))

    assert(dump.split("\n").any? { |l| l == '# HELP my_counter_int my-counter-int-desc' })
    assert_equal '46', assert_metric_line(dump, 'my_counter_int',
                                          attr_str: 'str-val', attr_bool: true, attr_int: 123, attr_float: 4.56)
    assert_equal '56', assert_metric_line(dump, 'my_counter_int',
                                          attr_str: 'str-val', attr_bool: true,
                                          attr_int: 234, attr_float: 4.56, another_attr: 'another-val')

    assert_equal '0', assert_metric_line(dump, 'my_histogram_int_bucket', attr_str: 'str-val', le: 50)
    assert_equal '1', assert_metric_line(dump, 'my_histogram_int_bucket', attr_str: 'str-val', le: 100)
    assert_equal '2', assert_metric_line(dump, 'my_histogram_int_bucket', attr_str: 'str-val', le: 500)
    assert_equal '525.6', assert_metric_line(dump, 'my_histogram_float_sum', attr_str: 'str-val')
    assert_equal '600', assert_metric_line(dump, 'my_histogram_duration_sum', attr_str: 'str-val')

    assert_equal '23', assert_metric_line(dump, 'my_gauge_int', attr_str: 'str-val')
    assert_equal '24.5', assert_metric_line(dump, 'my_gauge_float', attr_str: 'str-val')

    # Confirm proper failure of bad types to calls

    # steep:ignore:start
    assert_bad_call('Unrecognized instrument type') { meter.create_metric(:invalid_metric_type, 'bad-metric') }
    assert_bad_call('Unrecognized value type') { meter.create_metric(:counter, 'bad-metric', value_type: :float) }
    assert_bad_call('Unrecognized value type') { meter.create_metric(:counter, 'bad-metric', value_type: :duration) }
    assert_bad_call('Unrecognized value type') { meter.create_metric(:histogram, 'bad-metric', value_type: :bad) }
    assert_bad_call('Unrecognized value type') { meter.create_metric(:gauge, 'bad-metric', value_type: :duration) }

    counter_int.record(45.6)
    assert_bad_call { counter_int.record(-45) }
    assert_bad_call { counter_int.record('bad') }
    histogram_float.record(-45)
    assert_bad_call { histogram_float.record('bad') }
    assert_bad_call { histogram_duration.record(-45) }
    assert_bad_call { histogram_duration.record('bad') }

    counter_int.record(
      1,
      additional_attributes: { foo: 'str', 'bar' => 1, baz: true, qux: false, quux: true, corge: 5.67 }
    )
    assert_bad_call { counter_int.record(1, additional_attributes: { foo: :bad }) }
    assert_bad_call { counter_int.record(1, additional_attributes: { foo: nil }) }
    assert_bad_call { counter_int.record(1, additional_attributes: { 123 => 'foo' }) }
    # steep:ignore:end
  end
end
