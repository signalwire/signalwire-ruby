# frozen_string_literal: true

require "signalwire"

# Set logging to debug for testing
Signalwire::Logger.logger.level = ::Logger::DEBUG

SIGNALWIRE_PROJECT_KEY = ENV["SIGNALWIRE_PROJECT_KEY"]
SIGNALWIRE_TOKEN = ENV["SIGNALWIRE_TOKEN"]
FROM_NUMBER = ENV["FROM_NUMBER"] || "sip:1-999-123-4567@voip-provider.example.net"
TO_NUMBER = ENV["TO_NUMBER"] || "sip:1-999-123-4567@voip-provider.example.net"

client = Signalwire::Relay::Client.new(project: SIGNALWIRE_PROJECT_KEY, token: SIGNALWIRE_TOKEN)

client.on :ready do
  call = client.calling.new_call(from: FROM_NUMBER, to: TO_NUMBER, device_type: "sip")

  call.on :answered do |state_data|
    call.play_tts 'the quick brown fox jumps over the lazy dog'
    call.hangup
  end

  call.on :ended do |state_data|
    p "ended"
  end

  call.dial
end

client.connect!
