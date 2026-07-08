# frozen_string_literal: true

# Example: Minimal static agent.
#
# All configuration is set once at initialisation and never changes.
# Demonstrates voice, AI params, hints, global data, and structured
# prompt sections for a customer-service agent.

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:        'Simple Customer Service Agent',
  record_call: true
)

# --- Static configuration (set once at startup) ---

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

agent.set_params(
  'end_of_speech_timeout'    => 500,
  'attention_timeout'        => 15_000,
  'background_file_volume'   => -20
)

agent.add_hints(%w[SignalWire SWML API webhook SIP])

agent.set_global_data(
  'agent_type'        => 'customer_service',
  'service_level'     => 'standard',
  'features_enabled'  => %w[basic_conversation help_desk],
  'session_info'      => { 'environment' => 'production', 'version' => '1.0' }
)

agent.prompt_add_section(
  'Role and Purpose',
  'You are a professional customer service representative. ' \
  'Help customers with their questions and provide excellent service.'
)

agent.prompt_add_section(
  'Guidelines',
  'Follow these customer service principles:',
  bullets: [
    'Listen carefully to customer needs.',
    'Provide accurate and helpful information.',
    'Maintain a professional and friendly tone.',
    'Escalate complex issues when appropriate.'
  ]
)

agent.prompt_add_section(
  'Available Services',
  'You can help customers with:',
  bullets: [
    'General product information',
    'Account questions and support',
    'Technical troubleshooting',
    'Billing and payment inquiries'
  ]
)

puts 'Starting simple static agent...'
puts "  Configuration: STATIC (set once at startup)"
puts "  Agent available at: http://localhost:#{agent.port}/"
agent.run
