# frozen_string_literal: true

require 'rbi'
require 'sorbet-runtime'
require_relative 'rbi_paths'

# Parses the SDK's manual RBI files and applies Sorbet runtime type signatures to the
# real (already-loaded) class implementations using Sorbet's method_added
# machinery.
# This enables sorbet-runtime to validate argument and return types at runtime
# during test execution, catching any drift between the RBI and actual code.
#
# Type mismatches are collected and reported as a summary after the test run
# rather than raising mid-execution. This avoids hanging workflows where a
# TypeError would cause an unrecoverable task failure that retries forever.
module SigApplicator
  # Classes that use Sorbet generic type members which require the implementing class to include T::Generic.
  SKIP_CLASSES = [
    'Temporalio::Workflow::Future'
  ].freeze

  # Specific class#method pairs to skip.
  # Internal terminal interceptor implementations pass nil via super(nil)
  # to these initializers, but the public API contract is non-nilable.
  SKIP_METHODS = Set.new(
    [
      'Temporalio::Client::Interceptor::Outbound#initialize',
      'Temporalio::Worker::Interceptor::Activity::Inbound#initialize',
      'Temporalio::Worker::Interceptor::Activity::Outbound#initialize',
      'Temporalio::Worker::Interceptor::Workflow::Inbound#initialize',
      'Temporalio::Worker::Interceptor::Workflow::Outbound#initialize'
    ]
  ).freeze

  ATTR_NODE_CLASSES = [
    RBI::AttrAccessor,
    RBI::AttrReader,
    RBI::AttrWriter
  ].freeze

  @type_errors = []
  @mutex = Mutex.new
  @summary_hook_registered = false

  class << self
    def apply_all!
      @mutex.synchronize { @type_errors.clear }
      configure_error_handler!
      register_summary_hook!

      # Make T::Sig available on all modules/classes so we don't need to
      # extend it per-target inside apply_method_sig.
      ::Module.include(::T::Sig)

      errors = []
      skipped = 0
      applied = 0

      rbi_paths.each do |path|
        tree = RBI::Parser.parse_file(path)
        tree.nodes.each do |node|
          a, s = apply_scope(node, errors)
          applied += a
          skipped += s
        end
      end

      warn "SigApplicator: applied #{applied} runtime type signatures (#{skipped} skipped)" if skipped.positive?

      raise_instrumentation_errors!(errors)
    end

    def record_type_error(message)
      return if Thread.current[:sig_applicator_suppressed]

      # Avoid illegal_call_tracing_disabled here — interacting with the
      # workflow tracer + mutex from inside error handlers can cause
      # non-deterministic behavior. Instead, rescue the NondeterminismError
      # that fires when accessing Mutex from within a workflow.
      @mutex.synchronize { @type_errors << message }
    rescue Temporalio::Workflow::NondeterminismError
      # Best-effort: append without synchronization when inside a workflow
      @type_errors << message
    end

    def type_errors
      @mutex.synchronize { @type_errors.dup }
    end

    # Suppress type error recording for the duration of a block.
    # Use for tests that intentionally pass wrong types.
    def suppress_errors
      Thread.current[:sig_applicator_suppressed] = true
      yield
    ensure
      Thread.current[:sig_applicator_suppressed] = false
    end

    private

    def rbi_paths
      RbiPaths.manual
    end

    def configure_error_handler!
      T::Configuration.call_validation_error_handler = lambda do |_sig, opts|
        message = opts[:pretty_message] || opts[:message]
        value = opts[:value]
        type = opts[:type]

        # SimpleDelegator wrappers don't pass Sorbet's is_a? checks because
        # they inherit from Delegator, not the wrapped class. Check the
        # delegate object against the expected type instead.
        if value.is_a?(SimpleDelegator) && type
          delegate = value.__getobj__
          SigApplicator.record_type_error(message) unless type.valid?(delegate)
          return
        end

        # Include location for debugging
        location = opts[:location]
        full = location ? "#{message}\n  Location: #{location}" : message
        SigApplicator.record_type_error(full)
      end
    end

    # Register a Minitest after-run hook that asserts no type errors were
    # collected.
    def register_summary_hook!
      return if @summary_hook_registered

      @summary_hook_registered = true
      Minitest.after_run do
        raise_recorded_type_errors!
      end
    end

    def raise_recorded_type_errors!
      errors = type_errors
      return if errors.empty?

      unique = errors.tally
      summary = "SigApplicator: #{errors.size} runtime type errors detected (#{unique.size} unique):\n"
      unique.sort_by { |_, count| -count }.each do |msg, count|
        summary << "  [#{count}x] #{msg}\n"
      end
      raise Minitest::Assertion, summary.chomp
    end

    def raise_instrumentation_errors!(errors)
      return if errors.empty?

      summary = "SigApplicator: #{errors.size} methods could not be instrumented:\n"
      errors.each { |error| summary << "  #{error}\n" }
      raise summary.chomp
    end

    def apply_scope(node, errors)
      return [0, 0] unless node.respond_to?(:nodes)

      class_name = node.name if node.respond_to?(:name)
      return [0, 0] unless class_name
      return [0, 0] if SKIP_CLASSES.include?(class_name)

      begin
        klass = Object.const_get(class_name)
      rescue NameError
        errors << "#{class_name}: class not found"
        return [0, 0]
      end

      applied = 0
      skipped = 0

      node.nodes.each do |child|
        case child
        when RBI::Method
          target = child.is_singleton ? klass.singleton_class : klass
          result = apply_method_sig(target, class_name, child, errors, sig_eval_scope: klass)
          if result == :skipped
            skipped += 1
          elsif result
            applied += 1
          end
        when *ATTR_NODE_CLASSES
          a, s = apply_attr_sig(klass, class_name, child, errors, sig_eval_scope: klass)
          applied += a
          skipped += s
        when RBI::SingletonClass
          child.nodes.each do |scn|
            case scn
            when RBI::Method
              result = apply_method_sig(
                klass.singleton_class,
                class_name,
                scn,
                errors,
                class_method: true,
                sig_eval_scope: klass
              )
              if result == :skipped
                skipped += 1
              elsif result
                applied += 1
              end
            when *ATTR_NODE_CLASSES
              a, s = apply_attr_sig(
                klass.singleton_class,
                class_name,
                scn,
                errors,
                class_method: true,
                sig_eval_scope: klass
              )
              applied += a
              skipped += s
            end
          end
        end
      end
      [applied, skipped]
    end

    def apply_method_sig(target, class_name, method_node, errors, class_method: false, sig_eval_scope: target)
      return false if method_node.sigs.empty?

      method_name = method_node.name.to_sym
      singleton_method = class_method || method_node.is_singleton
      separator = singleton_method ? '.' : '#'
      full_name = "#{class_name}#{separator}#{method_name}"

      return :skipped if SKIP_METHODS.include?(full_name)

      begin
        original = target.instance_method(method_name)
      rescue NameError
        errors << "#{full_name}: method not found"
        return false
      end

      return :skipped if skip_method?(original, method_node, method_name)

      has_anon_block = anonymous_block?(original)
      sig_sources = method_node.sigs.map do |sig|
        # RBI::Sig#string serializes back to valid T::Sig DSL source
        sig_source = sig.string
        # Anonymous block params (def foo(&)) need `"&":` instead of the RBI
        # block parameter name.
        has_anon_block ? rewrite_block_param(sig_source, method_node, sig) : sig_source
      end

      apply_sig_sources_to_method(
        target,
        full_name,
        method_name,
        sig_sources,
        errors,
        original:,
        singleton_method:,
        sig_eval_scope:
      )
    end

    def apply_attr_sig(target, class_name, attr_node, errors, class_method: false, sig_eval_scope: target)
      return [0, 0] if attr_node.sigs.empty?

      singleton_method = class_method
      separator = singleton_method ? '.' : '#'
      applied = 0
      skipped = 0

      attr_node.names.each do |attr_name|
        attr_method_sig_sources(attr_node, attr_name).each do |method_name, sig_sources|
          method_name = method_name.to_sym
          full_name = "#{class_name}#{separator}#{method_name}"

          begin
            original = target.instance_method(method_name)
          rescue NameError
            errors << "#{full_name}: method not found"
            next
          end

          result = apply_sig_sources_to_method(
            target,
            full_name,
            method_name,
            sig_sources,
            errors,
            original:,
            singleton_method:,
            sig_eval_scope:
          )
          if result == :skipped
            skipped += 1
          elsif result
            applied += 1
          end
        end
      end

      [applied, skipped]
    end

    def attr_method_sig_sources(attr_node, attr_name)
      case attr_node
      when RBI::AttrReader
        [[attr_name, attr_node.sigs.map(&:string)]]
      when RBI::AttrWriter
        [["#{attr_name}=", attr_node.sigs.map(&:string)]]
      when RBI::AttrAccessor
        [
          [attr_name, attr_node.sigs.map(&:string)],
          ["#{attr_name}=", writer_sig_sources(attr_node, attr_name)]
        ]
      else
        raise ArgumentError, "Unsupported attr node type: #{attr_node.class}"
      end
    end

    def writer_sig_sources(attr_node, attr_name)
      attr_node.sigs.map do |sig|
        return_type = sig.return_type || 'T.untyped'
        "sig { params(#{attr_name}: #{return_type}).returns(#{return_type}) }"
      end
    end

    def apply_sig_sources_to_method(
      target,
      full_name,
      method_name,
      sig_sources,
      errors,
      original:,
      singleton_method:,
      sig_eval_scope:
    )
      # For inherited methods, copy the method locally so a subclass sig does not
      # instrument the parent globally.
      inherited_method = original.owner != target
      original = define_local_method_copy(target, method_name, original) if inherited_method

      sig_sources.each do |sig_source|
        apply_sig_source(sig_eval_scope, target, sig_source, singleton_method)
        apply_pending_sig(sig_eval_scope, target, method_name, singleton_method)

        # Force eager sig validation so mismatches are caught now rather than
        # causing cascading failures on first call.
        method_obj = target.instance_method(method_name)
        T::Utils.signature_for_method(method_obj)
      rescue StandardError => e
        # Restore the original method without the sig wrapper
        restore_original_method(target, method_name, original, remove_local_method: inherited_method)
        errors << "#{full_name}: #{e.message}"
        return false
      end

      true
    end

    def anonymous_block?(method)
      block_param = method.parameters.find { |kind, _| kind == :block }
      block_param && (block_param[1].nil? || block_param[1] == :&)
    end

    def apply_sig_source(sig_eval_scope, target, sig_source, singleton_method)
      if singleton_method
        sig_eval_scope.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          class << self
            #{sig_source} # #{sig_source}
          end
        RUBY
      else
        target.class_eval(sig_source)
      end
    end

    # The RBI sig is evaluated after the real method already exists, so Ruby
    # will not naturally fire method_added. Call Sorbet's hook directly instead
    # of redefining the method to make Ruby fire it.
    def apply_pending_sig(sig_eval_scope, target, method_name, singleton_method)
      hook_mod = singleton_method ? sig_eval_scope : target
      T::Private::Methods._on_method_added(hook_mod, target, method_name)
    end

    def define_local_method_copy(target, method_name, original)
      visibility = method_visibility(target, method_name)
      T::Private::DeclState.current.without_on_method_added do
        target.send(:define_method, method_name, original)
        target.send(visibility, method_name)
      end
      target.instance_method(method_name)
    end

    def method_visibility(target, method_name)
      return :private if target.private_method_defined?(method_name)
      return :protected if target.protected_method_defined?(method_name)

      :public
    end

    def restore_original_method(target, method_name, original, remove_local_method: false)
      T::Private::DeclState.current.without_on_method_added do
        if remove_local_method
          target.send(:remove_method, method_name)
        else
          target.send(:define_method, method_name, original)
        end
      end
    end

    # Rewrites the RBI block parameter name to `"&": <type>` so
    # sorbet-runtime matches the anonymous block parameter.
    def rewrite_block_param(sig_source, method_node, sig)
      block_param_name =
        method_node.params.find { |param| param.is_a?(RBI::BlockParam) }&.name ||
        sig.params.find { |param| param.type&.include?('T.proc') }&.name

      return sig_source unless block_param_name

      sig_source.sub(/\b#{Regexp.escape(block_param_name)}:\s/, '"&": ')
    end

    # Determines whether a method should be skipped for sig application based
    # on parameter shape mismatches between the RBI sig and the actual method.
    def skip_method?(original, method_node, _method_name)
      actual_params = original.parameters

      # Block param mismatch: methods using yield with no block param,
      # or sigs that omit declared blocks. Anonymous blocks (def foo(&))
      # are handled via sig rewriting in apply_method_sig.
      actual_block = actual_params.find { |kind, _| kind == :block }
      sig_block_params = method_node.sigs.flat_map { |sig| sig.params.select { |p| p.type&.include?('T.proc') } }
      actual_has_block = !actual_block.nil?
      sig_has_block = sig_block_params.any?
      return true if actual_has_block != sig_has_block

      # Native/extension methods may expose positional parameters without
      # names. Sorbet runtime signatures cannot name those parameters without
      # adding Ruby wrappers, so keep those RBIs for static checking only.
      has_unnamed_params = actual_params.any? { |_kind, name| name.nil? }
      return true if has_unnamed_params

      # Synthetic methods (e.g., Data.define generates .new, .[], #initialize,
      # #with with a single splat) where the RBI provides typed keyword params
      # for better static checking but the runtime signature is incompatible.
      non_block_params = actual_params.reject { |kind, _| kind == :block } # rubocop:disable Style/HashExcept
      all_rest_or_unnamed = non_block_params.all? { |kind, _| kind == :rest || kind == :keyrest }
      sig_named_params = method_node.sigs.flat_map { |s| s.params.reject { |p| p.type&.include?('T.proc') } }
      return true if all_rest_or_unnamed && non_block_params.any? && sig_named_params.any?

      false
    end
  end
end
