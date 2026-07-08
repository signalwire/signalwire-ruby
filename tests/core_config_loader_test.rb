# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Real-behavior tests for SignalWire::Core::ConfigLoader (parity with Python's
# signalwire.core.config_loader.ConfigLoader).
class CoreConfigLoaderTest < Minitest::Test
  def with_config(hash)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'cfg.json')
      File.write(path, JSON.generate(hash))
      yield SignalWire::Core::ConfigLoader.new([path]), path
    end
  end

  def test_loads_json_config
    with_config({ 'a' => 1 }) do |loader, path|
      assert loader.has_config
      assert_equal path, loader.get_config_file
      assert_equal({ 'a' => 1 }, loader.get_config)
    end
  end

  def test_no_config_when_missing
    loader = SignalWire::Core::ConfigLoader.new(['/nonexistent/definitely-not-here.json'])

    refute loader.has_config
    assert_nil loader.get_config_file
    assert_equal({}, loader.get_config)
  end

  def test_get_dot_path
    with_config({ 'security' => { 'ssl_enabled' => true, 'nested' => { 'x' => 'y' } } }) do |loader, _|
      assert_equal true, loader.get('security.ssl_enabled')
      assert_equal 'y', loader.get('security.nested.x')
      assert_equal 'fallback', loader.get('security.missing', 'fallback')
    end
  end

  def test_env_var_substitution
    ENV['SW_TEST_TOKEN'] = 'secret123'

    with_config({ 'token' => '${SW_TEST_TOKEN}' }) do |loader, _|
      assert_equal 'secret123', loader.get('token')
    end
  ensure
    ENV.delete('SW_TEST_TOKEN')
  end

  def test_env_var_substitution_with_default
    ENV.delete('SW_MISSING_VAR')

    with_config({ 'v' => '${SW_MISSING_VAR|fallbackval}' }) do |loader, _|
      assert_equal 'fallbackval', loader.get('v')
    end
  end

  def test_substitute_coerces_types
    ENV['SW_NUM'] = '42'
    ENV['SW_FLT'] = '3.5'
    ENV['SW_BOOL'] = 'true'
    with_config({ 'n' => '${SW_NUM}', 'f' => '${SW_FLT}', 'b' => '${SW_BOOL}' }) do |loader, _|
      assert_equal 42, loader.get('n')
      assert_in_delta 3.5, loader.get('f')
      assert_equal true, loader.get('b')
    end
  ensure
    %w[SW_NUM SW_FLT SW_BOOL].each { |k| ENV.delete(k) }
  end

  def test_get_section_substitutes_recursively
    ENV['SW_HOST'] = 'example.com'
    with_config({ 'server' => { 'host' => '${SW_HOST}', 'list' => ['${SW_HOST}', 'static'] } }) do |loader, _|
      section = loader.get_section('server')

      assert_equal 'example.com', section['host']
      assert_equal ['example.com', 'static'], section['list']
    end
  ensure
    ENV.delete('SW_HOST')
  end

  def test_merge_with_env_config_precedence
    ENV['SWML_TESTKEY'] = 'from_env'
    ENV['SWML_OTHER'] = 'env_other'
    with_config({ 'testkey' => 'from_config' }) do |loader, _|
      merged = loader.merge_with_env('SWML_')

      # config wins over env for a key present in config
      assert_equal 'from_config', merged['testkey']
      # env-only key is folded in
      assert_equal 'env_other', merged['other']
    end
  ensure
    ENV.delete('SWML_TESTKEY')
    ENV.delete('SWML_OTHER')
  end

  def test_substitute_vars_depth_guard
    loader = SignalWire::Core::ConfigLoader.new([])
    assert_raises(ArgumentError) { loader.substitute_vars({ 'a' => { 'b' => 'c' } }, 1) }
  end

  def test_find_config_file_returns_first_existing
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'web_config.json')
      File.write(target, '{}')

      Dir.chdir(dir) do
        assert_equal 'web_config.json', SignalWire::Core::ConfigLoader.find_config_file('web')
      end
    end
  end

  def test_find_config_file_nil_when_none
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        assert_nil SignalWire::Core::ConfigLoader.find_config_file('unlikely-service-name-xyz')
      end
    end
  end
end
