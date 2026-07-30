# frozen_string_literal: true

# Example: Verb management and debug events.
#
# Demonstrates pre-answer verbs, post-answer verbs, post-AI verbs,
# call recording, and debug event callbacks.

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name: 'call_flow_agent',
  route: '/',
  record_call: true,
  record_format: 'mp3',
  record_stereo: true
)

# --- Prompt ---

agent.prompt_add_section(
  'Role',
  'You are a customer service agent for a hotel chain. ' \
  'Help callers with reservations, room service, and general inquiries.'
)

# --- Pre-answer verbs (before the call is answered) ---

# Play a whisper to the agent before connecting
agent.add_pre_answer_verb('play', {
                            'url' => 'say:New inbound call arriving'
                          })

# --- Post-answer verbs (after answer, before AI starts) ---

# Play hold music while AI initialises
agent.add_post_answer_verb('play', {
                             'url' => 'https://cdn.example.com/hold-music.mp3',
                             'max_length' => 5
                           })

# --- Post-AI verbs (after AI conversation ends) ---

# Play a closing message after the AI hangs up
agent.add_post_ai_verb('play', {
                         'url' => 'say:Thank you for calling. Goodbye!'
                       })

# --- Debug events ---

agent.enable_debug_events(2) # Level 2 for detailed events

agent.on_debug_event(nil) do |event_type, event_data|
  puts "[DEBUG] #{event_type}: #{event_data.inspect}"
end

# --- Tools ---

agent.define_tool(
  name: 'check_availability',
  description: 'Check room availability for given dates',
  parameters: {
    'check_in' => { 'type' => 'string', 'description' => 'Check-in date (YYYY-MM-DD)' },
    'check_out' => { 'type' => 'string', 'description' => 'Check-out date (YYYY-MM-DD)' },
    'room_type' => { 'type' => 'string', 'description' => 'Room type: standard, deluxe, suite' }
  }, handler: nil
) do |args, _raw_data|
  SignalWire::Swaig::FunctionResult.new(
    "#{args['room_type']&.capitalize} room available from #{args['check_in']} " \
    "to #{args['check_out']}. Rate: $189/night. Includes breakfast and WiFi."
  )
end

agent.define_tool(
  name: 'make_reservation',
  description: 'Create a hotel reservation',
  parameters: {
    'guest_name' => { 'type' => 'string', 'description' => 'Guest full name' },
    'check_in' => { 'type' => 'string', 'description' => 'Check-in date (YYYY-MM-DD)' },
    'check_out' => { 'type' => 'string', 'description' => 'Check-out date (YYYY-MM-DD)' },
    'room_type' => { 'type' => 'string', 'description' => 'Room type' }
  }, handler: nil
) do |args, _raw_data|
  conf_num = "RES-#{rand(100_000..999_999)}"
  result = SignalWire::Swaig::FunctionResult.new(
    "Reservation confirmed! Confirmation: #{conf_num}. " \
    "Guest: #{args['guest_name']}, #{args['room_type']} room, " \
    "#{args['check_in']} to #{args['check_out']}."
  )
  result.update_global_data('last_confirmation' => conf_num)
  result
end

agent.define_tool(
  name: 'transfer_to_front_desk',
  description: 'Transfer the call to the front desk',
  parameters: {}, handler: nil
) do |_args, _raw_data|
  result = SignalWire::Swaig::FunctionResult.new(
    'Transferring you to the front desk now.'
  )
  result.connect('+15559876543')
  result
end

# --- Hints ---

agent.add_hints(%w[reservation room suite deluxe checkout checkin concierge])

# --- Pronunciations ---

agent.add_pronunciation('WiFi', 'Why-Fye')

puts "Starting call flow agent on port #{agent.port}..."
agent.run
