# Temporal Ruby SDK

[![CI status](https://github.com/temporalio/sdk-ruby/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/temporalio/sdk-ruby/actions/workflows/ci.yml?query=branch%3Amain)
[![Build](https://github.com/temporalio/sdk-ruby/actions/workflows/build-native-ext.yml/badge.svg)](https://github.com/temporalio/sdk-ruby/actions/workflows/build-native-ext.yml?query=branch%3Amain+event%3Arelease)
[![Gem Version](https://badge.fury.io/rb/temporalio.svg)](https://rubygems.org/gems/temporalio)

[Temporal](https://temporal.io/) is a distributed, scalable, durable, and highly available
orchestration engine used to execute asynchronous long-running business logic in a scalable and
resilient way.

"Temporal Ruby SDK" is the framework for authoring workflows and activities using the Ruby
programming language.

⚠️ UNDER DEVELOPMENT

The Ruby SDK is under development. There are no compatibility guarantees at this time.

At this point the SDK only supports the **Temporal Client** capabilities:

- Starting a workflow (defined in any other SDK)
- Interacting with a workflow (cancelling, querying, signalling, etc)
- Interceptor and Data Conversion support
- gRPC access to Temporal Server
- Temporal Cloud is not yet supported due to the lack of TLS support, but it's coming soon

As well as **Activity Worker** capabilities:

- Definiting activities
- Activity heartbeats/cancellations
- Running activity workers

## Quick Start

### Installation

Add the [temporalio gem](https://rubygems.org/gems/temporalio) to your Gemfile:

```ruby
gem 'temporalio'
```

The SDK is now ready for use. To build from source, see [Dev Setup](#dev-setup).

**NOTE: This README is for the current branch and not necessarily what's released on RubyGems.**


## Usage

### Client

A client can be created and used to start a workflow like so:

```ruby
# Establish a gRPC connection to the server
connection = Temporalio::Connection.new('localhost:7233')

# Initialize a Client with a namespace
client = Temporalio::Client.new(connection, 'my-namespace')

# Start a workflow
handle = client.start_workflow('MyWorkflow', 'some input', id: 'my-id', task_queue: 'my-task-queue')

# Wait for the workflow to finish processing
result = handle.result
puts "Result: #{result}"
```

Some things to note about the above code:

- A `Client` does not have an explicit "close"
- TLS is not yet supported
- All positional arguments after the workflow name are treated as workflow arguments
- The `handle` represents the workflow that was started and can be used for more than just getting
  the result
- Clients can have many more options not shown here (e.g. data converters and interceptors)

### Data Conversion

Data converters are used to convert raw Temporal payloads to/from actual Ruby types. These consist
of 3 distinct types of converters:

- **Payload Converters** to convert Ruby values to/from serialized bytes
- **Payload Codecs** to convert bytes to bytes (e.g. for compression or encryption)
- **Failure Converters** to convert exceptions to/from serialized failures

The default data converter supports converting multiple types including:

- `nil`
- bytes (`String` with `Encoding::ASCII_8BIT`)
- Anything that [JSON.generate](https://ruby-doc.org/stdlib-3.0.0/libdoc/json/rdoc/JSON.html#method-i-generate)
  supports

This notably doesn't include any `Date`, `Time`, or `DateTime` objects as they may not work across
different SDKs. A custom payload converter can be implemented to support these.

### Workers

Workers host workflows (coming soon) and/or activities. Here's how to run a worker:

```ruby
require 'temporal'

# Establish a gRPC connection to the server
connection = Temporal::Connection.new('localhost:7233')

# Initialize a new worker with your activities
worker = Temporal::Worker.new(connection, 'my-namespace', 'my-task-queue', activities: [MyActivity])

# Occupy the thread by running the worker
worker.run
```

Some things to note about the above code:

- This creates/uses the same connection that is used for initializing a client
- Workers can have many more options not shown here (e.g. data converters and interceptors)

In order to have more control over running of a worker you can provide a block of code by the end of
which the worker will shut itself down:

```ruby
# Initialize worker_1, worker_2 and worker_3 as in the example above

# Run the worker for 5 seconds, then shut down
worker_1.run { sleep 5 }

# Or shut the worker down when a workflow completes (very useful for running specs):
client = Temporal::Client.new(connection, 'my-namespace')
handle = client.start_workflow('MyWorkflow', 'some input', id: 'my-id', task_queue: 'my-task-queue')
worker_2.run { handle.result }

# Or wait for some external signal to stop the worker
stop_queue = Queue.new
Signal.trap('USR1') { stop_queue.close }
worker_3.run { stop_queue.pop }
```

You can also shut down a running worker by calling `Temporal::Worker#shutdown` from a separate
thread at any time.

#### Running multiple workers

In order to run multiple workers in the same thread you can use the `Temporal::Worker.run` method:

```ruby
# Initialize workers
worker_1 = Temporal::Worker.new(connection, 'my-namespace-1', 'my-task-queue-1', activities: [MyActivity1, MyActivity2])
worker_2 = Temporal::Worker.new(connection, 'my-namespace-2', 'my-task-queue-1', activities: [MyActivity3])
worker_3 = Temporal::Worker.new(connection, 'my-namespace-1', 'my-task-queue-2', activities: [MyActivity4])

Temporal::Worker.run(worker_1, worker_2, worker_3)
```

Please note that similar to `Temporal::Worker#run`, `Temporal::Worker.run` accepts a block that
behaves the same way — the workers will be shut down when the block finishes.

You can also configure your worker to listen on process signals to initiate a shutdown:

```ruby
Temporal::Worker.run(worker_1, worker_2, worker_3, shutdown_signals: %w[INT TERM])
```

#### Worker Shutdown

The `Temporal::Worker#run` (as well as `Temporal::Worker#shutdown`) invocation will wait on all
activities to complete, so if a long-running activity does not at least respect cancellation, the
shutdown may never complete.

If a worker was initialized with a `graceful_shutdown_timeout` option then a cancellation will be
issued for every running activity after the set timeout. The bahaviour is mostly identical to a
server requested cancellation and should be handled accordingly. More on this in [Heartbeating and
Cancellation](#heartbeating-and-cancellation).

### Activities

#### Definition

Activities are defined by subclassing `Temporal::Activity` class:

```ruby
class SayHelloActivity < Temporal::Activity
  # Optionally specify a custom activity name:
  #   (The class name `SayHelloActivity` will be used by default)
  activity_name 'say-hello'

  def execute(name)
    return "Hello, #{name}!"
  end
end
```

Some things to note about activity definitions:

- Long running activities should regularly heartbeat and handle cancellation
- Activities can only have positional arguments. Best practice is to only take a single argument
  that is an object/dataclass of fields that can be added to as needed.

#### Activity Context

Activity classes have access to `Temporal::Activity::Context` via the `activity` method. Which
itself provides access to useful methods, specifically:

- `info` - Returns the immutable info of the currently running activity
- `heartbeat(*details)` - Record a heartbeat
- `cancelled?` - Whether a cancellation has been requested on this activity
- `shield` - Prevent cancel exception from being thrown during the provided block of code

##### Heartbeating and Cancellation

In order for a non-local activity to be notified of cancellation requests, it must call
`activity.heartbeat`. It is strongly recommended that all but the fastest executing activities call
this method regularly.

In addition to obtaining cancellation information, heartbeats also support detail data that is
persisted on the server for retrieval during activity retry. If an activity calls
`activity.heartbeat(123, 456)` and then fails and is retried, `activity.info.heartbeat_details` will
return an array containing `123` and `456` on the next run.

A cancellation is implemented using the `Thread#raise` method, which will raise a
`Temporal::Error::ActivityCancelled` during the execution of an activity. This means that your code
might get interrupted at any point and never complete. In order to protect critical parts of your
activities wrap them in `activity.shield`:

```ruby
class ActivityWithCriticalLogic < Temporal::Activity
  def execute
    activity.shield do
      run_business_critical_logic_1
    end

    run_non_critical_logic

    activity.shield do
      run_business_critical_logic_2
    end
  end
end
```

This will ensure that a cancellation request received while inside the `activity.shield` block will
not raise an exception until that block finishes.

In case the entire activity is considered critical, you can mark it as `shielded!` and ignore
cancellation requests altogether:

```ruby
class CriticalActivity < Temporal::Activity
  shielded!

  def execute
    ...
  end
end
```

For any long-running activity using this approach it is recommended to periodically check
`activity.cancelled?` flag and respond accordingly.

Please note that your activities can also get cancelled during a worker shutdown process ([if
configured accordingly](#worker-shutdown)).


## Dev Setup

Once you've forked/cloned the repository you want to make sure all the submodules are fetched as
well. You can do that using:

```sh
> git submodule update --recursive
```

From there you should be able to install all the Ruby gems using:

```sh
> bundle install
```

In order to compile the Rust Bridge you need to have `rust`, `cargo` and `rustup` installed. You
will also need to install the `rustfmt` component:

```sh
> rustup component add rustfmt
```

Now you should be able to compile a dev build of the Bridge:

```sh
> bundle exec rake bridge:build
```

You can then run all the specs against a dev build using:

```sh
> bundle exec rspec
```

And open an IRB session using:

```sh
> bundle console
```
