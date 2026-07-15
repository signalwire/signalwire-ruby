# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require_relative '../../lib/signalwire/skills/builtin/web_search'

class WebSearchSkillDetailedTest < Minitest::Test
  include TestHelper::Helpers

  SEARCH_ENV_VARS = %w[GOOGLE_SEARCH_API_KEY GOOGLE_SEARCH_ENGINE_ID].freeze

  # Each input path of the old test_setup_requires_api_key_and_engine_id is
  # now its own method so a failure pinpoints which path broke.
  def test_setup_fails_without_any_params
    without_env_vars(SEARCH_ENV_VARS) do
      refute build_skill('web_search').setup,
             'web_search must fail setup with neither api_key nor engine id'
    end
  end

  def test_setup_fails_with_api_key_but_no_engine_id
    without_env_vars(SEARCH_ENV_VARS) do
      refute build_skill('web_search', 'api_key' => 'key').setup,
             'web_search must fail setup without a search_engine_id'
    end
  end

  def test_setup_succeeds_with_api_key_and_engine_id
    without_env_vars(SEARCH_ENV_VARS) do
      assert build_skill('web_search', 'api_key' => 'key', 'search_engine_id' => 'cx').setup,
             'web_search must set up with both api_key and search_engine_id'
    end
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'key', 'search_engine_id' => 'cx' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'web_search', tools[0][:name]
  end

  def test_supports_multiple_instances
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })

    assert_predicate skill, :supports_multiple_instances?
  end

  def test_instance_key_includes_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx', 'tool_name' => 'custom_search' })
    skill.setup

    assert_includes skill.instance_key, 'custom_search'
  end

  def test_version
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({})

    assert_equal '2.0.0', skill.version
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })
    skill.setup
    data = skill.get_global_data

    assert_equal true, data['web_search_enabled']
  end
end

# Ports Python 8aad242: response_prefix / response_postfix wrap a
# successful (non-empty) search result. Empty search results, empty
# query, and error paths do NOT receive the prefix/postfix.
#
# These exercise the wrapping logic via the snippets_only fast path
# (Python 51101da). snippets_only short-circuits before any page fetch,
# so it gives a deterministic, non-empty, prefix/postfix-wrapped body
# without needing the mock HTTP server — exactly what the wrapping tests
# need. (The default path now scrapes pages; the snippet-fallback header
# "Snippet-only results for ..." is what both the fast path and the
# deadline fallback emit, and both go through wrap_response.)
class WebSearchSkillResponsePrefixPostfixTest < Minitest::Test
  def make_skill(params = {})
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx',
                           'snippets_only' => true }.merge(params))
    skill.setup
    skill
  end

  # Stub google_search to return a fixed result list; this avoids needing
  # the mock HTTP server in a unit test of the wrapping logic.
  def stub_search(skill, results)
    skill.singleton_class.send(:define_method, :google_search) do |_q, _n|
      results
    end
  end

  def test_response_prefix_prepended_on_success
    skill = make_skill('response_prefix' => 'NOTE-FROM-WEB-SEARCH')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s

    assert_match(/NOTE-FROM-WEB-SEARCH/, body)
    assert_match(/Snippet-only results for 'cats'/, body)
  end

  def test_response_postfix_appended_on_success
    skill = make_skill('response_postfix' => 'CITE-THE-URL-PLEASE')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s

    assert_match(/CITE-THE-URL-PLEASE/, body)
  end

  def test_response_prefix_and_postfix_both_applied
    skill = make_skill('response_prefix' => 'PRE-MARK', 'response_postfix' => 'POST-MARK')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s

    assert_match(/PRE-MARK/, body)
    assert_match(/POST-MARK/, body)
  end

  def test_response_prefix_not_applied_when_no_results
    skill = make_skill('response_prefix' => 'SHOULD-NOT-APPEAR',
                       'no_results_message' => 'nothing found')
    stub_search(skill, [])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s

    refute_match(/SHOULD-NOT-APPEAR/, body)
    assert_match(/nothing found/, body)
  end

  def test_empty_prefix_and_postfix_leave_response_unchanged
    skill = make_skill
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    # No spurious leading/trailing markers; only the canonical
    # "Snippet-only results for 'cats' ..." header is present.
    assert body.start_with?("Snippet-only results for 'cats'"),
           "expected body to start with the canonical header, got: #{body[0, 80].inspect}"
  end

  def test_parameter_schema_advertises_prefix_postfix
    skill = make_skill
    schema = skill.get_parameter_schema

    assert schema.key?('response_prefix')
    assert schema.key?('response_postfix')
  end
