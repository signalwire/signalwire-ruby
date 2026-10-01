# frozen_string_literal: true

# Example: Survey prefab -- conduct an automated survey over the phone.
#
# The Survey prefab walks callers through a set of questions with
# different answer types (rating, open-ended, yes/no).

require 'signalwire'
require 'signalwire/prefabs/survey' # opt-in subsystem (Python: from signalwire.prefabs import ...)

# Create the Survey prefab
survey = SignalWire::Prefabs::Survey.new(
  survey_name: 'Customer Satisfaction Survey',
  questions: [
    {
      'id' => 'overall_satisfaction',
      'text' => 'On a scale of 1 to 5, how satisfied are you with our service?',
      'type' => 'rating',
      'scale' => 5
    },
    {
      'id' => 'recommend',
      'text' => 'Would you recommend us to a friend or colleague?',
      'type' => 'yes_no'
    },
    {
      'id' => 'best_feature',
      'text' => 'What is the best thing about our service?',
      'type' => 'open_ended'
    },
    {
      'id' => 'improvement',
      'text' => 'What is one thing we could improve?',
      'type' => 'open_ended'
    },
    {
      'id' => 'likelihood_to_return',
      'text' => 'On a scale of 1 to 10, how likely are you to use our service again?',
      'type' => 'rating',
      'scale' => 10
    }
  ],
  introduction: 'Thank you for taking the time to complete our brief survey. ' \
                'Your feedback helps us improve. Let me ask you a few quick questions.',
  conclusion: 'Thank you for your valuable feedback! We truly appreciate it. ' \
              'Have a wonderful day!'
)

# Wrap it in an agent for serving
agent = SignalWire::AgentBase.new(name: survey.name, route: survey.route)

# Apply prompt sections from the prefab
survey.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end

# Apply global data
agent.global_data = survey.global_data

# Register the survey's tool handlers
agent.define_tool(
  name: 'start_survey',
  description: 'Start the survey and present the first question',
  parameters: {}, handler: nil
) do |args, raw_data|
  survey.handle_start(args, raw_data)
end

agent.define_tool(
  name: 'submit_survey_answer',
  description: 'Record the answer to the current survey question',
  parameters: {
    'answer' => { 'type' => 'string', 'description' => "The caller's response" }
  }, handler: nil
) do |args, raw_data|
  survey.handle_submit(args, raw_data)
end

agent.define_tool(
  name: 'get_survey_summary',
  description: 'Get the final survey summary and thank the caller',
  parameters: {}, handler: nil
) do |args, raw_data|
  survey.handle_summary(args, raw_data)
end

# Hints
agent.add_hints(%w[survey rating satisfaction feedback recommend improve])

# LLM config -- be precise for surveys
agent.set_prompt_llm_params(temperature: 0.2)

puts "Starting #{survey.survey_name} on port #{agent.port}..."
puts "  Route: #{agent.route}"
puts "  Questions: #{survey.questions.size}"
agent.run
