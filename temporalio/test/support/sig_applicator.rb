# frozen_string_literal: true

require 'rbi'
require 'sorbet-runtime'

# Parses the SDK's RBI file and applies Sorbet runtime type signatures to the
# real (already-loaded) class implementations using define_method.
# This enables sorbet-runtime to validate argument and return types at runtime
# during test execution, catching any drift between the RBI and actual code.
#
# Type mismatches are collected and reported as a summary after the test run
# rather than raising mid-execution. This avoids hanging workflows where a
# TypeError would cause an unrecoverable task failure that retries forever.
module SigApplicator
  RBI_PATH = File.expand_path('../../rbi/temporalio.rbi', __dir__)

  # Namespace prefixes to skip — these are generated classes (e.g., protobuf)
  # whose methods may not be visible via normal Ruby reflection.
  SKIP_PREFIXES = [
    'Temporalio::Api::'
  ].freeze

  # Classes that use Sorbet generic type members (e.g., Elem = type_member)
  # which don't exist at runtime without T::Generic.
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

  @type_errors = []
  @mutex = Mutex.new

  class << self
    def apply_all!
      @mutex.synchronize { @type_errors.clear }
      configure_error_handler!
      register_summary_hook!

      # Make T::Sig available on all modules/classes so we don't need to
      # extend it per-target inside apply_method_sig.
      ::Module.include(::T::Sig)

      tree = RBI::Parser.parse_file(RBI_PATH)
      errors = []
      skipped = 0
      applied = 0

      tree.nodes.each do |node|
        a, s = apply_scope(node, errors)
        applied += a
        skipped += s
      end

      warn "SigApplicator: applied #{applied} runtime type signatures (#{skipped} skipped)"

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

    # Register a Minitest test class that runs last and asserts no type
    # errors were collected.
    def register_summary_hook!
      # Minitest runs test classes in alphabetical order by default.
      # "ZZZ" ensures this runs after all other tests.
      klass = Class.new(Minitest::Test) do
        define_method(:test_no_sorbet_runtime_type_errors) do
          errors = SigApplicator.type_errors
          return if errors.empty?

          unique = errors.tally
          summary = "SigApplicator: #{errors.size} runtime type errors detected (#{unique.size} unique):\n"
          unique.sort_by { |_, count| -count }.each do |msg, count|
            summary << "  [#{count}x] #{msg}\n"
          end
          flunk summary
        end
      end
      Object.const_set(:ZZZSigApplicatorTest, klass)
    end

    def raise_instrumentation_errors!(errors)
      return if errors.empty?

      summary = +"SigApplicator: #{errors.size} methods could not be instrumented:\n"
      errors.each { |error| summary << "  #{error}\n" }
      raise summary.chomp
    end

    def apply_scope(node, errors)
      return [0, 0] unless node.respond_to?(:nodes)

      class_name = node.name if node.respond_to?(:name)
      return [0, 0] unless class_name
      return [0, 0] if SKIP_PREFIXES.any? { |prefix| class_name.start_with?(prefix) }
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
          result = apply_method_sig(target, class_name, child, errors)
          if result == :skipped
            skipped += 1
          elsif result
            applied += 1
          end
        when RBI::SingletonClass
          child.nodes.each do |scn|
            next unless scn.is_a?(RBI::Method)

            result = apply_method_sig(klass.singleton_class, class_name, scn, errors, class_method: true)
            if result == :skipped
              skipped += 1
            elsif result
              applied += 1
            end
          end
        end
      end
      [applied, skipped]
    end

    def apply_method_sig(target, class_name, method_node, errors, class_method: false)
      return false if method_node.sigs.empty?

      method_name = method_node.name.to_sym
      separator = class_method || method_node.is_singleton ? '.' : '#'
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

      method_node.sigs.each do |sig|
        # RBI::Sig#string serializes back to valid T::Sig DSL source
        sig_source = sig.string
        # Anonymous block params (def foo(&)) need `"&":` instead of `block:`
        sig_source = rewrite_block_param(sig_source) if has_anon_block
        begin
          target.class_eval(sig_source)
          target.send(:define_method, method_name, original)

          # Force eager sig validation so mismatches are caught now rather than
          # causing cascading failures on first call.
          method_obj = target.instance_method(method_name)
          T::Utils.signature_for_method(method_obj)
        rescue StandardError => e
          # Restore the original method without the sig wrapper
          target.send(:define_method, method_name, original)
          errors << "#{full_name}: #{e.message}"
          return false
        end
      end

      true
    end

    def anonymous_block?(method)
      block_param = method.parameters.find { |kind, _| kind == :block }
      block_param && (block_param[1].nil? || block_param[1] == :&)
    end

    # Rewrites `block: <type>` to `"&": <type>` in a sig source string
    # so sorbet-runtime matches the anonymous block parameter.
    def rewrite_block_param(sig_source)
      sig_source.sub(/\bblock:\s/, '"&": ')
    end

    # Determines whether a method should be skipped for sig application based
    # on parameter shape mismatches between the RBI sig and the actual method.
    def skip_method?(original, method_node, method_name)
      actual_params = original.parameters

      # Block param mismatch: methods using yield with no block param,
      # or sigs that omit declared blocks. Anonymous blocks (def foo(&))
      # are handled via sig rewriting in apply_method_sig.
      actual_block = actual_params.find { |kind, _| kind == :block }
      sig_block_params = method_node.sigs.flat_map { |sig| sig.params.select { |p| p.type&.include?('T.proc') } }
      actual_has_block = !actual_block.nil?
      sig_has_block = sig_block_params.any?
      return true if actual_has_block != sig_has_block

      # Setter methods where Ruby creates unnamed params (attr_writer)
      has_unnamed_params = actual_params.any? { |_kind, name| name.nil? }
      return true if has_unnamed_params && method_name.end_with?('=')

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
