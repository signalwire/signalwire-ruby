# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class PlayBackgroundFileSkill < SkillBase
        def name = 'play_background_file'
        def description = 'Control background file playback'
        def supports_multiple_instances? = true

        def setup
          @tool_name = get_param('tool_name', default: 'play_background_file')
          @files     = get_param('files')
          return false unless @files.is_a?(Array) && !@files.empty?

          @files.each do |f|
            return false unless f.is_a?(Hash) && f['key'] && f['description'] && f['url']
          end
          true
        end

        def instance_key = "play_background_file_#{@tool_name}"

        def register_tools
          enum_values = @files.map { |f| "start_#{f['key']}" } + ['stop']
          descriptions = @files.map { |f| "start_#{f['key']}: #{f['description']}" }
          descriptions << 'stop: Stop any currently playing background file'
          param_desc = 'Action to perform. Options: ' + descriptions.join('; ')

          expressions = @files.map do |f|
            result = Swaig::FunctionResult.new(
              "Tell the user you are now going to play #{f['description']} for them."
            )
            result.set_post_process(true)
            result.play_background_file(f['url'], wait: f.fetch('wait', false))

            {
              'string' => '${args.action}',
              'pattern' => "/start_#{f['key']}/i",
              'output' => result.to_h
            }
          end

          stop_result = Swaig::FunctionResult.new(
            'Tell the user you have stopped the background file playback.'
          ).stop_background_file

          expressions << {
            'string' => '${args.action}',
            'pattern' => '/stop/i',
            'output' => stop_result.to_h
          }

          tool = {
            'function' => @tool_name,
            'description' => "Control background file playback for #{@tool_name.tr('_', ' ')}",
            'parameters' => {
              'type' => 'object',
              'properties' => {
                'action' => { 'type' => 'string', 'description' => param_desc, 'enum' => enum_values }
              },
              'required' => ['action']
            },
            'data_map' => { 'expressions' => expressions }
          }

          [{ datamap: tool }]
        end

        def get_parameter_schema
          {
            'files' => { 'type' => 'array', 'required' => true,
                         'items' => { 'type' => 'object', 'required' => %w[key description url] } }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('play_background_file') do |params|
  SignalWire::Skills::Builtin::PlayBackgroundFileSkill.new(params)
end
