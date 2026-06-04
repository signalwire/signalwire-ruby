# frozen_string_literal: true

# Example: InfoGatherer prefab -- collect answers to a series of questions.
#
# The InfoGatherer is a pre-built agent pattern that walks callers through
# a structured set of questions, confirms answers, and collects results.

require 'signalwire'

# Create the InfoGatherer prefab
gatherer = SignalWire::Prefabs::InfoGatherer.new(
  questions: [
    {
      'key_name'      => 'full_name',
      'question_text' => 'What is your full name?'
    },
    {
      'key_name'      => 'email',
      'question_text' => 'What is your email address?',
      'confirm'       => true
    },
    {
      'key_name'      => 'phone',
      'question_text' => 'What is the best phone number to reach you?',
      'confirm'       => true
    },
    {
      'key_name'      => 'reason',
      'question_text' => 'In a few words, what is the reason for your call today?'
    }
  ],
  name:  'intake_form',
  route: '/intake'
)

# Wrap it in an agent for serving
agent = SignalWire::AgentBase.new(name: gatherer.name, route: gatherer.route)

# Apply the prefab's prompt sections
gatherer.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end

# Apply global data
agent.global_data = gatherer.global_data

# Register the prefab's tool handlers
agent.define_tool(
  name:        'start_questions',
  description: 'Start the question sequence',
  parameters:  {}
) do |args, raw_data|
  gatherer.handle_start(args, raw_data)
end

agent.define_tool(
  name:        'submit_answer',
  description: 'Submit an answer to the current question',
  parameters:  {
    'answer' => { 'type' => 'string', 'description' => "The caller's answer" }
  }
) do |args, raw_data|
  gatherer.handle_submit(args, raw_data)
end

# Add relevant hints
agent.add_hints(%w[name email phone address])

puts "Starting InfoGatherer on port #{agent.port}..."
puts "  Route: #{agent.route}"
puts "  Questions: #{gatherer.questions.size}"
agent.run
