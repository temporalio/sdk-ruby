# frozen_string_literal: true

require 'delegate'
require 'logger'
require 'minitest/autorun'
require 'rbi'
require 'support/sig_applicator'

module Support
  class SigApplicatorTest < Minitest::Test
    # --- Block param mismatch skips ---

    def test_does_not_skip_anonymous_block_with_sig_block
      klass = Class.new do
        def foo(&); end
      end
      method_node = parse_method(
        'class X; sig { params(blk: T.proc.void).void }; def foo(&blk); end; end'
      )
      original = klass.instance_method(:foo)
      refute skip_method?(original, method_node, :foo)
    end

    def test_skips_method_with_block_but_sig_without
      klass = Class.new do
        def foo(&); end
      end
      method_node = parse_method('class X; sig { void }; def foo; end; end')
      original = klass.instance_method(:foo)
      assert skip_method?(original, method_node, :foo)
    end

    def test_skips_sig_with_block_but_method_without
      klass = Class.new do
        def foo; end
      end
      method_node = parse_method(
        'class X; sig { params(blk: T.proc.void).void }; def foo(&blk); end; end'
      )
      original = klass.instance_method(:foo)
      assert skip_method?(original, method_node, :foo)
    end

    def test_does_not_skip_matching_named_block
      klass = Class.new do
        def foo(&blk); end # rubocop:disable Naming/BlockForwarding
      end
      method_node = parse_method(
        'class X; sig { params(blk: T.proc.void).void }; def foo(&blk); end; end'
      )
      original = klass.instance_method(:foo)
      refute skip_method?(original, method_node, :foo)
    end

    # --- Anonymous block sig rewriting ---

    def test_rewrite_block_param
      input = 'sig { params(name: String, blk: T.proc.void).void }'
      expected = 'sig { params(name: String, "&": T.proc.void).void }'
      method_node = parse_method(
        'class X; sig { params(name: String, blk: T.proc.void).void }; def foo(name, &blk); end; end'
      )
      assert_equal expected, rewrite_block_param(input, method_node, method_node.sigs.first)
    end

    def test_rewrite_block_param_no_block
      input = 'sig { params(name: String).void }'
      method_node = parse_method('class X; sig { params(name: String).void }; def foo(name); end; end')
      assert_equal input, rewrite_block_param(input, method_node, method_node.sigs.first)
    end

    # --- Setter / unnamed param skips ---

    def test_skips_attr_writer_with_unnamed_params
      klass = Class.new { attr_writer :bar }
      method_node = parse_method(
        'class X; sig { params(value: Integer).void }; def bar=(value); end; end'
      )
      original = klass.instance_method(:bar=)
      assert skip_method?(original, method_node, :bar=)
    end

    def test_does_not_skip_regular_setter
      klass = Class.new do
        def bar=(value); end
      end
      method_node = parse_method(
        'class X; sig { params(value: Integer).void }; def bar=(value); end; end'
      )
      original = klass.instance_method(:bar=)
      refute skip_method?(original, method_node, :bar=)
    end

    # --- Synthetic rest-param skips ---

    def test_skips_rest_only_method_with_named_sig_params
      klass = Class.new do
        def initialize(*args); end
      end
      method_node = parse_method(<<~RBI)
        class X
          sig { params(name: String, age: Integer).void }
          def initialize(name:, age:); end
        end
      RBI
      original = klass.instance_method(:initialize)
      assert skip_method?(original, method_node, :initialize)
    end

    def test_does_not_skip_when_params_match
      klass = Class.new do
        def foo(val1, val2); end
      end
      method_node = parse_method(<<~RBI)
        class X
          sig { params(val1: Integer, val2: String).returns(String) }
          def foo(val1, val2); end
        end
      RBI
      original = klass.instance_method(:foo)
      refute skip_method?(original, method_node, :foo)
    end

    def test_does_not_skip_no_param_method
      klass = Class.new do
        def foo; end
      end
      method_node = parse_method('class X; sig { returns(String) }; def foo; end; end')
      original = klass.instance_method(:foo)
      refute skip_method?(original, method_node, :foo)
    end

    def test_apply_all_raises_when_signature_cannot_be_instrumented
      test_class = Class.new do
        extend T::Sig

        def self.foo(value); end
      end
      Support.const_set(:SigApplicatorApplyAllTest, test_class)

      tree = RBI::Parser.parse_string(<<~RBI)
        class Support::SigApplicatorApplyAllTest
          sig { params(other: String).void }
          def self.foo(value); end
        end
      RBI

      parser = RBI::Parser.singleton_class
      original_parse_file = RBI::Parser.method(:parse_file)
      parser.send(:define_method, :parse_file) { |_path| tree }

      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)

      error = assert_raises(RuntimeError) do
        with_sig_applicator_rbi_paths(['test.rbi']) { SigApplicator.apply_all! }
      end
      assert_includes error.message, 'SigApplicator: 1 methods could not be instrumented:'
      assert_includes error.message, 'Support::SigApplicatorApplyAllTest.foo:'
    ensure
      parser.send(:define_method, :parse_file, original_parse_file)
      if Support.const_defined?(:SigApplicatorApplyAllTest, false)
        Support.send(:remove_const, :SigApplicatorApplyAllTest)
      end
      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)
    end

    def test_apply_all_reads_all_rbi_paths
      test_class = Class.new do
        def self.foo(value)
          value
        end

        def self.bar(value)
          value
        end
      end
      Support.const_set(:SigApplicatorMultiFileTest, test_class)

      trees = {
        'one.rbi' => RBI::Parser.parse_string(<<~RBI),
          class Support::SigApplicatorMultiFileTest
            sig { params(value: String).returns(String) }
            def self.foo(value); end
          end
        RBI
        'two.rbi' => RBI::Parser.parse_string(<<~RBI)
          class Support::SigApplicatorMultiFileTest
            sig { params(value: String).returns(String) }
            def self.bar(value); end
          end
        RBI
      }
      parsed_paths = []

      parser = RBI::Parser.singleton_class
      original_parse_file = RBI::Parser.method(:parse_file)
      parser.send(:define_method, :parse_file) do |path|
        parsed_paths << path
        trees.fetch(path)
      end

      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)

      with_sig_applicator_rbi_paths(trees.keys) { SigApplicator.apply_all! }

      assert_equal trees.keys, parsed_paths
      assert_empty SigApplicator.type_errors
    ensure
      parser.send(:define_method, :parse_file, original_parse_file)
      if Support.const_defined?(:SigApplicatorMultiFileTest, false)
        Support.send(:remove_const, :SigApplicatorMultiFileTest)
      end
      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)
    end

    def test_apply_all_applies_attr_reader_signature
      test_class = Class.new do
        attr_reader :name

        def initialize(name)
          @name = name
        end
      end
      Support.const_set(:SigApplicatorAttrReaderTest, test_class)

      tree = RBI::Parser.parse_string(<<~RBI)
        class Support::SigApplicatorAttrReaderTest
          sig { returns(String) }
          attr_reader :name
        end
      RBI

      parser = RBI::Parser.singleton_class
      original_parse_file = RBI::Parser.method(:parse_file)
      parser.send(:define_method, :parse_file) { |_path| tree }

      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)

      with_sig_applicator_rbi_paths(['test.rbi']) { SigApplicator.apply_all! }
      test_class.new(123).name

      assert_includes SigApplicator.type_errors.join("\n"), 'Return value: Expected type String, got type Integer'
    ensure
      parser.send(:define_method, :parse_file, original_parse_file)
      if Support.const_defined?(:SigApplicatorAttrReaderTest, false)
        Support.send(:remove_const, :SigApplicatorAttrReaderTest)
      end
      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)
    end

    def test_apply_all_applies_attr_accessor_signature
      test_class = Class.new do
        attr_accessor :count
      end
      Support.const_set(:SigApplicatorAttrAccessorTest, test_class)

      tree = RBI::Parser.parse_string(<<~RBI)
        class Support::SigApplicatorAttrAccessorTest
          sig { returns(Integer) }
          attr_accessor :count
        end
      RBI

      parser = RBI::Parser.singleton_class
      original_parse_file = RBI::Parser.method(:parse_file)
      parser.send(:define_method, :parse_file) { |_path| tree }

      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)

      with_sig_applicator_rbi_paths(['test.rbi']) { SigApplicator.apply_all! }

      instance = test_class.new
      instance.count = 'bad'
      instance.count

      errors = SigApplicator.type_errors.join("\n")
      assert_includes errors, "Parameter 'count': Expected type Integer, got type String"
      assert_includes errors, 'Return value: Expected type Integer, got type String'
    ensure
      parser.send(:define_method, :parse_file, original_parse_file)
      if Support.const_defined?(:SigApplicatorAttrAccessorTest, false)
        Support.send(:remove_const, :SigApplicatorAttrAccessorTest)
      end
      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)
    end

    def test_apply_method_sig_supports_anonymous_block_with_named_rbi_block
      klass = Class.new do
        extend T::Sig

        def foo(&); end
      end
      method_node = parse_method(
        'class X; sig { params(blk: T.proc.void).void }; def foo(&blk); end; end'
      )
      errors = []

      assert apply_method_sig(klass, 'X', method_node, errors, sig_eval_scope: klass)
      assert_empty errors
    end

    def test_apply_method_sig_does_not_emit_extra_method_added_events
      klass = Class.new do
        extend T::Sig

        class << self
          attr_accessor :method_added_events
        end

        self.method_added_events = []

        def self.method_added(name)
          method_added_events << name
          super
        end

        def foo
          'ok'
        end
      end
      klass.method_added_events.clear
      method_node = parse_method('class X; sig { returns(String) }; def foo; end; end')
      errors = []

      assert apply_method_sig(klass, 'X', method_node, errors, sig_eval_scope: klass)
      assert_empty errors
      assert_equal 'ok', klass.new.foo
      assert_equal klass.method_added_events.select { |name| name == :foo }, klass.method_added_events
      # Sorbet replaces the method twice, we should not add to this
      assert_equal klass.method_added_events.size, 2
    end

    def test_apply_method_sig_restores_original_method_when_instrumentation_fails
      klass = Class.new do
        extend T::Sig

        def foo(value)
          "original: #{value}"
        end
      end
      original = klass.instance_method(:foo)
      method_node = parse_method(<<~RBI)
        class X
          sig { params(other: String).returns(String) }
          def foo(other); end
        end
      RBI
      errors = []

      refute apply_method_sig(klass, 'X', method_node, errors, sig_eval_scope: klass)
      assert_includes errors.join("\n"), 'The declaration for `foo` is missing parameter(s): value'
      assert_equal original, klass.instance_method(:foo)
      assert_equal 'original: ok', klass.new.foo('ok')
    end

    def test_apply_method_sig_catches_incompatible_override_after_inherited_method_sig
      base_class = Class.new do
        def to_h
          { value: 'base' }
        end
      end
      inherited_method_class = Class.new(base_class) { extend T::Sig }
      override_class = Class.new(inherited_method_class) do
        extend T::Sig

        def to_h
          { 'profile' => { value: 'override' } }
        end
      end

      Support.const_set(:SigApplicatorInheritedMethodSigTest, inherited_method_class)
      Support.const_set(:SigApplicatorIncompatibleOverrideTest, override_class)

      inherited_method_node = parse_method(<<~RBI)
        class Support::SigApplicatorInheritedMethodSigTest
          sig { returns(T::Hash[Symbol, T.untyped]) }
          def to_h; end
        end
      RBI
      override_method_node = parse_method(<<~RBI)
        class Support::SigApplicatorIncompatibleOverrideTest
          sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
          def to_h; end
        end
      RBI

      errors = []
      assert apply_method_sig(
        inherited_method_class,
        'Support::SigApplicatorInheritedMethodSigTest',
        inherited_method_node,
        errors,
        sig_eval_scope: inherited_method_class
      )
      assert_empty errors

      refute apply_method_sig(
        override_class,
        'Support::SigApplicatorIncompatibleOverrideTest',
        override_method_node,
        errors,
        sig_eval_scope: override_class
      )
      assert_includes errors.join("\n"), 'Incompatible return type in signature for override of method `to_h`'
    ensure
      if Support.const_defined?(:SigApplicatorInheritedMethodSigTest, false)
        Support.send(:remove_const, :SigApplicatorInheritedMethodSigTest)
      end
      if Support.const_defined?(:SigApplicatorIncompatibleOverrideTest, false)
        Support.send(:remove_const, :SigApplicatorIncompatibleOverrideTest)
      end
    end

    def test_apply_method_sig_for_inherited_method_does_not_wrap_original_owner
      original_delegator_initialize = Delegator.instance_method(:initialize)
      inherited_method_class = Class.new(SimpleDelegator) { extend T::Sig }
      child_class = Class.new(inherited_method_class) do
        attr_reader :marker

        def initialize(obj:, marker:)
          @marker = marker
          super(obj)
        end
      end
      Support.const_set(:SigApplicatorDelegatorSigTest, inherited_method_class)

      inherited_method_node = parse_method(<<~RBI)
        class Support::SigApplicatorDelegatorSigTest
          sig { params(obj: ::Logger).void }
          def initialize(obj); end
        end
      RBI

      errors = []
      assert apply_method_sig(
        inherited_method_class,
        'Support::SigApplicatorDelegatorSigTest',
        inherited_method_node,
        errors,
        sig_eval_scope: inherited_method_class
      )
      assert_empty errors

      assert_equal original_delegator_initialize, Delegator.instance_method(:initialize)
      assert_equal inherited_method_class, inherited_method_class.instance_method(:initialize).owner

      child = child_class.new(obj: Logger.new(nil), marker: :ok)
      assert_equal :ok, child.marker
      assert_instance_of Logger, child.__getobj__
    ensure
      if Support.const_defined?(:SigApplicatorDelegatorSigTest, false)
        Support.send(:remove_const, :SigApplicatorDelegatorSigTest)
      end
    end

    def test_apply_method_sig_preserves_inherited_method_visibility
      base_class = Class.new do
        protected

        def protected_value
          'protected'
        end

        private

        def private_value
          'private'
        end
      end
      inherited_method_class = Class.new(base_class) { extend T::Sig }
      Support.const_set(:SigApplicatorVisibilityTest, inherited_method_class)

      protected_node = parse_method(<<~RBI)
        class Support::SigApplicatorVisibilityTest
          sig { returns(String) }
          def protected_value; end
        end
      RBI
      private_node = parse_method(<<~RBI)
        class Support::SigApplicatorVisibilityTest
          sig { returns(String) }
          def private_value; end
        end
      RBI

      errors = []
      assert apply_method_sig(
        inherited_method_class,
        'Support::SigApplicatorVisibilityTest',
        protected_node,
        errors,
        sig_eval_scope: inherited_method_class
      )
      assert apply_method_sig(
        inherited_method_class,
        'Support::SigApplicatorVisibilityTest',
        private_node,
        errors,
        sig_eval_scope: inherited_method_class
      )
      assert_empty errors

      assert inherited_method_class.protected_method_defined?(:protected_value)
      assert inherited_method_class.private_method_defined?(:private_value)
      refute inherited_method_class.public_method_defined?(:protected_value)
      refute inherited_method_class.public_method_defined?(:private_value)
    ensure
      if Support.const_defined?(:SigApplicatorVisibilityTest, false)
        Support.send(:remove_const, :SigApplicatorVisibilityTest)
      end
    end

    def test_apply_method_sig_removes_local_copy_when_inherited_instrumentation_fails
      base_class = Class.new do
        def foo(value)
          "original: #{value}"
        end
      end
      inherited_method_class = Class.new(base_class) { extend T::Sig }
      Support.const_set(:SigApplicatorInheritedRestoreTest, inherited_method_class)

      method_node = parse_method(<<~RBI)
        class Support::SigApplicatorInheritedRestoreTest
          sig { params(other: String).returns(String) }
          def foo(other); end
        end
      RBI

      errors = []
      refute apply_method_sig(
        inherited_method_class,
        'Support::SigApplicatorInheritedRestoreTest',
        method_node,
        errors,
        sig_eval_scope: inherited_method_class
      )
      assert_includes errors.join("\n"), 'The declaration for `foo` is missing parameter(s): value'
      assert_equal base_class, inherited_method_class.instance_method(:foo).owner
      assert_equal 'original: ok', inherited_method_class.new.foo('ok')
    ensure
      if Support.const_defined?(:SigApplicatorInheritedRestoreTest, false)
        Support.send(:remove_const, :SigApplicatorInheritedRestoreTest)
      end
    end

    def test_apply_method_sig_resolves_singleton_sig_constants_in_class_namespace
      klass = Class.new do
        extend T::Sig

        class << self
          extend T::Sig
        end

        def self.foo(value); end
      end
      klass.const_set(:Inner, Data.define(:value))
      Support.const_set(:SigApplicatorSingletonScopeTest, klass)
      method_node = parse_method(<<~RBI)
        class Support::SigApplicatorSingletonScopeTest
          sig { params(value: Inner).void }
          def self.foo(value); end
        end
      RBI
      errors = []

      assert apply_method_sig(
        klass.singleton_class,
        'Support::SigApplicatorSingletonScopeTest',
        method_node,
        errors,
        sig_eval_scope: klass
      )
      assert_empty errors
    ensure
      if Support.const_defined?(:SigApplicatorSingletonScopeTest, false)
        Support.send(:remove_const, :SigApplicatorSingletonScopeTest)
      end
    end

    private

    def parse_method(source)
      tree = RBI::Parser.parse_string(source)
      klass = tree.nodes.first
      klass.nodes.find { |n| n.is_a?(RBI::Method) }
    end

    def skip_method?(original, method_node, method_name)
      SigApplicator.send(:skip_method?, original, method_node, method_name)
    end

    def rewrite_block_param(sig_source, method_node, sig)
      SigApplicator.send(:rewrite_block_param, sig_source, method_node, sig)
    end

    def apply_method_sig(target, class_name, method_node, errors, sig_eval_scope:)
      SigApplicator.send(
        :apply_method_sig,
        target,
        class_name,
        method_node,
        errors,
        sig_eval_scope:
      )
    end

    def attr_method_sig_sources(attr_node, attr_name)
      SigApplicator.send(:attr_method_sig_sources, attr_node, attr_name)
    end

    def with_sig_applicator_rbi_paths(paths)
      singleton_class = SigApplicator.singleton_class
      original = singleton_class.instance_method(:rbi_paths)
      singleton_class.send(:define_method, :rbi_paths) { paths }
      singleton_class.send(:private, :rbi_paths)
      yield
    ensure
      singleton_class.send(:define_method, :rbi_paths, original)
      singleton_class.send(:private, :rbi_paths)
    end
  end
end
