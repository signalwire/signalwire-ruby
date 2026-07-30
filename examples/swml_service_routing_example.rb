# frozen_string_literal: true

# Example: SWML service with routing callbacks.
#
# Demonstrates register_routing_callback to serve different SWML
# documents at /main, /customer, and /product sub-paths from a
# single Service instance.

require 'signalwire'
require 'json'

service = SignalWire::SWML::Service.new(
  name: 'routing-example',
  route: '/main'
)

# Default document
service.answer
service.play(url: 'say:Hello from the main service!')
service.hangup

# Customer route callback
service.register_routing_callback(nil, '/customer') do |request_data|
  doc = SignalWire::SWML::Document.new
  doc.add_verb('answer', {})

  customer_id = request_data && request_data['customer_id']
  if customer_id
    doc.add_verb('play', { 'url' => "say:Welcome back, customer #{customer_id}!" })
  else
    doc.add_verb('play', { 'url' => 'say:Hello from the customer service!' })
  end
  doc.add_verb('hangup', {})
  doc.to_h
end

# Product route callback
service.register_routing_callback(nil, '/product') do |request_data|
  doc = SignalWire::SWML::Document.new
  doc.add_verb('answer', {})

  product_id = request_data && request_data['product_id']
  if product_id
    doc.add_verb('play', { 'url' => "say:Product #{product_id} information loading." })
  else
    doc.add_verb('play', { 'url' => 'say:Hello from the product service!' })
  end
  doc.add_verb('hangup', {})
  doc.to_h
end

puts "Starting routing example on port #{service.port}..."
puts '  /main          -- Default greeting'
puts '  /main/customer -- Customer service'
puts '  /main/product  -- Product info'
service.serve
