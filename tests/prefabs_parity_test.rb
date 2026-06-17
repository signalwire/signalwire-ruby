# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Cross-port parity tests for the prefab hooks/tools that match the Python
# reference (signalwire.prefabs.*). Each test drives the real method and
# asserts on real returned/stored values or registered-tool / SWML effects —
# no mocking of the unit under test.

require 'minitest/autorun'
require 'stringio'

require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/prefabs/concierge'
require_relative '../lib/signalwire/prefabs/faq_bot'
require_relative '../lib/signalwire/prefabs/info_gatherer'
require_relative '../lib/signalwire/prefabs/receptionist'
require_relative '../lib/signalwire/prefabs/survey'

# ---------------------------------------------------------------------------
# Concierge: check_availability / get_directions / on_summary
# ---------------------------------------------------------------------------
class ConciergeParityTest < Minitest::Test
  def concierge
    SignalWire::Prefabs::Concierge.new(
      venue_name: 'Grand Hotel',
      services: %w[spa restaurant],
      amenities: {
        'pool' => { 'hours' => '7 AM - 10 PM', 'location' => '2nd Floor' }
      }
    )
  end

  def test_check_availability_available_service
    result = concierge.check_availability(
      { 'service' => 'spa', 'date' => '2026-01-01', 'time' => '14:00' }, {}
    )
    # Confirms availability for a known service, echoing the date/time.
    assert_match(/spa is available on 2026-01-01 at 14:00/, result.response)
    assert_match(/make a reservation/, result.response)
  end

  def test_check_availability_unknown_service
    result = concierge.check_availability({ 'service' => 'golf' }, {})
    # Unknown service => apology that lists the real services offered.
    assert_match(/we don't offer golf at Grand Hotel/, result.response)
    assert_match(/spa, restaurant/, result.response)
  end

  def test_get_directions_to_amenity_with_location
    result = concierge.get_directions({ 'location' => 'pool' }, {})
    # Amenity with a "location" detail => directions naming that location.
    assert_match(/pool is located at 2nd Floor/, result.response)
    assert_match(/follow the signs to 2nd Floor/, result.response)
  end

  def test_get_directions_unknown_location
    result = concierge.get_directions({ 'location' => 'helipad' }, {})

    assert_match(/I don't have specific directions to helipad/, result.response)
    assert_match(/front desk/, result.response)
  end

  def test_check_availability_and_get_directions_are_registered_tools
    tools = concierge.tools

    assert_includes tools, 'check_availability'
    assert_includes tools, 'get_directions'
  end

  def test_on_summary_logs_structured_summary_as_json
    out = capture_stdout { concierge.on_summary({ 'topic' => 'spa booking', 'follow_up_needed' => true }) }
    # Structured (Hash) summary is emitted as pretty JSON, key fields present.
    assert_match(/Concierge interaction summary:/, out)
    assert_match(/"topic": "spa booking"/, out)
    assert_match(/"follow_up_needed": true/, out)
  end

  def test_on_summary_nil_is_noop
    out = capture_stdout { assert_nil concierge.on_summary(nil) }

    assert_empty out.strip
  end

  private

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end

# ---------------------------------------------------------------------------
# FAQBot: on_summary
# ---------------------------------------------------------------------------
class FaqBotParityTest < Minitest::Test
  def faq_bot
    SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'What is SignalWire?', 'answer' => 'A comms platform.' }]
    )
  end

  def test_on_summary_logs_structured_summary
    out = capture_stdout { faq_bot.on_summary({ 'question' => 'pricing?', 'answered_successfully' => false }) }

    assert_match(/FAQ interaction summary:/, out)
    assert_match(/"question": "pricing\?"/, out)
    assert_match(/"answered_successfully": false/, out)
  end

  def test_on_summary_logs_unstructured_summary
    out = capture_stdout { faq_bot.on_summary('freeform text') }

    assert_match(/FAQ interaction summary: freeform text/, out)
  end

  def test_on_summary_nil_is_noop
    out = capture_stdout { assert_nil faq_bot.on_summary(nil) }

    assert_empty out.strip
  end

  private

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end

# ---------------------------------------------------------------------------
# InfoGatherer: set_question_callback / on_swml_request
# ---------------------------------------------------------------------------
class InfoGathererParityTest < Minitest::Test
  def test_static_mode_on_swml_request_is_noop
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    # Static mode: questions already configured => no per-request rewrite.
    assert_nil agent.on_swml_request({}, nil, request: nil)
  end

  def test_dynamic_mode_without_callback_returns_fallback_questions
    agent = SignalWire::Prefabs::InfoGatherer.new
    result = agent.on_swml_request({}, nil, request: nil)
    gd = result['global_data']

    assert_equal 0, gd['question_index']
    assert_equal [], gd['answers']
    keys = gd['questions'].map { |q| q['key_name'] }

    assert_equal %w[name message], keys
  end

  def test_set_question_callback_is_invoked_by_on_swml_request
    agent = SignalWire::Prefabs::InfoGatherer.new
    seen = {}
    ret = agent.set_question_callback(lambda { |query, body, headers|
      seen[:query] = query
      seen[:body] = body
      seen[:headers] = headers
      [{ 'key_name' => 'dob', 'question_text' => 'Date of birth?' }]
    })
    # Setter returns self for chaining (idiomatic).
    assert_same agent, ret

    request = Struct.new(:query_params, :headers).new({ 'set' => 'medical' }, { 'X-Trace' => '1' })
    result = agent.on_swml_request({ 'call_id' => 'abc' }, '/swml', request: request)

    # Callback received the request-derived params.
    assert_equal({ 'set' => 'medical' }, seen[:query])
    assert_equal({ 'call_id' => 'abc' }, seen[:body])
    assert_equal({ 'X-Trace' => '1' }, seen[:headers])

    # Returned global_data carries the callback's questions.
    questions = result['global_data']['questions']

    assert_equal 1, questions.size
    assert_equal 'dob', questions.first['key_name']
    assert_equal 'Date of birth?', questions.first['question_text']
  end

  def test_on_swml_request_falls_back_when_callback_raises
    agent = SignalWire::Prefabs::InfoGatherer.new
    agent.set_question_callback(->(_q, _b, _h) { raise 'boom' })
    result = capture_stdout_value { agent.on_swml_request({}, nil, request: nil) }
    out, value = result

    assert_match(/Error in question callback: boom/, out)
    # On error => deterministic fallback questions.
    assert_equal(%w[name message], value['global_data']['questions'].map { |q| q['key_name'] })
  end

  private

  def capture_stdout_value
    old = $stdout
    $stdout = StringIO.new
    val = yield
    [$stdout.string, val]
  ensure
    $stdout = old
  end
