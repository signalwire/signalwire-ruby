# frozen_string_literal: true

# Example: Auto-vivified SWML service.
#
# Demonstrates calling verb methods directly on a SWMLService instead
# of using add_verb. Builds voicemail, IVR, and call transfer services.

require 'signalwire'

# --- Voicemail Service ---
voicemail = SignalWire::SWML::Service.new(name: 'voicemail', route: '/voicemail')

voicemail.answer
voicemail.play(url: 'say:Hello, you have reached the voicemail service. Please leave a message after the beep.')
voicemail.sleep(1000)
voicemail.play(url: 'https://example.com/beep.wav')
voicemail.record(
  format: 'mp3',
  stereo: false,
  beep: false,
  max_length: 120,
  terminators: '#',
  status_url: 'https://example.com/voicemail-status'
)
voicemail.play(url: 'say:Thank you for your message. Goodbye!')
voicemail.hangup

# --- IVR Menu Service ---
ivr = SignalWire::SWML::Service.new(name: 'ivr', route: '/ivr')

ivr.answer
ivr.add_section('main_menu')
ivr.add_verb_to_section('main_menu', 'prompt',
  'play'        => 'say:Press 1 for sales, 2 for support, or 3 to leave a message.',
  'max_digits'  => 1,
  'terminators' => '#',
  'digit_timeout' => 5.0)
ivr.add_verb_to_section('main_menu', 'switch',
  'variable' => 'prompt_digits',
  'case'     => {
    '1' => [{ 'transfer' => { 'dest' => 'sales' } }],
    '2' => [{ 'transfer' => { 'dest' => 'support' } }]
  })
ivr.add_verb('transfer', 'dest' => 'main_menu')

# --- Call Transfer Service ---
transfer = SignalWire::SWML::Service.new(name: 'transfer', route: '/transfer')

transfer.answer
transfer.add_verb('play', 'url' => 'say:Connecting you with the next available agent.')
transfer.add_verb('connect',
  'from'     => '+15551234567',
  'timeout'  => 30,
  'parallel' => [
    { 'to' => '+15552223333' },
    { 'to' => '+15554445555' }
  ])
transfer.add_verb('record', 'format' => 'mp3', 'beep' => true, 'max_length' => 120)
transfer.hangup

# Run the voicemail service by default
puts "Starting voicemail service on port #{voicemail.port}..."
voicemail.serve
