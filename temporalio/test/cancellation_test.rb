# frozen_string_literal: true

require 'temporalio/cancellation'
require 'test_base'

class CancellationTest < TestBase
  also_run_all_tests_in_fiber

  def test_simple_cancellation
    # Create and confirm uncanceled state
    cancel, cancel_proc = Temporalio::Cancellation.new
    refute cancel.canceled?
    cancel.check!
    got_cancel1 = false
    cancel.add_cancel_callback { got_cancel1 = true }
    refute got_cancel1
    got_cancel_from_wait_queue = Queue.new
    run_in_background do
      cancel.wait
      got_cancel_from_wait_queue.push(true)
    end

    # Do the cancel and confirm state
    cancel_proc.call
    assert cancel.canceled?
    assert_raises(Temporalio::Error::CanceledError) { cancel.check! }
    assert got_cancel1
    got_cancel2 = false
    cancel.add_cancel_callback { got_cancel2 = true }
    assert got_cancel2
    assert got_cancel_from_wait_queue.pop
    cancel.wait
  end

  def test_parent_cancellation
    cancel_grandparent, cancel_grandparent_proc = Temporalio::Cancellation.new
    cancel_parent = Temporalio::Cancellation.new(cancel_grandparent)
    cancel = Temporalio::Cancellation.new(cancel_parent)

    refute cancel_grandparent.canceled?
    refute cancel_parent.canceled?
    refute cancel.canceled?

    cancel_grandparent_proc.call
    assert cancel_grandparent.canceled?
    assert cancel_parent.canceled?
    assert cancel.canceled?
  end

  def test_shielding
    # Create a cancellation, shield a couple of levels deep and confirm
    cancel, cancel_proc = Temporalio::Cancellation.new
    cancel.shield do
      cancel.shield do
        cancel_proc.call(reason: 'some reason')
        refute cancel.canceled?
      end
      refute cancel.canceled?
    end
    assert cancel.canceled?
    assert_equal 'some reason', cancel.canceled_reason
  end
end
