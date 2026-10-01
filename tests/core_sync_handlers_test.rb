# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# How the endpoints call synchronous user code: directly on the request's own
# thread (requests run concurrently), or — with SWML_SYNC_HANDLERS_INLINE —
# one call at a time. Parity: signalwire-python core/_sync_handlers.py.
class CoreSyncHandlersTest < Minitest::Test
  SH = SignalWire::Core::SyncHandlers

  def setup
    @saved = ENV.fetch('SWML_SYNC_HANDLERS_INLINE', nil)
  end

  def teardown
    @saved.nil? ? ENV.delete('SWML_SYNC_HANDLERS_INLINE') : ENV['SWML_SYNC_HANDLERS_INLINE'] = @saved
  end

  def test_inline_reads_the_environment
    ENV.delete('SWML_SYNC_HANDLERS_INLINE')

    refute SH.sync_handlers_inline
    %w[1 true YES].each do |v|
      ENV['SWML_SYNC_HANDLERS_INLINE'] = v

      assert SH.sync_handlers_inline, "#{v} must turn inline mode on"
    end
    ENV['SWML_SYNC_HANDLERS_INLINE'] = '0'

    refute SH.sync_handlers_inline
  end

  def test_run_sync_handler_returns_the_result_and_passes_arguments
    assert_equal [1, 2, 3], SH.run_sync_handler(->(a, b, c:) { [a, b, c] }, 1, 2, c: 3)
  end

  def test_exceptions_propagate_unchanged
    assert_raises(KeyError) { SH.run_sync_handler(-> { raise KeyError, 'x' }) }
  end

  def test_inline_mode_serializes_concurrent_calls
    ENV['SWML_SYNC_HANDLERS_INLINE'] = '1'

    assert_equal 1, peak_concurrency(4)
  end

  def test_default_mode_runs_concurrent_calls_concurrently
    ENV.delete('SWML_SYNC_HANDLERS_INLINE')

    assert_operator peak_concurrency(4), :>, 1
  end

  def test_inline_mode_is_reentrant
    ENV['SWML_SYNC_HANDLERS_INLINE'] = '1'

    assert_equal :inner, SH.run_sync_handler(-> { SH.run_sync_handler(-> { :inner }) })
  end

  def test_ruby_callables_are_not_async
    refute SH.is_async_callable(-> {})
    refute SH.is_async_callable(method(:puts))
  end

  private

  # Run +threads+ overlapping calls through run_sync_handler; return how many
  # were ever inside the callable at once.
  def peak_concurrency(threads)
    state = { active: 0, peak: 0 }
    lock = Mutex.new
    work = lambda do
      lock.synchronize { state[:peak] = [state[:peak], state[:active] += 1].max }
      sleep 0.05
      lock.synchronize { state[:active] -= 1 }
    end
    Array.new(threads) { Thread.new { SH.run_sync_handler(work) } }.each(&:join)
    state[:peak]
  end
end
