# frozen_string_literal: true

# Quickstart: the minimal AI agent from the top-level README.
#
# A self-contained microservice that generates SWML and handles SWAIG tool
# calls. Run it with `ruby quickstart_agent.rb`, or test it without a server
# via `swaig-test quickstart_agent.rb --list-tools`.

# region: agent
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'my-agent', route: '/')

agent.add_language('English', 'en-US', 'elevenlabs.rachel')
agent.prompt_add_section('Role', 'You are a helpful assistant.')

agent.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new("The time is #{Time.now.strftime('%H:%M:%S')}")
end

agent.run
# endregion: agent
