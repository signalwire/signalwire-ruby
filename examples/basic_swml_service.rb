# frozen_string_literal: true

# Example: Basic SWMLService (non-AI).
#
# Demonstrates using SWMLService directly to create and serve SWML
# documents without AI components -- voicemail, recording, and
# call transfer flows.

require 'signalwire'

# --- Voicemail service ---

voicemail = SignalWire::SWML::Service.new(
  name:  'voicemail',
  route: '/voicemail'
)

voicemail.answer
voicemail.play(url: "say:Hello, you've reached the voicemail service. Please leave a message after the beep.")
voicemail.sleep(1000)
voicemail.play(url: 'https://example.com/beep.wav')
voicemail.record(
  format:     'mp3',
  stereo:     false,
  beep:       false,
  max_length: 120,
  terminators: '#'
)
voicemail.play(url: 'say:Thank you for your message. Goodbye!')
voicemail.hangup

puts 'Voicemail SWML document:'
puts voicemail.render_pretty
puts

# --- Call recording service ---

recording = SignalWire::SWML::Service.new(
  name:  'recording',
  route: '/recording'
)

recording.answer
recording.record_call(
  control_id: 'call_recording',
  format:     'mp3',
  stereo:     true,
  direction:  'both',
  beep:       true
)
recording.play(url: 'say:This call is being recorded for quality and training purposes.')
recording.play(url: 'say:Please tell us about your experience.')
recording.sleep(30_000)
recording.execute_verb('stop_record_call', [], control_id: 'call_recording')
recording.play(url: 'say:Thank you for your time. Goodbye!')
recording.hangup

puts 'Recording SWML document:'
puts recording.render_pretty
puts

# --- Call transfer service ---

transfer = SignalWire::SWML::Service.new(
  name:  'transfer',
  route: '/transfer'
)

transfer.answer
transfer.play(url: "say:Thank you for calling. We'll connect you with the next available agent.")
# `connect` needs a destination -- one of `to` / `serial` / `parallel` /
# `serial_parallel`. Without one the document is schema-invalid and the call
# never dials anywhere.
transfer.connect(
  to:               '+15559876543',
  from:             '+15551234567',
  timeout:          30,
  answer_on_bridge: true
)
transfer.play(url: 'say:We apologize, but all agents are busy. Please try again later.')
transfer.hangup

puts 'Transfer SWML document:'
puts transfer.render_pretty

# To actually serve one of these:
# voicemail.serve
