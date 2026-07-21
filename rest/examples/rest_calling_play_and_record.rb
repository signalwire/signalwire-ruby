# frozen_string_literal: true

# Example: Control an active call with media operations (play, record, transcribe, denoise).
#
# NOTE: These commands require an active call. The call_id used here is
# illustrative -- in production you would obtain it from a dial response or
# inbound call event.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

# 1. Dial an outbound call
puts 'Dialing outbound call...'
begin
  call = client.calling.dial(
    from: '+15559876543',
    to:    '+15551234567',
    url:   'https://example.com/call-handler'
  )
  call_id = call.fetch('id', 'demo-call-id')
  puts "  Call initiated: #{call_id}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Dial failed (expected in demo): #{e.status_code}"
  call_id = 'demo-call-id'
end

# 2. Play TTS audio
puts "\nPlaying TTS on call..."
begin
  client.calling.play(call_id, play: [{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire.' } }])
  puts '  Play started'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Play failed (expected in demo): #{e.status_code}"
end

# 3. Pause, resume, adjust volume, stop playback
puts "\nControlling playback..."
# control_id identifies the in-progress playback (returned by the play response
# in production); a demo value keeps these command examples self-contained.
play_ctl = 'demo-play-control-id'
[
  ['Pause',       -> { client.calling.play_pause(call_id, control_id: play_ctl) }],
  ['Resume',      -> { client.calling.play_resume(call_id, control_id: play_ctl) }],
  ['Volume +2dB', -> { client.calling.play_volume(call_id, control_id: play_ctl, volume: 2.0) }],
  ['Stop',        -> { client.calling.play_stop(call_id, control_id: play_ctl) }]
].each do |label, action|
  begin
    action.call
    puts "  #{label}: OK"
  rescue SignalWire::REST::SignalWireRestError => e
    puts "  #{label}: failed (#{e.status_code})"
  end
end

# 4. Record the call
puts "\nRecording call..."
begin
  client.calling.record(call_id, audio: { 'format' => 'mp3', 'beep' => true })
  puts '  Recording started'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Record failed (expected in demo): #{e.status_code}"
end

# 5. Pause, resume, stop recording
puts "\nControlling recording..."
# control_id identifies the in-progress recording (returned by the record response).
record_ctl = 'demo-record-control-id'
[
  ['Pause',  -> { client.calling.record_pause(call_id, control_id: record_ctl) }],
  ['Resume', -> { client.calling.record_resume(call_id, control_id: record_ctl) }],
  ['Stop',   -> { client.calling.record_stop(call_id, control_id: record_ctl) }]
].each do |label, action|
  begin
    action.call
    puts "  #{label}: OK"
  rescue SignalWire::REST::SignalWireRestError => e
    puts "  #{label}: failed (#{e.status_code})"
  end
end

# 6. Transcribe the call
puts "\nTranscribing call..."
begin
  client.calling.transcribe(call_id, language: 'en-US')
  puts '  Transcription started'
  client.calling.transcribe_stop(call_id, control_id: 'demo-transcribe-control-id')
  puts '  Transcription stopped'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Transcribe failed (expected in demo): #{e.status_code}"
end

# 7. Denoise the call
puts "\nEnabling denoise..."
begin
  client.calling.denoise(call_id)
  puts '  Denoise started'
  client.calling.denoise_stop(call_id)
  puts '  Denoise stopped'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Denoise failed (expected in demo): #{e.status_code}"
end

# 8. End the call
puts "\nEnding call..."
begin
  client.calling.end(call_id, reason: 'hangup')
  puts '  Call ended'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  End call failed (expected in demo): #{e.status_code}"
end
