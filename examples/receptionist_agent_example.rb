# frozen_string_literal: true

# Example: ReceptionistAgent prefab.
#
# Demonstrates a call-routing receptionist with department transfers,
# custom greeting, and caller info collection.

require 'signalwire'
require 'signalwire/prefabs/receptionist'  # opt-in subsystem (Python: from signalwire.prefabs import ...)

departments = [
  { 'name' => 'sales',   'description' => 'Product inquiries and pricing',     'number' => '+15551235555' },
  { 'name' => 'support', 'description' => 'Technical assistance and bug reports', 'number' => '+15551236666' },
  { 'name' => 'billing', 'description' => 'Payment questions and invoices',    'number' => '+15551237777' },
  { 'name' => 'general', 'description' => 'All other inquiries',              'number' => '+15551238888' }
]

receptionist = SignalWire::Prefabs::Receptionist.new(
  departments: departments,
  name:        'acme-receptionist',
  route:       '/reception',
  greeting:    'Hello, thank you for calling ACME Corporation. How may I direct your call today?'
)

agent = SignalWire::AgentBase.new(name: receptionist.name, route: receptionist.route)

# Apply prompt sections
receptionist.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end

# Company information
agent.prompt_add_section(
  'Company Information',
  'ACME Corporation is a leading provider of innovative solutions. ' \
  'Business hours: Monday through Friday, 9 AM to 5 PM Eastern.'
)

# Apply global data
agent.global_data = receptionist.global_data

# Register transfer tool
agent.define_tool(
  name:        'transfer_to_department',
  description: 'Transfer the caller to a specific department',
  parameters:  {
    'department' => { 'type' => 'string', 'description' => 'Department name' }
  }, handler: nil
) do |args, raw_data|
  receptionist.handle_transfer(args, raw_data)
end

agent.add_hints(%w[sales support billing hours directions transfer])

agent.on_summary(nil) do |summary, _raw_data|
  puts "\n=== Call Summary ==="
  puts summary.inspect
  puts "==================\n"
end

puts "Starting Receptionist agent on port #{agent.port}..."
agent.run
