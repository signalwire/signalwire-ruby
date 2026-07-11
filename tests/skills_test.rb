# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'tmpdir'

# Load core dependencies
require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/datamap/data_map'
require_relative '../lib/signalwire/skills/skill_base'
require_relative '../lib/signalwire/skills/skill_manager'
require_relative '../lib/signalwire/skills/skill_registry'

# Load all built-in skills
SignalWire::Skills::SkillRegistry.register_builtins!

# Shared env-var save/restore helper for the skills tests.
module SkillsTestHelpers
  # Clear +names+ for the duration of the block, restoring prior values after.
  def without_env_vars(*names)
    saved = names.flatten.to_h { |k| [k, ENV.delete(k)] }
    yield
  ensure
    saved.each { |k, v| ENV[k] = v if v }
  end
end

class SkillRegistryTest < Minitest::Test
  include SkillsTestHelpers

  EXPECTED_SKILLS = %w[
    api_ninjas_trivia
    claude_skills
    custom_skills
    datasphere
    datasphere_serverless
    datetime
    google_maps
    info_gatherer
    joke
    math
    native_vector_search
    play_background_file
    spider
    swml_transfer
    weather_api
    web_search
    wikipedia_search
  ].freeze

  def test_registry_has_all_builtin_skills
    registered = SignalWire::Skills::SkillRegistry.list_skills.sort

    EXPECTED_SKILLS.each do |skill_name|
      assert_includes registered, skill_name, "Missing skill: #{skill_name}"
    end
    # 17 built-ins: mcp_gateway is NOT ported (approved Python-only per §I.1).
    assert_equal 17, EXPECTED_SKILLS.size
    assert_operator registered.size, :>=, 17, "Expected at least 17 skills, got #{registered.size}"
  end

  def test_each_skill_can_be_instantiated
    EXPECTED_SKILLS.each do |skill_name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(skill_name)

      refute_nil factory, "No factory for: #{skill_name}"

      skill = factory.call({})

      assert_kind_of SignalWire::Skills::SkillBase, skill, "#{skill_name} is not a SkillBase"
      assert_equal skill_name, skill.name
    end
  end

  def test_skills_without_env_var_requirements_setup_successfully
    # These skills don't require API keys or external config
    no_env_skills = %w[datetime math]
    no_env_skills.each do |skill_name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(skill_name)
      skill = factory.call({})

      assert skill.setup, "#{skill_name} setup should succeed"
    end
  end

  # Skills requiring API keys / params, with the env vars that could satisfy
  # them (cleared so setup must fail).
  PARAM_SKILL_ENV = %w[
    API_NINJAS_KEY WEATHER_API_KEY GOOGLE_SEARCH_API_KEY
    GOOGLE_SEARCH_ENGINE_ID GOOGLE_MAPS_API_KEY
    SIGNALWIRE_PROJECT_ID SIGNALWIRE_TOKEN
  ].freeze
  PARAM_SKILLS = %w[joke weather_api web_search datasphere datasphere_serverless
                    google_maps native_vector_search].freeze

  def test_skills_requiring_params_fail_setup_without_them
    without_env_vars(PARAM_SKILL_ENV) do
      PARAM_SKILLS.each do |skill_name|
        skill = SignalWire::Skills::SkillRegistry.get_factory(skill_name).call({})

        refute skill.setup, "#{skill_name} setup should fail without required params"
      end
    end
  end
end

