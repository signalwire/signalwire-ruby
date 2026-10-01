# frozen_string_literal: true

# Quickstart: the minimal RELAY client from the top-level README.
#
# Real-time call control over WebSocket. The client connects to SignalWire
# via the Blade protocol and gives you imperative control over live calls.

# region: relay
require 'signalwire'
require 'signalwire/relay/client'

client = SignalWire::Relay::Client.new(
  project: 'your-project-id',
  token: 'your-api-token',
  space: 'example.signalwire.com',
  contexts: ['default']
)

client.on_call(nil) do |call|
  call.answer
  action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome!' } }])
  action.wait
  call.hangup
end

client.run
# endregion: relay
