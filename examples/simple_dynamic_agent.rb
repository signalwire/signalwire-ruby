# frozen_string_literal: true

# Example: Per-request dynamic configuration callback.
#
# The dynamic config callback receives each incoming request and can modify
# the agent's prompt, tools, hints, and global data on a per-call basis.
# This is useful for multi-tenant deployments where each caller gets a
# customised experience.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'dynamic_agent', route: '/')

# Base prompt -- will be augmented per-request
agent.prompt_add_section('Role', 'You are a helpful assistant.')

# Register a dynamic config callback.
# This runs for every incoming SWML request, receiving an ephemeral copy
# of the agent that you can safely modify.
agent.set_dynamic_config_callback do |query_params, body_params, headers, ephemeral|
  # Customise based on query parameters
  tenant = query_params['tenant'] || 'default'

  case tenant
  when 'acme'
    ephemeral.prompt_add_section(
      'Company',
      'You work for Acme Corp. Be professional and solution-oriented.'
    )
    ephemeral.add_hints(%w[Acme AcmeCorp warranty returns])
    ephemeral.set_global_data('company_name' => 'Acme Corp')

  when 'globex'
    ephemeral.prompt_add_section(
      'Company',
      'You work for Globex Corporation. Be friendly and casual.'
    )
    ephemeral.add_hints(%w[Globex shipping tracking])
    ephemeral.set_global_data('company_name' => 'Globex Corporation')

  else
    ephemeral.prompt_add_section(
      'Company',
      'You are a general-purpose assistant.'
    )
  end

  # Customise based on a header
  lang = headers['accept-language']
  if lang && lang.start_with?('es')
    ephemeral.add_language(
      'name'  => 'Spanish',
      'code'  => 'es-US',
      'voice' => 'elevenlabs.antonio'
    )
  end
end

# Define a tool that uses global_data set by the dynamic config
agent.define_tool(
  name:        'get_company_info',
  description: 'Get information about the company',
  parameters:  {}
) do |_args, _raw_data|
  # In production, global_data would be populated per-request
  SignalWire::Swaig::FunctionResult.new(
    'Company info is available in the global data.'
  )
end

puts "Starting dynamic agent on port #{agent.port}..."
puts 'Try: curl http://localhost:3000/?tenant=acme'
agent.run
