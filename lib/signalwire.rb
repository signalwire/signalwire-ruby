# frozen_string_literal: true

require_relative 'signalwire/version'
require_relative 'signalwire/logging'
require_relative 'signalwire/core/logging_config'
require_relative 'signalwire/utils/serverless'
require_relative 'signalwire/utils/schema_utils'
require_relative 'signalwire/runtime'
require_relative 'signalwire/swml/document'
require_relative 'signalwire/swml/schema'
require_relative 'signalwire/swml/service'
require_relative 'signalwire/swaig/function_result'
require_relative 'signalwire/swaig/parameter_schema'
require_relative 'signalwire/security/session_manager'
require_relative 'signalwire/contexts/context_builder'
require_relative 'signalwire/pom/prompt_object_model'
require_relative 'signalwire/datamap/data_map'
require_relative 'signalwire/skills/skill_name'
require_relative 'signalwire/skills/skill_base'
require_relative 'signalwire/skills/skill_manager'
require_relative 'signalwire/skills/skill_registry'
require_relative 'signalwire/agent/agent_base'
require_relative 'signalwire/serverless/lambda_handler'

module SignalWire
  # Top-level convenience entry points — mirror Python's
  # ``signalwire/__init__.py`` factory + skill registry helpers.

  module_function

  # Construct a {SignalWire::REST::RestClient} instance.
  #
  # Mirrors Python's top-level ``signalwire.RestClient(*args, **kwargs)``
  # factory — a thin wrapper that lazy-imports
  # ``signalwire.rest.RestClient`` and instantiates it. Supports both
  # positional credentials (matching Go-style ``RestClient(project,
  # token, host)``) and keyword credentials (Ruby-idiomatic).
  #
  # @param args [Array<String>] Positional credentials (compat shim).
  # @param kwargs [Hash] Keyword credentials forwarded to the constructor.
  # @return [SignalWire::REST::RestClient]
  def RestClient(*args, **kwargs)
    require_relative 'signalwire/rest/rest_client'
    if args.length >= 3 && kwargs.empty?
      REST::RestClient.new(project: args[0], token: args[1], host: args[2])
    elsif !args.empty? && kwargs.empty?
      raise ArgumentError, 'positional form requires (project, token, host)'
    else
      REST::RestClient.new(**kwargs)
    end
  end

  # Register a custom skill class with the global skill registry.
  #
  # Mirrors Python's ``signalwire.register_skill(skill_class)`` — the
  # Ruby singleton registry stores factories by name. The class is
  # expected to expose a ``::skill_name`` (or ``SKILL_NAME`` constant)
  # so we can derive the registration key.
  #
  # @param skill_class [Class] A subclass of {SignalWire::Skills::SkillBase}
  # @return [void]
  def register_skill(skill_class)
    require_relative 'signalwire/skills/skill_registry'
    name = if skill_class.respond_to?(:skill_name)
             skill_class.skill_name
           elsif skill_class.const_defined?(:SKILL_NAME)
             skill_class.const_get(:SKILL_NAME)
           else
             raise ArgumentError,
                   "skill class #{skill_class} must define ::skill_name or SKILL_NAME"
           end
    Skills::SkillRegistry.register_skill(name, ->(params) { skill_class.new(params) })
  end

  # Add a directory to search for skills.
  #
  # Mirrors Python's ``signalwire.add_skill_directory(path)`` — delegates
  # to the singleton {SignalWire::Skills::SkillRegistry} instance so
  # third-party skill collections can be registered by path. Subsequent
  # calls accumulate (de-duplicated) into a shared external paths list.
  #
  # @param path [String] absolute or relative path to a skill directory.
  # @return [void]
  # @raise [ArgumentError] when the path doesn't exist or isn't a directory.
  def add_skill_directory(path)
    require_relative 'signalwire/skills/skill_registry'
    _signalwire_singleton_registry.add_skill_directory(path)
  end

  # List all available skills.
  #
  # Mirrors Python's top-level ``signalwire.list_skills()``. Delegates to
  # {SignalWire::Skills::SkillRegistry#list_skills} on the shared
  # singleton registry, returning one hash per skill (``name`` plus
  # ``description`` / ``version`` when the factory can be instantiated
  # without arguments).
  #
  # @return [Array<Hash>]
  def list_skills
    require_relative 'signalwire/skills/skill_registry'
    _signalwire_singleton_registry.list_skills
  end

  # Get complete schema for all available skills, including parameter metadata.
  #
  # Mirrors Python's ``signalwire.list_skills_with_params()``. Keys are
  # skill names; values describe metadata + parameter schema. Useful for
  # GUI configuration tools, API documentation, or programmatic skill
  # discovery.
  #
  # @return [Hash{String => Hash}]
  def list_skills_with_params
    require_relative 'signalwire/skills/skill_registry'
    if Skills::SkillRegistry.respond_to?(:get_all_skills_schema)
      Skills::SkillRegistry.get_all_skills_schema
    else
      # Fallback: list_skills returns names; pair them with empty params.
      Skills::SkillRegistry.list_skills.each_with_object({}) do |name, h|
        h[name] = { 'name' => name, 'parameters' => {} }
      end
    end
  end

  # Singleton SkillRegistry instance used by the top-level helpers.
  # Internal — exposed only so the helpers can share state across calls.
  def _signalwire_singleton_registry
    @_signalwire_singleton_registry ||= Skills::SkillRegistry.new
  end
  private_class_method :_signalwire_singleton_registry
end
