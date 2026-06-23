# MCP to SWAIG Gateway (Ruby)

## Overview

The MCP-SWAIG Gateway bridges Model Context Protocol (MCP) servers with SignalWire
AI Gateway (SWAIG) functions, letting SignalWire AI agents call MCP-based tools.

The Ruby gem ships the **client side** of this bridge -- the `mcp_gateway` built-in
skill, which connects an agent to a running gateway service and exposes that
gateway's MCP tools as SWAIG functions. The **gateway service itself** (the
long-running HTTP server that manages MCP server processes, sandboxing, sessions,
and rate limiting) is part of the Python reference and is not packaged in the Ruby
gem. Run the gateway service from the Python reference, then point the Ruby skill at
it via `gateway_url`.

If you want an agent to talk to MCP servers directly (without a gateway service),
use `add_mcp_server` / `enable_mcp_server` on `AgentBase` -- see
[MCP Integration](mcp_integration.md).

## Using the `mcp_gateway` Skill

Add the skill and point it at your gateway service:

```ruby
agent.add_skill('mcp_gateway', {
  'gateway_url'   => 'https://localhost:8080',
  'auth_user'     => 'admin',
  'auth_password' => 'changeme',
  'services'      => [
    { 'name' => 'todo', 'tools' => %w[add_todo list_todos] }, # specific tools only
    { 'name' => 'calculator', 'tools' => '*' }                # all tools
  ],
  'tool_prefix'   => 'mcp_'   # prefix for generated SWAIG function names
})
```

### Skill Parameters

| Parameter | Type | Description |
|---|---|---|
| `gateway_url` | String | Gateway service base URL (required) |
| `auth_user` | String | Basic-auth username for the gateway |
| `auth_password` | String | Basic-auth password for the gateway |
| `auth_token` | String | Bearer token (alternative to basic auth) |
| `services` | Array | Services/tools to expose (`{ 'name' => ..., 'tools' => [...] \| '*' }`) |
| `tool_prefix` | String | Prefix for generated SWAIG function names (default: `mcp_`) |
| `request_timeout` | Integer | Per-request timeout in seconds (default: 30) |

## Gateway Service

The gateway service, its `mcp-gateway` CLI, its `config.json` format
(`server` / `services` / `session` / `rate_limiting` / `logging` sections),
process sandboxing, and the Docker deployment tooling live in the **Python
reference**. The Ruby skill only consumes the service's HTTP API; consult the
Python reference's MCP gateway documentation to configure and deploy the service.

## Examples

- [`examples/mcp_gateway_demo.rb`](../examples/mcp_gateway_demo.rb) -- agent
  connecting to MCP servers through the `mcp_gateway` skill.
- [`examples/mcp_agent.rb`](../examples/mcp_agent.rb) -- agent using direct MCP
  integration via `add_mcp_server` / `enable_mcp_server`.

## See Also

- [MCP Integration](mcp_integration.md) -- direct MCP client/server support on `AgentBase`
- [Skills System Guide](skills_system.md) -- the built-in skills framework