end

# Latency-control contract (Python 51101da + 295745b):
#   - snippets_only skips page scraping entirely.
#   - overall_deadline truncates in-flight scrapes and falls back to a
#     non-empty snippet response (not the empty "no results" message) —
#     even when every page fetch sleeps far past the deadline.
#   - per_page_timeout bounds a single page fetch (Net::HTTP timeouts).
#   - all six params advertised in the schema with the right defaults.
#
# Scrape latency is simulated by stubbing extract_text_from_url to sleep,
# so the deadline path is deterministic and needs no real HTTP / mock
# server. (The deadline is wall-clock-enforced in handle_search, so a
# sleeping scrape exercises it faithfully.)
# Shared skill factory + scrape stubs + CSE fixtures for the latency-control
# web-search tests.
module WebSearchLatencyHelpers
  CSE_ITEMS = [
    { 'title' => 'Slow One', 'url' => 'https://slow-one.example.com/p',
      'snippet' => 'First CSE snippet about widgets.' },
    { 'title' => 'Slow Two', 'url' => 'https://slow-two.example.com/p', 'snippet' => 'Second CSE snippet about widgets.' }
  ].freeze

  # Three items, so a sequential run can dispatch some-but-not-all before
  # the deadline cuts it off.
  CSE_ITEMS3 = [
    { 'title' => 'One',   'url' => 'https://one.example.com/p',   'snippet' => 'First snippet about widgets.' },
    { 'title' => 'Two',   'url' => 'https://two.example.com/p',   'snippet' => 'Second snippet about widgets.' },
    { 'title' => 'Three', 'url' => 'https://three.example.com/p', 'snippet' => 'Third snippet about widgets.' }
  ].freeze

  def make_skill(params = {})
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx',
                           'min_quality_score' => 0.0 }.merge(params))
    skill.setup
    skill
  end

  def stub_search(skill, results)
    skill.singleton_class.send(:define_method, :google_search) do |_q, _n|
      results
    end
  end

  # Make every page fetch sleep `seconds` (simulating a hung site), and
  # count how many fetches were attempted so a test can prove scraping was
  # (or was not) reached.
  def stub_extract_sleep(skill, seconds, counter)
    skill.singleton_class.send(:define_method, :extract_text_from_url) do |_url|
      counter[:n] += 1
      sleep(seconds)
      'quality content about widgets ' * 50
    end
  end

  # Run handle_search('widgets') against +skill+, returning [elapsed, body].
  def run_search_with_timing(skill)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = skill.send(:handle_search, { 'query' => 'widgets' }, nil)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    [elapsed, result.response.to_s]
  end

  # Assert +body+ is the snippet-only fallback for +query+ (not the empty
  # "no quality results" message), optionally containing +snippet+.
  def assert_snippet_fallback(body, query, snippet: nil)
    assert_match(/Snippet-only results for '#{query}'/, body)
    refute_match(/couldn't find quality results/, body)
    assert_match(/#{Regexp.escape(snippet)}/, body) if snippet
  end

  # A fake Net::HTTP that records the open/read timeouts set on it into
  # +captured+ and raises on request (so no socket opens).
  def fake_timeout_http(captured)
    fake = Object.new
    fake.define_singleton_method(:use_ssl=) { |_v| }
    fake.define_singleton_method(:open_timeout=) { |v| captured[:open] = v }
    fake.define_singleton_method(:read_timeout=) { |v| captured[:read] = v }
    fake.define_singleton_method(:request) { |_req| raise 'no network in test' }
    fake
  end

  # Stub Net::HTTP.new for the block with #fake_timeout_http and return the
  # captured {open:, read:} timeouts.
  def capture_http_timeouts
    captured = {}
    fake_http = fake_timeout_http(captured)
    original_new = Net::HTTP.method(:new)
    Net::HTTP.singleton_class.send(:define_method, :new) { |*_a, **_k| fake_http }
    begin
      yield
    ensure
      Net::HTTP.singleton_class.send(:define_method, :new, original_new)
    end
    captured
  end
end

class WebSearchSkillLatencySchemaTest < Minitest::Test
  include WebSearchLatencyHelpers

  # ---- schema --------------------------------------------------------

  def test_schema_advertises_all_six_latency_and_response_params
    schema = make_skill.get_parameter_schema

    %w[response_prefix response_postfix per_page_timeout
       overall_deadline parallel_scrape snippets_only].each do |key|
      assert schema.key?(key), "setup() reads #{key} but schema omits it"
    end
  end

  # Assert a schema param advertises the expected default + type.
  def assert_schema_param(schema, key, default:, type:)
    assert_equal type, schema[key]['type']
    assert_in_delta(default, schema[key]['default']) if type == 'number'
    assert_equal default, schema[key]['default'] if type == 'boolean'
  end

  def test_schema_latency_defaults
    schema = make_skill.get_parameter_schema

    assert_schema_param(schema, 'per_page_timeout', default: 2.0, type: 'number')
    assert_schema_param(schema, 'overall_deadline', default: 10.0, type: 'number')
    assert_schema_param(schema, 'parallel_scrape', default: true, type: 'boolean')
    assert_schema_param(schema, 'snippets_only', default: false, type: 'boolean')
    assert_equal false, schema['per_page_timeout']['required']
    assert_equal false, schema['overall_deadline']['required']
  end
end

class WebSearchSkillLatencyControlTest < Minitest::Test
  include WebSearchLatencyHelpers

  # ---- defaults applied in setup ------------------------------------

  def test_latency_defaults_applied_in_setup
    skill = make_skill

    assert_in_delta 2.0,  skill.instance_variable_get(:@per_page_timeout), 1e-9
    assert_in_delta 10.0, skill.instance_variable_get(:@overall_deadline), 1e-9
    assert_equal true,  skill.instance_variable_get(:@parallel_scrape)
    assert_equal false, skill.instance_variable_get(:@snippets_only)
  end

  def test_parallel_scrape_false_is_honored_not_defaulted
    # Regression: get_param's `||` would turn a literal false into the
    # default true. bool_param must preserve false.
    skill = make_skill('parallel_scrape' => false)

    assert_equal false, skill.instance_variable_get(:@parallel_scrape)
  end

  def test_snippets_only_true_is_honored
    skill = make_skill('snippets_only' => true)

    assert_equal true, skill.instance_variable_get(:@snippets_only)
  end

  def test_per_page_timeout_overall_deadline_are_read
    skill = make_skill('per_page_timeout' => 3.5, 'overall_deadline' => 12.0)

    assert_in_delta 3.5,  skill.instance_variable_get(:@per_page_timeout), 1e-9
    assert_in_delta 12.0, skill.instance_variable_get(:@overall_deadline), 1e-9
  end

  # ---- snippets_only fast path --------------------------------------

  def test_snippets_only_skips_scraping
    counter = { n: 0 }
    skill = make_skill('snippets_only' => true)
    stub_search(skill, CSE_ITEMS)
    # If a scrape were attempted it would sleep 30s and fail the test's
    # wall-clock budget; proving the fast path never touches it.
    stub_extract_sleep(skill, 30, counter)

    elapsed, body = run_search_with_timing(skill)

    assert_equal 0, counter[:n], 'snippets_only must not scrape any page'
    assert_match(/Snippet-only results for 'widgets'/, body)
    assert_match(/First CSE snippet about widgets\./, body)
    assert_operator elapsed, :<, 1.0, 'snippets_only should be sub-second'
  end

  # ---- overall_deadline contract (parallel) -------------------------

  def test_overall_deadline_truncates_and_falls_back_to_snippets_parallel
    counter = { n: 0 }
    skill = make_skill('overall_deadline' => 1.0, 'parallel_scrape' => true,
                       'per_page_timeout' => 30.0)
    stub_search(skill, CSE_ITEMS)
    # Each scrape sleeps 30s — far past the 1.0s deadline. The handler MUST
    # abandon them and return the snippet fallback.
    stub_extract_sleep(skill, 30, counter)

    elapsed, body = run_search_with_timing(skill)

    # CONTRACT: returns within ~deadline + slack despite the hung scrapes.
    assert_operator elapsed, :>=, 0.9, 'should wait out roughly the deadline'
    assert_operator elapsed, :<, 5.0, "should not block on the 30s scrapes; took #{elapsed}s"
    # CONTRACT: non-empty snippet fallback, NOT the empty no-results msg.
    assert_snippet_fallback(body, 'widgets', snippet: 'First CSE snippet about widgets.')
    refute_empty body
  end

  # ---- overall_deadline contract (sequential) -----------------------

  def test_overall_deadline_enforced_in_sequential_mode_too
    counter = { n: 0 }
    # Three items, each scrape sleeps ~0.6s, deadline 1.0s. The loop checks
    # the deadline at the TOP of each iteration (Python/Go parity), so it
    # dispatches item 1 (t=0), item 2 (t~0.6 < 1.0), then breaks before
    # item 3 (t~1.2 >= 1.0). So strictly fewer than all 3 scrapes run —
    # proving the deadline truncates sequential dispatch. min_quality_score
    # is set unreachably high so nothing qualifies → snippet fallback.
    skill = make_skill('overall_deadline' => 1.0, 'parallel_scrape' => false,
                       'per_page_timeout' => 5.0, 'min_quality_score' => 2.0)
    stub_search(skill, CSE_ITEMS3)
    stub_extract_sleep(skill, 0.6, counter)

    elapsed, body = run_search_with_timing(skill)

    assert_operator counter[:n], :<, CSE_ITEMS3.length,
                    'sequential mode must stop dispatching past the deadline'
    # And it returned shortly after the deadline, not after all 3 sleeps (1.8s).
    assert_operator elapsed, :<, 1.7, "should break out near the deadline; took #{elapsed}s"
    assert_snippet_fallback(body, 'widgets')
  end

  # ---- per_page_timeout bounds a single fetch -----------------------

  def test_per_page_timeout_passed_to_http_layer
    # extract_text_from_url is where per_page_timeout is applied to
    # Net::HTTP open_timeout/read_timeout. capture_http_timeouts records the
    # timeouts the skill sets, without opening a real socket.
    skill = make_skill('per_page_timeout' => 0.25)

    assert_in_delta 0.25, skill.instance_variable_get(:@per_page_timeout), 1e-9

    captured = capture_http_timeouts { skill.send(:extract_text_from_url, 'https://example.com/p') }

    assert_in_delta 0.25, captured[:open], 1e-9
    assert_in_delta 0.25, captured[:read], 1e-9
  end

  # ---- snippet fallback on all-below-threshold ----------------------

  def test_all_results_below_threshold_falls_back_to_snippets
    # Every page returns content, but min_quality_score is unreachable, so
    # no candidate qualifies → snippet fallback (Python parity 295745b).
    skill = make_skill('min_quality_score' => 2.0, 'parallel_scrape' => false)
    stub_search(skill, CSE_ITEMS)
    skill.singleton_class.send(:define_method, :extract_text_from_url) do |_url|
      'short' # non-empty, but scores below the impossible 2.0 threshold
    end
    result = skill.send(:handle_search, { 'query' => 'widgets' }, nil)
    body = result.response.to_s

    assert_snippet_fallback(body, 'widgets', snippet: 'First CSE snippet about widgets.')
  end

  # ---- successful scrape still produces the quality header ----------

  def test_successful_scrape_produces_quality_results_header
    skill = make_skill('parallel_scrape' => false, 'min_quality_score' => 0.0)
    stub_search(skill, [CSE_ITEMS.first])
    skill.singleton_class.send(:define_method, :extract_text_from_url) do |_url|
      'widgets and gizmos in depth, ' * 80
    end
    result = skill.send(:handle_search, { 'query' => 'widgets' }, nil)
    body = result.response.to_s

    assert_match(/Quality web search results for 'widgets'/, body)
    assert_match(/Content:/, body)
  end
end
