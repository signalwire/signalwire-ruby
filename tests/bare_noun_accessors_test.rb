# frozen_string_literal: true

# D9-ruby: bare-noun accessors are the idiomatic Ruby surface layered over the
# reference-audited get_/set_/has_ names (which stay as the deprecating aliases).
# This pins that each bare-noun form is present AND behaves identically to its
# get_/set_/has_ counterpart, so "named once (parity), spelled twice (idiom)"
# is a proven fact, not a claim.

require 'minitest/autorun'
require 'signalwire'

class BareNounAccessorsTest < Minitest::Test
  def agent
    @agent ||= SignalWire::AgentBase.new(name: 'bare', route: '/x')
  end

  # Readers: the bare noun returns the same value as get_<name>.
  def test_app_reader_matches_get_app
    assert_same agent.get_app, agent.app
  end

  def test_full_url_reader_matches_get_full_url
    assert_equal agent.get_full_url, agent.full_url
  end

  def test_basic_auth_credentials_reader_matches_getter
    assert_equal agent.get_basic_auth_credentials, agent.basic_auth_credentials
  end

  # Predicate: skill? mirrors has_skill?.
  def test_skill_predicate_matches_has_skill
    assert_equal agent.has_skill?('datetime'), agent.skill?('datetime')
    refute agent.skill?('definitely_not_a_skill')
  end

  # Writer: multilingual= drives set_multilingual (same effect). Same agent name
  # so only the multilingual assignment path differs between the two.
  def test_multilingual_writer_drives_setter
    a1 = SignalWire::AgentBase.new(name: 'same')
    a2 = SignalWire::AgentBase.new(name: 'same')
    config = { 'enabled' => true, 'languages' => [] }
    a1.set_multilingual(config)
    a2.multilingual = config

    assert_equal a1.render_swml, a2.render_swml
  end

  # FunctionResult's set_* writers already have their bare-noun `X=` forms.
  def test_function_result_writers_present
    fr = SignalWire::Swaig::FunctionResult.new('hi')

    %i[response= post_process= metadata= end_of_speech_timeout= speech_event_timeout=].each do |m|
      assert_respond_to fr, m
    end
  end
end
