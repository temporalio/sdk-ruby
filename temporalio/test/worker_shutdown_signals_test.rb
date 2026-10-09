# frozen_string_literal: true

require 'open3'
require 'temporalio/worker'
require 'test'

class WorkerShutdownSignalsTest < Test
  def test_shutdown_signals_drain_activity
    %w[INT TERM].product(%w[run run_all]).each do |signal, method|
      output = run_signal_subprocess(<<~RUBY, signal:, server: true)
        class DrainActivity < Temporalio::Activity::Definition
          def execute
            context = Temporalio::Activity::Context.current
            puts 'READY'
            context.worker_shutdown_cancellation.wait
            raise 'Activity canceled during grace period' if context.cancellation.canceled?
            puts 'RELEASE_ACTIVITY'
            raise 'Missing release' unless $stdin.gets
            'finished'
          ensure
            puts 'ACTIVITY_CLEANUP'
          end
        end

        client = Test::TestEnvironment.instance.client
        worker = Temporalio::Worker.new(
          client:,
          task_queue: SecureRandom.uuid,
          activities: [DrainActivity],
          graceful_shutdown_period: 30
        )
        previous_handlers = %w[INT TERM].to_h { |name| [name, proc {}] }
        previous_handlers.each { |name, handler| Signal.trap(name, handler) }
        handle = client.start_activity(
          DrainActivity,
          id: SecureRandom.uuid,
          task_queue: worker.task_queue,
          start_to_close_timeout: 60,
          retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
        )
        if #{method == 'run'}
          worker.run(shutdown_signals: ['SIGINT', 'SIGTERM'])
        else
          Temporalio::Worker.run_all(worker, shutdown_signals: ['SIGINT', 'SIGTERM'])
        end
        raise 'Activity did not finish' unless handle.result == 'finished'
        previous_handlers.each do |name, handler|
          raise 'Previous handler not restored' unless Signal.trap(name, 'IGNORE').equal?(handler)
        end
        puts 'WORKER_STOPPED'
      RUBY
      assert_includes output, "RELEASE_ACTIVITY\n", "#{method}: SIG#{signal} did not start shutdown"
      assert_includes output, "ACTIVITY_CLEANUP\n"
      assert_includes output, "WORKER_STOPPED\n"
    end
  end

  def test_shutdown_signals_are_opt_in
    ['', 'shutdown_signals: []', "shutdown_signals: ['SIGINT']"].each do |options|
      output = run_signal_subprocess(<<~RUBY, signal: 'TERM', server: true)
        received = Queue.new
        handler = proc { received.push(nil) }
        Signal.trap('TERM', handler)
        Thread.new do
          received.pop
          puts 'RELEASE_ACTIVITY'
        end

        class OptInActivity < Temporalio::Activity::Definition
          def execute
            puts 'READY'
            raise 'Missing release' unless $stdin.gets
            if Temporalio::Activity::Context.current.worker_shutdown_cancellation.canceled?
              raise 'Unconfigured SIGTERM initiated shutdown'
            end
            'finished'
          end
        end

        client = Test::TestEnvironment.instance.client
        worker = Temporalio::Worker.new(client:, task_queue: SecureRandom.uuid, activities: [OptInActivity])
        handle = client.start_activity(
          OptInActivity,
          id: SecureRandom.uuid,
          task_queue: worker.task_queue,
          start_to_close_timeout: 60
        )
        worker.run(#{options}) { raise 'Activity did not finish' unless handle.result == 'finished' }
        raise 'Application handler changed' unless Signal.trap('TERM', 'IGNORE').equal?(handler)
        puts 'WORKER_STOPPED'
      RUBY
      assert_includes output, "WORKER_STOPPED\n"
    end
  end

  def test_shutdown_signal_handlers_support_overlapping_runs
    output = run_signal_subprocess(<<~RUBY, signal: 'TERM')
      handlers = Temporalio::Internal::Worker::MultiRunner::ShutdownSignalHandlers
      received = Queue.new
      original = proc { received.push(nil) }
      Signal.trap('TERM', original)
      first_queue = Queue.new
      second_queue = Queue.new
      first = handlers.new(['TERM', 'SIGTERM', Signal.list.fetch('TERM')], first_queue)
      second = handlers.new(['SIGTERM'], second_queue)
      puts 'READY'
      Timeout.timeout(10) do
        first_queue.pop
        second_queue.pop
      end
      first.close
      first.close
      puts 'READY'
      Timeout.timeout(10) { second_queue.pop }
      raise 'Closed registration received signal' unless first_queue.empty?
      second.close
      Process.kill('TERM', Process.pid)
      Timeout.timeout(10) { received.pop }
      raise 'Original handler not restored' unless Signal.trap('TERM', 'IGNORE').equal?(original)
      puts 'HANDLERS_RESTORED'
    RUBY
    assert_includes output, "HANDLERS_RESTORED\n"
  end

  def test_shutdown_signal_handlers_preserve_application_replacement
    run_signal_subprocess(<<~RUBY)
      handlers = Temporalio::Internal::Worker::MultiRunner::ShutdownSignalHandlers.new(['TERM'], Queue.new)
      replacement = proc {}
      Signal.trap('TERM', replacement)
      handlers.close
      raise 'Application replacement lost' unless Signal.trap('TERM', 'IGNORE').equal?(replacement)
    RUBY
  end

  def test_shutdown_signal_handlers_restore_after_registration_failure
    run_signal_subprocess(<<~RUBY)
      original = proc {}
      Signal.trap('TERM', original)
      begin
        Temporalio::Internal::Worker::MultiRunner::ShutdownSignalHandlers.new(['TERM', 'INVALID'], Queue.new)
        raise 'Expected invalid signal error'
      rescue ArgumentError
        raise 'Original handler not restored' unless Signal.trap('TERM', 'IGNORE').equal?(original)
      end
    RUBY
  end

  def test_shutdown_signal_handlers_restore_after_block_failure
    run_signal_subprocess(<<~RUBY, server: true)
      class UnusedActivity < Temporalio::Activity::Definition
        def execute
        end
      end
      worker = Temporalio::Worker.new(
        client: Test::TestEnvironment.instance.client,
        task_queue: SecureRandom.uuid,
        activities: [UnusedActivity]
      )
      original = proc {}
      Signal.trap('TERM', original)
      begin
        worker.run(shutdown_signals: ['TERM']) { raise 'Intentional failure' }
        raise 'Expected block failure'
      rescue RuntimeError => e
        raise unless e.message == 'Intentional failure'
        raise 'Original handler not restored' unless Signal.trap('TERM', 'IGNORE').equal?(original)
      end
    RUBY
  end

  def test_shutdown_signal_handlers_restore_after_interrupted_registration
    run_signal_subprocess(<<~RUBY)
      require 'minitest/mock'
      original = proc {}
      Signal.trap('TERM', original)
      trap = Signal.method(:trap)
      interrupted_trap = proc do |signal, command|
        raise Interrupt if signal == Signal.list.fetch('INT')

        trap.call(signal, command)
      end
      Signal.stub(:trap, interrupted_trap) do
        begin
          Temporalio::Internal::Worker::MultiRunner::ShutdownSignalHandlers.new(['TERM', 'INT'], Queue.new)
          raise 'Expected Interrupt'
        rescue Interrupt
          raise 'Original handler not restored' unless Signal.trap('TERM', 'IGNORE').equal?(original)
        end
      end
    RUBY
  end

  private

  def run_signal_subprocess(code, signal: nil, server: false)
    skip('POSIX signals required') if Gem.win_platform?

    child_env = if server
                  {
                    'TEMPORAL_TEST_CLIENT_TARGET_HOST' => env.client.connection.target_host,
                    'TEMPORAL_TEST_CLIENT_TARGET_NAMESPACE' => env.client.namespace
                  }
                else
                  {}
                end
    output = +''
    Open3.popen2e(child_env, RbConfig.ruby, '-Ilib', '-Itest', '-rtest', '-rtemporalio/worker', '-e',
                  "$stdout.sync = true\n#{code}") do |stdin, stdout, wait_thread|
      Timeout.timeout(45) do
        stdout.each_line do |line|
          output << line
          Process.kill(signal, wait_thread.pid) if signal && line.chomp == 'READY'
          stdin.puts('finish') if line.chomp == 'RELEASE_ACTIVITY'
        end
        assert wait_thread.value.success?, output
      end
    ensure
      if wait_thread.alive?
        Process.kill('KILL', wait_thread.pid)
        wait_thread.join
      end
    end
    output
  end
end
