# MCP Integration

The SDK supports the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) in two ways:

1. **MCP Client** — Connect to external MCP servers and use their tools in your agent
2. **MCP Server** — Expose your agent's `define_tool` functions as an MCP endpoint for other clients

These features are independent and can be used separately or together.

## Adding External MCP Servers

Use `add_mcp_server` to connect your agent to remote MCP servers. Tools are discovered at call start via the MCP protocol and added to the AI's tool list alongside your `define_tool` functions.

```ruby
require 'signalwire'

class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent', route: '/agent')

    add_mcp_server(
      'https://mcp.example.com/tools',
      headers: { 'Authorization' => 'Bearer sk-xxx' }
    )
  end
end
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `url` | String | MCP server HTTP endpoint URL |
| `headers` | Hash | Optional HTTP headers for authentication |
| `resources` | Boolean | Fetch resources into `global_data` (default: `false`) |
| `resource_vars` | Hash | Variables for URI template substitution |

### With Resources

MCP servers can expose read-only data as resources. When enabled, resources are fetched at session start and merged into `global_data`:

<!-- snippet: no-run illustrative fragment: add_mcp_server/enable_mcp_server are AgentBase instance methods shown outside an agent class -->
```ruby
add_mcp_server(
  'https://mcp.example.com/crm',
  headers: { 'Authorization' => 'Bearer sk-xxx' },
  resources: true,
  resource_vars: { 'caller_id' => '${caller_id_number}' }
)
```

Resource data is available in prompts via `${global_data.key}` and included in every webhook call.

### Multiple Servers

<!-- snippet: no-run illustrative fragment: add_mcp_server/enable_mcp_server are AgentBase instance methods shown outside an agent class -->
```ruby
add_mcp_server('https://mcp-search.example.com/tools',
  headers: { 'Authorization' => 'Bearer search-key' })
add_mcp_server('https://mcp-crm.example.com/tools',
  headers: { 'Authorization' => 'Bearer crm-key' })
```

Tools from all servers are merged into one list. If an MCP tool has the same name as a `define_tool` function, your local function's description is used but execution routes through MCP.

## Exposing Tools as MCP Server

Use `enable_mcp_server` to add an MCP endpoint at `/mcp` on your agent's server. Any MCP client can connect and use your `define_tool` functions.

```ruby
require 'signalwire'

class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent', route: '/agent')
    enable_mcp_server

    define_tool(
      name: 'get_weather',
      description: 'Get weather for a location',
      parameters: {
        'location' => { 'type' => 'string', 'description' => 'City name' }
      }, handler: nil
    ) do |args, _raw_data|
      location = args['location'] || 'unknown'
      SignalWire::Swaig::FunctionResult.new("72F sunny in #{location}")
    end
  end
end
```

The `/mcp` endpoint handles the full MCP protocol:
- `initialize` — protocol version and capability negotiation
- `notifications/initialized` — ready signal
- `tools/list` — returns all `define_tool` functions in MCP format
- `tools/call` — invokes the handler and returns the result
- `ping` — keepalive

### Connecting from Claude Desktop

Add your agent as an MCP server in Claude Desktop's config:

```json
{
    "mcpServers": {
        "my-agent": {
            "url": "https://your-server.com/agent/mcp"
        }
    }
}
```

Your `define_tool` functions are now available in Claude Desktop conversations.

## Using Both Together

The two features are independent:

```ruby
require 'signalwire'

class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent', route: '/agent')

    # Expose my tools as MCP (for Claude Desktop, other agents)
    enable_mcp_server

    # Pull in tools from external MCP servers (for voice calls)
    add_mcp_server('https://mcp.example.com/crm',
      headers: { 'Authorization' => 'Bearer sk-xxx' },
      resources: true)

    define_tool(
      name: 'transfer_call',
      description: 'Transfer the caller',
      parameters: {}, handler: nil
    ) do |_args, _raw_data|
      # This tool is available both as MCP AND as SWAIG webhook
      SignalWire::Swaig::FunctionResult.new('Transferring now.')
    end
  end
end
```

In this setup:
- Voice calls use `transfer_call` via SWAIG webhook + CRM tools via MCP
- Claude Desktop uses `transfer_call` via MCP endpoint
- The same tool code serves both protocols

### Self-Referencing

If you want your agent's voice calls to also discover tools via MCP instead of webhooks:

<!-- snippet: no-run illustrative fragment: add_mcp_server/enable_mcp_server are AgentBase instance methods shown outside an agent class -->
```ruby
enable_mcp_server
add_mcp_server('https://your-server.com/agent/mcp')
```

This is optional — by default, `enable_mcp_server` only adds the endpoint without affecting the agent's own SWML output.

## MCP vs SWAIG Webhooks

| | SWAIG Webhooks | MCP Tools |
|---|---|---|
| Response format | JSON with `response`, `action`, `SWML` | Text content only |
| Call control | Can trigger hold, transfer, SWML | Response only |
| Discovery | Defined in SWML config | Auto-discovered via protocol |
| Auth | `web_hook_auth_user/password` | `headers` dict |

MCP tools are best for data retrieval. Use `define_tool` functions with SWAIG webhooks when you need call control actions.
