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
require 'signalwire/relay/client'  # opt-in subsystem (Python: from signalwire.relay import RelayClient)

from_number = ENV.fetch('RELAY_FROM_NUMBER', '+15551230001')
to_number   = ENV.fetch('RELAY_TO_NUMBER', '+15551230002')

client = SignalWire::Relay::Client.new
client.connect
puts 'Connected to RELAY'

# Dial the number
devices = [[{ 'type' => 'phone', 'params' => { 'to_number' => to_number, 'from_number' => from_number } }]]

begin
  call = client.dial(devices, timeout: 30)
rescue SignalWire::Relay::RelayError => e
  # No answer / dial not completed (e.g. the destination never picks up). The
  # demo has exercised the connect + dial path, which is all that can run
  # without a real answering party; exit cleanly.
  puts "No answer -- #{e.message}"
  client.stop
  exit 0
end

puts "Call answered -- call_id: #{call.call_id}"

# Play TTS
puts 'Playing TTS...'
action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire' } }])
action.wait(timeout: 15)
puts 'Playback finished -- hanging up'

call.hangup
call.wait_for_ended(timeout: 10)
puts 'Call ended'

client.stop