# Registry directory-scanning + instance-API coverage (split from
# SkillRegistryTest to keep each class under the size limit).
class SkillRegistryDirectoryTest < Minitest::Test
  include SkillsTestHelpers

  # ── add_skill_directory parity ────────────────────────────────────────
  # Mirrors Python's signalwire.skills.registry.SkillRegistry.add_skill_directory
  # (test_registry.py::TestDirectoryScanning::test_add_skill_directory_*).

  def test_add_skill_directory_valid
    Dir.mktmpdir do |tmpdir|
      registry = SignalWire::Skills::SkillRegistry.new
      registry.add_skill_directory(tmpdir)

      assert_includes registry.external_paths, tmpdir
    end
  end

  def test_add_skill_directory_not_exists
    registry = SignalWire::Skills::SkillRegistry.new
    err = assert_raises(ArgumentError) do
      registry.add_skill_directory('/no/such/swrb_path/abc123')
    end
    assert_match(/does not exist/, err.message)
  end

  def test_add_skill_directory_not_a_directory
    Tempfile.create('swrb_skill_file') do |f|
      registry = SignalWire::Skills::SkillRegistry.new
      err = assert_raises(ArgumentError) do
        registry.add_skill_directory(f.path)
      end
      assert_match(/not a directory/, err.message)
    end
  end

  # --- Python parity: SkillRegistry instance logger --------------
  def test_registry_instance_logger
    registry = SignalWire::Skills::SkillRegistry.new

    refute_nil registry.logger
    assert_respond_to registry.logger, :info
  end

  # --- Python parity: SkillRegistry#list_skills (instance form) --
  def test_registry_instance_list_skills_returns_hashes
    registry = SignalWire::Skills::SkillRegistry.new
    skills = registry.list_skills

    assert_kind_of Array, skills
    refute_empty skills
    skills.each do |entry|
      assert_kind_of Hash, entry
      assert entry.key?('name'), "expected entry to have 'name' key: #{entry.inspect}"
    end
  end

  # --- Python parity: SkillRegistry#register_skill (instance form) ---
  def fake_skill_class(skill_name)
    Class.new(SignalWire::Skills::SkillBase) do
      define_method(:name)        { skill_name }
      define_method(:description) { 'Test' }
      define_method(:setup)       { true }
    end
  end

  def test_registry_instance_register_skill_with_class
    registry = SignalWire::Skills::SkillRegistry.new
    registry.register_skill(fake_skill_class('test_register_skill_class_form'))

    assert_equal 'test_register_skill_class_form', registry.last_registered
    assert SignalWire::Skills::SkillRegistry.registered?('test_register_skill_class_form')

    # Clean up only the entry we added so other tests still see the
    # built-ins.
    factories_var = SignalWire::Skills::SkillRegistry.instance_variable_get(:@factories)
    factories_var.delete('test_register_skill_class_form')
  end

  def test_add_skill_directory_dedup
    Dir.mktmpdir do |tmpdir|
      registry = SignalWire::Skills::SkillRegistry.new
      registry.add_skill_directory(tmpdir)
      registry.add_skill_directory(tmpdir)
      paths = registry.external_paths

      assert_equal 1, paths.count(tmpdir)
    end
  end
end

# ── SIGNALWIRE_SKILL_PATHS auto-consumption parity ──────────────────────
# Mirrors the Python reference, which reads
# os.environ.get("SIGNALWIRE_SKILL_PATHS", "").split(os.pathsep) and folds
# those directories into the skill search path (registry.py:59 and :387).
# The Ruby port must auto-consume the same var — NOT require the user to
# wire it manually.
class SkillEnvPathsTest < Minitest::Test
  def with_skill_paths(value)
    saved = ENV.delete('SIGNALWIRE_SKILL_PATHS')
    ENV['SIGNALWIRE_SKILL_PATHS'] = value
    yield
  ensure
    ENV.delete('SIGNALWIRE_SKILL_PATHS')
    ENV['SIGNALWIRE_SKILL_PATHS'] = saved if saved
  end

  def test_env_skill_paths_folded_into_external_paths
    Dir.mktmpdir do |dir_a|
      Dir.mktmpdir do |dir_b|
        with_skill_paths([dir_a, dir_b].join(File::PATH_SEPARATOR)) do
          paths = SignalWire::Skills::SkillRegistry.new.external_paths

          assert_includes paths, dir_a, 'env-var skill dir A should be on the search path'
          assert_includes paths, dir_b, 'env-var skill dir B should be on the search path'
        end
      end
    end
  end

  def test_env_skill_paths_empty_entries_dropped
    with_skill_paths(['', File::PATH_SEPARATOR, ''].join) do
      registry = SignalWire::Skills::SkillRegistry.new

      refute_includes registry.external_paths, '', 'empty env-var entries must be dropped'
    end
  end

  def test_env_skill_paths_read_fresh_after_construction
    registry = SignalWire::Skills::SkillRegistry.new
    Dir.mktmpdir do |late_dir|
      with_skill_paths(late_dir) do
        # Var set AFTER the registry was built; Python reads it at search time,
        # so the Ruby port must too.
        assert_includes registry.external_paths, late_dir
      end
    end
  end

  def test_env_skill_paths_deduped_with_registered
    Dir.mktmpdir do |shared|
      with_skill_paths(shared) do
        registry = SignalWire::Skills::SkillRegistry.new
        registry.add_skill_directory(shared)

        assert_equal 1, registry.external_paths.count(shared),
                     'a dir both registered and in the env var appears once'
      end
    end
  end

  # A skill subdir so _skill_dirs_under has something to report.
  def write_demo_skill(dir)
    skill_dir = File.join(dir, 'demo_skill')
    Dir.mkdir(skill_dir)
    File.write(File.join(skill_dir, 'skill.rb'), "# demo\n")
  end

  def test_env_skill_paths_appear_in_list_all_skill_sources
    Dir.mktmpdir do |dir|
      write_demo_skill(dir)
      with_skill_paths(dir) do
        sources = SignalWire::Skills::SkillRegistry.new.list_all_skill_sources

        assert_includes sources['external_paths'], 'demo_skill',
                        'env-var skill dir contents should surface in list_all_skill_sources'
      end
    end
  end
