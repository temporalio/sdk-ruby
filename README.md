<div style="overflow: hidden"><img src="https://raw.githubusercontent.com/temporalio/assets/main/files/w/ruby.png" alt="Temporal Ruby SDK" /></div>

![Ruby 3.2 | 3.3 | 3.4](https://img.shields.io/badge/ruby-3.2%20|%203.3%20|%203.4-blue.svg?style=for-the-badge)
[![MIT](https://img.shields.io/github/license/temporalio/sdk-ruby.svg?style=for-the-badge)](LICENSE)
[![Gem](https://img.shields.io/gem/v/temporalio?style=for-the-badge)](https://rubygems.org/gems/temporalio)

[Temporal](https://temporal.io/) is a distributed, scalable, durable, and highly available orchestration engine used to
execute asynchronous, long-running business logic in a scalable and resilient way.

**Temporal Ruby SDK** is the framework for authoring workflows and activities using the Ruby programming language.

Also see:

* [Ruby SDK](https://github.com/temporalio/sdk-ruby)
* [Ruby Samples](https://github.com/temporalio/samples-ruby)
* [API Documentation](https://ruby.temporal.io)

**NOTE: This README is for the current branch and not necessarily what's released on RubyGems.**

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Contents**

- [Quick Start](#quick-start)
  - [Installation](#installation)
  - [Implementing a Workflow and Activity](#implementing-a-workflow-and-activity)
  - [Running a Worker](#running-a-worker)
  - [Executing a Workflow](#executing-a-workflow)
- [Usage](#usage)
  - [Client](#client)
    - [Cloud Client Using mTLS](#cloud-client-using-mtls)
    - [Cloud Client Using API Key](#cloud-client-using-api-key)
    - [Data Conversion](#data-conversion)
      - [ActiveModel](#activemodel)
      - [Converter Hints](#converter-hints)
  - [Workers](#workers)
  - [Workflows](#workflows)
    - [Workflow Definition](#workflow-definition)
    - [Running Workflows](#running-workflows)
    - [Invoking Activities](#invoking-activities)
    - [Invoking Child Workflows](#invoking-child-workflows)
    - [Timers and Conditions](#timers-and-conditions)
    - [Workflow Fiber Scheduling and Cancellation](#workflow-fiber-scheduling-and-cancellation)
    - [Workflow Futures](#workflow-futures)
    - [Workflow Utilities](#workflow-utilities)
    - [Workflow Exceptions](#workflow-exceptions)
    - [Workflow Logic Constraints](#workflow-logic-constraints)
    - [Workflow Testing](#workflow-testing)
      - [Automatic Time Skipping](#automatic-time-skipping)
      - [Manual Time Skipping](#manual-time-skipping)
      - [Mocking Activities](#mocking-activities)
    - [Workflow Replay](#workflow-replay)
    - [Advanced Workflow Safety and Escaping](#advanced-workflow-safety-and-escaping)
      - [Durable Fiber Scheduler](#durable-fiber-scheduler)
      - [Illegal Call Tracing](#illegal-call-tracing)
  - [Activities](#activities)
    - [Activity Definition](#activity-definition)
    - [Activity Context](#activity-context)
    - [Activity Heartbeating and Cancellation](#activity-heartbeating-and-cancellation)
    - [Activity Worker Shutdown](#activity-worker-shutdown)
    - [Activity Concurrency and Executors](#activity-concurrency-and-executors)
    - [Activity Testing](#activity-testing)
  - [Telemetry](#telemetry)
    - [Metrics](#metrics)
    - [OpenTelemetry Tracing](#opentelemetry-tracing)
      - [OpenTelemetry Tracing in Workflows](#opentelemetry-tracing-in-workflows)
  - [Rails](#rails)
    - [ActiveRecord](#activerecord)
    - [Lazy/Eager Loading](#lazyeager-loading)
  - [Forking](#forking)
  - [Ractors](#ractors)
  - [Platform Support](#platform-support)
  - [Migration from Coinbase Ruby SDK](#migration-from-coinbase-ruby-sdk)
- [Development](#development)
  - [Build](#build)
    - [Build Platform-specific Gem](#build-platform-specific-gem)
  - [Testing](#testing)
  - [Code Formatting and Type Checking](#code-formatting-and-type-checking)
  - [Proto Generation](#proto-generation)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Quick Start

### Installation

The Ruby SDK works with Ruby 3.2, 3.3, and 3.4.

Can require in a Gemfile like:

```
gem 'temporalio'
```

Or via `gem install` like:

```
gem install temporalio
```

**NOTE**: Only macOS ARM/x64 and Linux ARM/x64 are supported, and the platform-specific gem chosen is based on when the
gem/bundle install is performed. A source gem is published but cannot be used directly and will fail to build if tried.
MinGW-based Windows is not currently supported. There are caveats with the Google Protobuf dependency on musl-based
Linux. See the [Platform Support](#platform-support) section for more information.

**NOTE**: Due to [an issue](https://github.com/temporalio/sdk-ruby/issues/162), fibers (and `async` gem) are only
supported on Ruby versions 3.3 and newer.

### Implementing a Workflow and Activity

Activities are classes. Here is an example of a simple activity that can be put in `say_hello_activity.rb`:


```ruby
require 'temporalio/activity'

# Implementation of a simple activity
class SayHelloActivity < Temporalio::Activity::Definition
  def execute(name)
    "Hello, #{name}!"
  end
end
```

Workflows are also classes. To create the workflow, put the following in `say_hello_workflow.rb`:

```ruby
require 'temporalio/workflow'
require_relative 'say_hello_activity'

class SayHelloWorkflow < Temporalio::Workflow::Definition
  def execute(name)
    Temporalio::Workflow.execute_activity(
      SayHelloActivity,
      name,
      schedule_to_close_timeout: 300
    )
  end
end
```

This is a simple workflow that executes the `SayHelloActivity` activity.

### Running a Worker

To run this in a worker, put the following in `worker.rb`:

```ruby
require 'temporalio/client'
require 'temporalio/worker'
require_relative 'say_hello_activity'
require_relative 'say_hello_workflow'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Create a worker with the client, activities, and workflows
worker = Temporalio::Worker.new(
  client:,
  task_queue: 'my-task-queue',
  workflows: [SayHelloWorkflow],
  # There are various forms an activity can take, see "Activities" section for details
  activities: [SayHelloActivity]
)

# Run the worker until SIGINT. This can be done in many ways, see "Workers" section for details.
worker.run(shutdown_signals: ['SIGINT'])
```

Running that will run the worker until Ctrl+C is pressed.

### Executing a Workflow

To start and wait on the workflow result, with the worker program running elsewhere, put the following in
`execute_workflow.rb`:

```ruby
require 'temporalio/client'
require_relative 'say_hello_workflow'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Run workflow
result = client.execute_workflow(
  SayHelloWorkflow,
  'Temporal', # This is the input to the workflow
  id: 'my-workflow-id',
  task_queue: 'my-task-queue'
)
puts "Result: #{result}"
```

This will output:

```
Result: Hello, Temporal!
```

## Usage

### Client

A client can be created and used to start a workflow or otherwise interact with Temporal. For example:

```ruby
require 'temporalio/client'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Start a workflow
handle = client.start_workflow(
  MyWorkflow,
  'arg1', 'arg2',
  id: 'my-workflow-id',
  task_queue: 'my-task-queue'
)

# Wait for result
result = handle.result
puts "Result: #{result}"
```

Notes about the above code:

* Temporal clients are not explicitly closed.
* To enable TLS, the `tls` option can be set to `true` or a `Temporalio::Client::Connection::TLSOptions` instance.
* Instead of `start_workflow` + `result` above, `execute_workflow` shortcut can be used if the handle is not needed.
* Both `start_workflow` and `execute_workflow` accept either the workflow class or the string/symbol name of the
  workflow.
* The `handle` above is a `Temporalio::Client::WorkflowHandle` which has several other operations that can be performed
  on a workflow. To get a handle to an existing workflow, use `workflow_handle` on the client.
* Clients are thread safe and are fiber-compatible (but fiber compatibility only supported for Ruby 3.3+ at this time).

#### Cloud Client Using mTLS

Assuming a client certificate is present at `my-cert.pem` and a client key is present at `my-key.pem`, this is how to
connect to Temporal Cloud:

```ruby
require 'temporalio/client'

# Create a client
client = Temporalio::Client.connect(
  'my-namespace.a1b2c.tmprl.cloud:7233',
  'my-namespace.a1b2c',
  tls: Temporalio::Client::Connection::TLSOptions.new(
    client_cert: File.read('my-cert.pem'),
    client_private_key: File.read('my-key.pem')
  ))
```

#### Cloud Client Using API Key

Assuming the API key is 'my-api-key', this is how to connect to Temporal cloud:

```ruby
require 'temporalio/client'

# Create a client
client = Temporalio::Client.connect(
  'my-namespace.a1b2c.tmprl.cloud:7233',
  'my-namespace.a1b2c',
  api_key: 'my-api-key'
  tls: true
)
```

#### Data Conversion

Data converters are used to convert raw Temporal payloads to/from actual Ruby types. A custom data converter can be set
via the `data_converter` keyword argument when creating a client. Data converters are a combination of payload
converters, payload codecs, and failure converters. Payload converters convert Ruby values to/from serialized bytes.
Payload codecs convert bytes to bytes (e.g. for compression or encryption). Failure converters convert exceptions
to/from serialized failures.

Data converters are in the `Temporalio::Converters` module. The default data converter uses a default payload converter,
which supports the following types:

* `nil`
* "bytes" (i.e. `String` with `Encoding::ASCII_8BIT` encoding)
* `Google::Protobuf::MessageExts` instances
* [JSON module](https://docs.ruby-lang.org/en/master/JSON.html) for everything else

This means that normal Ruby objects will use `JSON.generate` when serializing and `JSON.parse` when deserializing (with
`create_additions: true` set by default). So a Ruby object will often appear as a hash when deserialized. Also, hashes
that are passed in with symbol keys end up with string keys when deserialized. While "JSON Additions" are supported, it
is not cross-SDK-language compatible since this is a Ruby-specific construct.

The default payload converter is a collection of "encoding payload converters". On serialize, each encoding converter
will be tried in order until one accepts (default falls through to the JSON one). The encoding converter sets an
`encoding` metadata value which is used to know which converter to use on deserialize. Custom encoding converters can be
created, or even the entire payload converter can be replaced with a different implementation.

**NOTE:** For ActiveRecord, or other general/ORM models that are used for a different purpose, it is not recommended to
try to reuse them as Temporal models. Eventually model purposes diverge and models for a Temporal workflows/activities
should be specific to their use for clarity and compatibility reasons. Also many Ruby ORMs do many lazy things and
therefore provide unclear serialization semantics. Instead, consider having models specific for workflows/activities and
translate to/from existing models as needed. See the next section on how to do this with ActiveModel objects.

##### ActiveModel

By default, ActiveModel objects do not natively support the `JSON` module. A mixin can be created to add this support
for ActiveRecord, for example:

```ruby
module ActiveModelJSONSupport
  extend ActiveSupport::Concern
  include ActiveModel::Serializers::JSON

  included do
    def as_json(*)
      super.merge(::JSON.create_id => self.class.name)
    end

    def to_json(*args)
      as_json.to_json(*args)
    end

    def self.json_create(object)
      object = object.dup
      object.delete(::JSON.create_id)
      new(**object.symbolize_keys)
    end
  end
end
```

Now if `include ActiveModelJSONSupport` is present on any ActiveModel class, on serialization `to_json` will be used
which will use `as_json` which calls the super `as_json` but also includes the fully qualified class name as the JSON
`create_id` key. On deserialization, Ruby JSON then uses this key to know what class to call `json_create` on.

##### Converter Hints

In most places where objects are converted to payloads or vice versa, a "hint" can be provided to tell the converter
something else about the object/payload to assist conversion. The default converters ignore these hints, but custom
converters can be written to take advantage of them. For example, hints may be used to provide a custom converter the
Ruby type to deserialize a payload into.

These hints manifest themselves various ways throughout the API. The most obvious way is when making definitions. An
activity can define `activity_arg_hint` (which accepts multiple) and/or `activity_result_hint` for activity-level hints.
Similarly, a workflow can define `workflow_arg_hint` and/or `workflow_result_hint` for workflow-level hints.
`workflow_signal`, `workflow_query`, and `workflow_update` all similarly accept `arg_hints` and `result_hint` (except
signal of course). These definition-level hints are passed to converters both from the caller side and the
implementation side.

There are some advanced payload uses in the SDK that do not currently have a way to set hints. These include
workflow/schedule memo, workflow get/upsert memo, and application error details. In some cases, users can use
`Temporalio::Converters::RawValue` and then manually convert with hints. For others, hints can be added as needed,
please open an issue or otherwise contact Temporal.

### Workers

Workers host workflows and/or activities. Here's how to run a worker:

```ruby
require 'temporalio/client'
require 'temporalio/worker'
require 'my_module'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Create a worker with the client, activities, and workflows
worker = Temporalio::Worker.new(
  client:,
  task_queue: 'my-task-queue',
  workflows: [MyModule::MyWorkflow],
  # There are various forms an activity can take, see "Activities" section for details
  activities: [MyModule::MyActivity]
)

# Run the worker until block complete
worker.run do
  something_that_waits_for_completion
end
```

Notes about the above code:

* A worker uses the same client that is used for other Temporal things.
* This just shows providing an activity class, but there are other forms, see the "Activities" section for details.
* The worker `run` method accepts an optional `Temporalio::Cancellation` object that can be used to cancel instead or in
  addition to providing a block that waits for completion.
* The worker `run` method accepts a `shutdown_signals` array which will trap the signal and start shutdown when
  received.
* Workers work with threads or fibers (but fiber compatibility only supported for Ruby 3.3+ at this time). Fiber-based
  activities (see "Activities" section) only work if the worker is created within a fiber.
* The `run` method does not return until the worker is shut down. This means even if shutdown is triggered (e.g. via
  `Cancellation` or block completion), it may not return immediately. Activities not completing may hang worker
  shutdown, see the "Activities" section.
* Workers can have many more options not shown here (e.g. tuners and interceptors).
* The `Temporalio::Worker.run_all` class method is available for running multiple workers concurrently.

### Workflows

#### Workflow Definition

Workflows are defined as classes that extend `Temporalio::Workflow::Definition`. The entry point for a workflow is
`execute` and must be defined. Methods for handling signals, queries, and updates are marked with `workflow_signal`,
`workflow_query`, and `workflow_update` just before the method is defined. Here is an example of a workflow definition:

```ruby
require 'temporalio/workflow'

class GreetingWorkflow < Temporalio::Workflow::Definition
  workflow_query_attr_reader :current_greeting

  def execute(params)
    loop do
      # Call activity called CreateGreeting to create greeting and store as attribute
      @current_greeting = Temporalio::Workflow.execute_activity(
        CreateGreeting,
        params,
        schedule_to_close_timeout: 300
      )
      Temporalio::Workflow.logger.debug("Greeting set to #{@current_greeting}")

      # Wait for param update or complete signal. Note, cancellation can occur by default
      # on wait_condition calls, so Cancellation object doesn't need to be passed
      # explicitly.
      Temporalio::Workflow.wait_condition { @greeting_params_update || @complete }

      # If there was an update, exchange and rerun. If it's _only_ a complete, finish
      # workflow with the greeting.
      if @greeting_params_update
        params, @greeting_params_update = @greeting_params_update, nil
      else
        return @current_greeting
      end
    end
  end

  workflow_update
  def update_greeting_params(greeting_params_update)
    @greeting_params_update = greeting_params_update
  end

  workflow_signal
  def complete_with_greeting
    @complete = true
  end
end
```

Notes about the above code:

* `execute` is the primary entrypoint and its result/exception represents the workflow result/failure.
* `workflow_signal`, `workflow_query` (and the shortcut seen above, `workflow_query_attr_reader`), and `workflow_update`
  implicitly create class methods usable by callers/clients. A workflow definition with no methods actually implemented
  can even be created for use by clients if the workflow is implemented elsewhere and/or in another language.
* Workflow code must be deterministic. See the "Workflow Logic Constraints" section below.
* `execute_activity` accepts either the activity class or the string/symbol for the name.

The following protected class methods are available on `Temporalio::Workflow::Definition` to customize the overall
workflow definition/behavior:

* `workflow_name` - Accepts a string or symbol to change the name. Otherwise the name is defaulted to the unqualified
  class name.
* `workflow_dynamic` - Marks a workflow as dynamic. Dynamic workflows do not have names and handle any workflow that is
  not otherwise registered. A worker can only have one dynamic workflow. It is often useful to use `workflow_raw_args`
  with this.
* `workflow_raw_args` - Have workflow arguments delivered to `execute` (and `initialize` if `workflow_init` in use) as
  `Temporalio::Converters::RawValue`s. These are wrappers for the raw payloads that have not been decoded. They can be
  decoded with `Temporalio::Workflow.payload_converter`. Using this with `*args` splat can be helpful in dynamic
  situations.
* `workflow_failure_exception_type` - Accepts one or more exception classes that will be considered workflow failure
  instead of task failure. See the "Exceptions" section later on what this means. This can be called multiple times.
* `workflow_query_attr_reader` - Is a helper that accepts one or more symbols for attributes to expose as `attr_reader`
  _and_ `workflow_query`. This means it is a superset of `attr_reader` and will not work if also using `attr_reader` or
  `attr_accessor`. If a writer is needed alongside this, use `attr_writer`.

The following protected class methods can be called just before defining instance methods to customize the
definition/behavior of the method:

* `workflow_init` - Mark an `initialize` method as needing the workflow start arguments. Otherwise, `initialize` must
  accept no required arguments. This must be placed above the `initialize` method or it will fail.
* `workflow_signal` - Mark the next method as a workflow signal. The signal name is defaulted to the method name but can
  be customized by the `name` kwarg. See the API documentation for more kwargs that can be set. Return values for
  signals are discarded and exceptions raised in signal handlers are treated as if they occurred in the primary workflow
  method. This also defines a class method of the same name to return the definition for use by clients.
* `workflow_query` - Mark the next method as a workflow query. The query name is defaulted to the method name but can
  be customized by the `name` kwarg. See the API documentation for more kwargs that can be set. The result of the method
  is the result of the query. Queries must never have any side effects, meaning they should never mutate state or try to
  wait on anything. This also defines a class method of the same name to return the definition for use by clients.
* `workflow_update` - Mark the next method as a workflow update. The update name is defaulted to the method name but can
  be customized by the `name` kwarg. See the API documentation for more kwargs that can be set. The result of the method
  is the result of the update. This also defines a class method of the same name to return the definition for use by
  clients.
* `workflow_update_validator` - Mark the next method as a validator to an update. This accepts a symbol for the
  `workflow_update` method it validates. Validators are used to do early rejection of updates and must never have any
  side effects, meaning they should never mutate state or try to wait on anything.

Workflows can be inherited, but subclass workflow-level decorators override superclass ones, and the same method can't
be decorated with different handler types/names in the hierarchy. Workflow handlers (execute or any marked method)
cannot accept keyword arguments.

#### Running Workflows

To start a workflow from a client, you can `start_workflow` and use the resulting handle:

```ruby
# Start the workflow
handle = my_client.start_workflow(
  GreetingWorkflow,
  { salutation: 'Hello', name: 'Temporal' },
  id: 'my-workflow-id',
  task_queue: 'my-task-queue'
)

# Check current greeting via query
puts "Current greeting: #{handle.query(GreetingWorkflow.current_greeting)}"

# Change the params via update
handle.execute_update(
  GreetingWorkflow.update_greeting_params,
  { salutation: 'Aloha', name: 'John' }
)

# Tell it to complete via signal
handle.signal(GreetingWorkflow.complete_with_greeting)

# Wait for workflow result
puts "Final greeting: #{handle.result}"
```

Some things to note about the above code:

* This uses the `GreetingWorkflow` workflow from the previous section.
* The output of this code is "Current greeting: Hello, Temporal!" and "Final greeting: Aloha, John!".
* ID and task queue are required for starting a workflow.
* Signal, query, and update calls here use the class methods created on the definition for safety. So if the
  `update_greeting_params` method didn't exist or wasn't marked as an update, the code will fail client side before even
  attempting the call. Static typing tooling may also take advantage of this for param/result type checking.
* A helper `execute_workflow` method is available on the client that is just `start_workflow` + handle `result`.

#### Invoking Activities

* Activities are executed with `Temporalio::Workflow.execute_activity`, which accepts the activity class or a
  string/symbol activity name.
* Activity options are kwargs on the `execute_activity` method. Either `schedule_to_close_timeout` or
  `start_to_close_timeout` must be set.
* Other options like `retry_policy`, `cancellation_type`, etc can also be set.
* The `cancellation` can be set to a `Cancellation` to send a cancel request to the activity. By default, the
  `cancellation` is the overall `Temporalio::Workflow.cancellation` which is the overarching workflow cancellation.
* Activity failures are raised from the call as `Temporalio::Error::ActivityError`.
* `execute_local_activity` exists with mostly the same options for local activities.

#### Invoking Child Workflows

* Child workflows are started with `Temporalio::Workflow.start_child_workflow`, which accepts the workflow class or
  string/symbol name, arguments, and other options.
* Result for `start_child_workflow` is a `Temporalio::Workflow::ChildWorkflowHandle` which has the `id`, the ability to
  wait on the `result`, and the ability to `signal` the child.
* The `start_child_workflow` call does not complete until the start has been accepted by the server.
* A helper `execute_child_workflow` method is available that is just `start_child_workflow` + handle `result`.

#### Timers and Conditions

* A timer is represented by `Temporalio::Workflow.sleep`.
  * Timers are also started on `Temporalio::Workflow.timeout`.
  * `Kernel.sleep` and `Timeout.timeout` are considered illegal by default.
  * Each timer accepts a `Cancellation`, but if none is given, it defaults to `Temporalio::Workflow.cancellation`.
* `Temporalio::Workflow.wait_condition` accepts a block that waits until the evaluated block result is truthy, then
  returns the value.
  * This function is invoked on each iteration of the internal event loop. This means it cannot have any side effects.
  * This is commonly used for checking if a variable is changed from some other part of a workflow (e.g. a signal
    handler).
  * Each wait conditions accepts a `Cancellation`, but if none is given, it defaults to
    `Temporalio::Workflow.cancellation`.

#### Workflow Fiber Scheduling and Cancellation

Workflows are backed by a custom, deterministic `Fiber::Scheduler`. All fiber calls inside a workflow use this scheduler
to ensure coroutines run deterministically. Although this means that `Kernel.sleep` and `Mutex` and such should work and
since they are Fiber-aware, Temporal intentionally disables their use by default to prevent accidental use. See
"Workflow Logic Constraints" and "Advanced Workflow Safety and Escaping" for more details, and see "Workflow Utilities"
for alternatives.

Every workflow contains a `Temporalio::Cancellation` at `Temporalio::Workflow.cancellation`. This is canceled when the
workflow is canceled. For all workflow calls that accept a cancellation token, this is the default. So if a workflow is
waiting on `execute_activity` and the workflow is canceled, that cancellation will propagate to the waiting activity.

`Cancellation`s may be created to perform cancellation more specifically. A `Cancellation` token derived from the
workflow one can be created via `my_cancel, my_cancel_proc = Cancellation.new(Temporalio::Workflow.cancellation)`. Then
`my_cancel` can be passed as `cancellation` to cancel something more specifically when `my_cancel_proc.call` is invoked.

`Cancellation`s don't have to be derived from the workflow one, they can just be created standalone or "detached". This
is useful for executing, say, a cleanup activity in an `ensure` block that needs to run even on cancel. If the cleanup
activity had instead used the workflow cancellation or one derived from it, then on cancellation it would be cancelled
before it even started.

#### Workflow Futures

`Temporalio::Workflow::Future` can be used for running things in the background or concurrently. This is basically a
safe wrapper around `Fiber.schedule` for starting and `Workflow.wait_condition` for waiting.

Nothing uses futures by default, but they work with all workflow code/constructs. For instance, to run 3 activities and
wait for them all to complete, something like this can be written:

```ruby
# Start 3 activities in background
fut1 = Temporalio::Workflow::Future.new do
  Temporalio::Workflow.execute_activity(MyActivity1, schedule_to_close_timeout: 300)
end
fut2 = Temporalio::Workflow::Future.new do
  Temporalio::Workflow.execute_activity(MyActivity2, schedule_to_close_timeout: 300)
end
fut3 = Temporalio::Workflow::Future.new do
  Temporalio::Workflow.execute_activity(MyActivity3, schedule_to_close_timeout: 300)
end

# Wait for them all to complete
Temporalio::Workflow::Future.all_of(fut1, fut2, fut3).wait

Temporalio::Workflow.logger.debug("Got: #{fut1.result}, #{fut2.result}, #{fut3.result}")
```

Or, say, to wait on the first of 5 activities or a timeout to complete:

```ruby
# Start 5 activities
act_futs = 5.times.map do |i|
  Temporalio::Workflow::Future.new do
    Temporalio::Workflow.execute_activity(MyActivity, "my-arg-#{i}", schedule_to_close_timeout: 300)
  end
end
# Start a timer
sleep_fut = Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(30) }

# Wait for first act result or sleep fut
act_result = Temporalio::Workflow::Future.any_of(sleep_fut, *act_futs).wait
# Fail if timer done first
raise Temporalio::Error::ApplicationError, 'Timer expired' if sleep_fut.done?
# Print act result otherwise
puts "Act result: #{act_result}"
```

There are several other details not covered here about futures, such as how exceptions are handled, how to use a setter
proc instead of a block, etc. See the API documentation for details.

#### Workflow Utilities

In addition to the pieces documented above, additional methods are available on `Temporalio::Workflow` that can be used
from workflows including:

* `in_workflow?` - Returns `true` if in the workflow or `false` otherwise. This is the only method on the class that can
  be called outside of a workflow without raising an exception.
* `info` - Immutable workflow information.
* `logger` - A Ruby logger that adds contextual information and takes care not to log on replay.
* `metric_meter` - A metric meter for making custom metrics that adds contextual information and takes care not to
  record on replay.
* `random` - A deterministic `Random` instance.
* `memo` - A read-only hash of the memo (updated via `upsert_memo`).
* `search_attributes` - A read-only `SearchAttributes` collection (updated via `upsert_search_attributes`).
* `now` - Current, deterministic UTC time for the workflow.
* `all_handlers_finished?` - Returns true when all signal and update handlers are done. Useful as
  `Temporalio::Workflow.wait_condition { Temporalio::Workflow.all_handlers_finished? }` for making sure not to return
  from the primary workflow method until all handlers are done.
* `patched` and `deprecate_patch` - Support for patch-based versioning inside the workflow.
* `continue_as_new_suggested` - Returns true when the server recommends performing a continue as new.
* `current_update_info` - Returns `Temporalio::Workflow::UpdateInfo` if the current code is inside an update, or nil
  otherwise.
* `external_workflow_handle` - Obtain an handle to an external workflow for signalling or cancelling.
* `payload_converter` - Payload converter if needed for converting raw args.
* `signal_handlers`, `query_handlers`, and `update_handlers` - Hashes for the current set of handlers keyed by name (or
  nil key for dynamic). `[]=` or `store` can be called on these to update the handlers, though defined handlers are
  encouraged over runtime-set ones.

There are also classes for `Temporalio::Workflow::Mutex`, `Temporalio::Workflow::Queue`, and
`Temporalio::Workflow::SizedQueue` that are workflow-safe wrappers around the standard library forms.

`Temporalio::Workflow::ContinueAsNewError` can be raised to continue-as-new the workflow. It accepts positional args and
defaults the workflow to the same as the current, though it can be changed with the `workflow` kwarg. See API
documentation for other details.

#### Workflow Exceptions

* Workflows can raise exceptions to fail the workflow/update or the "workflow task" (i.e. suspend the workflow, retrying
  until code update allows it to continue).
* By default, exceptions that are instances of `Temporalio::Error::Failure` (or `Timeout::Error`) will fail the
  workflow/update with that exception.
  * For failing the workflow/update explicitly with a user exception, explicitly raise
    `Temporalio::Error::ApplicationError`. This can be marked non-retryable or include details as needed.
  * Other exceptions that come from activity execution, child execution, cancellation, etc are already instances of
    `Temporalio::Error::Failure` and will fail the workflow/update if uncaught.
* By default, all other exceptions fail the "workflow task" which means the workflow/update will continually retry until
  the code is fixed. This is helpful for bad code or other non-predictable exceptions. To actually fail the
  workflow/update, use `Temporalio::Error::ApplicationError` as mentioned above.
* By default, all non-deterministic exceptions that are detected internally fail the "workflow task".

The default behavior can be customized at the worker level for all workflows via the
`workflow_failure_exception_types` worker option or per workflow via the `workflow_failure_exception_type` definition
method on the workflow itself. When a workflow encounters a "workflow task" fail (i.e. suspend), it will first check
either of these collections to see if the exception is an instance of any of the types and if so, will turn into a
workflow/update failure. As a special case, when a non-deterministic exception occurs and
`Temporalio::Workflow::NondeterminismError` is assignable to any of the types in the collection, that too
will turn into a workflow/update failure. However unlike other exceptions, non-deterministic exceptions that match
during update handlers become workflow failures not update failures because a non-deterministic exception is an
entire-workflow-failure situation.

#### Workflow Logic Constraints

Temporal Workflows [must be deterministic](https://docs.temporal.io/workflows#deterministic-constraints), which includes
Ruby workflows. This means there are several things workflows cannot do such as:

* Perform IO (network, disk, stdio, etc)
* Access/alter external mutable state
* Do any threading or blocking calls
* Do anything using the system clock (e.g. `Time.Now`)
* Make any random calls
* Make any not-guaranteed-deterministic calls

This means you can't even use logger calls outside of `Temporalio::Workflow.logger` because they use mutexes which may
be hit during periods of high-contention, but they are not completely disabled since users may do quick debugging with
them. See the [Advanced Workflow Safety and Escaping](#advanced-workflow-safety-and-escaping) section if needing to work
around this.

#### Workflow Testing

Workflow testing can be done in an integration-test fashion against a real server. However, it is hard to simulate
timeouts and other long time-based code. Using the time-skipping workflow test environment can help there.

A non-time-skipping `Temporalio::Testing::WorkflowEnvironment` can be started via `start_local` which supports all
standard Temporal features. It is actually a real Temporal server lazily downloaded on first use and run as a
subprocess in the background.

A time-skipping `Temporalio::Testing::WorkflowEnvironment` can be started via `start_time_skipping` which is a
reimplementation of the Temporal server with special time skipping capabilities. This too lazily downloads the process
to run when first called. Note, this class is not thread safe nor safe for use with independent tests. It can be reused,
but only for one test at a time because time skipping is locked/unlocked at the environment level. Note, the
time-skipping test server does not work on ARM-based processors at this time, though macOS ARM users can use it via the
built-in x64 translation in macOS.

##### Automatic Time Skipping

Anytime a workflow result is waited on, the time-skipping server automatically advances to the next event it can. To
manually advance time before waiting on the result of the workflow, the `WorkflowEnvironment.sleep` method can be used
on the environment itself. If an activity is running, time-skipping is disabled.

Here's a simple example of a workflow that sleeps for 24 hours:

```ruby
require 'temporalio/workflow'

class WaitADayWorkflow < Temporalio::Workflow::Definition
  def execute
    Temporalio::Workflow.sleep(1 * 24 * 60 * 60)
    'all done'
  end
end
```

A regular integration test of this workflow on a normal server would be way too slow. However, the time-skipping server
automatically skips to the next event when we wait on the result. Here's a minitest for that workflow:

```ruby
class MyTest < Minitest::Test
  def test_wait_a_day
    Temporalio::Testing::WorkflowEnvironment.start_time_skipping do |env|
      worker = Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        workflows: [WaitADayWorkflow],
        workflow_executor: Temporalio::Worker::WorkflowExecutor::ThreadPool.default
      )
      worker.run do
        result = env.client.execute_workflow(
          WaitADayWorkflow,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue
        )
        assert_equal 'all done', result
      end
    end
  end
end
```

This test will run almost instantly. This is because by calling `execute_workflow` on our client, we are actually
calling `start_workflow` + handle `result`, and `result` automatically skips time as much as it can (basically until the
end of the workflow or until an activity is run).

To disable automatic time-skipping while waiting for a workflow result, run code inside a block passed to
`auto_time_skipping_disabled`.

##### Manual Time Skipping

Until a workflow is waited on, all time skipping in the time-skipping environment is done manually via
`WorkflowEnvironment.sleep`.

Here's a workflow that waits for a signal or times out:

```ruby
require 'temporalio/workflow'

class SignalWorkflow < Temporalio::Workflow::Definition
  def execute
    Temporalio::Workflow.timeout(45) do
      Temporalio::Workflow.wait_condition { @signal_received }
      'got signal'
    rescue Timeout::Error
      'got timeout'
    end
  end

  workflow_signal
  def some_signal
    @signal_received = true
  end
end
```

To test a normal signal, you might:

```ruby
class MyTest < Minitest::Test
  def test_signal_workflow_success
    Temporalio::Testing::WorkflowEnvironment.start_time_skipping do |env|
      worker = Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        workflows: [SignalWorkflow],
        workflow_executor: Temporalio::Worker::WorkflowExecutor::ThreadPool.default
      )
      worker.run do
        handle = env.client.start_workflow(
          SignalWorkflow,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue
        )
        handle.signal(SignalWorkflow.some_signal)
        assert_equal 'got signal', handle.result
      end
    end
  end
end
```

But how would you test the timeout part? Like so:

```ruby
class MyTest < Minitest::Test
  def test_signal_workflow_timeout
    Temporalio::Testing::WorkflowEnvironment.start_time_skipping do |env|
      worker = Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        workflows: [SignalWorkflow],
        workflow_executor: Temporalio::Worker::WorkflowExecutor::ThreadPool.default
      )
      worker.run do
        handle = env.client.start_workflow(
          SignalWorkflow,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue
        )
        env.sleep(50)
        assert_equal 'got timeout', handle.result
      end
    end
  end
end
```

This test will run almost instantly. The `env.sleep(50)` manually skips 50 seconds of time, allowing the timeout to be
triggered without actually waiting the full 45 seconds to time out.

##### Mocking Activities

When testing workflows, often you don't want to actually run the activities. Activities are just classes that extend
`Temporalio::Activity::Definition`. Simply write different/empty/fake/asserting ones and pass those to the worker to
have different activities called during the test. You may need to use `activity_name :MyRealActivityClassName` inside
the mock activity class to make it appear as the real name.

#### Workflow Replay

Given a workflow's history, it can be replayed locally to check for things like non-determinism errors. For example,
assuming the `history_json` parameter below is given a JSON string of history exported from the CLI or web UI, the
following function will replay it:

```ruby
def replay_from_json(history_json)
  replayer = Temporalio::Worker::WorkflowReplayer.new(workflows: [MyWorkflow])
  replayer.replay_workflow(Temporalio::WorkflowHistory.from_history_json(history_json))
end
```

If there is a non-determinism, this will raise an exception by default.

Workflow history can be loaded from more than just JSON. It can be fetched individually from a workflow handle, or even
in a list. For example, the following code will check that all workflow histories for a certain workflow type (i.e.
workflow class) are safe with the current workflow code.

```ruby
def check_past_histories(client)
  replayer = Temporalio::Worker::WorkflowReplayer.new(workflows: [MyWorkflow])
  results = replayer.replay_workflows(client.list_workflows("WorkflowType = 'MyWorkflow'").map do |desc|
    client.workflow_handle(desc.id, run_id: desc.run_id).fetch_history
  end)
  results.each { |res| raise res.replay_failure if res.replay_failure }
end
```

But this only raises at the end because by default `replay_workflows` does not raise on failure like `replay_workflow`
does. The `raise_on_replay_failure: true` parameter could be set, or the replay worker can be used to process each one
like so:

```ruby
def check_past_histories(client)
  Temporalio::Worker::WorkflowReplayer.new(workflows: [MyWorkflow]) do |worker|
    client.list_workflows("WorkflowType = 'MyWorkflow'").each do |desc|
      worker.replay_workflow(client.workflow_handle(desc.id, run_id: desc.run_id).fetch_history)
    end
  end
end
```

See the `WorkflowReplayer` API documentation for more details.

#### Advanced Workflow Safety and Escaping

Workflows use a custom fiber scheduler to make fibers durable. There is also call tracing to prevent accidentally making
illegal workflow calls. But sometimes in advanced situations, workarounds may be needed. This section describes advanced
situations working with the workflow Fiber scheduler and illegal call tracer.

##### Durable Fiber Scheduler

By default, Temporal considers `Logger`, `sleep`, `Timeout.timeout`, `Queue`, etc illegal. However, there are cases
where it may be desired for these to work locally inside a workflow such as for logging or other side-effecting,
known-non-deterministic aspects.

Users can pass a block to `Temporalio::Workflow::Unsafe.durable_scheduler_disabled` to not use the durable scheduler.
This should be used any time the scheduler needs to be bypassed, e.g. for local stdout. Not doing this can cause
workflows to get hung in high contention situations. For instance, if there is a logger (that isn't the safe-to-use
`Temporalio::Workflow.logger`) in a workflow, _technically_ Ruby surrounds the IO writes with a mutex and in extreme
high contention that mutex may durably block and then the workflow task may complete causing hung workflows because no
event comes to wake the mutex.

Also, by default anything that relies on IO wait that is not inside `durable_scheduler_disabled` will fail. It is
recommended to put things that need this in `durable_scheduler_disabled`, but if the durable scheduler is still needed
but IO wait is also needed, then a block passed to `Temporalio::Workflow::Unsafe.io_enabled` can be used.

Note `durable_scheduler_disabled` implies `illegal_call_tracing_disabled` (see next section). Many use of 
`durable_scheduler_disabled`, such as for tracing or logging, often surround themselves in a
`unless Temporalio::Workflow.replaying?` block to make sure they don't duplicate the side effects on replay.

##### Illegal Call Tracing

Ruby workflow threads employ a `TracePoint` to catch illegal calls such as `sleep` or `Time.now` or `Thread.new`. The
set of illegal calls can be configured via the `illegal_workflow_calls` parameter when creating a worker. The default
set is at `Temporalio::Worker.default_illegal_workflow_calls`.

When an illegal call is encountered, an exception is thrown. In advanced cases there may be a need to allow an illegal
call that is known to be used deterministically. This code can be in a block passed to
`Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled`. If this has side-effecting behavior that needs to use the
non-durable scheduler, use `durable_scheduler_disabled` instead (which implies this, see previous section).

### Activities

#### Activity Definition

Activities can be defined in a few different ways. They are usually classes, but manual definitions are supported too.

Here is a common activity definition:

```ruby
class FindUserActivity < Temporalio::Activity::Definition
  def execute(user_id)
    User.find(user_id)
  end
end
```

Activities are defined as classes that extend `Temporalio::Activity::Definition` and provide an `execute` method. When
this activity is provided to the worker as a _class_ (e.g. `activities: [FindUserActivity]`), it will be instantiated
for _every attempt_. Many users may prefer using the same instance across activities, for example:

```ruby
class FindUserActivity < Temporalio::Activity
  def initialize(db)
    @db = db
  end

  def execute(user_id)
    @db[:users].first(id: user_id)
  end
end
```

When this is provided to a worker as an instance of the activity (e.g. `activities: [FindUserActivity.new(my_db)]`) then
the same instance is reused for each activity.

Some notes about activity definition:

* Temporal activities are identified by their name (or sometimes referred to as "activity type"). This defaults to the
  unqualified class name of the activity, but can be customized by calling the `activity_name` class method.
* Long running activities should heartbeat regularly, see "Activity Heartbeating and Cancellation" later.
* By default every activity attempt is executed in a thread on a thread pool, but fibers are also supported. See
  "Activity Concurrency and Executors" section later for more details.
* Technically an activity definition can be created manually via `Temporalio::Activity::Definition::Info.new` that
  accepts a proc or a block, but the class form is recommended.
* `activity_dynamic` can be used to mark an activity dynamic. Dynamic activities do not have names and handle any
  activity that is not otherwise registered. A worker can only have one dynamic activity.
* `workflow_raw_args` can be used to have activity arguments delivered to `execute` as
  `Temporalio::Converters::RawValue`s. These are wrappers for the raw payloads that have not been converted to types
  (but they have been decoded by the codec if present). They can be converted with `payload_converter` on the context.
* Activities cannot accept keyword arguments.

#### Activity Context

When running in an activity, the `Temporalio::Activity::Context` is available via
`Temporalio::Activity::Context.current` which is backed by a thread/fiber local. In addition to other more advanced
things, this context provides:

* `info` - Information about the running activity.
* `heartbeat` - Method to call to issue an activity heartbeat (see "Activity Heartbeating and Cancellation" later).
* `cancellation` - Instance of `Temporalio::Cancellation` canceled when an activity is canceled (see
  "Activity Heartbeating and Cancellation" later).
* `worker_shutdown_cancellation` - Instance of `Temporalio::Cancellation` canceled when worker is shutting down (see
  "Activity Worker Shutdown" later).
* `logger` - Logger that automatically appends a hash with some activity info to every message.

#### Activity Heartbeating and Cancellation

In order for a non-local activity to be notified of server-side cancellation requests, it must regularly invoke
`heartbeat` on the `Temporalio::Activity::Context` instance (available via `Temporalio::Activity::Context.current`). It
is strongly recommended that all but the fastest executing activities call this function regularly.

In addition to obtaining cancellation information, heartbeats also support detail data that is persisted on the server
for retrieval during activity retry. If an activity calls `heartbeat(123)` and then fails and is retried,
`Temporalio::Activity::Context.current.info.heartbeat_details.first` will be `123`.

An activity can be canceled for multiple reasons, some server-side and some worker side. Server side cancellation
reasons include workflow canceling the activity, workflow completing, or activity timing out. On the worker side, the
activity can be canceled on worker shutdown (see next section). By default cancellation is relayed two ways - by marking
the `cancellation` on `Temporalio::Activity::Context` as canceled, and by issuing a `Thread.raise` or `Fiber.raise` with
the `Temporalio::Error::CanceledError`.

The `raise`-by-default approach was chosen because it is dangerous to the health of the system and the continued use of
worker slots to require activities opt-in to checking for cancellation by default. But if this behavior is not wanted,
`activity_cancel_raise false` class method can be called at the top of the activity which will disable the `raise`
behavior and just set the `cancellation` as canceled.

If needing to shield work from being canceled, the `shield` call on the `Temporalio::Cancellation` object can be used
with a block for the code to be shielded. The cancellation will not take effect on the cancellation object nor the raise
call while the work is shielded (regardless of nested depth). Once the shielding is complete, the cancellation will take
effect, including `Thread.raise`/`Fiber.raise` if that remains enabled.

#### Activity Worker Shutdown

An activity can react to a worker shutdown specifically and also a normal cancellation will be sent. A worker will not
complete its shutdown while an activity is in progress.

Upon worker shutdown, the `worker_shutdown_cancellation` cancellation on `Temporalio::Activity::Context` will be
canceled. Then the worker will wait a for a grace period set by the `graceful_shutdown_period` worker option (default 0)
before issuing actual cancellation to all still-running activities.

Worker shutdown will then wait on all activities to complete. If a long-running activity does not respect cancellation,
the shutdown may never complete.

#### Activity Concurrency and Executors

By default, activities run in the "thread pool executor" (i.e. `Temporalio::Worker::ActivityExecutor::ThreadPool`). This
default is shared across all workers and is a naive thread pool that continually makes threads as needed when none are
idle/available to handle incoming work. If a thread sits idle long enough, it will be killed.

The maximum number of concurrent activities a worker will run at a time is configured via its `tuner` option. The
default is `Temporalio::Worker::Tuner.create_fixed` which defaults to 100 activities at a time for that worker. When
this value is reached, the worker will stop asking for work from the server until there are slots available again.

In addition to the thread pool executor, there is also a fiber executor in the default executor set. To use fibers, call
`activity_executor :fiber` class method at the top of the activity class (the default of this value is `:default` which
is the thread pool executor). Activities can only choose the fiber executor if the worker has been created and run in a
fiber, but thread pool executor is always available. Currently due to
[an issue](https://github.com/temporalio/sdk-ruby/issues/162), workers can only run in a fiber on Ruby versions 3.3 and
newer.

Technically the executor can be customized. The `activity_executors` worker option accepts a hash with the key as the
symbol and the value as a `Temporalio::Worker::ActivityExecutor` implementation. Users should usually not need to
customize this. If general code is needed to run around activities, users should use interceptors instead.

#### Activity Testing

Unit testing an activity can be done via the `Temporalio::Testing::ActivityEnvironment` class. Simply instantiate the
class, then invoke `run` with the activity to test and the arguments to give. The result will be the activity result or
it will raise the error raised in the activity.

The constructor of the environment has multiple keyword arguments that can be set to affect the activity context for the
activity.

### Telemetry

#### Metrics

Metrics can be configured on a `Temporalio::Runtime`. Only one runtime is expected to be created for the entire
application and it should be created before any clients are created. For example, this configures Prometheus to export
metrics at `http://127.0.0.1:9000/metrics`:

```ruby
require 'temporalio/runtime'

Temporalio::Runtime.default = Temporalio::Runtime.new(
  telemetry: Temporalio::Runtime::TelemetryOptions.new(
    metrics: Temporalio::Runtime::MetricsOptions.new(
      prometheus: Temporalio::Runtime::PrometheusMetricsOptions.new(
        bind_address: '127.0.0.1:9000'
      )
    )
  )
)
```

Now every client created will use this runtime. Setting the default will fail if a runtime has already been requested or
a default already set. Technically a runtime can be created without setting the default and be set on each client via
the `runtime` parameter, but this is discouraged because a runtime represents a heavy internal engine not meant to be
created multiple times.

OpenTelemetry metrics can be configured instead by passing `Temporalio::Runtime::OpenTelemetryMetricsOptions` as the
`opentelemetry` parameter to the metrics options. See API documentation for details.

#### OpenTelemetry Tracing

OpenTelemetry tracing for clients, activities, and workflows can be enabled using the
`Temporalio::Contrib::OpenTelemetry::TracingInterceptor`. Specifically, when creating a client, set the interceptor like
so:

```ruby
require 'opentelemetry/api'
require 'opentelemetry/sdk'
require 'temporalio/client'
require 'temporalio/contrib/open_telemetry'

# ... assumes my_otel_tracer_provider is a tracer provider created by the user
my_tracer = my_otel_tracer_provider.tracer('my-otel-tracer')

my_client = Temporalio::Client.connect(
  'localhost:7233', 'my-namespace',
  interceptors: [Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(my_tracer)]
)
```

Now many high-level client calls and activities/workflows on workers using this client will have spans created on that
OpenTelemetry tracer.

##### OpenTelemetry Tracing in Workflows

OpenTelemetry works by creating spans as necessary and in some cases serializing them to Temporal headers to be
deserialized by workflows/activities to be set on the context. However, OpenTelemetry requires spans to be finished
where they start, so spans cannot be resumed. This is fine for client calls and activity attempts, but Temporal
workflows are resumable functions that may start on a different machine than they complete. Due to this, spans created
by workflows are immediately closed since there is no way for the span to actually span machines. They are also not
created during replay. The spans still become the proper parents of other spans if they are created.

Custom spans can be created inside of workflows using class methods on the
`Temporalio::Contrib::OpenTelemetry::Workflow` module. For example:

```ruby
class MyWorkflow < Temporalio::Workflow::Definition
  def execute
    # Sleep for a bit
    Temporalio::Workflow.sleep(10)
    # Run activity in span
    Temporalio::Contrib::OpenTelemetry::Workflow.with_completed_span(
      'my-span',
      attributes: { 'my-attr' => 'some val' }
    ) do
      # Execute an activity
      Temporalio::Workflow.execute_activity(MyActivity, start_to_close_timeout: 10)
    end
  end
end
```

If this all executes on one worker (because Temporal has a concept of stickiness that caches instances), the span tree
may look like:

```
StartWorkflow:MyWorkflow          <-- created by client outbound
  RunWorkflow:MyWorkflow          <-- created inside workflow on first task
    my-span                       <-- created inside workflow by code
      StartActivity:MyActivity    <-- created inside workflow when first called
        RunActivity:MyActivity    <-- created inside activity attempt 1
    CompleteWorkflow:MyWorkflow   <-- created inside workflow on last task
```

However if, say, the worker crashed during the 10s sleep and the workflow was resumed (i.e. replayed) on another worker,
the span tree may look like:

```
StartWorkflow:MyWorkflow          <-- created by client outbound
  RunWorkflow:MyWorkflow          <-- created by workflow inbound on first task
  my-span                         <-- created inside the workflow
    StartActivity:MyActivity      <-- created by workflow outbound
      RunActivity:MyActivity      <-- created by activity attempt 1 inbound
  CompleteWorkflow:MyWorkflow     <-- created by workflow inbound on last task
```

Notice how the spans are no longer under `RunWorkflow`. This is because spans inside the workflow are not created on
replay, so there is no parent on replay. But there are no orphans because we still have the overarching parent of
`StartWorkflow` that was created by the client and is serialized into Temporal headers so it can always be the parent.

And reminder that `StartWorkflow` and `RunActivity` spans do last the length of their calls (so time to start the
workflow and time to run the activity attempt respectively), but the other spans have no measurable time because they
are created in workflows and closed immediately since long-lived spans cannot work for durable software that may resume
on other machines.

### Rails

Temporal Ruby SDK is a generic Ruby library that can work in any Ruby environment. However, there are some common
conventions for Rails users to be aware of.

See the [rails_app](https://github.com/temporalio/samples-ruby/tree/main/rails_app) sample for an example of using
Temporal from Rails.

#### ActiveRecord

For ActiveRecord, or other general/ORM models that are used for a different purpose, it is not recommended to
try to reuse them as Temporal models. Eventually model purposes diverge and models for a Temporal workflows/activities
should be specific to their use for clarity and compatibility reasons. Also many Ruby ORMs do many lazy things and
therefore provide unclear serialization semantics. Instead, consider having models specific for workflows/activities and
translate to/from existing models as needed. See the [ActiveModel](#activemodel) section on how to do this with
ActiveModel objects.

#### Lazy/Eager Loading

By default, Rails
[eagerly loads](https://guides.rubyonrails.org/v7.2/autoloading_and_reloading_constants.html#eager-loading) all
application code on application start in production, but lazily loads it in non-production environments. Temporal
workflows by default disallow use of IO during the workflow run. With lazy loading enabled in dev/test environments,
when an activity class is referenced in a workflow before it has been explicitly `require`d, it can give an error like:

> Cannot access File path from inside a workflow. If this is known to be safe, the code can be run in a
> Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled block.

This comes from `bootsnap` via `zeitwork` because it is lazily loading a class/module at workflow runtime. It is not
good to lazily load code during a workflow run because it can be side effecting. Workflows and the classes they
reference should be eagerly loaded.

To resolve this, either always eagerly load (e.g. `config.eager_load = true`) or explicitly `require` what is used by a
workflow at the top of the file.

Note, this only affects non-production environments.

### Forking

Objects created with the Temporal Ruby SDK cannot be used across forks. This includes runtimes, clients, and workers. By
default, using `Client.connect` uses `Runtime.default` which is lazily created. If it was already created on the parent,
an exception will occur when trying to reuse it to create clients or workers in a forked child. Similarly any RPC
invocation or worker execution inside of a forked child separate from where the runtime or client or worker were created
will raise an exception.

If forking must be used, make sure Temporal objects are only created _inside_ the fork.

### Ractors

It was an original goal to have workflows actually be Ractors for deterministic state isolation and have the library
support Ractors in general. However, due to the SDK's heavy use of the Google Protobuf library which
[is not Ractor-safe](https://github.com/protocolbuffers/protobuf/issues/19321), the Temporal Ruby SDK does not currently
work with Ractors.

### Platform Support

This SDK is backed by a Ruby C extension written in Rust leveraging the
[Temporal Rust Core](https://github.com/temporalio/sdk-core). Gems are currently published for the following platforms:

* `aarch64-linux`
* `aarch64-linux-musl`
* `x86_64-linux`
* `x86_64-linux-musl`
* `arm64-darwin`
* `x86_64-darwin`

This means Linux and macOS for ARM and x64 have published gems.

Due to [an issue](https://github.com/temporalio/sdk-ruby/issues/172) with Windows and multi-threaded Rust, MinGW-based
Windows (i.e. `x64-mingw-ucrt`) is not supported. But WSL is supported using the normal Linux gem.

Due to [an issue](https://github.com/protocolbuffers/protobuf/issues/16853) with Google Protobuf, latest Linux versions
of Google Protobuf gems will not work in musl-based environments. Instead use the pure "ruby" platform which will build
the Google Protobuf gem on install (e.g.
`gem 'google-protobuf', force_ruby_platform: RUBY_PLATFORM.include?('linux-musl')` in the `Gemfile`).

At this time a pure source gem is published for documentation reasons, but it cannot be built and will fail if tried.
Building from source requires many files across submodules and requires Rust to be installed. See the [Build](#build)
section for how to build a the repository.

The SDK works on Ruby 3.2+, but due to [an issue](https://github.com/temporalio/sdk-ruby/issues/162), fibers (and
`async` gem) are only supported on Ruby versions 3.3 and newer.

### Migration from Coinbase Ruby SDK

The [Coinbase Ruby SDK](https://github.com/coinbase/temporal-ruby) predates this official Temporal SDK and has been a
popular approach to developing in Temporal with Ruby. While Temporal encourages users to use the official SDK to get new
features and support, this section covers differences from the Coinbase SDK to help those looking to migrate.

See [this Ruby sample](https://github.com/temporalio/samples-ruby/tree/main/coinbase_ruby) which demonstrates
interoperability between Coinbase Ruby and Temporal Ruby clients, workflows, and activities. Specifically, it discusses
how to disable API class loading on the Coinbase Ruby side if needing to use both dependencies in the same project,
since two sets of API classes cannot both be present.

Migration cannot be done on a live, running workflow. Overall, Coinbase Ruby workflow events are incompatible with
Temporal Ruby workflow events at runtime, so both SDK versions cannot have workers for the same task queue. A live
workflow migration cannot occur, an separate task queue would be needed. However, Coinbase Ruby clients, workflows, and
activities can be used with Temporal Ruby clients, workflows, and activities in either direction. Migrating from the
Coinbase Ruby SDK to the Temporal Ruby SDK would be similar to migrating from Temporal Go SDK to Temporal Java SDK. You
can interact across, but the workflow events are incompatible and therefore the task queues cannot be served by both at
the same time.

Here is an overview of the primary differences between the SDKs:

| Feature | Coinbase Ruby | Temporal Ruby |
| --- | --- | --- |
| Base module | `Temporal::` | `Temporalio::` |
| Client + start workflow | Global `Temporal.configure` + `Temporal.start_workflow` | `Temporalio::Client.connect` + `my_client.start_workflow` |
| Client implementation | Ruby gRPC | Rust gRPC |
| Activity definition | Extend `Temporal::Activity` + impl `execute` | Extend `Temporalio::Activity::Definition` + impl `execute` |
| Workflow definition | Extend `Temporal::Workflow` + impl `execute` | Extend `Temporalio::Workflow::Definition` + impl `execute` |
| Invoke activity from workflow | `MyActivity.execute!` or `workflow.execute_activity!(MyActivity)` | `Workflow.execute_activity(MyActivity)` |
| Handle signal/query/update in workflow | `workflow.on_signal`/`workflow.on_query`/update-unsupported | Decorate with `workflow_signal`/`workflow_query`/`workflow_update` |
| Run worker | `Temporal::Worker.new` + `start` | `Temporalio::Worker.new` + `run` |

This is just a high-level overview, there are many more differences on more specific Temporal components.

## Development

### Build

Prerequisites:

* [Ruby](https://www.ruby-lang.org/) >= 3.2 (i.e. `ruby` and `bundle` on the `PATH`)
* [Rust](https://www.rust-lang.org/) latest stable (i.e. `cargo` on the `PATH`)
* This repository, cloned recursively
* Change to the `temporalio/` directory

First, install dependencies:

    # Optional: Change bundler install path to be local
    bundle config --local path $(pwd)/.bundle
    bundle install

To build shared library for development use (ensure you have cloned submodules) :

    bundle exec rake compile

**NOTE**: This will make the current directory usable for the current Ruby version by putting the shared library
`lib/temporalio/internal/bridge/temporalio_bridge.<ext>` in the proper place. But this development shared library may
not work for other Ruby versions or other OS/arch combinations. For that, see "Build Platform-specific Gem" below.

**NOTE**: This is not `compile:dev` because debug-mode in Rust has
[an issue](https://github.com/rust-lang/rust/issues/34283) that causes runtime stack size problems.

To lint, build, and test:

    bundle exec rake

#### Build Platform-specific Gem

The standard `bundle exec rake build` will produce a gem in the `pkg` directory, but that gem will not be usable because
the shared library is not present (neither the Rust code nor the compiled form). To create a platform-specific gem that
can be used, `rb-sys-dock` must be run. See the
[Cross-Compilation documentation](https://oxidize-rb.github.io/rb-sys/tutorial/publishing/cross-compilation.html) in the
`rb-sys` repository. For example, running:

    bundle exec rb-sys-dock --platform x86_64-linux --ruby-versions 3.2,3.3 --build

Will create a `pkg/temporalio-<version>-x86_64-linux.gem` file that can be used in x64 Linux environments on both Ruby
3.2 and Ruby 3.3 because it contains the shared libraries. For this specific example, the shared libraries are inside
the gem at `lib/temporalio/internal/bridge/3.2/temporalio_bridge.so` and
`lib/temporalio/internal/bridge/3.3/temporalio_bridge.so`.

### Testing

Note you can set `TEMPORAL_TEST_CLIENT_TARGET_HOST` and `TEMPORAL_TEST_CLIENT_TARGET_NAMESPACE`
(optional, defaults to 'default') environment variables to use an existing server.

This project uses `minitest`. To test:

    bundle exec rake test

Can add options via `TESTOPTS`. E.g. single test:

    bundle exec rake test TESTOPTS="--name=test_some_method"

E.g. all starting with prefix:

    bundle exec rake test TESTOPTS="--name=/^test_some_method_prefix/"

E.g. all for a class:

    bundle exec rake test TESTOPTS="--name=/SomeClassName/"

E.g. show all test names while executing:

    bundle exec rake test TESTOPTS="--verbose"

### Code Formatting and Type Checking

This project uses `rubocop`:

    bundle exec rake rubocop:autocorrect

This project uses `steep`. First may need the RBS collection:

    bundle exec rake rbs:install_collection

Now can run `steep`:

    bundle exec rake steep

### Proto Generation

Run:

    bundle exec rake proto:generate
