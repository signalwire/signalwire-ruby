# frozen_string_literal: true

# Example: MCP gateway skill.
#
# Connects an agent to MCP (Model Context Protocol) servers through the
# mcp_gateway skill. The gateway bridges MCP tools so the agent can use
# them as SWAIG functions.
#
# Environment variables:
#   MCP_GATEWAY_URL          -- URL of the running MCP gateway service
#   MCP_GATEWAY_AUTH_USER    -- Basic auth username
#   MCP_GATEWAY_AUTH_PASSWORD -- Basic auth password

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:  'MCP Gateway Agent',
  route: '/mcp-gateway'
)

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a helpful assistant with access to external tools provided ' \
  'through MCP servers. Use the available tools to help users accomplish their tasks.'
)

# Connect to MCP gateway -- tools are discovered automatically
agent.add_skill('mcp_gateway', {
  'gateway_url'   => ENV.fetch('MCP_GATEWAY_URL', 'http://localhost:8080'),
  'auth_user'     => ENV.fetch('MCP_GATEWAY_AUTH_USER', 'admin'),
  'auth_password' => ENV.fetch('MCP_GATEWAY_AUTH_PASSWORD', 'changeme'),
  'services'      => [{ 'name' => 'todo' }]
})

puts "Starting MCP Gateway agent on port #{agent.port}..."
agent.run