end

class SkillManagerTest < Minitest::Test
  def setup
    @manager = SignalWire::Skills::SkillManager.new
  end

  def test_load_and_get
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})
    @manager.load('datetime', skill)

    assert @manager.loaded?('datetime')
    assert_equal skill, @manager.get('datetime')
    assert_equal 1, @manager.size
  end

  def test_unload
    factory = SignalWire::Skills::SkillRegistry.get_factory('math')
    skill = factory.call({})
    @manager.load('math', skill)

    assert @manager.loaded?('math')

    removed = @manager.unload('math')

    assert_equal skill, removed
    refute @manager.loaded?('math')
    assert_equal 0, @manager.size
  end

  def test_load_duplicate_raises
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})
    @manager.load('datetime', skill)

    assert_raises(ArgumentError) { @manager.load('datetime', skill) }
  end

  def test_loaded_keys
    %w[datetime math].each do |name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(name)
      @manager.load(name, factory.call({}))
    end

    keys = @manager.loaded_keys.sort

    assert_equal %w[datetime math], keys
  end

  def test_clear
    %w[datetime math].each do |name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(name)
      @manager.load(name, factory.call({}))
    end

    @manager.clear

    assert_equal 0, @manager.size
  end

  # --- Python parity: SkillManager(agent) -------------------------
  def test_constructor_accepts_agent_back_pointer
    fake_agent = Object.new
    manager = SignalWire::Skills::SkillManager.new(fake_agent)

    assert_same fake_agent, manager.agent
  end

  def test_constructor_default_agent_is_nil
    manager = SignalWire::Skills::SkillManager.new

    assert_nil manager.agent
  end

  def test_logger_is_present
    refute_nil @manager.logger
    assert_respond_to @manager.logger, :info
  end
end

class SkillBaseConstructorTest < Minitest::Test
  # --- Python parity: SkillBase(agent, params=None) -----------------
  def setup
    @skill_class = Class.new(SignalWire::Skills::SkillBase) do
      define_method(:name)        { 'test_skill_base' }
      define_method(:description) { 'Test' }
      define_method(:setup)       { true }
    end
  end

  def test_legacy_one_arg_form_with_params_only
    skill = @skill_class.new('foo' => 'bar')

    assert_nil skill.agent
    assert_equal 'bar', skill.params['foo']
  end

  def test_two_arg_form_python_style
    fake_agent = Object.new
    skill = @skill_class.new(fake_agent, 'tz' => 'UTC')

    assert_same fake_agent, skill.agent
    assert_equal 'UTC', skill.params['tz']
  end

  def test_swaig_fields_pulled_out_of_params
    skill = @skill_class.new(nil, 'foo' => 'bar', 'swaig_fields' => { 'k' => 'v' })

    assert_equal({ 'k' => 'v' }, skill.swaig_fields)
    refute skill.params.key?('swaig_fields')
  end

  def test_logger_is_namespaced
    skill = @skill_class.new

    refute_nil skill.logger
    assert_respond_to skill.logger, :info
    assert_match(/test_skill_base/, skill.logger.name)
  end
