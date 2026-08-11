# frozen_string_literal: true

# Example: Kubernetes-ready agent.
#
# Configured for production K8s deployment with built-in /health and
# /ready endpoints, environment-based port configuration, and a
# simple health-check tool.
#
# Usage:
#   PORT=8080 ruby examples/kubernetes.rb

require 'signalwire'

port = Integer(ENV.fetch('PORT', 8080))

agent = SignalWire::AgentBase.new(
  name: 'k8s-agent',
  route: '/',
  host: '0.0.0.0',
  port: port
)

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a production-ready AI agent running in Kubernetes. ' \
  'Help users with general questions and demonstrate cloud-native deployment.'
)

agent.define_tool(
  name: 'health_status',
  description: 'Get the health status of this agent',
  parameters: {}, handler: nil
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new(
    "Agent '#{agent.name}' is healthy, running on port #{agent.port} in Kubernetes."
  )
end

puts "READY: Kubernetes-ready agent starting on port #{port}"
puts "HEALTH: Health check at http://localhost:#{port}/health"
puts "STATUS: Readiness check at http://localhost:#{port}/ready"
agent.run
