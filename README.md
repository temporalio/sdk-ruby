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


## Quick Start

### Installation

Add the [`temporalio` gem](https://rubygems.org/gems/temporalio) to your Gemfile:

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
connection = Temporal::Connection.new('http://localhost:7233')

# Initialize a Client with a namespace
client = Temporal::Client.new(connection, 'my-namespace')

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
- Anything that [`JSON.generate`](https://ruby-doc.org/stdlib-3.0.0/libdoc/json/rdoc/JSON.html#method-i-generate)
  supports

This notably doesn't include any `Date`, `Time`, or `DateTime` objects as they may not work across
different SDKs. A custom payload converter can be implemented to support these.


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
