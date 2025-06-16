# frozen_string_literal: true

require 'temporalio/internal/proto_utils'
require 'temporalio/workflow'
require 'temporalio/workflow/handler_unfinished_policy'

module Temporalio
  module Workflow
    # Base class for all workflows.
    #
    # Workflows are instances of this class and must implement {execute}. Inside the workflow code, class methods on
    # {Workflow} can be used.
    #
    # By default, the workflow is named as its unqualified class name. This can be customized with {workflow_name}.
    class Definition
      class << self
        protected

        # Customize the workflow name. By default the workflow is named the unqualified class name of the class provided
        # to the worker.
        #
        # @param workflow_name [String, Symbol] Name to use.
        def workflow_name(workflow_name)
          if !workflow_name.is_a?(Symbol) && !workflow_name.is_a?(String)
            raise ArgumentError,
                  'Workflow name must be a symbol or string'
          end

          @workflow_name = workflow_name.to_s
        end

        # Set a workflow as dynamic. Dynamic workflows do not have names and handle any workflow that is not otherwise
        # registered. A worker can only have one dynamic workflow. It is often useful to use {workflow_raw_args} with
        # this.
        #
        # @param value [Boolean] Whether the workflow is dynamic.
        def workflow_dynamic(value = true) # rubocop:disable Style/OptionalBooleanParameter
          @workflow_dynamic = value
        end

        # Have workflow arguments delivered to `execute` (and `initialize` if {workflow_init} in use) as
        # {Converters::RawValue}s. These are wrappers for the raw payloads that have not been converted to types (but
        # they have been decoded by the codec if present). They can be converted with {Workflow.payload_converter}.
        #
        # @param value [Boolean] Whether the workflow accepts raw arguments.
        def workflow_raw_args(value = true) # rubocop:disable Style/OptionalBooleanParameter
          @workflow_raw_args = value
        end

        # Configure workflow failure exception types. This sets the types of exceptions that, if a
        # workflow-thrown exception extends, will cause the workflow/update to fail instead of suspending the workflow
        # via task failure. These are applied in addition to the worker option. If {::Exception} is set, it effectively
        # will fail a workflow/update in all user exception cases.
        #
        # @param types [Array<Class<Exception>>] Exception types to turn into workflow failures.
        def workflow_failure_exception_type(*types)
          types.each do |t|
            raise ArgumentError, 'All types must classes inheriting Exception' unless t.is_a?(Class) && t <= Exception
          end
          @workflow_failure_exception_types ||= []
          @workflow_failure_exception_types.concat(types)
        end

        # Expose an attribute as a method and as a query. A `workflow_query_attr_reader :foo` is the equivalent of:
        # ```
        # workflow_query
        # def foo
        #   @foo
        # end
        # ```
        # This means it is a superset of `attr_reader`` and will not work if also using `attr_reader` or
        # `attr_accessor`. If a writer is needed alongside this, use `attr_writer`.
        #
        # @param attr_names [Array<Symbol>] Attributes to expose.
        # @param description [String, nil] Description that may appear in CLI/UI, applied to each query handler
        #   implicitly created. This is currently experimental.
        def workflow_query_attr_reader(*attr_names, description: nil)
          @workflow_queries ||= {}
          attr_names.each do |attr_name|
            raise 'Expected attr to be a symbol' unless attr_name.is_a?(Symbol)

            if method_defined?(attr_name, false)
              raise 'Method already defined for this attr name. ' \
                    'Note that a workflow_query_attr_reader includes attr_reader behavior. ' \
                    'If you also want a writer for this attribute, use a separate attr_writer.'
            end

            # Just run this as if done manually
            workflow_query(description:)
            define_method(attr_name) { instance_variable_get("@#{attr_name}") }
          end
        end

        # Set the versioning behavior of this workflow.
        #
        # WARNING: This method is experimental and may change in future versions.
        #
        # @param behavior [VersioningBehavior] The versioning behavior.
        def workflow_versioning_behavior(behavior)
          @versioning_behavior = behavior
        end

        # Mark an `initialize` as needing the workflow start arguments. Otherwise, `initialize` must accept no required
        # arguments. This must be placed above the `initialize` method or it will fail.
        #
        # @param value [Boolean] Whether the start parameters will be passed to `initialize`.
        def workflow_init(value = true) # rubocop:disable Style/OptionalBooleanParameter
          self.pending_handler_details = { type: :init, value: }
        end

        # Mark the next method as a workflow signal with a default name as the name of the method. Signals cannot return
        # values.
        #
        # @param name [String, Symbol, nil] Override the default name.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param dynamic [Boolean] If true, make the signal dynamic. This means it receives all other signals without
        #   handlers. This cannot have a name override since it is nameless. The first parameter will be the name. Often
        #   it is useful to have the second parameter be `*args` and `raw_args` be true.
        # @param raw_args [Boolean] If true, does not convert arguments, but instead provides each argument as
        #   {Converters::RawValue} which is a raw payload wrapper, convertible with {Workflow.payload_converter}.
        # @param unfinished_policy [HandlerUnfinishedPolicy] How to treat unfinished handlers if they are still running
        #   when the workflow ends. The default warns, but this can be disabled.
        def workflow_signal(
          name: nil,
          description: nil,
          dynamic: false,
          raw_args: false,
          unfinished_policy: HandlerUnfinishedPolicy::WARN_AND_ABANDON
        )
          raise 'Cannot provide name if dynamic is true' if name && dynamic

          self.pending_handler_details = { type: :signal, name:, description:, dynamic:, raw_args:, unfinished_policy: }
        end

        # Mark the next method as a workflow query with a default name as the name of the method. Queries can not have
        # any side effects, meaning they should never mutate state or try to wait on anything.
        #
        # @param name [String, Symbol, nil] Override the default name.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param dynamic [Boolean] If true, make the query dynamic. This means it receives all other queries without
        #   handlers. This cannot have a name override since it is nameless. The first parameter will be the name. Often
        #   it is useful to have the second parameter be `*args` and `raw_args` be true.
        # @param raw_args [Boolean] If true, does not convert arguments, but instead provides each argument as
        #   {Converters::RawValue} which is a raw payload wrapper, convertible with {Workflow.payload_converter}.
        def workflow_query(
          name: nil,
          description: nil,
          dynamic: false,
          raw_args: false
        )
          raise 'Cannot provide name if dynamic is true' if name && dynamic

          self.pending_handler_details = { type: :query, name:, description:, dynamic:, raw_args: }
        end

        # Mark the next method as a workflow update with a default name as the name of the method. Updates can return
        # values. Separate validation methods can be provided via {workflow_update_validator}.
        #
        # @param name [String, Symbol, nil] Override the default name.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param dynamic [Boolean] If true, make the update dynamic. This means it receives all other updates without
        #   handlers. This cannot have a name override since it is nameless. The first parameter will be the name. Often
        #   it is useful to have the second parameter be `*args` and `raw_args` be true.
        # @param raw_args [Boolean] If true, does not convert arguments, but instead provides each argument as
        #   {Converters::RawValue} which is a raw payload wrapper, convertible with {Workflow.payload_converter}.
        # @param unfinished_policy [HandlerUnfinishedPolicy] How to treat unfinished handlers if they are still running
        #   when the workflow ends. The default warns, but this can be disabled.
        def workflow_update(
          name: nil,
          description: nil,
          dynamic: false,
          raw_args: false,
          unfinished_policy: HandlerUnfinishedPolicy::WARN_AND_ABANDON
        )
          raise 'Cannot provide name if dynamic is true' if name && dynamic

          self.pending_handler_details = { type: :update, name:, description:, dynamic:, raw_args:, unfinished_policy: }
        end

        # Mark the next method as a workflow update validator to the given update method. The validator is expected to
        # have the exact same parameter signature. It will run before an update and if it raises an exception, the
        # update will be rejected, possibly before even reaching history. Validators cannot have any side effects or do
        # any waiting, and they do not return values.
        #
        # @param update_method [Symbol] Name of the update method.
        def workflow_update_validator(update_method)
          self.pending_handler_details = { type: :update_validator, update_method: }
        end

        # Mark the next method as returning some dynamic configuraion.
        #
        # Because dynamic workflows may conceptually represent more than one workflow type, it may
        # be desirable to have different settings for fields that would normally be passed to
        # `workflow_xxx` setters, but vary based on the workflow type name or other information
        # available in the workflow's context. This function will be called after the workflow's
        # `initialize`, if it has one, but before the workflow's `execute` method.
        #
        # The method must only take self as a parameter, and any values set in the class it returns
        # will override those provided to other `workflow_xxx` setters.
        #
        # Cannot be specified on non-dynamic workflows.
        def workflow_dynamic_options
          raise 'Dynamic options method can only be set on workflows using `workflow_dynamic`' unless @workflow_dynamic

          self.pending_handler_details = { type: :dynamic_options }
        end

        private

        attr_reader :pending_handler_details

        def pending_handler_details=(value)
          if value.nil?
            @pending_handler_details = value
            return
          elsif @pending_handler_details
            raise "Previous #{@pending_handler_details[:type]} handler was not put on method before this handler"
          end

          @pending_handler_details = value
        end
      end

      # @!visibility private
      def self.method_added(method_name)
        super

        # Nothing to do if there are no pending handler details
        handler = pending_handler_details
        return unless handler

        # Reset details
        self.pending_handler_details = nil

        # Disallow kwargs in parameters
        begin
          if instance_method(method_name).parameters.any? { |t, _| t == :key || t == :keyreq }
            raise "Workflow #{handler[:type]} cannot have keyword arguments"
          end
        rescue NameError
          # Ignore name error
        end

        # Initialize class variables if not done already
        @workflow_signals ||= {}
        @workflow_queries ||= {}
        @workflow_updates ||= {}
        @workflow_update_validators ||= {}
        @defined_methods ||= []

        defn, hash, other_hashes =
          case handler[:type]
          when :init
            raise "workflow_init was applied to #{method_name} instead of initialize" if method_name != :initialize

            @workflow_init = handler[:value]
            return
          when :update_validator
            other = @workflow_update_validators[handler[:update_method]]
            if other && (other[:method_name] != method_name || other[:update_method] != handler[:update_method])
              raise "Workflow update validator on #{method_name} for #{handler[:update_method]} defined separately " \
                    "on #{other[:method_name]} for #{other[:update_method]}"
            end

            # Just store this, we'll apply validators to updates at definition
            # building time
            @workflow_update_validators[handler[:update_method]] = { method_name:, **handler }
            return
          when :signal
            [Signal.new(
              name: handler[:dynamic] ? nil : (handler[:name] || method_name).to_s,
              to_invoke: method_name,
              description: handler[:description],
              raw_args: handler[:raw_args],
              unfinished_policy: handler[:unfinished_policy]
            ), @workflow_signals, [@workflow_queries, @workflow_updates]]
          when :query
            [Query.new(
              name: handler[:dynamic] ? nil : (handler[:name] || method_name).to_s,
              to_invoke: method_name,
              description: handler[:description],
              raw_args: handler[:raw_args]
            ), @workflow_queries, [@workflow_signals, @workflow_updates]]
          when :update
            [Update.new(
              name: handler[:dynamic] ? nil : (handler[:name] || method_name).to_s,
              to_invoke: method_name,
              description: handler[:description],
              raw_args: handler[:raw_args],
              unfinished_policy: handler[:unfinished_policy]
            ), @workflow_updates, [@workflow_signals, @workflow_queries]]
          when :dynamic_options
            raise 'Dynamic options method already set' if @dynamic_options_method

            @dynamic_options_method = method_name
            return
          else
            raise "Unrecognized handler type #{handler[:type]}"
          end

        # We only allow dupes with the same method name (override/redefine)
        # TODO(cretz): Should we also check that everything else is the same?
        other = hash[defn.name]
        if other && other.to_invoke != method_name
          raise "Workflow #{handler[:type].name} #{defn.name || '<dynamic>'} defined on " \
                "different methods #{other.to_invoke} and #{method_name}"
        elsif defn.name && other_hashes.any? { |h| h.include?(defn.name) }
          raise "Workflow signal #{defn.name} already defined as a different handler type"
        end
        hash[defn.name] = defn

        # Define class method for referencing the definition only if non-dynamic
        return unless defn.name

        define_singleton_method(method_name) { defn }
        @defined_methods.push(method_name)
      end

      # @!visibility private
      def self.singleton_method_added(method_name)
        super
        # We need to ensure class methods are not added after we have defined a method
        return unless @defined_methods&.include?(method_name)

        raise 'Attempting to override Temporal-defined class definition method'
      end

      # @!visibility private
      def self._workflow_definition
        @workflow_definition ||= _build_workflow_definition
      end

      # @!visibility private
      def self._workflow_type_from_workflow_parameter(workflow)
        case workflow
        when Class
          unless workflow < Definition
            raise ArgumentError, "Class '#{workflow}' does not extend Temporalio::Workflow::Definition"
          end

          info = Info.from_class(workflow)
          info.name || raise(ArgumentError, 'Cannot pass dynamic workflow to start')
        when Info
          workflow.name || raise(ArgumentError, 'Cannot pass dynamic workflow to start')
        when String, Symbol
          workflow.to_s
        else
          raise ArgumentError, 'Workflow is not a workflow class or string/symbol'
        end
      end

      # @!visibility private
      def self._build_workflow_definition
        # Make sure there isn't dangling pending handler details
        if pending_handler_details
          raise "Leftover #{pending_handler_details&.[](:type)} handler not applied to a method"
        end

        # Disallow kwargs in execute parameters
        if instance_method(:execute).parameters.any? { |t, _| t == :key || t == :keyreq }
          raise 'Workflow execute cannot have keyword arguments'
        end

        # Apply all update validators before merging with super
        updates = @workflow_updates&.dup || {}
        @workflow_update_validators&.each_value do |validator|
          update = updates.values.find { |u| u.to_invoke == validator[:update_method] }
          unless update
            raise "Unable to find update #{validator[:update_method]} pointed to by " \
                  "validator on #{validator[:method_name]}"
          end
          if instance_method(validator[:method_name])&.parameters !=
             instance_method(validator[:update_method])&.parameters
            raise "Validator on #{validator[:method_name]} does not have " \
                  "exact parameter signature of #{validator[:update_method]}"
          end

          updates[update.name] = update._with_validator_to_invoke(validator[:method_name])
        end

        # If there is a superclass, apply some values and check others
        override_name = @workflow_name
        dynamic = @workflow_dynamic
        init = @workflow_init
        raw_args = @workflow_raw_args
        signals = @workflow_signals || {}
        queries = @workflow_queries || {}
        if superclass && superclass != Temporalio::Workflow::Definition
          # @type var super_info: Temporalio::Workflow::Definition::Info
          super_info = superclass._workflow_definition # steep:ignore

          # Override values if not set here
          override_name = super_info.override_name if override_name.nil?
          dynamic = super_info.dynamic if dynamic.nil?
          init = super_info.init if init.nil?
          raw_args = super_info.raw_args if raw_args.nil?

          # Make sure handlers on the same method at least have the same name
          # TODO(cretz): Need to validate any other handler override details?
          # Probably not because we only care that caller-needed values remain
          # unchanged (method and name), implementer-needed values can be
          # overridden/changed.
          self_handlers = signals.values + queries.values + updates.values
          super_handlers = super_info.signals.values + super_info.queries.values + super_info.updates.values
          super_handlers.each do |super_handler|
            self_handler = self_handlers.find { |h| h.to_invoke == super_handler.to_invoke }
            next unless self_handler

            if super_handler.class != self_handler.class
              raise "Superclass handler on #{self_handler.to_invoke} is a #{super_handler.class} " \
                    "but current class expects #{self_handler.class}"
            end
            if super_handler.name != self_handler.name
              raise "Superclass handler on #{self_handler.to_invoke} has name #{super_handler.name} " \
                    "but current class expects #{self_handler.name}"
            end
          end

          # Merge handlers. We will merge such that handlers defined here
          # override ones from superclass by _name_ (not method to invoke).
          signals = super_info.signals.merge(signals)
          queries = super_info.queries.merge(queries)
          updates = super_info.updates.merge(updates)
        end

        # If init is true, validate initialize and execute signatures are identical
        if init && instance_method(:initialize)&.parameters&.size != instance_method(:execute)&.parameters&.size
          raise 'workflow_init present, so parameter count of initialize and execute must be the same'
        end

        raise 'Workflow cannot be given a name and be dynamic' if dynamic && override_name

        if !dynamic && !@dynamic_options_method.nil?
          raise 'Workflow cannot have a dynamic_options_method unless it is dynamic'
        end

        Info.new(
          workflow_class: self,
          override_name:,
          dynamic: dynamic || false,
          init: init || false,
          raw_args: raw_args || false,
          failure_exception_types: @workflow_failure_exception_types || [],
          signals:,
          queries:,
          updates:,
          versioning_behavior: @versioning_behavior || VersioningBehavior::UNSPECIFIED,
          dynamic_options_method: @dynamic_options_method
        )
      end

      # Execute the workflow. This is the primary workflow method. The workflow is completed when this method completes.
      # This must be implemented by all workflows.
      def execute(*args)
        raise NotImplementedError, 'Workflow did not implement "execute"'
      end

      # Information about the workflow definition. This is usually not used directly.
      class Info
        attr_reader :workflow_class, :override_name, :dynamic, :init, :raw_args,
                    :failure_exception_types, :signals, :queries, :updates, :versioning_behavior,
                    :dynamic_options_method

        # Derive the workflow definition info from the class.
        #
        # @param workflow_class [Class<Definition>] Workflow class.
        # @return [Info] Built info.
        def self.from_class(workflow_class)
          unless workflow_class.is_a?(Class) && workflow_class < Definition
            raise "Workflow '#{workflow_class}' must be a class and must extend Temporalio::Workflow::Definition"
          end

          workflow_class._workflow_definition
        end

        # Create a definition info. This should usually not be used directly, but instead a class that extends
        # {Workflow::Definition} should be used.
        def initialize(
          workflow_class:,
          override_name: nil,
          dynamic: false,
          init: false,
          raw_args: false,
          failure_exception_types: [],
          signals: {},
          queries: {},
          updates: {},
          versioning_behavior: VersioningBehavior::UNSPECIFIED,
          dynamic_options_method: nil
        )
          @workflow_class = workflow_class
          @override_name = override_name
          @dynamic = dynamic
          @init = init
          @raw_args = raw_args
          @failure_exception_types = failure_exception_types.dup.freeze
          @signals = signals.dup.freeze
          @queries = queries.dup.freeze
          @updates = updates.dup.freeze
          @versioning_behavior = versioning_behavior
          @dynamic_options_method = dynamic_options_method
          Internal::ProtoUtils.assert_non_reserved_name(name)
        end

        # @return [String] Workflow name.
        def name
          dynamic ? nil : (override_name || workflow_class.name.to_s.split('::').last)
        end
      end

      # A signal definition. This is usually built as a result of a {Definition.workflow_signal} method, but can be
      # manually created to set at runtime on {Workflow.signal_handlers}.
      class Signal
        attr_reader :name, :to_invoke, :description, :raw_args, :unfinished_policy

        # @!visibility private
        def self._name_from_parameter(signal)
          case signal
          when Workflow::Definition::Signal
            signal.name || raise(ArgumentError, 'Cannot call dynamic signal directly')
          when String, Symbol
            signal.to_s
          else
            raise ArgumentError, 'Signal is not a definition or string/symbol'
          end
        end

        # Create a signal definition manually. See {Definition.workflow_signal} for more details on some of the
        # parameters.
        #
        # @param name [String, nil] Name or nil if dynamic.
        # @param to_invoke [Symbol, Proc] Method name or proc to invoke.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param raw_args [Boolean] Whether the parameters should be raw values.
        # @param unfinished_policy [HandlerUnfinishedPolicy] How the workflow reacts when this handler is still running
        #   on workflow completion.
        def initialize(
          name:,
          to_invoke:,
          description: nil,
          raw_args: false,
          unfinished_policy: HandlerUnfinishedPolicy::WARN_AND_ABANDON
        )
          @name = name
          @to_invoke = to_invoke
          @description = description
          @raw_args = raw_args
          @unfinished_policy = unfinished_policy
          Internal::ProtoUtils.assert_non_reserved_name(name)
        end
      end

      # A query definition. This is usually built as a result of a {Definition.workflow_query} method, but can be
      # manually created to set at runtime on {Workflow.query_handlers}.
      class Query
        attr_reader :name, :to_invoke, :description, :raw_args

        # @!visibility private
        def self._name_from_parameter(query)
          case query
          when Workflow::Definition::Query
            query.name || raise(ArgumentError, 'Cannot call dynamic query directly')
          when String, Symbol
            query.to_s
          else
            raise ArgumentError, 'Query is not a definition or string/symbol'
          end
        end

        # Create a query definition manually. See {Definition.workflow_query} for more details on some of the
        # parameters.
        #
        # @param name [String, nil] Name or nil if dynamic.
        # @param to_invoke [Symbol, Proc] Method name or proc to invoke.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param raw_args [Boolean] Whether the parameters should be raw values.
        def initialize(
          name:,
          to_invoke:,
          description: nil,
          raw_args: false
        )
          @name = name
          @to_invoke = to_invoke
          @description = description
          @raw_args = raw_args
          Internal::ProtoUtils.assert_non_reserved_name(name)
        end
      end

      # An update definition. This is usually built as a result of a {Definition.workflow_update} method, but can be
      # manually created to set at runtime on {Workflow.update_handlers}.
      class Update
        attr_reader :name, :to_invoke, :description, :raw_args, :unfinished_policy, :validator_to_invoke

        # @!visibility private
        def self._name_from_parameter(update)
          case update
          when Workflow::Definition::Update
            update.name || raise(ArgumentError, 'Cannot call dynamic update directly')
          when String, Symbol
            update.to_s
          else
            raise ArgumentError, 'Update is not a definition or string/symbol'
          end
        end

        # Create an update definition manually. See {Definition.workflow_update} for more details on some of the
        # parameters.
        #
        # @param name [String, nil] Name or nil if dynamic.
        # @param to_invoke [Symbol, Proc] Method name or proc to invoke.
        # @param description [String, nil] Description for this handler that may appear in CLI/UI. This is currently
        #   experimental.
        # @param raw_args [Boolean] Whether the parameters should be raw values.
        # @param unfinished_policy [HandlerUnfinishedPolicy] How the workflow reacts when this handler is still running
        #   on workflow completion.
        # @param validator_to_invoke [Symbol, Proc, nil] Method name or proc validator to invoke.
        def initialize(
          name:,
          to_invoke:,
          description: nil,
          raw_args: false,
          unfinished_policy: HandlerUnfinishedPolicy::WARN_AND_ABANDON,
          validator_to_invoke: nil
        )
          @name = name
          @to_invoke = to_invoke
          @description = description
          @raw_args = raw_args
          @unfinished_policy = unfinished_policy
          @validator_to_invoke = validator_to_invoke
          Internal::ProtoUtils.assert_non_reserved_name(name)
        end

        # @!visibility private
        def _with_validator_to_invoke(validator_to_invoke)
          Update.new(
            name:,
            to_invoke:,
            description:,
            raw_args:,
            unfinished_policy:,
            validator_to_invoke:
          )
        end
      end
    end

    DefinitionOptions = Struct.new(
      :failure_exception_types,
      :versioning_behavior
    )
    # @!attribute failure_exception_types
    #   Dynamic equivalent of {Definition.workflow_failure_exception_type}.
    #   Will override any types set there if set, including if set to an empty array.
    #   @return [Array<Class<Exception>>, nil] The failure exception types
    #
    # @!attribute versioning_behavior
    #   Dynamic equivalent of {Definition.workflow_versioning_behavior}.
    #   Will override any behavior set there if set.
    #   WARNING: Deployment-based versioning is experimental and APIs may change.
    #   @return [VersioningBehavior, nil] The versioning behavior
    #
    # @return [VersioningBehavior, nil] The versioning behavior
    class DefinitionOptions
      def initialize(
        failure_exception_types: nil,
        versioning_behavior: nil
      )
        super
      end
    end
  end
end
