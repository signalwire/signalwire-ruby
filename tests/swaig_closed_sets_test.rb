# frozen_string_literal: true

# Single-source-of-truth tests for the SWAIG closed-set vocabularies.
#
# These cover the named constants extracted in
# lib/signalwire/swaig/function_result.rb (RecordFormat, RecordDirection,
# TapDirection, Codec). For each set we prove three things with REAL
# behaviour (no mocks — we drive the actual record_call / tap methods and
# inspect their serialised SWML):
#
#   (a) each constant's value IS its wire string;
#   (b) the named constant and the bare string produce a BYTE-IDENTICAL
#       record_call / tap action (same to_h);
#   (c) the constant set is EXACTLY what the method validates — every
#       member is accepted, and an out-of-set value is rejected by the same
#       inline validation that references the constant set (single source of
#       truth: ALL is the literal object the validator checks against).
#
# RecordDirection and TapDirection both name the channels speak/listen/both
# (the SWML record_call and tap verbs' enums), but each verb is validated
# against its OWN set; 'hear' is in neither (it produced SWML the platform
# rejects).

require 'minitest/autorun'
require_relative '../lib/signalwire/swaig/function_result'

# Shared constants + SWML accessors for the SWAIG closed-set tests, included
# by both the record-vocabulary and tap-vocabulary test classes below.
module SwaigClosedSetHelpers
  FR = SignalWire::Swaig::FunctionResult
  RecordFormat    = SignalWire::Swaig::RecordFormat
  RecordDirection = SignalWire::Swaig::RecordDirection
  TapDirection    = SignalWire::Swaig::TapDirection
  Codec           = SignalWire::Swaig::Codec

  # Pull the record_call params hash out of the serialised SWML document.
  def record_params(result)
    result.to_h['action'].first['SWML']['sections']['main'][0]['record_call']
  end

  # Pull the tap params hash out of the serialised SWML document.
  def tap_params(result)
    result.to_h['action'].first['SWML']['sections']['main'][0]['tap']
  end

  # For each {constant => literal} pair, drive record_call once with the named
  # constant and once with the bare literal and assert byte-identical SWML and
  # that the serialised param equals the literal.
  def assert_record_const_matches_string(mapping, param)
    mapping.each do |const_val, literal|
      via_const  = FR.new.record_call(param => const_val)
      via_string = FR.new.record_call(param => literal)

      assert_equal via_string.to_h, via_const.to_h,
                   "record_call #{param} #{literal.inspect}: constant vs string diverged"
      assert_equal literal, record_params(via_const)[param.to_s]
    end
  end

  # As above, for tap's kwargs (direction / codec). tap requires a URI arg.
  def assert_tap_const_matches_string(mapping, param)
    mapping.each do |const_val, literal|
      via_const  = FR.new.tap('rtp://10.0.0.1:9000', param => const_val)
      via_string = FR.new.tap('rtp://10.0.0.1:9000', param => literal)

      assert_equal via_string.to_h, via_const.to_h,
                   "tap #{param} #{literal.inspect}: constant vs string diverged"
    end
  end
end

class SwaigClosedSetsTest < Minitest::Test
  include SwaigClosedSetHelpers

  # ------------------------------------------------------------------
  # RecordFormat {wav, mp3, mp4}
  # ------------------------------------------------------------------

  # (a) constant value IS the wire string
  def test_record_format_constants_are_wire_strings
    assert_equal 'wav', RecordFormat::WAV
    assert_equal 'mp3', RecordFormat::MP3
    assert_equal 'mp4', RecordFormat::MP4
    assert_equal %w[wav mp3 mp4], RecordFormat::ALL
    assert_predicate RecordFormat::ALL, :frozen?
  end

  # (b) constant and bare string => byte-identical action.
  # Each pair drives record_call with the NAMED constant and again with the
  # bare literal, then asserts identical serialised SWML.
  def test_record_format_constant_matches_bare_string
    assert_record_const_matches_string(
      { RecordFormat::WAV => 'wav', RecordFormat::MP3 => 'mp3', RecordFormat::MP4 => 'mp4' },
      :format
    )
  end

  # (c) the constant set is EXACTLY what record_call validates
  def test_record_format_set_is_exactly_validated
    # every member accepted (no raise)
    RecordFormat::ALL.each do |fmt|
      FR.new.record_call(format: fmt)
    end
    # an out-of-set value is rejected by the same validation
    refute_includes RecordFormat::ALL, 'ogg'
    err = assert_raises(ArgumentError) { FR.new.record_call(format: 'ogg') }
    assert_match(/format must be/, err.message)
  end

  # ------------------------------------------------------------------
  # RecordDirection {speak, listen, both}
  # ------------------------------------------------------------------

  def test_record_direction_constants_are_wire_strings
    assert_equal 'speak',  RecordDirection::SPEAK
    assert_equal 'listen', RecordDirection::LISTEN
    assert_equal 'both',   RecordDirection::BOTH
    assert_equal %w[speak listen both], RecordDirection::ALL
    assert_predicate RecordDirection::ALL, :frozen?
  end

  def test_record_direction_constant_matches_bare_string
    assert_record_const_matches_string(
      { RecordDirection::SPEAK => 'speak', RecordDirection::LISTEN => 'listen',
        RecordDirection::BOTH => 'both' },
      :direction
    )
  end

  def test_record_direction_set_is_exactly_validated
    RecordDirection::ALL.each { |dir| FR.new.record_call(direction: dir) }

    refute_includes RecordDirection::ALL, 'hear' # not a SWML direction
    err = assert_raises(ArgumentError) { FR.new.record_call(direction: 'hear') }
    assert_match(/direction must be/, err.message)
  end
