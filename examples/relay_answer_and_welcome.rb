# frozen_string_literal: true

# Example: RELAY client usage -- answer inbound calls and play greetings.
#
# The RELAY client uses WebSocket (JSON-RPC 2.0) for real-time call
# control. Unlike the agent HTTP model, RELAY gives you imperative
# control over each call step.
#
# Set these env vars:
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space

require 'signalwire'
require 'signalwire/relay/client'  # opt-in subsystem (Python: from signalwire.relay import RelayClient)

client = SignalWire::Relay::Client.new(contexts: ['default'])

# Handle inbound calls
client.on_call do |call|
  puts "Incoming call from #{call.device.dig('params', 'from_number') || 'unknown'}"
  puts "  Call ID: #{call.call_id}"
  puts "  Direction: #{call.direction}"

  # Answer the call
  call.answer

  # Play a welcome message
  action = call.play([
    { 'type' => 'tts', 'params' => { 'text' => 'Hello! Welcome to the SignalWire RELAY demo.' } },
    { 'type' => 'tts', 'params' => { 'text' => 'This call is being handled by the Ruby RELAY client.' } }
  ])
  action.wait

  # Record a short message
  puts 'Starting recording...'
  record_action = call.record(beep: true, direction: 'both')

  # Wait a few seconds, then stop recording
  sleep 5
  record_action.stop
  puts 'Recording stopped.'

  # Play goodbye
  bye_action = call.play([
    { 'type' => 'tts', 'params' => { 'text' => 'Thank you for trying the RELAY demo. Goodbye!' } }
  ])
  bye_action.wait

  # Hang up
  call.hangup
  puts "Call #{call.call_id} ended."
end

# Handle inbound messages (optional)
client.on_message do |msg|
  puts "Incoming message from #{msg.from_number}: #{msg.body}"
end

puts 'RELAY client starting...'
puts 'Waiting for inbound calls on context "default"...'
client.run
