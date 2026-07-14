# frozen_string_literal: true

# Quickstart: the minimal AI agent from the top-level README.
#
# A self-contained microservice that generates SWML and handles SWAIG tool
# calls. Run it with `ruby quickstart_agent.rb`, or test it without a server
# via `swaig-test quickstart_agent.rb --simulate-serverless lambda --list-tools`.
#
# The agent is exposed as the `AGENT` constant so swaig-test can discover it,
# and the blocking `AGENT.run` is guarded so loading the file for a test does
# not start a server.

# region: agent
require 'signalwire'

AGENT = SignalWire::AgentBase.new(name: 'my-agent', route: '/')

AGENT.add_language('English', 'en-US', 'elevenlabs.rachel')
AGENT.prompt_add_section('Role', 'You are a helpful assistant.')

AGENT.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new("The time is #{Time.now.strftime('%H:%M:%S')}")
end

AGENT.run if __FILE__ == $PROGRAM_NAME
# endregion: agent
