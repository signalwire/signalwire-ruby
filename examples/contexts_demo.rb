# frozen_string_literal: true

# Example: Multi-step workflows using contexts and steps.
#
# This agent uses the contexts system to guide a caller through
# an insurance claim process with structured steps.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'claims_agent', route: '/')

# Base prompt
agent.prompt_add_section(
  'Role',
  'You are an insurance claims assistant. Guide the caller through ' \
  'filing a new claim step by step.'
)

# --- Define contexts and steps ---

ctx = agent.define_contexts.add_context('default')

# Step 1: Greeting
greeting = ctx.add_step('greeting')
greeting.set_text(
  'Welcome the caller warmly. Ask if they need to file a new claim ' \
  'or check the status of an existing claim.'
)
greeting.valid_steps = %w[new_claim check_status]
greeting.functions = %w[check_claim_status]

# Step 2: New Claim
new_claim = ctx.add_step('new_claim')
new_claim.add_section('Instructions', 'Collect the following information for the new claim:')
new_claim.add_bullets('Required Fields', [
  'Type of claim (auto, home, health)',
  'Date of incident',
  'Brief description of what happened',
  'Estimated damage amount'
])
new_claim.set_step_criteria(
  'All four required fields have been collected and confirmed with the caller.'
)
new_claim.valid_steps = %w[review]
new_claim.functions = %w[submit_claim]

# Step 3: Check Status
check_status = ctx.add_step('check_status')
check_status.set_text(
  'Ask the caller for their claim number, then look it up using the ' \
  'check_claim_status tool. Report the findings clearly.'
)
check_status.valid_steps = %w[greeting]
check_status.functions = %w[check_claim_status]

# Step 4: Review
review = ctx.add_step('review')
review.set_text(
  'Summarise all the claim details back to the caller. Ask them to ' \
  'confirm everything is correct. If they confirm, submit the claim. ' \
  'If they want to change something, go back to new_claim.'
)
review.valid_steps = %w[new_claim]
review.functions = %w[submit_claim]
review.set_end(true)

# --- Tools ---

agent.define_tool(
  name:        'check_claim_status',
  description: 'Look up the status of an existing insurance claim',
  parameters:  {
    'claim_number' => { 'type' => 'string', 'description' => 'The claim number to look up' }
  }
) do |args, _raw_data|
  claim = args['claim_number'] || 'unknown'
  SignalWire::Swaig::FunctionResult.new(
    "Claim #{claim}: Status is 'Under Review'. Filed on 2024-01-15 for auto damage. " \
    'Estimated amount: $3,200. Adjuster assigned: Jane Smith.'
  )
end

agent.define_tool(
  name:        'submit_claim',
  description: 'Submit a new insurance claim',
  parameters:  {
    'type'        => { 'type' => 'string', 'description' => 'Claim type: auto, home, or health' },
    'date'        => { 'type' => 'string', 'description' => 'Date of incident (YYYY-MM-DD)' },
    'description' => { 'type' => 'string', 'description' => 'Description of the incident' },
    'amount'      => { 'type' => 'number', 'description' => 'Estimated damage amount in USD' }
  }
) do |args, _raw_data|
  claim_num = "CLM-#{rand(100_000..999_999)}"
  result = SignalWire::Swaig::FunctionResult.new(
    "Claim submitted successfully! Your claim number is #{claim_num}. " \
    "Type: #{args['type']}, Date: #{args['date']}, Amount: $#{args['amount']}."
  )
  result.update_global_data('last_claim_number' => claim_num)
  result
end

# --- Hints ---

agent.add_hints(%w[claim insurance auto home health damage adjuster])

puts "Starting claims agent on port #{agent.port}..."
agent.run
