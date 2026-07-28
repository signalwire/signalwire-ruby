# frozen_string_literal: true

# Example: Declarative agent configuration.
#
# Builds the prompt entirely through prompt_add_section calls made once
# at startup, with a post-prompt for structured conversation summaries.
# Tools are defined alongside the agent rather than via a decorator.

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:  'declarative',
  route: '/declarative'
)

# --- Declarative prompt sections ---

agent.prompt_add_section(
  'Personality',
  'You are a friendly and helpful AI assistant who responds in a casual, conversational tone.'
)

agent.prompt_add_section(
  'Goal',
  'Help users with their questions about time and weather.'
)

agent.prompt_add_section('Instructions', nil, bullets: [
  'Be concise and direct in your responses.',
  "If you don't know something, say so clearly.",
  'Use the get_time function when asked about the current time.',
  'Use the get_weather function when asked about the weather.'
])

# --- Post-prompt for summary ---

agent.set_post_prompt(<<~PROMPT
  Return a JSON summary of the conversation:
  {
    "topic": "MAIN_TOPIC",
    "satisfied": true/false,
    "follow_up_needed": true/false
  }
PROMPT
)

# --- Tools ---

agent.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}, handler: nil
) do |_args, _raw_data|
  now = Time.now.strftime('%H:%M:%S')
  SignalWire::Swaig::FunctionResult.new("The current time is #{now}")
end

agent.define_tool(
  name:        'get_weather',
  description: 'Get the current weather for a location',
  parameters:  {
    'location' => { 'type' => 'string', 'description' => 'City or location' }
  }, handler: nil
) do |args, _raw_data|
  location = args['location'] || 'Unknown location'
  SignalWire::Swaig::FunctionResult.new("It's sunny and 72F in #{location}.")
end

# --- Summary callback ---

agent.on_summary(nil) do |summary, _raw_data|
  puts "Conversation summary: #{summary.inspect}"
end

puts "Starting declarative agent on port #{agent.port}..."
agent.run
