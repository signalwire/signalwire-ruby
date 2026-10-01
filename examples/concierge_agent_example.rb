# frozen_string_literal: true

# Example: ConciergeAgent prefab.
#
# Demonstrates creating a virtual concierge for a hotel with amenity
# and service lookups, hours of operation, and custom welcome message.

require 'signalwire'
require 'signalwire/prefabs/concierge' # opt-in subsystem (Python: from signalwire.prefabs import ...)

# Build the concierge prefab
concierge = SignalWire::Prefabs::Concierge.new(
  venue_name: 'Oceanview Resort',
  services: [
    'room service',
    'spa bookings',
    'restaurant reservations',
    'activity bookings',
    'airport shuttle',
    'valet parking'
  ],
  amenities: {
    'infinity pool' => {
      'hours' => '7:00 AM - 10:00 PM',
      'location' => 'Main Level, Ocean View',
      'description' => 'Heated infinity pool with poolside service.'
    },
    'spa' => {
      'hours' => '9:00 AM - 8:00 PM',
      'location' => 'Lower Level, East Wing',
      'description' => 'Full-service luxury spa.',
      'reservation' => 'Required'
    },
    'fitness center' => {
      'hours' => '24 hours',
      'location' => '2nd Floor, North Wing',
      'description' => 'State-of-the-art fitness center.'
    },
    'beach access' => {
      'hours' => 'Dawn to Dusk',
      'location' => 'Southern Pathway',
      'services' => 'Beach attendants, food and beverage'
    }
  },
  hours_of_operation: {
    'check-in' => '3:00 PM',
    'check-out' => '11:00 AM',
    'front desk' => '24 hours',
    'concierge' => '7:00 AM - 11:00 PM',
    'room service' => '24 hours'
  },
  welcome_message: 'Welcome to Oceanview Resort! I am your virtual concierge, ' \
                   'ready to assist with any requests. How may I help you today?'
)

# Wrap the prefab in an AgentBase for HTTP serving
agent = SignalWire::AgentBase.new(name: concierge.name, route: concierge.route)

concierge.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end

agent.global_data = concierge.global_data

agent.define_tool(
  name: 'get_amenity_info',
  description: 'Get information about a resort amenity',
  parameters: {
    'amenity' => { 'type' => 'string', 'description' => 'Name of the amenity' }
  }, handler: nil
) do |args, raw_data|
  concierge.handle_amenity_info(args, raw_data)
end

agent.define_tool(
  name: 'get_service_info',
  description: 'Get information about a resort service',
  parameters: {
    'service' => { 'type' => 'string', 'description' => 'Name of the service' }
  }, handler: nil
) do |args, raw_data|
  concierge.handle_service_info(args, raw_data)
end

agent.add_hints(%w[pool spa fitness beach restaurant shuttle valet concierge])

puts "Starting Concierge agent on port #{agent.port}..."
agent.run
