# frozen_string_literal: true

# Example: Dial a number and play "Welcome to SignalWire" using the RELAY client.
#
# Requires env vars:
#   SIGNALWIRE_PROJECT_ID
#   SIGNALWIRE_API_TOKEN
#   SIGNALWIRE_SPACE
#   RELAY_FROM_NUMBER   - a number on your SignalWire project
#   RELAY_TO_NUMBER     - destination to call

require 'signalwire'

from_number = ENV.fetch('RELAY_FROM_NUMBER')
to_number   = ENV.fetch('RELAY_TO_NUMBER')

client = SignalWire::Relay::Client.new

# Dial the number
devices = [[{ 'type' => 'phone', 'params' => { 'to_number' => to_number, 'from_number' => from_number } }]]

begin
  call = client.dial(devices, timeout: 30)
  puts "Call answered -- call_id: #{call.call_id}"
rescue SignalWire::Relay::RelayError => e
  puts "Dial failed: #{e.message}"
  exit 1
end

# Play TTS
puts 'Playing TTS...'
action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire' } }])
action.wait(timeout: 15)
puts 'Playback finished -- hanging up'

call.hangup
call.wait_for_ended(timeout: 10)
puts 'Call ended'
