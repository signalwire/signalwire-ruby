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
require 'signalwire/relay/client' # opt-in subsystem (Python: from signalwire.relay import RelayClient)

AGENT_NUMBER = '+19184238080'

client = SignalWire::Relay::Client.new(contexts: ['default'])

def tts(text)
  { 'type' => 'tts', 'params' => { 'text' => text } }
end

MENU_COLLECT = {
  'digits' => { 'max' => 1, 'digit_timeout' => 5.0 },
  'initial_timeout' => 10.0
}.freeze

# Play the menu and collect one digit; returns the digit string ('' on no input).
def collect_menu_digit(call)
  media = [tts('Welcome to SignalWire!'),
           tts('Press 1 for sales. Press 2 for support. Press 0 to speak with an agent.')]
  # media + collect are POSITIONAL on Call#play_and_collect. Passing them as
  # `media:` / `collect:` keywords sends them into **kwargs and leaves both
  # required positionals unfilled -> ArgumentError.
  result = call.play_and_collect(media, MENU_COLLECT).wait.params.fetch('result', {})
  result_type = result.fetch('type', '')
  digits = result.dig('params', 'digits') || ''
  puts "Collect result: type=#{result_type} digits=#{digits}"
  result_type == 'digit' ? digits : ''
end

def say_and_wait(call, text)
  call.play([tts(text)]).wait
end

# One serial ring group holding a single phone device. `devices` is a list of
# lists: the outer list rings in sequence, each inner list rings in parallel.
def agent_devices(from_number)
  [[{
    'type' => 'phone',
    'params' => { 'to_number' => AGENT_NUMBER, 'from_number' => from_number,
                  'timeout' => 30 }
  }]]
end

# Bridge the caller to a live agent and stay on the call until the bridge ends.
def connect_to_agent(call)
  say_and_wait(call, 'Connecting you to an agent now. Please hold.')
  from_number = call.device.dig('params', 'to_number') || ''
  puts "Connecting to #{AGENT_NUMBER} from #{from_number}"

  call.connect(devices: agent_devices(from_number),
               ringback: [tts('Please wait while we connect your call.')])

  call.wait_for_ended
  puts "Connected call ended: #{call.call_id}"
end

client.on_call(nil) do |call|
  puts "Incoming call: #{call.call_id}"
  call.answer

  case collect_menu_digit(call)
  when '1'
    say_and_wait(call, 'Thank you for your interest! A sales representative ' \
                       'will be with you shortly.')
  when '2'
    say_and_wait(call, 'Please hold while we connect you to our support team.')
  when '0'
    # connect_to_agent blocks until the bridge ends and hangs up with it, so
    # this arm must NOT fall through to the call.hangup below.
    connect_to_agent(call)
    next
  else
    say_and_wait(call, "We didn't receive a valid selection.")
  end

  call.hangup
  puts "Call ended: #{call.call_id}"
end

puts 'Waiting for inbound calls on context "default" ...'
client.run
