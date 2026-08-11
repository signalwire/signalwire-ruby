# frozen_string_literal: true

# Example: Three agents hosted on a single AgentServer.
#
# AgentServer provides multi-agent hosting on one port with
# longest-prefix-match routing.

require 'signalwire'

# --- Agent 1: Sales ---

sales = SignalWire::AgentBase.new(name: 'sales', route: '/sales')
sales.prompt_add_section('Role', 'You are a sales representative for TechCo.')
sales.prompt_add_section('Guidelines', nil, bullets: [
                           'Be enthusiastic about our products.',
                           'Offer to schedule a demo if the caller is interested.',
                           'Never discuss competitor products.'
                         ])
sales.add_hints(%w[pricing demo trial enterprise])

sales.define_tool(
  name: 'schedule_demo',
  description: 'Schedule a product demo for the caller',
  parameters: {
    'email' => { 'type' => 'string', 'description' => 'Caller email address' },
    'date' => { 'type' => 'string', 'description' => 'Preferred date (YYYY-MM-DD)' }
  }, handler: nil
) do |args, _raw_data|
  SignalWire::Swaig::FunctionResult.new(
    "Demo scheduled for #{args['email']} on #{args['date']}. " \
    "You'll receive a confirmation email shortly."
  )
end

# --- Agent 2: Support ---

support = SignalWire::AgentBase.new(name: 'support', route: '/support')
support.prompt_add_section('Role', 'You are a technical support agent for TechCo.')
support.prompt_add_section('Guidelines', nil, bullets: [
                             'Ask for the ticket number first.',
                             'Walk through troubleshooting steps methodically.',
                             'Escalate to a human if the issue cannot be resolved.'
                           ])
support.add_hints(%w[ticket error crash login password])

support.define_tool(
  name: 'lookup_ticket',
  description: 'Look up a support ticket by number',
  parameters: {
    'ticket_number' => { 'type' => 'string', 'description' => 'The support ticket number' }
  }, handler: nil
) do |args, _raw_data|
  SignalWire::Swaig::FunctionResult.new(
    "Ticket #{args['ticket_number']}: Status is 'In Progress'. " \
    'Issue: Login timeout after recent update. Assigned to engineering team.'
  )
end

# --- Agent 3: Receptionist ---

receptionist = SignalWire::AgentBase.new(name: 'receptionist', route: '/reception')
receptionist.prompt_add_section('Role', 'You are the main receptionist for TechCo.')
receptionist.prompt_add_section('Guidelines', nil, bullets: [
                                  'Greet callers warmly.',
                                  'Ask how you can direct their call.',
                                  'Transfer to the appropriate department.'
                                ])
receptionist.add_hints(%w[sales support billing hours directions])

receptionist.define_tool(
  name: 'transfer_call',
  description: 'Transfer the caller to a department',
  parameters: {
    'department' => {
      'type' => 'string',
      'description' => 'Department name: sales, support, or billing'
    }
  }, handler: nil
) do |args, _raw_data|
  dept = args['department'] || 'unknown'
  result = SignalWire::Swaig::FunctionResult.new(
    "Transferring you to #{dept} now. Please hold."
  )
  result.connect("+1555000#{dept.length}#{dept.length}#{dept.length}#{dept.length}")
  result
end

# --- Server ---

server = SignalWire::AgentServer.new(host: '0.0.0.0', port: 3000)
server.register(sales)
server.register(support)
server.register(receptionist)

puts 'Starting multi-agent server on port 3000...'
puts '  /sales      -- Sales agent'
puts '  /support    -- Support agent'
puts '  /reception  -- Receptionist'
server.run
