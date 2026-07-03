# frozen_string_literal: true

# SKILL-INTERFACE hook-override parity tests.
#
# Closes the cross-port gap where several SKILL-INTERFACE hook overrides exist
# in the Python reference but were missing (or not visibly defined on the class)
# in the Ruby port:
#
#   ApiNinjasTriviaSkill#get_tools / #initialize        (Python __init__ + get_tools)
#   PlayBackgroundFileSkill#get_tools / #initialize
#   WeatherApiSkill#get_tools / #initialize
#   SpiderSkill#initialize
#   DatasphereSkill#cleanup / #get_hints
#   DatasphereServerlessSkill#get_hints
#   DateTimeSkill / JokeSkill / MathSkill / WebSearchSkill /
#     WikipediaSearchSkill#get_hints
#
# Each test drives the *real* method (no mocking the thing under test) and
# asserts on real content. The overrides must be defined directly on the skill
# class (public_instance_methods(false)) so the cross-port surface enumerator
# picks them up — a merely-inherited method is invisible to the audit.

require 'minitest/autorun'

require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/api_ninjas_trivia'
require_relative '../../lib/signalwire/skills/builtin/play_background_file'
require_relative '../../lib/signalwire/skills/builtin/weather_api'
require_relative '../../lib/signalwire/skills/builtin/spider'
require_relative '../../lib/signalwire/skills/builtin/datasphere'
require_relative '../../lib/signalwire/skills/builtin/datasphere_serverless'
require_relative '../../lib/signalwire/skills/builtin/datetime'
require_relative '../../lib/signalwire/skills/builtin/joke'
require_relative '../../lib/signalwire/skills/builtin/math'
require_relative '../../lib/signalwire/skills/builtin/web_search'
require_relative '../../lib/signalwire/skills/builtin/wikipedia_search'

# ---------------------------------------------------------------------------
# get_tools: the three DataMap skills expose their raw SWAIG tool DEFINITIONS
# (Python parity). register_tools builds on top of get_tools.
# ---------------------------------------------------------------------------
class ApiNinjasTriviaGetToolsParityTest < Minitest::Test
  def build(params = {})
    SignalWire::Skills::SkillRegistry.get_factory('api_ninjas_trivia')
                                     .call({ 'api_key' => 'k' }.merge(params))
  end

  def test_get_tools_returns_the_tool_definition
    tools = build.get_tools

    assert_kind_of Array, tools
    assert_equal 1, tools.size
    tool = tools.first

    assert_equal 'get_trivia', tool['function']
    assert tool.key?('data_map'), 'trivia tool must carry a data_map'
    assert_equal(%w[category], tool['parameters']['required'])
  end

  def test_get_tools_honors_custom_tool_name
    tools = build('tool_name' => 'get_science').get_tools

    assert_equal 'get_science', tools.first['function']
  end

  def test_register_tools_wraps_get_tools_as_datamap
    skill = build
    reg = skill.register_tools

    assert_equal skill.get_tools, reg.map { |e| e[:datamap] },
                 'register_tools must wrap get_tools output under :datamap'
  end

  def test_overrides_are_own_methods
    klass = SignalWire::Skills::Builtin::ApiNinjasTriviaSkill

    assert_includes klass.public_instance_methods(false), :get_tools
    # initialize is always a private method in Ruby; assert it's overridden
    # directly on the class (Python __init__ parity).
    assert_includes klass.private_instance_methods(false), :initialize
  end

  def test_initialize_extracts_config_at_construction_time
    # Python parity: __init__ sets the config ivars before setup runs.
    skill = build('tool_name' => 'get_music')

    assert_equal 'get_music', skill.instance_variable_get(:@tool_name)
    assert_equal 'k', skill.instance_variable_get(:@api_key)
  end
end

class PlayBackgroundFileGetToolsParityTest < Minitest::Test
  FILES = [{ 'key' => 'bgm', 'description' => 'Background music',
             'url' => 'https://example.com/bgm.mp3' }].freeze

  def build(params = {})
    SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
                                     .call({ 'files' => FILES }.merge(params))
  end

  def test_get_tools_returns_tool_with_filler_flags
    tool = build.get_tools.first

    assert_equal 'play_background_file', tool['function']
    assert tool['wait_for_fillers'], 'Python parity: wait_for_fillers is true'
    assert tool['skip_fillers'], 'Python parity: skip_fillers is true'
  end

  def test_get_tools_action_enum_covers_files_and_stop
    enum = build.get_tools.first['parameters']['properties']['action']['enum']

    assert_includes enum, 'start_bgm'
    assert_includes enum, 'stop'
  end

  def test_register_tools_wraps_get_tools
    skill = build

    assert_equal(skill.get_tools, skill.register_tools.map { |e| e[:datamap] })
  end

  def test_overrides_are_own_methods
    klass = SignalWire::Skills::Builtin::PlayBackgroundFileSkill

    assert_includes klass.public_instance_methods(false), :get_tools
    assert_includes klass.private_instance_methods(false), :initialize
  end
end

