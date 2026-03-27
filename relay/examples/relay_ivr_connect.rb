# frozen_string_literal: true

# Example: IVR menu with DTMF collection, playback, and call connect.
#
# Answers an inbound call, plays a greeting, collects a digit, and
# routes the caller based on their choice:
#   1 - Hear a sales message
#   2 - Hear a support message
#   0 - Connect to a live agent
#
# Set these env vars (or pass them directly to Client.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space

require 'signalwire'

AGENT_NUMBER = '+19184238080'

client = SignalWire::Relay::Client.new(contexts: ['default'])

def tts(text)
  { 'type' => 'tts', 'params' => { 'text' => text } }
end

client.on_call do |call|
  puts "Incoming call: #{call.call_id}"
  call.answer

  # Play greeting and collect a single digit
  collect_action = call.play_and_collect(
    media: [
      tts('Welcome to SignalWire!'),
      tts('Press 1 for sales. Press 2 for support. Press 0 to speak with an agent.')
    ],
    collect: {
      'digits' => { 'max' => 1, 'digit_timeout' => 5.0 },
      'initial_timeout' => 10.0
    }
  )

  result_event = collect_action.wait
  result      = result_event.params.fetch('result', {})
  result_type = result.fetch('type', '')
  digits      = result.dig('params', 'digits') || ''

  puts "Collect result: type=#{result_type} digits=#{digits}"

  if result_type == 'digit' && digits == '1'
    # Sales
    action = call.play([tts('Thank you for your interest! A sales representative will be with you shortly.')])
    action.wait

  elsif result_type == 'digit' && digits == '2'
    # Support
    action = call.play([tts('Please hold while we connect you to our support team.')])
    action.wait

  elsif result_type == 'digit' && digits == '0'
    # Connect to live agent
    action = call.play([tts('Connecting you to an agent now. Please hold.')])
    action.wait

    from_number = call.device.dig('params', 'to_number') || ''
    puts "Connecting to #{AGENT_NUMBER} from #{from_number}"

    call.connect(
      devices: [[{
        'type' => 'phone',
        'params' => {
          'to_number'   => AGENT_NUMBER,
          'from_number' => from_number,
          'timeout'     => 30
        }
      }]],
      ringback: [tts('Please wait while we connect your call.')]
    )

    # Stay on the call until the bridge ends
    call.wait_for_ended
    puts "Connected call ended: #{call.call_id}"
    next
  else
    # No input or invalid
    action = call.play([tts("We didn't receive a valid selection.")])
    action.wait
  end

  call.hangup
  puts "Call ended: #{call.call_id}"
end

puts 'Waiting for inbound calls on context "default" ...'
client.run
