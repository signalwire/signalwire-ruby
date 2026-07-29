# frozen_string_literal: true

# Example: Answer an inbound call and say "Welcome to SignalWire!"
#
# Set these env vars (or pass them directly to Client.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/relay/client'  # opt-in subsystem (Python: from signalwire.relay import RelayClient)

client = SignalWire::Relay::Client.new(contexts: ['default'])

client.on_call(nil) do |call|
  puts "Incoming call: #{call.call_id}"
  call.answer

  action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire!' } }])
  action.wait

  call.hangup
  puts "Call ended: #{call.call_id}"
end

puts 'Waiting for inbound calls on context "default" ...'
client.run
