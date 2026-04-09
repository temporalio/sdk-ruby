# frozen_string_literal: true

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
      input = 'sig { params(name: String, block: T.proc.void).void }'
      expected = 'sig { params(name: String, "&": T.proc.void).void }'
      assert_equal expected, rewrite_block_param(input)
    end

    def test_rewrite_block_param_no_block
      input = 'sig { params(name: String).void }'
      assert_equal input, rewrite_block_param(input)
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

      error = assert_raises(RuntimeError) { SigApplicator.apply_all! }
      assert_includes error.message, 'SigApplicator: 1 methods could not be instrumented:'
      assert_includes error.message, 'Support::SigApplicatorApplyAllTest.foo:'
    ensure
      parser.send(:define_method, :parse_file, original_parse_file)
      Support.send(:remove_const, :SigApplicatorApplyAllTest) if Support.const_defined?(:SigApplicatorApplyAllTest, false)
      Object.send(:remove_const, :ZZZSigApplicatorTest) if Object.const_defined?(:ZZZSigApplicatorTest)
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

    def rewrite_block_param(sig_source)
      SigApplicator.send(:rewrite_block_param, sig_source)
    end
  end
end
