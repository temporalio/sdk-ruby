# frozen_string_literal: true

require 'rbi'
require 'sorbet-runtime'
require_relative 'rbi_paths'

# Parses the Ruby SDK's RBI files and applies Sorbet runtime type signatures to
# already-loaded class implementations using Sorbet's method_added
# machinery.
# This enables sorbet-runtime to validate argument and return types at runtime
# during test execution.
#
# Type mismatches are collected and reported as a summary after the test run
# rather than raising mid-execution.
module SigApplicator
  # Classes that use Sorbet generic type members require the implementing class to include T::Generic.
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

  MethodShape = Data.define(:actual_params, :rbi_params)

  class MethodShape
    def self.from(original, method_node)
      new(original.parameters, method_node.params)
    end

    def actual_block_param
      actual_params.find { |kind, _| kind == :block }
    end

    def rbi_block_param
      rbi_params.find { |param| param.is_a?(RBI::BlockParam) }
    end

    def actual_block?
      !actual_block_param.nil?
    end

    def rbi_block?
      !rbi_block_param.nil?
    end

    def actual_non_block_params
      actual_params.reject { |param| param.first == :block }
    end

    def sig_method_params(sig)
      block_param_name = rbi_block_param&.name
      return sig.params unless block_param_name

      sig.params.reject { |param| param.name.to_s == block_param_name.to_s }
    end
  end

  class Accumulator
    attr_accessor :applied, :skipped, :missing, :errors

    def initialize(applied: 0, skipped: 0, missing: 0, errors: [])
      @applied = applied
      @skipped = skipped
      @missing = missing
      @errors = errors
    end

    def record(result)
      case result
      when :applied
        @applied += 1
      when :skipped
        @skipped += 1
      when :missing
        @missing += 1
      else
        raise ArgumentError, "unexpected accumulator symbol #{result}"
      end
    end

    def error(error)
      @errors << error
    end
  end

  @type_errors = []
  @summary_hook_registered = false

  class << self
    def apply_all!
      @type_errors.clear
      configure_error_handler!
      register_summary_hook!

      # Make T::Sig available on all modules/classes
      ::Module.include(::T::Sig)

      acc = Accumulator.new(applied: 0, skipped: 0, missing: 0, errors: [])

      rbi_paths.each do |path|
        tree = RBI::Parser.parse_file(path)
        next unless valid_rbi_signatures?(tree, acc)

        tree.nodes.each do |node|
          apply_scope(node, acc)
        end
      end

      if acc.skipped.positive?
        warn "SigApplicator: applied #{acc.applied} runtime type signatures (#{acc.skipped} skipped)"
      end

      raise_instrumentation_errors!(acc)
    end

    def record_type_error(message)
      return if Thread.current[:sig_applicator_suppressed]

      @type_errors << message
    end

    def type_errors
      @type_errors.dup
    end

    # Use for tests that intentionally pass wrong types.
    def suppress_errors
      raise 'SigApplicator.suppress_errors cannot be nested' if Thread.current[:sig_applicator_suppressed]

      Thread.current[:sig_applicator_suppressed] = true
      begin
        yield
      ensure
        Thread.current[:sig_applicator_suppressed] = false
      end
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

    # Register an after-run hook that asserts no type errors seen
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

    def raise_instrumentation_errors!(acc)
      return if acc.errors.empty? && acc.missing.zero?

      summary = "SigApplicator: #{acc.errors.size} methods could not be instrumented:\n"
      acc.errors.each { |error| summary << "  #{error}\n" }
      summary << "#{acc.missing} methods missing a signature" if acc.missing.positive?
      raise summary.chomp
    end

    def valid_rbi_signatures?(node, acc)
      valid = true

      if node.is_a?(RBI::Method)
        method_param_names = node.params.map(&:name).sort
        node.sigs.each do |sig|
          sig_param_names = sig.params.map(&:name).sort
          next if sig_param_names == method_param_names

          valid = false
          method_name = node.fully_qualified_name.delete_prefix('::')
          method_name = method_name.sub(/::([^:]+)\z/, '.\1') if node.is_singleton
          method_name = method_name.sub('::<self>#', '.')
          acc.error "#{method_name}: signature parameters #{sig_param_names.inspect} " \
                    "do not match method parameters #{method_param_names.inspect}"
        end
      end

      if node.respond_to?(:nodes)
        node.nodes.each do |child|
          valid = false unless valid_rbi_signatures?(child, acc)
        end
      end

      valid
    end

    def apply_scope(node, acc)
      return unless node.respond_to?(:nodes)

      class_name = node.name if node.respond_to?(:name)
      return unless class_name

      if SKIP_CLASSES.include?(class_name)
        acc.record :skipped
        return
      end

      begin
        klass = Object.const_get(class_name)
      rescue NameError
        acc.error "#{class_name}: class not found"
        return
      end

      node.nodes.each do |child|
        case child
        when RBI::Method
          target = child.is_singleton ? klass.singleton_class : klass
          apply_method_sig(target, class_name, child, acc, sig_eval_scope: klass)
        when *ATTR_NODE_CLASSES
          apply_attr_sig(klass, class_name, child, acc, sig_eval_scope: klass)
        when RBI::SingletonClass
          child.nodes.each do |scn|
            case scn
            when RBI::Method
              apply_method_sig(
                klass.singleton_class,
                class_name,
                scn,
                acc,
                class_method: true,
                sig_eval_scope: klass
              )
            when *ATTR_NODE_CLASSES
              apply_attr_sig(
                klass.singleton_class,
                class_name,
                scn,
                acc,
                class_method: true,
                sig_eval_scope: klass
              )
            end
          end
        end
      end
    end

    def apply_method_sig(target, class_name, method_node, acc, class_method: false, sig_eval_scope: target)
      if method_node.sigs.empty?
        acc.record :missing
        return
      end

      method_name = method_node.name.to_sym
      singleton_method = class_method || method_node.is_singleton
      separator = singleton_method ? '.' : '#'
      full_name = "#{class_name}#{separator}#{method_name}"

      if SKIP_METHODS.include?(full_name)
        acc.record :skipped
        return
      end

      begin
        original = target.instance_method(method_name)
      rescue NameError
        acc.error "#{full_name}: method not found"
        return
      end

      if skip_method?(original, method_node, method_name)
        acc.record :skipped
        return
      end

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
        acc,
        original:,
        singleton_method:,
        sig_eval_scope:
      )
    end

    def apply_attr_sig(target, class_name, attr_node, acc, class_method: false, sig_eval_scope: target)
      return if attr_node.sigs.empty?

      singleton_method = class_method
      separator = singleton_method ? '.' : '#'

      attr_node.names.each do |attr_name|
        attr_method_sig_sources(attr_node, attr_name).each do |method_name, sig_sources|
          method_name = method_name.to_sym
          full_name = "#{class_name}#{separator}#{method_name}"

          begin
            original = target.instance_method(method_name)
          rescue NameError
            acc.error "#{full_name}: method not found"
            next
          end

          apply_sig_sources_to_method(
            target,
            full_name,
            method_name,
            sig_sources,
            acc,
            original:,
            singleton_method:,
            sig_eval_scope:
          )
        end
      end
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
      acc,
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
        acc.error "#{full_name}: #{e.message}"
      end

      acc.record :applied
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

    # The RBI sig is evaluated after the real method already exists,
    # call Sorbet's hook directly instead or redefining the method.
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

    def restore_original_method(target, method_name, original, remove_local_method: false)
      T::Private::DeclState.current.without_on_method_added do
        if remove_local_method
          target.send(:remove_method, method_name)
        else
          target.send(:define_method, method_name, original)
        end
      end
    end

    def method_visibility(target, method_name)
      return :private if target.private_method_defined?(method_name)
      return :protected if target.protected_method_defined?(method_name)

      :public
    end

    # Rewrites the RBI block parameter name to `"&": <type>` so
    # sorbet-runtime matches the anonymous block parameter.
    def rewrite_block_param(sig_source, method_node, _sig)
      block_param_name = method_node.params.find { |param| param.is_a?(RBI::BlockParam) }&.name

      return sig_source unless block_param_name

      sig_source.sub(/\b#{Regexp.escape(block_param_name)}:\s/, '"&": ')
    end

    # Determines whether a method should be omitted from instrumenting
    # due to mismatches between typing and implementations.
    def skip_method?(original, method_node, _method_name)
      shape = MethodShape.from(original, method_node)

      # Block param mismatch: methods using yield with no block param,
      # or sigs that omit declared blocks.
      return true if shape.actual_block? != shape.rbi_block?

      # Native methods may expose positional parameters without
      # names. Sorbet runtime signatures cannot name those parameters without
      # adding Ruby wrappers.
      has_unnamed_params = shape.actual_params.any? { |_kind, name| name.nil? }
      return true if has_unnamed_params

      # Data.define generates initializers with splats where
      # RBI provides typed keyword params for better static checking.
      non_block_params = shape.actual_non_block_params
      all_rest_or_unnamed = non_block_params.all? { |kind, _| kind == :rest || kind == :keyrest }
      sig_named_params = method_node.sigs.flat_map { |sig| shape.sig_method_params(sig) }
      return true if all_rest_or_unnamed && non_block_params.any? && sig_named_params.any?

      false
    end
  end
end