end

class DateTimeSkillTest < Minitest::Test
  def setup
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    @skill = factory.call({})
    @skill.setup
  end

  def test_name_and_description
    assert_equal 'datetime', @skill.name
    assert_equal 'Get current date, time, and timezone information', @skill.description
  end

  def test_register_tools_returns_two_tools
    tools = @skill.register_tools

    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'get_current_time'
    assert_includes names, 'get_current_date'
  end

  def test_get_current_time_handler
    tools = @skill.register_tools
    time_tool = tools.find { |t| t[:name] == 'get_current_time' }
    result = time_tool[:handler].call({ 'timezone' => 'UTC' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/current time is/i, result.response)
  end

  def test_get_current_date_handler
    tools = @skill.register_tools
    date_tool = tools.find { |t| t[:name] == 'get_current_date' }
    result = date_tool[:handler].call({ 'timezone' => 'UTC' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/date is/i, result.response)
  end

  def test_prompt_sections
    sections = @skill.get_prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Date and Time Information', sections[0]['title']
  end
end

class MathSkillTest < Minitest::Test
  def setup
    factory = SignalWire::Skills::SkillRegistry.get_factory('math')
    @skill = factory.call({})
    @skill.setup
  end

  def test_name_and_description
    assert_equal 'math', @skill.name
    assert_equal 'Perform basic mathematical calculations', @skill.description
  end

  def test_register_tools_returns_one_tool
    tools = @skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'calculate', tools[0][:name]
  end

  def test_calculate_addition
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '2 + 3' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/= 5/, result.response)
  end

  def test_calculate_multiplication
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '4 * 7' }, {})

    assert_match(/= 28/, result.response)
  end

  def test_calculate_complex_expression
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '(10 + 5) / 3' }, {})

    assert_match(/= 5/, result.response)
  end

  def test_calculate_power
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '2 ** 10' }, {})

    assert_match(/= 1024/, result.response)
  end

  def test_calculate_modulo
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '17 % 5' }, {})

    assert_match(/= 2/, result.response)
  end

  def test_calculate_division_by_zero
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '5 / 0' }, {})

    assert_match(/division by zero/i, result.response)
  end

  def test_calculate_invalid_expression
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => 'hello world' }, {})

    assert_match(/error/i, result.response)
  end

  def test_calculate_empty_expression
    tools = @skill.register_tools
    calc = tools[0][:handler]
    result = calc.call({ 'expression' => '' }, {})

    assert_match(/provide/i, result.response)
  end

  def test_prompt_sections
    sections = @skill.get_prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Mathematical Calculations', sections[0]['title']
  end
end

class InfoGathererSkillTest < Minitest::Test
  def build_info_gatherer
    SignalWire::Skills::SkillRegistry.get_factory('info_gatherer').call({
                                                                          'questions' => [
                                                                            { 'key_name' => 'name',
                                                                              'question_text' => 'What is your name?' },
                                                                            { 'key_name' => 'email',
                                                                              'question_text' => 'What is your email?',
                                                                              'confirm' => true }
                                                                          ]
                                                                        })
  end

  def test_setup_and_register_tools
    skill = build_info_gatherer

    assert skill.setup
    tools = skill.register_tools

    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'start_questions'
    assert_includes names, 'submit_answer'
  end

  def test_setup_fails_without_questions
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    skill = factory.call({})

    refute skill.setup
  end
end

class CustomSkillsTest < Minitest::Test
  def build_custom_skills
    SignalWire::Skills::SkillRegistry.get_factory('custom_skills').call({
                                                                          'tools' => [
                                                                            { 'name' => 'my_tool',
                                                                              'description' => 'Does something',
                                                                              'response' => 'Done!' }
                                                                          ]
                                                                        })
  end

  def test_setup_and_register
    skill = build_custom_skills

    assert skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'my_tool', tools[0][:name]

    # Execute the handler
    result = tools[0][:handler].call({}, {})

    assert_equal 'Done!', result.response
  end
end

