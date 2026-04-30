# frozen_string_literal: true

# Tests for the top-level convenience entry points exposed on the
# ``SignalWire`` module — ``RestClient``, ``register_skill``,
# ``add_skill_directory``, ``list_skills_with_params``. These mirror
# Python's package-level ``signalwire/__init__.py`` factory + skill
# registry helpers.

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'signalwire'
# Loading builtin skills populates the singleton SkillRegistry.
SignalWire::Skills::SkillRegistry.register_builtins!

class SignalWireTopLevelTest < Minitest::Test
  def test_rest_client_factory_with_keyword_credentials
    client = SignalWire.RestClient(
      project: 'p-123',
      token: 't-456',
      host: 'demo.signalwire.com',
    )
    assert_kind_of SignalWire::REST::RestClient, client
    refute_nil client.fabric
    refute_nil client.calling
    refute_nil client.compat
  end

  def test_rest_client_factory_with_positional_credentials
    client = SignalWire.RestClient('proj', 'tok', 'pos.signalwire.com')
    assert_kind_of SignalWire::REST::RestClient, client
  end

  def test_rest_client_factory_raises_on_missing_credentials
    env = ENV.to_h
    begin
      ENV.delete('SIGNALWIRE_PROJECT_ID')
      ENV.delete('SIGNALWIRE_API_TOKEN')
      ENV.delete('SIGNALWIRE_SPACE')
      assert_raises(ArgumentError) { SignalWire.RestClient }
    ensure
      ENV.replace(env)
    end
  end

  def test_add_skill_directory_records_path_on_singleton_registry
    Dir.mktmpdir do |tmp|
      SignalWire.add_skill_directory(tmp)
      paths = SignalWire.send(:_signalwire_singleton_registry).external_paths
      assert_includes paths, tmp
    end
  end

  def test_add_skill_directory_raises_on_missing_directory
    assert_raises(ArgumentError) do
      SignalWire.add_skill_directory('/no/such/path/zzz_top_level_test')
    end
  end

  def test_register_skill_registers_class_with_singleton
    klass = Class.new do
      def self.skill_name
        'top_level_dummy_skill_ruby'
      end

      def initialize(_params = {}); end
    end
    SignalWire.register_skill(klass)
    assert_includes SignalWire::Skills::SkillRegistry.list_skills,
                    'top_level_dummy_skill_ruby'
  end

  def test_list_skills_with_params_returns_schema_hash
    schema = SignalWire.list_skills_with_params
    assert_kind_of Hash, schema
    refute_empty schema
    schema.each do |name, info|
      assert_kind_of String, name
      assert_kind_of Hash, info
      assert_equal name, info['name']
    end
  end
end
