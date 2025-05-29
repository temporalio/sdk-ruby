# frozen_string_literal: true

module Temporalio
  class Worker
    module Interceptor
      # Mixin for intercepting activity worker work. Clases that `include` may implement their own {intercept_activity}
      # that returns their own instance of {Inbound}.
      #
      # @note Input classes herein may get new required fields added and therefore the constructors of the Input classes
      #   may change in backwards incompatible ways. Users should not try to construct Input classes themselves.
      module Activity
        # Method called when intercepting an activity. This is called when starting an activity attempt.
        #
        # @param next_interceptor [Inbound] Next interceptor in the chain that should be called. This is usually passed
        #   to {Inbound} constructor.
        # @return [Inbound] Interceptor to be called for activity calls.
        def intercept_activity(next_interceptor)
          next_interceptor
        end

        # Input for {Inbound.execute}.
        ExecuteInput = Data.define(
          :proc,
          :args,
          :headers
        )

        # Inbound interceptor for intercepting inbound activity calls. This should be extended by users needing to
        # intercept activities.
        class Inbound
          # @return [Inbound] Next interceptor in the chain.
          attr_reader :next_interceptor

          # Initialize inbound with the next interceptor in the chain.
          #
          # @param next_interceptor [Inbound] Next interceptor in the chain.
          def initialize(next_interceptor)
            @next_interceptor = next_interceptor
          end

          # Initialize the outbound interceptor. This should be extended by users to return their own {Outbound}
          # implementation that wraps the parameter here.
          #
          # @param outbound [Outbound] Next outbound interceptor in the chain.
          # @return [Outbound] Outbound activity interceptor.
          def init(outbound)
            @next_interceptor.init(outbound)
          end

          # Execute an activity and return result or raise exception. Next interceptor in chain (i.e. `super`) will
          # perform the execution.
          #
          # @param input [ExecuteInput] Input information.
          # @return [Object] Activity result.
          def execute(input)
            @next_interceptor.execute(input)
          end
        end

        # Input for {Outbound.heartbeat}.
        HeartbeatInput = Data.define(
          :details
        )

        # Outbound interceptor for intercepting outbound activity calls. This should be extended by users needing to
        # intercept activity calls.
        class Outbound
          # @return [Outbound] Next interceptor in the chain.
          attr_reader :next_interceptor

          # Initialize outbound with the next interceptor in the chain.
          #
          # @param next_interceptor [Outbound] Next interceptor in the chain.
          def initialize(next_interceptor)
            @next_interceptor = next_interceptor
          end

          # Issue a heartbeat.
          #
          # @param input [HeartbeatInput] Input information.
          def heartbeat(input)
            @next_interceptor.heartbeat(input)
          end
        end
      end

      # Mixin for intercepting workflow worker work. Classes that `include` may implement their own {intercept_workflow}
      # that returns their own instance of {Inbound}.
      #
      # @note Input classes herein may get new required fields added and therefore the constructors of the Input classes
      #   may change in backwards incompatible ways. Users should not try to construct Input classes themselves.
      module Workflow
        # Method called when intercepting a workflow. This is called when creating a workflow instance.
        #
        # @param next_interceptor [Inbound] Next interceptor in the chain that should be called. This is usually passed
        #   to {Inbound} constructor.
        # @return [Inbound] Interceptor to be called for workflow calls.
        def intercept_workflow(next_interceptor)
          next_interceptor
        end

        # Input for {Inbound.execute}.
        ExecuteInput = Data.define(
          :args,
          :headers
        )

        # Input for {Inbound.handle_signal}.
        HandleSignalInput = Data.define(
          :signal,
          :args,
          :definition,
          :headers
        )

        # Input for {Inbound.handle_query}.
        HandleQueryInput = Data.define(
          :id,
          :query,
          :args,
          :definition,
          :headers
        )

        # Input for {Inbound.validate_update} and {Inbound.handle_update}.
        HandleUpdateInput = Data.define(
          :id,
          :update,
          :args,
          :definition,
          :headers
        )

        # Inbound interceptor for intercepting inbound workflow calls. This should be extended by users needing to
        # intercept workflows.
        class Inbound
          # @return [Inbound] Next interceptor in the chain.
          attr_reader :next_interceptor

          # Initialize inbound with the next interceptor in the chain.
          #
          # @param next_interceptor [Inbound] Next interceptor in the chain.
          def initialize(next_interceptor)
            @next_interceptor = next_interceptor
          end

          # Initialize the outbound interceptor. This should be extended by users to return their own {Outbound}
          # implementation that wraps the parameter here.
          #
          # @param outbound [Outbound] Next outbound interceptor in the chain.
          # @return [Outbound] Outbound workflow interceptor.
          def init(outbound)
            @next_interceptor.init(outbound)
          end

          # Execute a workflow and return result or raise exception. Next interceptor in chain (i.e. `super`) will
          # perform the execution.
          #
          # @param input [ExecuteInput] Input information.
          # @return [Object] Workflow result.
          def execute(input)
            @next_interceptor.execute(input)
          end

          # Handle a workflow signal. Next interceptor in chain (i.e. `super`) will perform the handling.
          #
          # @param input [HandleSignalInput] Input information.
          def handle_signal(input)
            @next_interceptor.handle_signal(input)
          end

          # Handle a workflow query and return result or raise exception. Next interceptor in chain (i.e. `super`) will
          # perform the handling.
          #
          # @param input [HandleQueryInput] Input information.
          # @return [Object] Query result.
          def handle_query(input)
            @next_interceptor.handle_query(input)
          end

          # Validate a workflow update. Next interceptor in chain (i.e. `super`) will perform the validation.
          #
          # @param input [HandleUpdateInput] Input information.
          def validate_update(input)
            @next_interceptor.validate_update(input)
          end

          # Handle a workflow update and return result or raise exception. Next interceptor in chain (i.e. `super`) will
          # perform the handling.
          #
          # @param input [HandleUpdateInput] Input information.
          # @return [Object] Update result.
          def handle_update(input)
            @next_interceptor.handle_update(input)
          end
        end

        # Input for {Outbound.cancel_external_workflow}.
        CancelExternalWorkflowInput = Data.define(
          :id,
          :run_id
        )

        # Input for {Outbound.execute_activity}.
        ExecuteActivityInput = Data.define(
          :activity,
          :args,
          :task_queue,
          :summary,
          :schedule_to_close_timeout,
          :schedule_to_start_timeout,
          :start_to_close_timeout,
          :heartbeat_timeout,
          :retry_policy,
          :cancellation,
          :cancellation_type,
          :activity_id,
          :disable_eager_execution,
          :headers,
          :priority
        )

        # Input for {Outbound.execute_local_activity}.
        ExecuteLocalActivityInput = Data.define(
          :activity,
          :args,
          :schedule_to_close_timeout,
          :schedule_to_start_timeout,
          :start_to_close_timeout,
          :retry_policy,
          :local_retry_threshold,
          :cancellation,
          :cancellation_type,
          :activity_id,
          :headers
        )

        # Input for {Outbound.initialize_continue_as_new_error}.
        InitializeContinueAsNewErrorInput = Data.define(
          :error
        )

        # Input for {Outbound.signal_child_workflow}.
        SignalChildWorkflowInput = Data.define(
          :id,
          :signal,
          :args,
          :cancellation,
          :headers
        )

        # Input for {Outbound.signal_external_workflow}.
        SignalExternalWorkflowInput = Data.define(
          :id,
          :run_id,
          :signal,
          :args,
          :cancellation,
          :headers
        )

        # Input for {Outbound.sleep}.
        SleepInput = Data.define(
          :duration,
          :summary,
          :cancellation
        )

        # Input for {Outbound.start_child_workflow}.
        StartChildWorkflowInput = Data.define(
          :workflow,
          :args,
          :id,
          :task_queue,
          :static_summary,
          :static_details,
          :cancellation,
          :cancellation_type,
          :parent_close_policy,
          :execution_timeout,
          :run_timeout,
          :task_timeout,
          :id_reuse_policy,
          :retry_policy,
          :cron_schedule,
          :memo,
          :search_attributes,
          :headers,
          :priority
        )

        # Outbound interceptor for intercepting outbound workflow calls. This should be extended by users needing to
        # intercept workflow calls.
        class Outbound
          # @return [Outbound] Next interceptor in the chain.
          attr_reader :next_interceptor

          # Initialize outbound with the next interceptor in the chain.
          #
          # @param next_interceptor [Outbound] Next interceptor in the chain.
          def initialize(next_interceptor)
            @next_interceptor = next_interceptor
          end

          # Cancel external workflow.
          #
          # @param input [CancelExternalWorkflowInput] Input.
          def cancel_external_workflow(input)
            @next_interceptor.cancel_external_workflow(input)
          end

          # Execute activity.
          #
          # @param input [ExecuteActivityInput] Input.
          # @return [Object] Activity result.
          def execute_activity(input)
            @next_interceptor.execute_activity(input)
          end

          # Execute local activity.
          #
          # @param input [ExecuteLocalActivityInput] Input.
          # @return [Object] Activity result.
          def execute_local_activity(input)
            @next_interceptor.execute_local_activity(input)
          end

          # Initialize continue as new error.
          #
          # @param input [InitializeContinueAsNewErrorInput] Input.
          def initialize_continue_as_new_error(input)
            @next_interceptor.initialize_continue_as_new_error(input)
          end

          # Signal child workflow.
          #
          # @param input [SignalChildWorkflowInput] Input.
          def signal_child_workflow(input)
            @next_interceptor.signal_child_workflow(input)
          end

          # Signal external workflow.
          #
          # @param input [SignalExternalWorkflowInput] Input.
          def signal_external_workflow(input)
            @next_interceptor.signal_external_workflow(input)
          end

          # Sleep.
          #
          # @param input [SleepInput] Input.
          def sleep(input)
            @next_interceptor.sleep(input)
          end

          # Start child workflow.
          #
          # @param input [StartChildWorkflowInput] Input.
          # @return [Workflow::ChildWorkflowHandle] Child workflow handle.
          def start_child_workflow(input)
            @next_interceptor.start_child_workflow(input)
          end
        end
      end
    end
  end
end
