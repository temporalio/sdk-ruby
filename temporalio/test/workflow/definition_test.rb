# frozen_string_literal: true

require 'temporalio/workflow/definition'
require 'test'

module Workflow
  class DefinitionTest < Test
    class ValidWorkflowSimple < Temporalio::Workflow::Definition
      workflow_signal
      def my_signal(some_arg); end

      workflow_query
      def my_query(some_arg); end

      workflow_update
      def my_update(some_arg); end
    end

    def test_valid_simple
      defn = Temporalio::Workflow::Definition::Info.from_class(ValidWorkflowSimple)

      assert_equal 'ValidWorkflowSimple', defn.name
      assert_equal ValidWorkflowSimple, defn.workflow_class
      refute defn.init
      refute defn.raw_args

      assert_equal 1, defn.signals.size
      assert_equal 'my_signal', defn.signals['my_signal'].name
      assert_equal :my_signal, defn.signals['my_signal'].to_invoke
      refute defn.signals['my_signal'].raw_args
      assert_equal Temporalio::Workflow::HandlerUnfinishedPolicy::WARN_AND_ABANDON,
                   defn.signals['my_signal'].unfinished_policy
      assert_same defn.signals['my_signal'], ValidWorkflowSimple.my_signal

      assert_equal 1, defn.queries.size
      assert_equal 'my_query', defn.queries['my_query'].name
      assert_equal :my_query, defn.queries['my_query'].to_invoke
      refute defn.queries['my_query'].raw_args
      assert_same defn.queries['my_query'], ValidWorkflowSimple.my_query

      assert_equal 1, defn.updates.size
      assert_equal 'my_update', defn.updates['my_update'].name
      assert_equal :my_update, defn.updates['my_update'].to_invoke
      refute defn.updates['my_update'].raw_args
      assert_equal Temporalio::Workflow::HandlerUnfinishedPolicy::WARN_AND_ABANDON,
                   defn.updates['my_update'].unfinished_policy
      assert_nil defn.updates['my_update'].validator_to_invoke
      # Note, this would fail if there was a validator since adding a validator
      # creates a new definition
      assert_same defn.updates['my_update'], ValidWorkflowSimple.my_update
    end

    class ValidWorkflowAdvancedBase < Temporalio::Workflow::Definition
      workflow_signal name: 'custom-signal-name-1'
      def my_base_signal1; end

      workflow_signal name: 'custom-signal-name-2'
      def my_base_signal2; end

      workflow_signal
      def my_base_signal3; end
    end

    class ValidWorkflowAdvanced1 < ValidWorkflowAdvancedBase
      workflow_name 'custom-workflow-name'
      workflow_raw_args

      workflow_init
      def initialize(arg1, arg2); end # rubocop:disable Lint/MissingSuper

      def execute(arg1, arg2); end

      workflow_update dynamic: true,
                      raw_args: true,
                      unfinished_policy: Temporalio::Workflow::HandlerUnfinishedPolicy::ABANDON
      def my_dynamic_update(*args); end

      workflow_update_validator :my_dynamic_update
      def my_dynamic_update_validator(*args); end

      workflow_update_validator :another_update
      def another_update_validator(arg1, arg2); end

      workflow_update name: 'custom-update-name'
      def another_update(arg1, arg2); end
    end

    class ValidWorkflowAdvanced2 < ValidWorkflowAdvancedBase
      workflow_dynamic

      workflow_signal name: 'custom-signal-name-1'
      def my_base_signal1; end

      workflow_signal name: 'custom-signal-name-2'
      def my_renamed_signal; end

      workflow_signal
      def my_new_signal; end

      workflow_update name: 'custom-update-name'
      def another_update; end
    end

    def test_valid_advanced
      defn = Temporalio::Workflow::Definition::Info.from_class(ValidWorkflowAdvanced1)

      assert_equal 'custom-workflow-name', defn.name
      assert_equal ValidWorkflowAdvanced1, defn.workflow_class
      refute defn.dynamic
      assert defn.init
      assert defn.raw_args
      assert_equal 3, defn.signals.size
      assert_equal 2, defn.updates.size
      assert_equal :my_dynamic_update, defn.updates[nil].to_invoke
      assert defn.updates[nil].raw_args
      assert_equal Temporalio::Workflow::HandlerUnfinishedPolicy::ABANDON, defn.updates[nil].unfinished_policy
      assert_equal :my_dynamic_update_validator, defn.updates[nil].validator_to_invoke
      refute ValidWorkflowAdvanced1.respond_to?(:my_dynamic_update)
      assert_equal :another_update, defn.updates['custom-update-name'].to_invoke
      refute defn.updates['custom-update-name'].raw_args
      assert_equal Temporalio::Workflow::HandlerUnfinishedPolicy::WARN_AND_ABANDON,
                   defn.updates['custom-update-name'].unfinished_policy
      assert_equal :another_update_validator, defn.updates['custom-update-name'].validator_to_invoke
      assert_equal 'custom-update-name', ValidWorkflowAdvanced1.another_update.name

      defn = Temporalio::Workflow::Definition::Info.from_class(ValidWorkflowAdvanced2)

      assert_nil defn.name
      assert_equal ValidWorkflowAdvanced2, defn.workflow_class
      assert defn.dynamic
      refute defn.init
      refute defn.raw_args

      assert_equal 4, defn.signals.size
      assert_equal :my_base_signal1, defn.signals['custom-signal-name-1'].to_invoke
      assert_equal :my_renamed_signal, defn.signals['custom-signal-name-2'].to_invoke
      assert_equal :my_base_signal3, defn.signals['my_base_signal3'].to_invoke
      assert_equal :my_new_signal, defn.signals['my_new_signal'].to_invoke
    end

    def assert_invalid_workflow_code(message_contains, code_to_eval)
      # Eval, which may fail, then try to get definition from last class
      err = assert_raises(StandardError) do
        before_classes = ObjectSpace.each_object(Class).to_a
        eval(code_to_eval) # rubocop:disable Security/Eval
        (ObjectSpace.each_object(Class).to_a - before_classes).each do |new_class|
          Temporalio::Workflow::Definition::Info.from_class(new_class) if new_class < Temporalio::Workflow::Definition
        end
      end
      assert_includes err.message, message_contains
    end

    def test_invalid_dynamic_and_name
      assert_invalid_workflow_code 'cannot be given a name and be dynamic', <<~CODE
        class TestInvalidDynamicAndName < Temporalio::Workflow::Definition
          workflow_name 'my-name'
          workflow_dynamic
        end
      CODE
    end

    def test_invalid_duplicate_handlers
      assert_invalid_workflow_code 'signal my_signal_1 defined on different methods', <<~CODE
        class TestInvalidDuplicateHandlers < Temporalio::Workflow::Definition
          workflow_signal
          def my_signal_1; end

          workflow_signal name: 'my_signal_1'
          def my_signal_2; end
        end
      CODE
    end

    def test_invalid_duplicate_handlers_different_type
      assert_invalid_workflow_code 'my-name already defined as a different handler type', <<~CODE
        class TestInvalidDuplicateHandlersDifferentType < Temporalio::Workflow::Definition
          workflow_signal name: 'my-name'
          def my_signal; end

          workflow_update name: 'my-name'
          def my_update; end
        end
      CODE
    end

    def test_invalid_init_not_on_initialize
      assert_invalid_workflow_code 'was applied to not_initialize instead of initialize', <<~CODE
        class TestInvalidInitNotOnInitialize < Temporalio::Workflow::Definition
          workflow_init
          def not_initialize; end
        end
      CODE
    end

    def test_invalid_init_not_match_execute
      assert_invalid_workflow_code 'parameter count of initialize and execute must be the same', <<~CODE
        class TestInvalidInitNotMatchExecute < Temporalio::Workflow::Definition
          workflow_init
          def initialize(arg1, arg2); end

          def execute(arg3, arg4, arg5); end
        end
      CODE
    end

    def test_invalid_shadow_class_method
      assert_invalid_workflow_code 'Attempting to override Temporal-defined class definition method', <<~CODE
        class TestInvalidShadowClassMethod < Temporalio::Workflow::Definition
          workflow_signal
          def my_signal_1; end

          def self.my_signal_1; end
        end
      CODE
    end

    def test_invalid_two_handler_decorators
      assert_invalid_workflow_code 'Previous signal handler was not put on method before this handler', <<~CODE
        class TestInvalidTwoHandlerDecorators < Temporalio::Workflow::Definition
          workflow_signal
          workflow_update
          def my_update; end
        end
      CODE
    end

    def test_invalid_leftover_decorator
      assert_invalid_workflow_code 'Leftover signal handler not applied to a method', <<~CODE
        class TestInvalidLeftoverDecorator < Temporalio::Workflow::Definition
          workflow_signal
        end
      CODE
    end

    def test_invalid_update_validator_no_update
      assert_invalid_workflow_code 'Unable to find update does_not_exist', <<~CODE
        class TestInvalidUpdateValidatorNoUpdate < Temporalio::Workflow::Definition
          workflow_update
          def my_update; end

          workflow_update_validator :does_not_exist
          def my_update_validator; end
        end
      CODE
    end

    def test_invalid_update_validator_param_mismatch
      assert_invalid_workflow_code 'my_update_validator does not have exact parameter signature of my_update', <<~CODE
        class TestInvalidUpdateValidatorParamMismatch < Temporalio::Workflow::Definition
          workflow_update
          def my_update(arg1, arg2); end

          workflow_update_validator :my_update
          def my_update_validator(arg2, arg3); end
        end
      CODE
    end

    def test_invalid_multiple_dynamic
      assert_invalid_workflow_code 'Workflow signal <dynamic> defined on different methods', <<~CODE
        class TestInvalidMultipleDynamic < Temporalio::Workflow::Definition
          workflow_signal dynamic: true
          def my_signal_1; end

          workflow_signal dynamic: true
          def my_signal_2; end
        end
      CODE
    end

    def test_invalid_override_different_name
      assert_invalid_workflow_code 'Superclass handler on my_signal has name foo but current class expects bar', <<~CODE
        class TestInvalidOverrideDifferentNameBase < Temporalio::Workflow::Definition
          workflow_signal name: 'foo'
          def my_signal; end
        end

        class TestInvalidOverrideDifferentName < TestInvalidOverrideDifferentNameBase
          workflow_signal name: 'bar'
          def my_signal; end
        end
      CODE
    end

    def test_invalid_override_different_type
      assert_invalid_workflow_code(
        'Superclass handler on do_thing is a Temporalio::Workflow::Definition::Update ' \
        'but current class expects Temporalio::Workflow::Definition::Signal',
        <<~CODE
          class TestInvalidOverrideDifferentTypeBase < Temporalio::Workflow::Definition
            workflow_update
            def do_thing; end
          end

          class TestInvalidOverrideDifferentType < TestInvalidOverrideDifferentTypeBase
            workflow_signal
            def do_thing; end
          end
        CODE
      )
    end
  end
end