end

# Tap-verb closed-set vocabularies (TapDirection, Codec) + the 3-vocabulary
# trap. Split from SwaigClosedSetsTest to keep each class within budget.
class SwaigTapClosedSetsTest < Minitest::Test
  include SwaigClosedSetHelpers

  # ------------------------------------------------------------------
  # TapDirection {speak, listen, both} — the SWML tap verb's enum
  # ------------------------------------------------------------------

  def test_tap_direction_constants_are_wire_strings
    assert_equal 'speak',  TapDirection::SPEAK
    assert_equal 'listen', TapDirection::LISTEN
    assert_equal 'both',   TapDirection::BOTH
    assert_equal %w[speak listen both], TapDirection::ALL
    assert_predicate TapDirection::ALL, :frozen?
  end

  def test_tap_direction_constant_matches_bare_string
    assert_tap_const_matches_string(
      { TapDirection::SPEAK => 'speak', TapDirection::LISTEN => 'listen',
        TapDirection::BOTH => 'both' },
      :direction
    )
  end

  def test_tap_direction_set_is_exactly_validated
    TapDirection::ALL.each { |dir| FR.new.tap('rtp://x', direction: dir) }

    refute_includes TapDirection::ALL, 'hear' # not a tap direction
    err = assert_raises(ArgumentError) { FR.new.tap('rtp://x', direction: 'hear') }
    assert_equal "direction must be 'speak', 'listen', or 'both'", err.message
  end

  # Parity: python fix 2d0c6c5 — direction is always sent: the verb's own
  # default is "speak", not this helper's "both".
  def test_tap_direction_is_always_emitted
    tap = FR.new.tap('rtp://x').action.first['SWML']['sections']['main'][0]['tap']

    assert_equal 'both', tap['direction']
  end

  # ------------------------------------------------------------------
  # Codec {PCMU, PCMA}  (SWAIG tap codec only — NOT the RELAY superset)
  # ------------------------------------------------------------------

  def test_codec_constants_are_wire_strings
    assert_equal 'PCMU', Codec::PCMU
    assert_equal 'PCMA', Codec::PCMA
    assert_equal %w[PCMU PCMA], Codec::ALL
    assert_predicate Codec::ALL, :frozen?
  end

  def test_codec_constant_matches_bare_string
    assert_tap_const_matches_string(
      { Codec::PCMU => 'PCMU', Codec::PCMA => 'PCMA' },
      :codec
    )
  end

  def test_codec_set_is_exactly_validated
    Codec::ALL.each { |codec| FR.new.tap('rtp://x', codec: codec) }
    # OPUS is in the RELAY device-codec superset but NOT the SWAIG tap set.
    refute_includes Codec::ALL, 'OPUS'
    err = assert_raises(ArgumentError) { FR.new.tap('rtp://x', codec: 'OPUS') }
    assert_match(/codec must be/, err.message)
  end

  # ------------------------------------------------------------------
  # RecordDirection and TapDirection are SEPARATE sets (one per verb).
  # ------------------------------------------------------------------

  def test_record_and_tap_direction_are_distinct_sets
    # Both verbs name the channels speak/listen/both; neither accepts 'hear'.
    assert_includes RecordDirection::ALL, 'listen'
    assert_includes TapDirection::ALL, 'listen'
    refute_includes RecordDirection::ALL, 'hear'
    refute_includes TapDirection::ALL, 'hear'
    # Each verb validates against its OWN frozen set.
    refute_same RecordDirection::ALL, TapDirection::ALL
  end
end