class SpiderSkillTest < Minitest::Test
  def test_register_tools_returns_three_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})

    assert skill.setup
    tools = skill.register_tools

    assert_equal 3, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'scrape_url'
    assert_includes names, 'crawl_site'
    assert_includes names, 'extract_structured_data'
  end
end

class JokeSkillTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('API_NINJAS_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['API_NINJAS_KEY'] = saved if saved
    end
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({ 'api_key' => 'test_key' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert tools[0].key?(:datamap), 'Joke skill should return a datamap tool'
    assert_equal 'get_joke', tools[0][:datamap]['function']
  end
end

class WeatherApiSkillTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('WEATHER_API_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['WEATHER_API_KEY'] = saved if saved
    end
  end
end

class SwmlTransferSkillTest < Minitest::Test
  TRANSFERS = {
    'sales' => { 'url' => 'https://example.com/sales', 'message' => 'Transferring to sales' },
    'support' => { 'address' => '+15551234567', 'message' => 'Connecting to support' }
  }.freeze

  def test_setup_and_register
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({ 'transfers' => TRANSFERS })

    assert skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_operator tools[0][:datamap]['data_map']['expressions'].size, :>=, 3  # 2 patterns + fallback
  end
end

class PlayBackgroundFileSkillTest < Minitest::Test
  def test_setup_and_register
    factory = SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
    skill = factory.call({
                           'files' => [
                             { 'key' => 'music1', 'description' => 'Background music', 'url' => 'https://example.com/music.mp3' }
                           ]
                         })

    assert skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_operator tools[0][:datamap]['data_map']['expressions'].size, :>=, 2  # 1 start + stop
  end
end

class ApiNinjasTriviaSkillTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('API_NINJAS_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('api_ninjas_trivia')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['API_NINJAS_KEY'] = saved if saved
    end
  end
end

class NativeVectorSearchSkillTest < Minitest::Test
  def test_setup_requires_remote_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({})

    refute skill.setup

    skill_with_url = factory.call({ 'remote_url' => 'https://example.com/search' })

    assert skill_with_url.setup
  end
end

class SkillBaseTest < Minitest::Test
  def test_get_param_with_defaults
    skill = SignalWire::Skills::SkillBase.new({ 'foo' => 'bar', baz: 'qux' })

    assert_equal 'bar', skill.get_param('foo')
    assert_equal 'qux', skill.get_param('baz')
    assert_equal 'default_val', skill.get_param('missing', default: 'default_val')
    assert_nil skill.get_param('missing')
  end

  def test_get_param_with_env_var
    ENV['TEST_SKILL_KEY'] = 'env_value'
    skill = SignalWire::Skills::SkillBase.new({})

    assert_equal 'env_value', skill.get_param('missing', env_var: 'TEST_SKILL_KEY')
  ensure
    ENV.delete('TEST_SKILL_KEY')
  end

  def test_abstract_methods_raise
    skill = SignalWire::Skills::SkillBase.new({})
    assert_raises(NotImplementedError) { skill.name }
    assert_raises(NotImplementedError) { skill.description }
  end

  def test_default_scalar_methods
    skill = SignalWire::Skills::SkillBase.new({})

    assert_equal '1.0.0', skill.version
    assert_equal [], skill.required_env_vars
    refute_predicate skill, :supports_multiple_instances?
    assert skill.setup
    assert_nil skill.cleanup
  end

  def test_default_collection_methods
    skill = SignalWire::Skills::SkillBase.new({})

    assert_equal [], skill.register_tools
    assert_equal [], skill.get_hints
    assert_equal({}, skill.get_global_data)
    assert_equal [], skill.get_prompt_sections
    assert_equal({}, skill.get_parameter_schema)
  end
end

class SkillRegistryClassTest < Minitest::Test
  def test_registered?
    assert SignalWire::Skills::SkillRegistry.registered?('datetime')
    assert SignalWire::Skills::SkillRegistry.registered?('math')
    refute SignalWire::Skills::SkillRegistry.registered?('nonexistent_skill_xyz')
  end

  def test_get_factory_returns_nil_for_unknown
    assert_nil SignalWire::Skills::SkillRegistry.get_factory('nonexistent_skill_xyz')
  end
end
