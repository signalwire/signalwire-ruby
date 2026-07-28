# frozen_string_literal: true

# Example: LLM parameter tuning for different agent personalities.
#
# Demonstrates using set_prompt_llm_params and set_post_prompt_llm_params
# to configure three distinct agent styles: precise, creative, and
# customer-service.

require 'signalwire'

# --- Precise technical assistant ---

precise = SignalWire::AgentBase.new(name: 'precise-assistant', route: '/precise')

precise.prompt_add_section('Role', 'You are a precise technical assistant.')
precise.prompt_add_section('Instructions', nil, bullets: [
  'Provide accurate, factual information.',
  'Be concise and direct.',
  'If uncertain, say so clearly.'
])

precise.set_prompt_llm_params(
  temperature:       0.2,
  top_p:             0.85,
  presence_penalty:  0.0,
  frequency_penalty: 0.1
)

precise.post_prompt = 'Provide a brief technical summary of the key points discussed.'
precise.set_post_prompt_llm_params(temperature: 0.1)

precise.define_tool(
  name: 'get_system_info', description: 'Get system info', parameters: {}, handler: nil
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new(
    "System Status: CPU #{rand(10..90)}%, Memory #{rand(1..16)}GB, Uptime #{rand(1..30)} days"
  )
end

# --- Creative writing assistant ---

creative = SignalWire::AgentBase.new(name: 'creative-assistant', route: '/creative')

creative.prompt_add_section('Role', 'You are a creative writing assistant.')
creative.prompt_add_section('Instructions', nil, bullets: [
  'Be imaginative and creative.',
  'Use varied vocabulary.',
  'Encourage creative thinking.'
])

creative.set_prompt_llm_params(
  temperature:       0.8,
  top_p:             0.95,
  presence_penalty:  0.2,
  frequency_penalty: 0.3
)

creative.post_prompt = 'Create an artistic summary of our conversation.'
creative.set_post_prompt_llm_params(temperature: 0.7)

creative.define_tool(
  name: 'generate_story_prompt', description: 'Generate a creative story prompt',
  parameters: { 'theme' => { 'type' => 'string', 'description' => 'Story theme' } }, handler: nil
) do |args, _raw_data|
  theme = args['theme'] || 'adventure'
  prompts = {
    'adventure' => 'A map that only appears during thunderstorms',
    'mystery'   => 'A photograph where people keep disappearing',
    'default'   => 'An ordinary object with extraordinary powers'
  }
  SignalWire::Swaig::FunctionResult.new(
    "Story prompt for #{theme}: #{prompts.fetch(theme.downcase, prompts['default'])}"
  )
end

# --- Customer service agent ---

support = SignalWire::AgentBase.new(name: 'customer-service', route: '/support')

support.prompt_add_section('Role', 'You are a professional customer service representative.')
support.prompt_add_section('Guidelines', nil, bullets: [
  'Always be polite and empathetic.',
  'Listen carefully to customer concerns.',
  'Provide clear, helpful solutions.'
])

support.set_prompt_llm_params(
  temperature:       0.4,
  top_p:             0.9,
  presence_penalty:  0.1,
  frequency_penalty: 0.1
)

support.post_prompt = "Summarise the customer's issue and resolution for the ticket system."
support.set_post_prompt_llm_params(temperature: 0.3)

support.define_tool(
  name: 'check_order_status', description: 'Check order status',
  parameters: { 'order_id' => { 'type' => 'string', 'description' => 'Order ID' } }, handler: nil
) do |args, _raw_data|
  order_id = args['order_id'] || 'unknown'
  statuses = [
    'Processing - Expected to ship within 24 hours',
    "Shipped - Tracking: TRK#{rand(100_000..999_999)}",
    'Out for delivery - Expected today by 6 PM',
    'Delivered - Left at front door'
  ]
  SignalWire::Swaig::FunctionResult.new("Order #{order_id}: #{statuses.sample}")
end

# --- Host all three on one server ---

server = SignalWire::AgentServer.new(host: '0.0.0.0', port: 3000)
server.register(precise)
server.register(creative)
server.register(support)

puts 'Starting LLM params demo on port 3000...'
puts '  /precise  -- Low temperature (precise, consistent)'
puts '  /creative -- High temperature (varied, creative)'
puts '  /support  -- Balanced (professional customer service)'
server.run
