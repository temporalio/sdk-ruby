# typed: strong

module Temporalio
  class Client
    module ActivityOptions
      class Key
        sig { returns(String) }
        def name; end

        sig do
          params(
            name: String,
            to_proto: T.proc.params(proto: Temporalio::Api::Activity::V1::ActivityOptions, value: Object).void
          ).void
        end
        def initialize(name, &to_proto); end

        sig { params(value: Object).returns(Temporalio::Client::ActivityOptions::Update) }
        def value_set(value); end

        sig { returns(Temporalio::Client::ActivityOptions::Update) }
        def value_unset; end

        sig { params(proto: Temporalio::Api::Activity::V1::ActivityOptions, value: Object).void }
        def _apply(proto, value); end
      end

      class Update
        sig { returns(Temporalio::Client::ActivityOptions::Key) }
        def key; end

        sig { returns(T.nilable(Object)) }
        def value; end

        sig { params(key: Temporalio::Client::ActivityOptions::Key, value: T.nilable(Object)).void }
        def initialize(key, value); end
      end

      TASK_QUEUE = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      SCHEDULE_TO_CLOSE_TIMEOUT = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      SCHEDULE_TO_START_TIMEOUT = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      START_TO_CLOSE_TIMEOUT = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      HEARTBEAT_TIMEOUT = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      START_DELAY = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      RETRY_POLICY = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
      PRIORITY = T.let(T.unsafe(nil), Temporalio::Client::ActivityOptions::Key)
    end
  end
end
