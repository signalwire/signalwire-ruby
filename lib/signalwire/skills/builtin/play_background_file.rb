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

        # Python parity: ``PlayBackgroundFileSkill.__init__`` extracts the
        # configuration (tool_name / files) off ``params`` right after
        # ``super().__init__``. Ruby normally reads these in {#setup}; this
        # mirrors Python so the ivars exist at construction time. {#setup}
        # re-reads them (and returns the validation bool).
        def initialize(agent = nil, params = nil)
          super
          @tool_name = get_param('tool_name', default: 'play_background_file')
          @files     = get_param('files')
        end

        def setup
          @tool_name = get_param('tool_name', default: 'play_background_file')
          @files     = get_param('files')
          return false unless @files.is_a?(Array) && !@files.empty?
          return false unless @files.all? { |f| valid_file?(f) }

          true
        end

        def instance_key = "play_background_file_#{@tool_name}"

        # Python parity: ``get_tools`` returns the raw SWAIG tool DEFINITION
        # hashes (the DataMap tool the skill provides), including the
        # ``wait_for_fillers``/``skip_fillers`` flags. {#register_tools}
        # builds on top of this.
        def get_tools
          [
            {
              'function' => @tool_name,
              'description' => "Control background file playback for #{@tool_name.tr('_', ' ')}",
              'parameters' => tool_parameters,
              'wait_for_fillers' => true,
              'skip_fillers' => true,
              'data_map' => { 'expressions' => expressions }
            }
          ]
        end

        def register_tools
          get_tools.map { |tool| { datamap: tool } }
        end

        def get_parameter_schema
          {
            'files' => { 'type' => 'array', 'required' => true,
                         'items' => { 'type' => 'object', 'required' => %w[key description url] } }
          }
        end

        private

        def tool_parameters
          {
            'type' => 'object',
            'properties' => {
              'action' => { 'type' => 'string', 'description' => action_param_desc, 'enum' => enum_values }
            },
            'required' => ['action']
          }
        end

        def valid_file?(file)
          file.is_a?(Hash) && file['key'] && file['description'] && file['url']
        end

        def enum_values
          @files.map { |f| "start_#{f['key']}" } + ['stop']
        end

        def action_param_desc
          descriptions = @files.map { |f| "start_#{f['key']}: #{f['description']}" }
          descriptions << 'stop: Stop any currently playing background file'
          "Action to perform. Options: #{descriptions.join('; ')}"
        end

        def expressions
          exprs = @files.map { |f| start_expression(f) }
          exprs << stop_expression
        end

        def start_expression(file)
          result = Swaig::FunctionResult.new(
            "Tell the user you are now going to play #{file['description']} for them."
          )
          result.set_post_process(true)
          result.play_background_file(file['url'], wait: file.fetch('wait', false))

          {
            'string' => '${args.action}',
            'pattern' => "/start_#{file['key']}/i",
            'output' => result.to_h
          }
        end

        def stop_expression
          stop_result = Swaig::FunctionResult.new(
            'Tell the user you have stopped the background file playback.'
          ).stop_background_file

          {
            'string' => '${args.action}',
            'pattern' => '/stop/i',
            'output' => stop_result.to_h
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('play_background_file') do |params|
  SignalWire::Skills::Builtin::PlayBackgroundFileSkill.new(params)
end
