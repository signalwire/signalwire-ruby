# frozen_string_literal: true

# Example: Global data, post-prompt, and on_summary callback.
#
# Demonstrates how to use session state to track conversation data,
# configure post-prompt analysis, and receive call summaries.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'stateful_agent', route: '/')

# --- Prompt ---

agent.prompt_add_section(
  'Role',
  'You are an order-tracking assistant for ShipFast Logistics. ' \
  'Help callers check their order status and update delivery preferences.'
)

agent.prompt_add_section(
  'Guidelines',
  nil,
  bullets: [
    'Always greet the caller by name if available in global_data.',
    'Use the lookup_order tool to find order details.',
    'Update global_data with any preference changes.',
    'Summarise what was discussed before ending the call.'
  ]
)

# --- Post-prompt (analysis after each AI turn) ---

agent.set_post_prompt(
  'Analyse the conversation so far. Return a JSON object with: ' \
  '{"sentiment": "positive|neutral|negative", "resolved": true|false, ' \
  '"topics": ["list", "of", "topics"]}'
)

agent.set_post_prompt_llm_params(temperature: 0.1)

# --- Global data (pre-populated per-call state) ---

agent.set_global_data(
  'customer_name'  => 'Jane Doe',
  'account_id'     => 'ACCT-12345',
  'recent_orders'  => %w[ORD-001 ORD-002 ORD-003],
  'preferences'    => { 'delivery_window' => 'morning', 'sms_updates' => true }
)

# --- Tools ---

agent.define_tool(
  name:        'lookup_order',
  description: 'Look up an order by order ID',
  parameters:  {
    'order_id' => { 'type' => 'string', 'description' => 'The order ID to look up' }
  }, handler: nil
) do |args, _raw_data|
  order_id = args['order_id'] || 'unknown'
  SignalWire::Swaig::FunctionResult.new(
    "Order #{order_id}: Shipped on 2024-01-10, currently in transit. " \
    'Expected delivery: January 15. Carrier: FedEx. Tracking: 1Z999AA10123456784.'
  )
end

agent.define_tool(
  name:        'update_preferences',
  description: 'Update customer delivery preferences',
  parameters:  {
    'delivery_window' => { 'type' => 'string', 'description' => 'Preferred window: morning, afternoon, evening' },
    'sms_updates'     => { 'type' => 'boolean', 'description' => 'Enable SMS delivery updates' }
  }, handler: nil
) do |args, _raw_data|
  result = SignalWire::Swaig::FunctionResult.new(
    "Preferences updated: delivery window=#{args['delivery_window']}, " \
    "SMS updates=#{args['sms_updates']}."
  )
  # Persist changes to global_data so the AI sees the updated state
  result.update_global_data(
    'preferences' => {
      'delivery_window' => args['delivery_window'],
      'sms_updates'     => args['sms_updates']
    }
  )
  result
end

# --- Summary callback ---

agent.on_summary(nil) do |summary, raw_data|
  puts "\n=== Call Summary ==="
  puts "Summary: #{summary}"
  call_id = raw_data&.dig('call', 'call_id') || 'unknown'
  puts "Call ID: #{call_id}"
  puts "==================\n"
end

# --- Hints ---

agent.add_hints(%w[order tracking delivery FedEx UPS preferences SMS])

puts "Starting stateful agent on port #{agent.port}..."
agent.run
