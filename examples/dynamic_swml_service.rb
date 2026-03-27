# frozen_string_literal: true

# Example: Dynamic SWML service.
#
# Demonstrates using register_routing_callback to generate different
# SWML responses based on the request path and POST data, without any
# AI components.

require 'signalwire'
require 'json'

service = SignalWire::SWML::Service.new(
  name:  'dynamic-greeting',
  route: '/greeting'
)

# Build default SWML document
service.answer
service.play(url: 'say:Hello, thank you for calling our service.')
service.hangup

# Register a callback for the /vip sub-path
service.register_routing_callback('/vip') do |request_data|
  doc = SignalWire::SWML::Document.new
  doc.add_verb('answer', {})

  caller_name = request_data && request_data['caller_name']
  greeting = caller_name ? "Welcome back, #{caller_name}!" : 'Welcome, VIP guest!'

  doc.add_verb('play', { 'url' => "say:#{greeting} Connecting you to priority support." })
  doc.add_verb('connect', { 'to' => '+15551234567', 'timeout' => 30 })
  doc.add_verb('hangup', {})
  doc.to_h
end

# Register a callback for the /new sub-path
service.register_routing_callback('/new') do |_request_data|
  doc = SignalWire::SWML::Document.new
  doc.add_verb('answer', {})
  doc.add_verb('play', { 'url' => 'say:Welcome to our service! Press 1 to learn about our products, 2 to speak with sales.' })
  doc.add_verb('hangup', {})
  doc.to_h
end

puts "Starting dynamic SWML service on port #{service.port}..."
puts "  GET/POST /greeting     -- Default greeting"
puts "  POST     /greeting/vip -- VIP greeting"
puts "  POST     /greeting/new -- New customer greeting"
service.serve
