# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/core/logging_config'

# strip_control_chars takes the event hash alone or processor-style
# (logger, method_name, event) — the LAST positional argument is the event.
# Parity: signalwire-python core/logging_config.py strip_control_chars(*args).
class LoggingStripControlCharsTest < Minitest::Test
  LC = SignalWire::Core::LoggingConfig

  def test_event_hash_alone
    event = { 'event' => "hi\u0007there", 'n' => 3 }

    assert_same event, LC.strip_control_chars(event)
    assert_equal({ 'event' => 'hithere', 'n' => 3 }, event)
  end

  def test_processor_call_uses_the_last_argument
    event = { 'msg' => "a\u001Bb\tc" }

    assert_equal({ 'msg' => "ab\tc" }, LC.strip_control_chars(:logger, 'info', event))
  end

  def test_no_arguments_is_an_error
    assert_raises(ArgumentError) { LC.strip_control_chars }
  end
end
