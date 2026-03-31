# frozen_string_literal: true

# Example: Dynamic InfoGatherer with callback-based question selection.
#
# Selects questions based on request parameters:
#   /contact            (default)
#   /contact?set=support
#   /contact?set=medical
#   /contact?set=onboarding

require 'signalwire'

question_sets = {
  'default' => [
    { 'key_name' => 'name',   'question_text' => 'What is your full name?' },
    { 'key_name' => 'phone',  'question_text' => 'What is your phone number?', 'confirm' => true },
    { 'key_name' => 'reason', 'question_text' => 'How can I help you today?' }
  ],
  'support' => [
    { 'key_name' => 'customer_name',  'question_text' => 'What is your name?' },
    { 'key_name' => 'account_number', 'question_text' => 'What is your account number?', 'confirm' => true },
    { 'key_name' => 'issue',          'question_text' => 'What issue are you experiencing?' },
    { 'key_name' => 'priority',       'question_text' => 'How urgent is this? (Low, Medium, High)' }
  ],
  'medical' => [
    { 'key_name' => 'patient_name', 'question_text' => "What is the patient's full name?" },
    { 'key_name' => 'symptoms',     'question_text' => 'What symptoms are you experiencing?', 'confirm' => true },
    { 'key_name' => 'duration',     'question_text' => 'How long have you had these symptoms?' },
    { 'key_name' => 'medications',  'question_text' => 'Are you currently taking any medications?' }
  ],
  'onboarding' => [
    { 'key_name' => 'full_name',  'question_text' => 'What is your full name?' },
    { 'key_name' => 'email',      'question_text' => 'What is your email address?', 'confirm' => true },
    { 'key_name' => 'company',    'question_text' => 'What company do you work for?' },
    { 'key_name' => 'department', 'question_text' => 'What department will you be working in?' },
    { 'key_name' => 'start_date', 'question_text' => 'What is your start date?' }
  ]
}

agent = SignalWire::Prefabs::InfoGathererAgent.new(
  questions: nil, # dynamic mode
  name:      'dynamic-intake',
  route:     '/contact'
)

agent.set_question_callback do |query_params, _body_params, _headers|
  set = query_params['set'] || 'default'
  puts "Dynamic question set: #{set}"
  question_sets[set] || question_sets['default']
end

puts 'Starting Dynamic InfoGatherer'
puts '  /contact            (default: name, phone, reason)'
puts '  /contact?set=support (customer support)'
puts '  /contact?set=medical (medical intake)'
puts '  /contact?set=onboarding (employee onboarding)'
agent.run
