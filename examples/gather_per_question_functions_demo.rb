# frozen_string_literal: true

# Per-Question Function Whitelist Demo (gather_info)
#
# This example exists to teach one specific gotcha: while a step's
# gather_info is asking questions, ALL of the step's other functions are
# forcibly deactivated. The only callable tools during a gather question
# are:
#
#   - +gather_submit+ (the native answer-submission tool, always active)
#   - Whatever names you list in that question's +functions:+ option
#
# +next_step+ and +change_context+ are also filtered out — the model
# literally cannot navigate away until the gather completes. This is by
# design: it forces a tight ask → submit → next-question loop.
#
# If a question needs to call out to a tool — for example, to validate an
# email format, geocode a ZIP, or look up something from an external
# service — you must list that tool name in the question's +functions:+
# option. The function is active ONLY for that question.
#
# Below: a customer-onboarding gather flow where each question unlocks a
# different validation tool, and where the step's own non-gather tools
# (escalate_to_human, lookup_existing_account) are LOCKED OUT during
# gather because they aren't whitelisted on any question.
#
# Run this file to see the resulting SWML.

require 'json'
require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:  'gather_per_question_functions_demo',
  route: '/'
)

# Tools that the step would normally have available — but during gather
# questioning, they're all locked out unless they appear in a question's
# `functions` whitelist.
agent.define_tool(
  name:        'validate_email',
  description: 'Validate that an email address is well-formed and deliverable',
  parameters:  { 'email' => { 'type' => 'string' } }, handler: nil
) { |_args, _raw| { 'response' => 'valid' } }

agent.define_tool(
  name:        'geocode_zip',
  description: 'Look up the city/state for a US ZIP code',
  parameters:  { 'zip' => { 'type' => 'string' } }, handler: nil
) { |_args, _raw| { 'response' => '{"city":"...","state":"..."}' } }

agent.define_tool(
  name:        'check_age_eligibility',
  description: 'Verify the customer is old enough for the product',
  parameters:  { 'age' => { 'type' => 'integer' } }, handler: nil
) { |_args, _raw| { 'response' => 'eligible' } }

# These tools are NOT whitelisted on any gather question. They are
# registered on the agent and active outside the gather, but during the
# gather they cannot be called — gather mode locks them out.
agent.define_tool(
  name:        'escalate_to_human',
  description: 'Transfer the conversation to a live agent',
  parameters:  {}, handler: nil
) { |_args, _raw| { 'response' => 'transferred' } }

agent.define_tool(
  name:        'lookup_existing_account',
  description: 'Search for an existing account by email',
  parameters:  { 'email' => { 'type' => 'string' } }, handler: nil
) { |_args, _raw| { 'response' => 'not found' } }

# Build a single-context agent with one onboarding step.
ctx = agent.define_contexts.add_context('default')

onboard = ctx.add_step('onboard')
onboard.set_text(
  "Onboard a new customer by collecting their details. Use " \
  "gather_info to ask one question at a time. Each question may " \
  "unlock a specific validation tool — only that tool and " \
  "gather_submit are callable while answering it."
)
onboard.set_functions(%w[
  escalate_to_human
  lookup_existing_account
])
# Outside of the gather (which is the entire step here), these would be
# available. During the gather they are forcibly hidden in favor of the
# per-question whitelists.

onboard.set_gather_info(
  output_key:        'customer',
  completion_action: 'next_step',
  prompt: "I'll need to collect a few details to set up your " \
          "account. I'll ask one question at a time."
)

# Question 1: email — only validate_email + gather_submit callable.
onboard.add_gather_question(
  key:       'email',
  question:  "What's your email address?",
  confirm:   true,
  functions: %w[validate_email]
)

# Question 2: zip — only geocode_zip + gather_submit callable.
onboard.add_gather_question(
  key:       'zip',
  question:  "What's your ZIP code?",
  functions: %w[geocode_zip]
)

# Question 3: age — only check_age_eligibility + gather_submit callable.
onboard.add_gather_question(
  key:       'age',
  question:  'How old are you?',
  type:      'integer',
  functions: %w[check_age_eligibility]
)

# Question 4: referral_source — no +functions+ → only gather_submit is
# callable. The model cannot validate, lookup, escalate — nothing. This
# is the right pattern when a question needs no tools.
onboard.add_gather_question(
  key:      'referral_source',
  question: 'How did you hear about us?'
)

# A simple confirmation step the gather auto-advances into.
ctx.add_step('confirm')
   .set_text(
     "Read the collected info back to the customer and confirm " \
     "everything is correct."
   )
   .set_functions([])
   .set_end(true)

puts JSON.pretty_generate(agent.render_swml)
