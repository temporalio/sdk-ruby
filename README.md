# Temporal Ruby SDK

Temporal is a distributed, scalable, durable, and highly available orchestration engine used to
execute asynchronous long-running business logic in a scalable and resilient way.

"Temporal Ruby SDK" is the framework for authoring workflows and activities using the Ruby
programming language.

⚠️ UNDER DEVELOPMENT

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
> DEBUG=true bundle exec rspec
```

And open an IRB session using:

```sh
> DEBUG=true bundle console
```
