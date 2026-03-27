# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # User-defined custom tools.
      class CustomSkillsSkill < SkillBase
        def name;        'custom_skills'; end
        def description; 'Register user-defined custom tools'; end
        def supports_multiple_instances?; true; end

        def setup
          @tools_config = get_param('tools')
          return false unless @tools_config.is_a?(Array)
          true
        end

        def instance_key
          tool_name = get_param('tool_name', default: 'custom')
          "custom_skills_#{tool_name}"
        end

        def register_tools
          (@tools_config || []).filter_map do |tool_def|
            next unless tool_def.is_a?(Hash) && tool_def['name']

            {
              name: tool_def['name'],
              description: tool_def['description'] || "Custom tool: #{tool_def['name']}",
              parameters: tool_def['parameters'] || {},
              handler: lambda { |args, _raw_data|
                response = tool_def['response'] || "Custom tool #{tool_def['name']} executed."
                Swaig::FunctionResult.new(response)
              }
            }
          end
        end

        def get_parameter_schema
          {
            'tools' => { 'type' => 'array', 'required' => true }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('custom_skills') do |params|
  SignalWire::Skills::Builtin::CustomSkillsSkill.new(params)
end
