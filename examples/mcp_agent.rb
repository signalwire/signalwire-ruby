#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MCP Integration -- Client and Server
#
# This agent demonstrates both MCP features:
#
# 1. MCP Server: Exposes tools at /mcp so external MCP clients
#    (Claude Desktop, other agents) can discover and invoke them.
#
# 2. MCP Client: Connects to external MCP servers to pull in additional
#    tools for voice calls.
#
# Usage:
#   ruby mcp_agent.rb
#
#   Then:
#   - Point a SignalWire phone number at http://your-server:3000/agent
#   - Connect Claude Desktop to http://your-server:3000/agent/mcp

require_relative '../lib/signalwire'

agent = SignalWire::AgentBase.new(name: 'mcp-agent', route: '/agent')

# -- MCP Server ---------------------------------------------------------------
# Adds a /mcp endpoint that speaks JSON-RPC 2.0 (MCP protocol).
agent.enable_mcp_server

# -- MCP Client ---------------------------------------------------------------
# Connect to external MCP servers.
agent.add_mcp_server(
  'https://mcp.example.com/tools',
  headers: { 'Authorization' => 'Bearer sk-your-mcp-api-key' }
)

# MCP Client with resources
agent.add_mcp_server(
  'https://mcp.example.com/crm',
  headers: { 'Authorization' => 'Bearer sk-your-crm-key' },
  resources: true,
  resource_vars: { 'caller_id' => '${caller_id_number}', 'tenant' => 'acme-corp' }
)

# -- Agent Configuration ------------------------------------------------------
agent.prompt_add_section('Role',
                         'You are a helpful customer support agent. ' \
                         'Use the available tools to look up information and assist the caller.')

agent.params = { 'attention_timeout' => 15_000 }

# -- Local Tools ---------------------------------------------------------------
agent.define_tool(
  name: 'get_weather',
  description: 'Get the current weather for a location',
  parameters: {
    'location' => { 'type' => 'string', 'description' => 'City name or zip code' }
  }, handler: nil
) do |args, _raw|
  location = args['location'] || 'unknown'
  SignalWire::Swaig::FunctionResult.new("Currently 72F and sunny in #{location}.")
end

agent.define_tool(
  name: 'create_ticket',
  description: 'Create a support ticket for the customer',
  parameters: {
    'subject' => { 'type' => 'string', 'description' => 'Ticket subject' },
    'description' => { 'type' => 'string', 'description' => 'Detailed description' }
  }, handler: nil
) do |args, _raw|
  subject = args['subject'] || 'No subject'
  SignalWire::Swaig::FunctionResult.new("Ticket created: '#{subject}'. Reference number: TK-12345.")
end

agent.run
