# AWS Lambda worker sample

This sample packages the SDK from this checkout in the AWS Ruby 3.4 container image. Each invocation runs a worker
until its shutdown budget is reached. The workflow and activity arguments remain positional; the AWS handler accepts
`event:` and `context:` keywords.

## Build

From `temporalio/`, build a native gem for the Lambda architecture using the repository's pinned protobuf compiler:

```sh
RB_SYS_VERSION=$(bundle exec ruby -e 'require "rb_sys/version"; puts RbSys::VERSION')
PROTOC_VERSION=$(cat ../.protoc-version)
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE="rbsys/aarch64-linux:$RB_SYS_VERSION" \
  --build-arg PROTOC_VERSION="$PROTOC_VERSION" \
  -f ../.github/docker/rb-sys-protoc.Dockerfile \
  -t temporal-ruby-lambda-builder ..
RCD_IMAGE=temporal-ruby-lambda-builder \
  bundle exec rb-sys-dock --platform aarch64-linux --ruby-versions 3.4 -- \
  'bundle exec ruby extra/aws_lambda/build_gem.rb'
```

From the repository root, build the image using the resulting gem:

```sh
docker build --platform linux/arm64 \
  -f temporalio/extra/aws_lambda/Dockerfile \
  --build-arg SDK_GEM=temporalio/pkg/temporalio-1.9.0-aarch64-linux.gem \
  -t temporal-ruby-lambda .
```

For x86-64, use `x86_64-linux`, `linux/amd64`, and a Lambda function configured for the x86-64 architecture.
Also add `--build-arg GCC_VERSION=10` when building the native gem builder, as in the release workflow.
The Dockerfile installs the optional telemetry gems; tracing is enabled only when `TEMPORAL_LAMBDA_OTEL=1`.

## Configure and deploy

Publish the image to your ECR repository and use it to create a Lambda function with an invocation timeout of at
least 15 seconds. Configure these environment variables:

| Variable | Value |
| --- | --- |
| `TEMPORAL_ADDRESS` | Temporal endpoint, including its port |
| `TEMPORAL_NAMESPACE` | Temporal namespace |
| `TEMPORAL_API_KEY` | API key, if used; TLS is enabled automatically |
| `TEMPORAL_TASK_QUEUE` | Task queue shared with the workflow starter |
| `TEMPORAL_DEPLOYMENT_NAME` | Worker deployment name |
| `TEMPORAL_WORKER_BUILD_ID` | Immutable build identifier, such as the source commit SHA |

The execution role needs the usual Lambda logging permissions. Configure Temporal Cloud's AWS Lambda compute
integration to invoke this function for the deployment version. Follow the
[Serverless Workers deployment guide](https://docs.temporal.io/production-deployment/worker-deployments/serverless-workers/aws-lambda).
The function needs network access to the Temporal endpoint.

Register the version by invoking the function once before starting a workflow pinned to it. To run the sample, set
the same Temporal and deployment environment variables locally, then run from `temporalio/`:

```sh
bundle exec ruby extra/aws_lambda/start_workflow.rb Ruby
```

The result is `Hello, Ruby!`. The event sent to the Lambda function does not contain workflow arguments; the worker
polls Temporal for tasks.

## Optional ADOT telemetry

Container functions bundle extensions in the image. Download the ADOT Collector Lambda layer matching the function
architecture and region, and extract its zip into `temporalio/extra/aws_lambda/adot/`. Choose the collector-only layer
from the [ADOT collector layer ARNs](https://aws-otel.github.io/docs/getting-started/lambda/lambda-go/).
The AWS CLI's `get-layer-version-by-arn` command returns a download URL in `Content.Location`.
Rebuild from the repository root with the optional target:

```sh
docker build --platform linux/arm64 --target with-adot \
  -f temporalio/extra/aws_lambda/Dockerfile \
  --build-arg SDK_GEM=temporalio/pkg/temporalio-1.9.0-aarch64-linux.gem \
  -t temporal-ruby-lambda-adot .
```

Enable `TEMPORAL_LAMBDA_OTEL=1` for this image.
Set `OPENTELEMETRY_COLLECTOR_CONFIG_URI=/var/task/otel-collector-config.yaml` and `AWS_REGION`.
The bundled collector configuration exports traces to X-Ray and metrics to CloudWatch Logs through EMF.
The execution role must allow the collector to write X-Ray segments and its CloudWatch log group/streams.

The Ruby trace exporter sends OTLP over HTTP to `localhost:4318/v1/traces`; Core metrics use gRPC on `localhost:4317`.
Override these separately with `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` and `OTEL_EXPORTER_OTLP_ENDPOINT`.
ADOT converts OpenTelemetry trace IDs to X-Ray's format. The plugin flushes the tracer provider after the worker drains.
Core metrics export periodically; they have no explicit flush API. This sample exports them every second. Choose
`metric_periodicity:` shorter than the invocation budget when customizing the telemetry plugin.

## Local verification

The SDK tests use a local Temporal server and fake Lambda contexts to verify deadline handling, worker shutdown,
activity retries, and workflow continuation across invocations. From `temporalio/`:

```sh
bundle exec rake test TESTOPTS="--name=/LambdaWorker/"
TEMPORAL_SORBET_RUNTIME_CHECK=1 bundle exec rake test TESTOPTS="--name=/LambdaWorker/"
```

These tests do not create or invoke AWS resources.
