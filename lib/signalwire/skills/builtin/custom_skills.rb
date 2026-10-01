# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # User-defined custom tools.
      class CustomSkillsSkill < SkillBase
        # The name this skill is added under (`agent.add_skill('custom_skills')`).
        #
        # @return [String]
        def name = 'custom_skills'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Register user-defined custom tools'
        # This skill may be loaded more than once on one agent — each instance
        # is distinguished by its `prefix` param, which also namespaces its
        # tools and its slice of `global_data`.
        #
        # @return [Boolean] true
        def supports_multiple_instances? = true

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @tools_config = get_param('tools')
          return false unless @tools_config.is_a?(Array)

          true
        end

        # The key this instance is tracked under — `custom_skills_<tool_name>` — so several
        # instances can coexist on one agent without colliding.
        #
        # @return [String]
        def instance_key
          tool_name = get_param('tool_name', default: 'custom')
          "custom_skills_#{tool_name}"
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          (@tools_config || []).filter_map do |tool_def|
            next unless tool_def.is_a?(Hash) && tool_def['name']

            build_custom_tool(tool_def)
          end
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          {
            'tools' => { 'type' => 'array', 'required' => true }
          }
        end

        private

        # @api private — one SWAIG tool from a `tools` config entry. The handler
        # ignores its arguments and returns the entry's fixed `response` string, so
        # these are canned-answer tools, not computed ones.
        #
        # @return [Hash]
        def build_custom_tool(tool_def)
          {
            name: tool_def['name'],
            description: tool_def['description'] || "Custom tool: #{tool_def['name']}",
            parameters: tool_def['parameters'] || {},
            handler: lambda { |_args, _raw_data|
              response = tool_def['response'] || "Custom tool #{tool_def['name']} executed."
              Swaig::FunctionResult.new(response)
            }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('custom_skills') do |params|
  SignalWire::Skills::Builtin::CustomSkillsSkill.new(params)
end
