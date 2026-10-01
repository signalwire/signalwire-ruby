# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/core/capabilities'

# Reading what a client declares it can render. The rule pinned here is that
# ABSENCE MEANS NO: every path resolves malformed or missing data to "not
# declared". Parity: signalwire-python tests/unit/core/test_capabilities.py.
class CoreCapabilitiesTest < Minitest::Test
  C = SignalWire::Core::Capabilities

  BODY = {
    'vars' => {
      'userVariables' => {
        'capabilities' => { 'display_content' => true, 'transcript' => true, 'chat_handoff' => false },
        'metadata' => { 'widget' => { 'opened_at' => '2026-01-01T00:00:00Z' } }
      }
    }
  }.freeze

  JUNK_USER_VARIABLES = [nil, {}, 'nonsense', 42, { 'vars' => nil }, { 'vars' => {} },
                         { 'vars' => { 'userVariables' => nil } },
                         { 'vars' => { 'userVariables' => 'not a dict' } }].freeze

  JUNK_CAPABILITIES = [nil, {}, 'nonsense', 42,
                       { 'vars' => { 'userVariables' => { 'capabilities' => 'not a dict' } } },
                       { 'vars' => { 'userVariables' => { 'capabilities' => nil } } },
                       { 'vars' => { 'userVariables' => {} } }].freeze

  def test_extracts_from_the_nested_shape
    assert_includes C.user_variables(BODY), 'capabilities'
  end

  def test_missing_levels_yield_an_empty_hash
    JUNK_USER_VARIABLES.each { |junk| assert_equal({}, C.user_variables(junk), junk.inspect) }
  end

  def test_only_truthy_names_are_returned
    assert_equal Set['display_content', 'transcript'], C.declared_capabilities(BODY)
  end

  def test_false_is_not_a_declaration
    refute_includes C.declared_capabilities(BODY), 'chat_handoff'
  end

  def test_accepts_already_extracted_user_variables
    assert_equal Set['a'], C.declared_capabilities({ 'capabilities' => { 'a' => true } })
  end

  def test_a_name_this_sdk_has_never_heard_of_still_passes_through
    assert C.has_capability({ 'capabilities' => { 'future_thing' => true } }, 'future_thing')
  end

  def test_absence_and_malformation_both_mean_no
    JUNK_CAPABILITIES.each do |junk|
      assert_empty C.declared_capabilities(junk), junk.inspect
      refute C.has_capability(junk, 'display_content')
    end
  end

  def test_json_falsy_values_are_not_declarations
    caps = C.declared_capabilities({ 'capabilities' => { 'z' => 0, 'e' => '', 'a' => [], 'y' => 1 } })

    assert_equal Set['y'], caps
  end

  def test_has_capability
    assert C.has_capability(BODY, 'display_content')
    refute C.has_capability(BODY, 'chat_handoff')
    refute C.has_capability(BODY, 'telepathy')
  end

  def test_declared_set_is_frozen
    assert_predicate C.declared_capabilities(BODY), :frozen?
  end
end