class WeatherApiGetToolsParityTest < Minitest::Test
  def build(params = {})
    SignalWire::Skills::SkillRegistry.get_factory('weather_api')
                                     .call({ 'api_key' => 'k' }.merge(params))
  end

  def test_get_tools_returns_weather_tool
    tool = build.get_tools.first

    assert_equal 'get_weather', tool['function']
    assert tool.key?('data_map')
    assert_equal(%w[location], tool['parameters']['required'])
  end

  def test_get_tools_reflects_temperature_unit
    tool = build('temperature_unit' => 'celsius').get_tools.first
    template = tool['data_map']['webhooks'].first['output'].to_s

    assert_includes template, 'Celsius'
  end

  def test_register_tools_wraps_get_tools
    skill = build

    assert_equal(skill.get_tools, skill.register_tools.map { |e| e[:datamap] })
  end

  def test_overrides_are_own_methods
    klass = SignalWire::Skills::Builtin::WeatherApiSkill

    assert_includes klass.public_instance_methods(false), :get_tools
    assert_includes klass.private_instance_methods(false), :initialize
  end
end

# ---------------------------------------------------------------------------
# SpiderSkill#initialize: config + cache exist at construction (Python __init__).
# ---------------------------------------------------------------------------
class SpiderInitializeParityTest < Minitest::Test
  def build(params = {})
    SignalWire::Skills::SkillRegistry.get_factory('spider').call(params)
  end

  def test_initialize_allocates_cache_and_config
    skill = build('max_text_length' => 500, 'timeout' => 9)

    assert_equal 500, skill.instance_variable_get(:@max_text_length)
    assert_equal 9, skill.instance_variable_get(:@timeout)
    refute_nil skill.instance_variable_get(:@cache), 'cache is allocated when caching is enabled'
  end

  def test_initialize_applies_tool_prefix
    skill = build('tool_name' => 'crawler')

    # Python parity: a non-empty tool_name becomes a "<name>_" prefix.
    assert_equal 'crawler_', skill.instance_variable_get(:@tool_prefix)
  end

  def test_initialize_is_own_method
    assert_includes SignalWire::Skills::Builtin::SpiderSkill.private_instance_methods(false), :initialize
  end
end

# ---------------------------------------------------------------------------
# DatasphereSkill#cleanup: idempotent teardown (Python closes requests.Session).
# ---------------------------------------------------------------------------
class DatasphereCleanupParityTest < Minitest::Test
  PARAMS = { 'space_name' => 'sp', 'project_id' => 'p', 'token' => 't',
             'document_id' => 'd' }.freeze

  def build
    skill = SignalWire::Skills::SkillRegistry.get_factory('datasphere').call(PARAMS)

    assert skill.setup, 'datasphere setup should succeed with full params'
    skill
  end

  def test_cleanup_is_idempotent_and_returns_nil
    skill = build

    refute_nil skill.instance_variable_get(:@api_url), 'setup populates the search endpoint'
    assert_nil skill.cleanup, 'cleanup returns nil (Python parity: returns None)'
    assert_nil skill.instance_variable_get(:@api_url), 'cleanup drops the endpoint'
    assert_nil skill.cleanup, 'cleanup is safe to call again'
  end

  def test_cleanup_is_own_public_method
    assert_includes SignalWire::Skills::Builtin::DatasphereSkill.public_instance_methods(false), :cleanup
  end
end

# ---------------------------------------------------------------------------
# get_hints: overrides that faithfully return [] per the Python reference, but
# MUST be defined directly on each class so the surface enumerator sees them.
# ---------------------------------------------------------------------------
class GetHintsSurfaceParityTest < Minitest::Test
  # skill name => [factory params, skill class]
  EMPTY_HINT_SKILLS = {
    'datasphere' => [{ 'space_name' => 's', 'project_id' => 'p', 'token' => 't', 'document_id' => 'd' },
                     SignalWire::Skills::Builtin::DatasphereSkill],
    'datasphere_serverless' => [{ 'space_name' => 's', 'project_id' => 'p', 'token' => 't', 'document_id' => 'd' },
                                SignalWire::Skills::Builtin::DatasphereServerlessSkill],
    'datetime' => [{}, SignalWire::Skills::Builtin::DateTimeSkill],
    'joke' => [{ 'api_key' => 'k' }, SignalWire::Skills::Builtin::JokeSkill],
    'math' => [{}, SignalWire::Skills::Builtin::MathSkill],
    'web_search' => [{ 'api_key' => 'k', 'search_engine_id' => 'e' },
                     SignalWire::Skills::Builtin::WebSearchSkill],
    'wikipedia_search' => [{}, SignalWire::Skills::Builtin::WikipediaSearchSkill]
  }.freeze

  def test_get_hints_returns_empty_array_and_is_own_public_method
    EMPTY_HINT_SKILLS.each do |name, (params, klass)|
      skill = SignalWire::Skills::SkillRegistry.get_factory(name).call(params)

      assert_equal [], skill.get_hints, "#{name}#get_hints must return [] (Python parity)"
      assert_includes klass.public_instance_methods(false), :get_hints,
                      "#{name}#get_hints must be defined on the class so the enumerator sees it"
    end
  end
end
