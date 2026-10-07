FROM public.ecr.aws/lambda/ruby:3.4 AS worker

ARG SDK_GEM
COPY ${SDK_GEM} /tmp/temporalio.gem
RUN gem install /tmp/temporalio.gem --no-document \
    && gem install opentelemetry-sdk opentelemetry-exporter-otlp --no-document \
    && rm /tmp/temporalio.gem

COPY temporalio/extra/aws_lambda/lambda_function.rb ${LAMBDA_TASK_ROOT}/
COPY temporalio/extra/aws_lambda/telemetry.rb ${LAMBDA_TASK_ROOT}/
COPY temporalio/extra/aws_lambda/otel-collector-config.yaml ${LAMBDA_TASK_ROOT}/

CMD ["lambda_function.lambda_handler"]

FROM worker AS with-adot
COPY temporalio/extra/aws_lambda/adot/ /opt/

FROM worker AS default
