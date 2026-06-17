# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

module SignalWire
  module Skills
    module Builtin
      class SwmlTransferSkill < SkillBase
        def name = 'swml_transfer'
        def description = 'Transfer calls between agents based on pattern matching'
        def supports_multiple_instances? = true

        def setup
          @transfers = get_param('transfers')
          return false unless @transfers.is_a?(Hash) && !@transfers.empty?

          @tool_name       = get_param('tool_name', default: 'transfer_call')
          @desc            = get_param('description', default: 'Transfer call based on pattern matching')
          @param_name      = get_param('parameter_name', default: 'transfer_type')
          @param_desc      = get_param('parameter_description', default: 'The type of transfer to perform')
          @default_message = get_param('default_message', default: 'Please specify a valid transfer type.')
          @required_fields = get_param('required_fields') || {}

          # Validate each transfer
          @transfers.each do |_pattern, config|
            return false unless config.is_a?(Hash)
            return false unless config.key?('url') || config.key?('address')

            config['message']        ||= 'Transferring you now...'
            config['return_message'] ||= 'The transfer is complete. How else can I help you?'
            config['post_process']     = true  unless config.key?('post_process')
            config['final']            = true  unless config.key?('final')
          end
          true
        end

        def instance_key = "swml_transfer_#{@tool_name}"

        def register_tools
          dm = DataMap.new(@tool_name)
                      .description(@desc)
                      .parameter(@param_name, 'string', @param_desc, required: true)

          @required_fields.each do |field, field_desc|
            dm.parameter(field, 'string', field_desc, required: true)
          end

          @transfers.each do |pattern, config|
            result = Swaig::FunctionResult.new(config['message'])
            result.set_post_process(config['post_process'])

            if config.key?('url')
              result.swml_transfer(config['url'], config['return_message'], final: config['final'])
            else
              result.connect(config['address'], final: config['final'], from_addr: config['from_addr'])
            end

            dm.expression("${args.#{@param_name}}", pattern, result)
          end

          # Default fallback
          default_result = Swaig::FunctionResult.new(@default_message)
          dm.expression("${args.#{@param_name}}", '/.*/', default_result)

          [{ datamap: dm.to_swaig_function }]
        end

        def get_hints
          hints = []
          @transfers&.each_key do |pattern|
            clean = pattern.gsub(%r{^/|/i*$}, '')
            next if clean.empty? || clean.start_with?('.')

            if clean.include?('|')
              clean.split('|').each { |p| hints << p.strip.downcase }
            else
              hints << clean.downcase
            end
          end
          hints.concat(['transfer', 'connect', 'speak to', 'talk to'])
        end

        def get_prompt_sections
          return [] unless @transfers && !@transfers.empty?

          bullets = @transfers.map do |pattern, config|
            clean = pattern.gsub(%r{^/|/i*$}, '')
            dest = config['url'] || config['address']
            "\"#{clean}\" - transfers to #{dest}"
          end

          [
            { 'title' => 'Transferring', 'body' => "Transfer calls using #{@tool_name}.", 'bullets' => bullets },
            { 'title' => 'Transfer Instructions', 'body' => 'How to use the transfer capability:',
              'bullets' => [
                "Use the #{@tool_name} function when a transfer is needed",
                "Pass the destination type to the '#{@param_name}' parameter"
              ] }
          ]
        end

        def get_parameter_schema
          {
            'transfers' => { 'type' => 'object', 'required' => true },
            'description' => { 'type' => 'string', 'default' => 'Transfer call based on pattern matching' },
            'parameter_name' => { 'type' => 'string', 'default' => 'transfer_type' },
            'default_message' => { 'type' => 'string', 'default' => 'Please specify a valid transfer type.' },
            'required_fields' => { 'type' => 'object', 'default' => {} }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('swml_transfer') do |params|
  SignalWire::Skills::Builtin::SwmlTransferSkill.new(params)
end
