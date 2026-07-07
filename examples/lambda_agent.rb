# frozen_string_literal: true

# Example: AWS Lambda-deployed agent.
#
# This file doubles as:
#   * A local script you can run directly (`ruby lambda_agent.rb`) — it
#     boots a WEBrick server the same way every other example does.
#   * A Lambda deployment entrypoint — bundle the SDK into a Lambda zip,
#     point the function handler at `lambda_agent.handler`, and AWS will
#     invoke the bottom of this file.
#
# No code changes are required between the two modes: the SDK auto-detects
# Lambda via `AWS_LAMBDA_FUNCTION_NAME` / `LAMBDA_TASK_ROOT`, and
# `SignalWire::Serverless::LambdaHandler` adapts API Gateway / Function
# URL events to the agent's Rack app.
#
# Webhook URLs are derived automatically in this priority order:
#   1. `SWML_PROXY_URL_BASE`          (any custom domain / proxy)
#   2. `AWS_LAMBDA_FUNCTION_URL`      (Function URLs, the usual case)
#   3. `https://{AWS_LAMBDA_FUNCTION_NAME}.lambda-url.{AWS_REGION}.on.aws`
#
# In each case the agent's `route:` is appended, so deploying at a
# non-root route (e.g. `/my-agent`) just works.

require 'signalwire'

AGENT = SignalWire::AgentBase.new(
  name:  'lambda-agent',
  route: '/'
)

AGENT.add_language('English', 'en-US', 'elevenlabs.rachel')

AGENT.prompt_add_section(
  'Role',
  'You are a helpful AI assistant running in a serverless environment.'
)

AGENT.prompt_add_section('Instructions', nil, bullets: [
  'Greet users warmly and offer help.',
  'Use the greet_user function when asked to greet someone.',
  'Use the get_time function when asked about the current time.'
])

AGENT.define_tool(
  name:        'greet_user',
  description: 'Greet a user by name',
  parameters:  {
    'name' => { 'type' => 'string', 'description' => 'Name to greet' }
  }
) do |args, _raw_data|
  name = args['name'] || 'friend'
  SignalWire::Swaig::FunctionResult.new("Hello #{name}! I'm running in serverless mode!")
end

AGENT.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new("Current time: #{Time.now.iso8601}")
end

# ---------------------------------------------------------------------------
# Lambda entrypoint. AWS invokes `handler(event:, context:)` at the top level
# of this file. `LambdaHandler.for(agent)` builds a long-lived adapter that
# translates API Gateway / Function URL events to Rack and back.
# ---------------------------------------------------------------------------
HANDLER = SignalWire::Serverless::LambdaHandler.for(AGENT)

def handler(event:, context: nil)
  HANDLER.call(event, context)
end

# ---------------------------------------------------------------------------
# Local development fallback — only runs when this file is the main script.
# ---------------------------------------------------------------------------
if __FILE__ == $PROGRAM_NAME
  puts "Starting lambda-style agent on port #{AGENT.port}..."
  AGENT.run
end
