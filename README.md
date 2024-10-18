![Temporal Ruby SDK](https://raw.githubusercontent.com/temporalio/assets/main/files/w/ruby.png)

![Ruby 3.1 | 3.2 | 3.3](https://img.shields.io/badge/ruby-3.1%20%7C%203.2%20%7C%203.3-blue.svg?style=for-the-badge)
[![MIT](https://img.shields.io/github/license/temporalio/sdk-ruby.svg?style=for-the-badge)](LICENSE)
<!-- TODO: [![Gem](https://img.shields.io/gem/v/temporalio?style=for-the-badge)](https://rubygems.org/gems/temporalio) -->

[Temporal](https://temporal.io/) is a distributed, scalable, durable, and highly available orchestration engine used to
execute asynchronous, long-running business logic in a scalable and resilient way.

**Temporal Ruby SDK** is the framework for authoring workflows and activities using the Ruby programming language.

⚠️ UNDER ACTIVE DEVELOPMENT

This SDK is under active development and has not released a stable version yet. APIs may change in incompatible ways
until the SDK is marked stable. The SDK has undergone a refresh from a previous unstable version. The last tag before
this refresh is [v0.1.1](https://github.com/temporalio/sdk-ruby/tree/v0.1.1). Please reference that tag for the
previous code if needed.

Notably missing from this SDK:

* Workflow workers

**NOTE: This README is for the current branch and not necessarily what's released on RubyGems.**

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Contents**

- [Quick Start](#quick-start)
  - [Installation](#installation)
  - [Implementing an Activity](#implementing-an-activity)
  - [Running a Workflow](#running-a-workflow)
- [Usage](#usage)
  - [Client](#client)
    - [Cloud Client Using mTLS](#cloud-client-using-mtls)
    - [Data Conversion](#data-conversion)
      - [ActiveRecord and ActiveModel](#activerecord-and-activemodel)
  - [Workers](#workers)
  - [Workflows](#workflows)
  - [Activities](#activities)
    - [Activity Definition](#activity-definition)
    - [Activity Context](#activity-context)
    - [Activity Heartbeating and Cancellation](#activity-heartbeating-and-cancellation)
    - [Activity Worker Shutdown](#activity-worker-shutdown)
    - [Activity Concurrency and Executors](#activity-concurrency-and-executors)
    - [Activity Testing](#activity-testing)
  - [Platform Support](#platform-support)
- [Development](#development)
  - [Build](#build)
  - [Testing](#testing)
  - [Code Formatting and Type Checking](#code-formatting-and-type-checking)
  - [Proto Generation](#proto-generation)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Quick Start

### Installation

Install the gem to the desired version as mentioned at https://rubygems.org/gems/temporalio. Since the SDK is still in
pre-release, the version should be specified explicitly. So either in a Gemfile like:

```
gem 'temporalio', '<version>'
```

Or via `gem install` like:

```
gem install temporalio -v '<version>'
```

**NOTE**: Due to [an issue](https://github.com/temporalio/sdk-ruby/issues/162), fibers (and `async` gem) are only
supported on Ruby versions 3.3 and newer.

**NOTE**: MinGW-based Windows is not currently supported natively, but is via WSL. Prebuilt gems for Linux MUSL are also
not currently present. We also do not publish a gem for building from source at this time. See the
[Platform Support](#platform-support) section later for more information.

### Implementing an Activity

Implementing workflows is not yet supported in the Ruby SDK, but implementing activities is.

For example, if you have a `SayHelloWorkflow` workflow in another Temporal language that invokes `SayHello` activity on
`my-task-queue` in Ruby, you can have the following Ruby script:

```ruby
require 'temporalio/activity'
require 'temporalio/cancellation'
require 'temporalio/client'
require 'temporalio/worker'

# Implementation of a simple activity
class SayHelloActivity < Temporalio::Activity
  def execute(name)
    "Hello, #{name}!"
  end
end

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Create a worker with the client and activities
worker = Temporalio::Worker.new(
  client:,
  task_queue: 'my-task-queue',
  # There are various forms an activity can take, see specific section for details.
  activities: [SayHelloActivity]
)

# Run the worker until SIGINT. This can be done in many ways, see specific
# section for details.
worker.run(shutdown_signals: ['SIGINT'])
```

Running that will run the worker until Ctrl+C pressed.

### Running a Workflow

Assuming that `SayHelloWorkflow` just calls this activity, it can be run like so:

```ruby
require 'temporalio/client'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Run workflow
result = client.execute_workflow(
  'SayHelloWorkflow',
  'Temporal',
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
  'SayHelloWorkflow',
  'Temporal',
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
* [`JSON` module](https://docs.ruby-lang.org/en/master/JSON.html) for everything else

This means that normal Ruby objects will use `JSON.generate` when serializing and `JSON.parse` when deserializing (with
`create_additions: true` set by default). So a Ruby object will often appear as a hash when deserialized. While
"JSON Additions" are supported, it is not cross-SDK-language compatible since this is a Ruby-specific construct.

The default payload converter is a collection of "encoding payload converters". On serialize, each encoding converter
will be tried in order until one accepts (default falls through to the JSON one). The encoding converter sets an
`encoding` metadata value which is used to know which converter to use on deserialize. Custom encoding converters can be
created, or even the entire payload converter can be replaced with a different implementation.

##### ActiveRecord and ActiveModel

By default, `ActiveRecord` and `ActiveModel` objects do not natively support the `JSON` module. A mixin can be created
to add this support for `ActiveRecord`, for example:

```ruby
module ActiveRecordJSONSupport
  extend ActiveSupport::Concern
  include ActiveModel::Serializers::JSON

  included do
    def to_json(*args)
      hash = as_json
      hash[::JSON.create_id] = self.class.name
      hash.to_json(*args)
    end

    def self.json_create(object)
      object.delete(::JSON.create_id)
      ret = new
      ret.attributes = object
      ret
    end
  end
end
```

Similarly, a mixin for `ActiveModel` that adds `attributes` accessors can leverage this same mixin, for example:

```ruby
module ActiveModelJSONSupport
  extend ActiveSupport::Concern
  include ActiveRecordJSONSupport

  included do
    def attributes=(hash)
      hash.each do |key, value|
        send("#{key}=", value)
      end
    end

    def attributes
      instance_values
    end
  end
end
```

Now `include ActiveRecordJSONSupport` or `include ActiveModelJSONSupport` will make the models work with Ruby `JSON`
module and therefore Temporal. Of course any other approach to make the models work with the `JSON` module will work as
well.

### Workers

Workers host workflows and/or activities. Workflows cannot yet be written in Ruby, but activities can. Here's how to run
an activity worker:

```ruby
require 'temporalio/client'
require 'temporalio/worker'
require 'my_module'

# Create a client
client = Temporalio::Client.connect('localhost:7233', 'my-namespace')

# Create a worker with the client and activities
worker = Temporalio::Worker.new(
  client:,
  task_queue: 'my-task-queue',
  # There are various forms an activity can take, see specific section for details.
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
* The worker `run` method accepts an `shutdown_signals` array which will trap the signal and start shutdown when
  received.
* Workers work with threads or fibers (but fiber compatibility only supported for Ruby 3.3+ at this time). Fiber-based
  activities (see "Activities" section) only work if the worker is created within a fiber.
* The `run` method does not return until the worker is shut down. This means even if shutdown is triggered (e.g. via
  `Cancellation` or block completion), it may not return immediately. Activities not completing may hang worker
  shutdown, see the "Activities" section.
* Workers can have many more options not shown here (e.g. data converters and interceptors).
* The `Temporalio::Worker.run_all` class method is available for running multiple workers concurrently.

### Workflows

⚠️ Workflows cannot yet be implemented Ruby.

### Activities

#### Activity Definition

Activities can be defined in a few different ways. They are usually classes, but manual definitions are supported too.

Here is a common activity definition:

```ruby
class FindUserActivity < Temporalio::Activity
  def execute(user_id)
    User.find(user_id)
  end
end
```

Activities are defined as classes that extend `Temporalio::Activity` and provide an `execute` method. When this activity
is provided to the worker as a _class_ (e.g. `activities: [FindUserActivity]`), it will be instantiated for
_every attempt_. Many users may prefer using the same instance across activities, for example:

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
* Technically an activity definition can be created manually via `Temporalio::Activity::Definition.new` that accepts a
  proc or a block, but the class form is recommended.

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

### Platform Support

This SDK is backed by a Ruby C extension written in Rust leveraging the
[Temporal Rust Core](https://github.com/temporalio/sdk-core). Gems are currently published for the following platforms:

* `aarch64-linux`
* `x86_64-linux`
* `arm64-darwin`
* `x86_64-darwin`

This means Linux and macOS for ARM and x64 have published gems. Currently, a gem is not published for
`aarch64-linux-musl` so Alpine Linux users may need to build from scratch or use a libc-based distro.

Due to [an issue](https://github.com/temporalio/sdk-ruby/issues/172) with Windows and multi-threaded Rust, MinGW-based
Windows (i.e. `x64-mingw-ucrt`) is not supported. But WSL is supported using the normal Linux gem.

At this time a pure source gem is not published, which means that when trying to install the gem on an unsupported
platform, you may get an error that it is not available. Building from source requires many files across submodules and
requires Rust to be installed. See the [Build](#build) section for how to build a gem from the repository.

The SDK works on Ruby 3.1+, but due to [an issue](https://github.com/temporalio/sdk-ruby/issues/162), fibers (and
`async` gem) are only supported on Ruby versions 3.3 and newer.

## Development

### Build

Prerequisites:

* [Ruby](https://www.ruby-lang.org/) >= 3.1 (i.e. `ruby` and `bundle` on the `PATH`)
* [Rust](https://www.rust-lang.org/) latest stable (i.e. `cargo` on the `PATH`)
* This repository, cloned recursively
* Change to the `temporalio/` directory

First, install dependencies:

    bundle install

To build shared library for development use:

    bundle exec rake compile

Note, this is not `compile:dev` because debug-mode in Rust has
[an issue](https://github.com/rust-lang/rust/issues/34283) that causes runtime stack size problems.

To lint, build, and test release:

    bundle exec rake

### Testing

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
