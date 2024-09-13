# Temporal Ruby SDK

⚠️ UNDER ACTIVE DEVELOPMENT

The last tag before this refresh is [v0.1.1](https://github.com/temporalio/sdk-ruby/tree/v0.1.1). Please reference that
tag for the previous code.

**TODO: Usage documentation**

## Development

### Build

Prerequisites:

* [Ruby](https://www.ruby-lang.org/) >= 3.1 (i.e. `ruby` and `bundle` on the `PATH`)
* [Rust](https://www.rust-lang.org/) latest stable (i.e. `cargo` on the `PATH`)
* [Protobuf Compiler](https://protobuf.dev/) (i.e. `protoc` on the `PATH`)
* This repository, cloned recursively
* Change to the `temporalio/` directory

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
