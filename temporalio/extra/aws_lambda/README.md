# Build an SDK gem for Lambda development

This directory contains SDK development tooling for building a platform-specific gem to test
unreleased Lambda support. Application examples belong in
[`temporalio/samples-ruby`](https://github.com/temporalio/samples-ruby).

## Build a Linux ARM64 gem

Install/activate the development tools described in the repository contributor guide, then run from
`temporalio/`:

```bash
rb_sys_version=$(bundle exec ruby -rrb_sys/version -e 'puts RbSys::VERSION')
protoc_version=$(mise config get tools.protoc)
image="temporalio-rbsys/aarch64-linux:${rb_sys_version}-protoc-${protoc_version}"
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE="rbsys/aarch64-linux:${rb_sys_version}" \
  --build-arg PROTOC_VERSION="$protoc_version" \
  -t "$image" -f ../.github/docker/rb-sys-protoc.Dockerfile ..
RCD_IMAGE="$image" bundle exec rb-sys-dock --platform aarch64-linux --ruby-versions 3.4 \
  -- 'bundle exec ruby extra/aws_lambda/build_gem.rb'
```

The custom builder matches the release build's protoc pin; the base cross-compiler image alone does
not include the required compiler. The build script also keeps gem packaging in cross-compilation mode
instead of recompiling for the builder's host Ruby.

The generated gem is written to `temporalio/pkg/` (repository-relative). Supply that gem to the
application sample; do not substitute a macOS extension or an uncompiled source gem.

For x86_64, replace `aarch64-linux` with `x86_64-linux` throughout and add
`--build-arg GCC_VERSION=10` to the builder-image command, as in the release workflow.
