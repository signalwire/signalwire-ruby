# frozen_string_literal: true

# Quickstart: the minimal REST client from the top-level README.
#
# Synchronous REST client for managing SignalWire resources and controlling
# calls over HTTP. No WebSocket required.

# A live call id would come from an inbound webhook / a prior create call.
call_id = 'example-call-id'

# region: rest
require 'signalwire'
require 'signalwire/rest/rest_client'

client = SignalWire::REST::RestClient.new(
  project: 'your-project-id',
  token:   'your-api-token',
  host:    'example.signalwire.com'
)

client.fabric.ai_agents.create(name: 'Support Bot', prompt: { 'text' => 'You are helpful.' })
client.calling.play(call_id, play: [{ 'type' => 'tts', 'text' => 'Hello!' }])
client.phone_numbers.search(area_code: '512')
client.datasphere.documents.search(query_string: 'billing policy')
# endregion: rest
