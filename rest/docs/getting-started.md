# Getting Started with the REST Client

The REST client provides synchronous access to all SignalWire APIs using standard HTTP requests. No WebSocket connection required.

## Installation

The REST client ships in the `signalwire-sdk` gem:

```bash
gem install signalwire-sdk
```

Or add it to your `Gemfile`:

```ruby
gem 'signalwire-sdk', require: 'signalwire'
```

## Configuration

You need three things to connect:

| Parameter | Env Var | Description |
|-----------|---------|-------------|
| `project` | `SIGNALWIRE_PROJECT_ID` | Your SignalWire project ID |
| `token` | `SIGNALWIRE_API_TOKEN` | Your SignalWire API token |
| `host` | `SIGNALWIRE_SPACE` | Your space hostname (e.g. `example.signalwire.com`) |

## Minimal Example

```ruby
require 'signalwire'

client = SignalWire::REST::RestClient.new(
  project: 'your-project-id',
  token:   'your-api-token',
  host:    'example.signalwire.com'
)

# List your AI agents
agents = client.fabric.ai_agents.list
puts agents
```

Or use environment variables and skip the constructor args:

```bash
export SIGNALWIRE_PROJECT_ID=your-project-id
export SIGNALWIRE_API_TOKEN=your-api-token
export SIGNALWIRE_SPACE=example.signalwire.com
```

```ruby
require 'signalwire'

client = SignalWire::REST::RestClient.new
agents = client.fabric.ai_agents.list
```

## CRUD Pattern

Most resources follow the same CRUD pattern:

```ruby
# List
items = client.fabric.ai_agents.list

# Create
agent = client.fabric.ai_agents.create(name: 'Support', prompt: { 'text' => 'Be helpful' })

# Get by ID
agent = client.fabric.ai_agents.get('agent-uuid')

# Update
client.fabric.ai_agents.update('agent-uuid', name: 'Updated Name')

# Delete
client.fabric.ai_agents.delete('agent-uuid')
```

Fabric resources also support listing addresses:

```ruby
addresses = client.fabric.ai_agents.list_addresses('agent-uuid')
```

Calls return plain Ruby Hashes (parsed JSON) -- there are no wrapper objects.

## Error Handling

A non-2xx response raises `SignalWire::REST::SignalWireRestError`, which exposes
`status_code` and `body`:

```ruby
require 'signalwire'

client = SignalWire::REST::RestClient.new

begin
  agent = client.fabric.ai_agents.get('nonexistent-id')
rescue SignalWire::REST::SignalWireRestError => e
  puts "HTTP #{e.status_code}: #{e.body}"
  # HTTP 404: {"error"=>"not found"}
end
```

## Debug Logging

Set the log level to see HTTP request details:

```bash
export SIGNALWIRE_LOG_LEVEL=debug
```

## Next Steps

- [Client Reference](client-reference.md) -- all namespaces and constructor options
- [Fabric Resources](fabric.md) -- managing AI agents, SWML scripts, and more
- [Calling Commands](calling.md) -- REST-based call control
- [All Namespaces](namespaces.md) -- phone numbers, video, datasphere, and more
