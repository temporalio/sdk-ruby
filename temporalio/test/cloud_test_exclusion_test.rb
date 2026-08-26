# frozen_string_literal: true

require 'test'

class CloudTestExclusionTest < Test
  EXCLUSION_NOTE = 'Requires test-specific Cloud setup.'

  def setup
    super
    @test_classes = []
  end

  def teardown
    @test_classes.each { |test_class| Minitest::Runnable.runnables.delete(test_class) }
    super
  end

  def test_method_exclusion_filters_cloud_runs_and_fiber_variant
    test_class = Class.new(Test) #: singleton(Test)
    @test_classes << test_class
    test_class.also_run_all_tests_in_fiber

    # The annotation is consumed when the next test method is defined.
    test_class.exclude_from_cloud(:needs_cloud_adaptation, EXCLUSION_NOTE)
    test_class.define_method(:test_excluded) { nil }
    test_class.define_method(:test_eligible) { nil }

    expected = Test::CloudTestExclusion.new(:needs_cloud_adaptation, EXCLUSION_NOTE)
    assert_equal expected, test_class.cloud_test_exclusion(:test_excluded)
    eligible_methods = ['test_eligible']
    if Temporalio::Internal::Bridge.fibers_supported
      # The harness-generated fiber copy must carry the source test's exclusion.
      assert_equal expected, test_class.cloud_test_exclusion(:test_excluded_in_fiber)
      eligible_methods << 'test_eligible_in_fiber'
    end
    TemporalioTestMode.stub(:cloud?, true) do # steep:ignore NoMethod
      assert_equal eligible_methods.sort, test_class.runnable_methods.sort
    end
  end

  def test_class_exclusion_filters_inherited_tests
    parent = Class.new(Test) #: singleton(Test)
    parent.exclude_class_from_cloud(:requires_local_server, EXCLUSION_NOTE)
    parent.define_method(:test_parent) { nil }
    child = Class.new(parent) #: singleton(Test)
    child.define_method(:test_child) { nil }
    @test_classes.push(parent, child)

    expected = Test::CloudTestExclusion.new(:requires_local_server, EXCLUSION_NOTE)
    assert_equal expected, child.cloud_test_exclusion(:test_child)
    TemporalioTestMode.stub(:cloud?, true) { assert_empty child.runnable_methods } # steep:ignore NoMethod
  end

  def test_invalid_exclusions_fail_fast
    invalid = Class.new(Test) #: singleton(Test)
    @test_classes << invalid
    assert_raises(ArgumentError) do
      invalid.exclude_from_cloud(:unknown, EXCLUSION_NOTE) # steep:ignore ArgumentTypeMismatch
    end
    assert_raises(ArgumentError) { invalid.exclude_from_cloud(:needs_cloud_adaptation, '  ') }
    invalid.exclude_from_cloud(:needs_cloud_adaptation, EXCLUSION_NOTE)
    assert_raises(RuntimeError) { invalid.exclude_from_cloud(:requires_local_server, EXCLUSION_NOTE) }
    assert_raises(RuntimeError) { invalid.define_method(:helper) { nil } }

    dangling = Class.new(Test) #: singleton(Test)
    @test_classes << dangling
    dangling.exclude_from_cloud(:needs_cloud_adaptation, EXCLUSION_NOTE)
    assert_raises(RuntimeError) { dangling.runnable_methods }
  end
end