end

# ---------------------------------------------------------------------------
# Receptionist: on_summary (no-op subclass hook)
# ---------------------------------------------------------------------------
class ReceptionistParityTest < Minitest::Test
  def receptionist
    SignalWire::Prefabs::Receptionist.new(
      departments: [{ 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }]
    )
  end

  def test_on_summary_is_noop_returning_nil
    out = capture_stdout { assert_nil receptionist.on_summary({ 'caller_name' => 'Ada' }) }
    # Base receptionist deliberately does not process the summary.
    assert_empty out.strip
  end

  def test_on_summary_accepts_optional_raw_data
    assert_nil receptionist.on_summary({ 'x' => 1 }, { 'raw' => true })
  end

  private

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end

# ---------------------------------------------------------------------------
# Survey: validate_response / log_response / on_summary
# ---------------------------------------------------------------------------
class SurveyParityTest < Minitest::Test
  def survey
    SignalWire::Prefabs::Survey.new(
      survey_name: 'CSAT',
      questions: [
        { 'id' => 'satisfaction', 'text' => 'How satisfied?', 'type' => 'rating', 'scale' => 5 },
        { 'id' => 'channel', 'text' => 'Which channel?', 'type' => 'multiple_choice', 'options' => %w[phone email] },
        { 'id' => 'recommend', 'text' => 'Recommend us?', 'type' => 'yes_no' },
        { 'id' => 'comments', 'text' => 'Anything else?', 'type' => 'open_ended', 'required' => true }
      ]
    )
  end

  def test_validate_rating_in_range_is_valid
    result = survey.validate_response({ 'question_id' => 'satisfaction', 'response' => '4' }, {})

    assert_match(/Response to 'satisfaction' is valid/, result.response)
  end

  def test_validate_rating_out_of_range_is_invalid
    result = survey.validate_response({ 'question_id' => 'satisfaction', 'response' => '9' }, {})

    assert_match(/Invalid rating\. Please provide a number between 1 and 5/, result.response)
  end

  def test_validate_rating_non_numeric_is_invalid
    result = survey.validate_response({ 'question_id' => 'satisfaction', 'response' => 'great' }, {})

    assert_match(/Invalid rating/, result.response)
  end

  def test_validate_multiple_choice_rejects_unlisted_option
    result = survey.validate_response({ 'question_id' => 'channel', 'response' => 'carrier pigeon' }, {})

    assert_match(/Invalid choice\. Please select one of: phone, email/, result.response)
  end

  def test_validate_multiple_choice_accepts_listed_option_case_insensitively
    result = survey.validate_response({ 'question_id' => 'channel', 'response' => 'PHONE' }, {})

    assert_match(/is valid/, result.response)
  end

  def test_validate_yes_no_rejects_other
    result = survey.validate_response({ 'question_id' => 'recommend', 'response' => 'maybe' }, {})

    assert_match(/Please answer with 'yes' or 'no'/, result.response)
  end

  def test_validate_open_ended_required_empty_is_invalid
    result = survey.validate_response({ 'question_id' => 'comments', 'response' => '   ' }, {})

    assert_match(/A response is required for this question/, result.response)
  end

  def test_validate_unknown_question_id
    result = survey.validate_response({ 'question_id' => 'nope', 'response' => 'x' }, {})

    assert_match(/Question with ID 'nope' not found/, result.response)
  end

  def test_log_response_acknowledges_by_question_text
    result = survey.log_response({ 'question_id' => 'satisfaction', 'response' => '5' }, {})
    # Acknowledgement names the question by its text (not its id).
    assert_match(/Response to 'How satisfied\?' has been recorded/, result.response)
  end

  def test_validate_and_log_response_are_registered_tools
    tools = survey.tools

    assert_includes tools, 'validate_response'
    assert_includes tools, 'log_response'
  end

  def test_on_summary_logs_structured_survey_results
    out = capture_stdout { survey.on_summary({ 'survey_name' => 'CSAT', 'completion_status' => 'complete' }) }

    assert_match(/Survey completed:/, out)
    assert_match(/"survey_name": "CSAT"/, out)
    assert_match(/"completion_status": "complete"/, out)
  end

  def test_on_summary_logs_unstructured_survey_results
    out = capture_stdout { survey.on_summary('partial') }

    assert_match(/Survey summary \(unstructured\): partial/, out)
  end

  private

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end
