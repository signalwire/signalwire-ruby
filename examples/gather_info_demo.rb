# frozen_string_literal: true

# Example: GatherInfo in steps.
#
# Uses the contexts system's gather_info mode for structured data
# collection. Questions are presented one at a time, with answers
# stored in global_data under the configured output key.

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:  'Patient Intake Agent',
  route: '/patient-intake'
)

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a friendly medical office intake assistant. ' \
  'Collect patient information accurately and professionally.'
)

# --- Define contexts with gather info steps ---

ctx = agent.define_contexts.add_context('default')

# Step 1: Demographics
step1 = ctx.add_step('demographics')
step1.set_text('Collect the patient\'s basic information.')
step1.set_gather_info(
  output_key: 'patient_demographics',
  prompt:     'Please collect the following patient information.'
)
step1.add_gather_question(key: 'full_name',     question: 'What is your full name?')
step1.add_gather_question(key: 'date_of_birth', question: 'What is your date of birth?')
step1.add_gather_question(key: 'phone_number',  question: 'What is your phone number?', confirm: true)
step1.add_gather_question(key: 'email',         question: 'What is your email address?')
step1.set_valid_steps(%w[symptoms])

# Step 2: Symptoms
step2 = ctx.add_step('symptoms')
step2.set_text('Ask about the patient\'s current symptoms and reason for visit.')
step2.set_gather_info(
  output_key: 'patient_symptoms',
  prompt:     "Now let's talk about why you're visiting today."
)
step2.add_gather_question(key: 'reason_for_visit',  question: 'What is the main reason for your visit today?')
step2.add_gather_question(key: 'symptom_duration',  question: 'How long have you been experiencing these symptoms?')
step2.add_gather_question(key: 'pain_level',        question: 'On a scale of 1 to 10, how would you rate your discomfort?')
step2.set_valid_steps(%w[confirmation])

# Step 3: Confirmation (normal step, not gather)
step3 = ctx.add_step('confirmation')
step3.set_text(
  'Summarise all the information collected and confirm with the patient ' \
  'that everything is correct. Thank them for their time.'
)
step3.set_step_criteria('Patient has confirmed all information is correct')

agent.add_hints(%w[name birthday phone email symptoms pain])

puts "Starting patient intake agent on port #{agent.port}..."
agent.run
