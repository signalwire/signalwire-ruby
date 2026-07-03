# SignalWire REST Client (Ruby)

Synchronous REST client for managing SignalWire resources, controlling live calls, and interacting with every SignalWire API surface from Ruby. No WebSocket required -- just standard HTTP requests.

## Quick Start

```ruby
require 'signalwire'

client = SignalWire::REST::RestClient.new(
  project: 'your-project-id',
  token:   'your-api-token',
  host:    'example.signalwire.com'
)

# Create an AI agent
agent = client.fabric.ai_agents.create(
  name:   'Support Bot',
  prompt: { 'text' => 'You are a helpful support agent.' }
)

# Search for a phone number
results = client.phone_numbers.search(area_code: '512')

# Place a call via REST
client.calling.dial(
  from_: '+15559876543',
  to:    '+15551234567',
  url:   'https://example.com/call-handler'
)
```

## Features

- Single `RestClient` with namespaced sub-objects for every API
- All 37 calling commands: dial, play, record, collect, detect, tap, stream, AI, transcribe, and more
- Full Fabric API: 13 resource types with CRUD + addresses, tokens, and generic resources
- Datasphere: document management and semantic search
- Video: rooms, sessions, recordings, conferences, tokens, streams
- Compatibility API: full Twilio-compatible LAML surface
- Phone number management, 10DLC registry, MFA, logs, and more
- Hash returns -- raw JSON, no wrapper objects to learn

## API Examples

### Fabric -- AI Agents

```ruby
agent = client.fabric.ai_agents.create(name: 'Bot', prompt: { 'text' => 'You are helpful.' })
agents = client.fabric.ai_agents.list
client.fabric.ai_agents.delete(agent['id'])
```

### Calling -- Play and Record

```ruby
call = client.calling.dial(from_: '+15559876543', to: '+15551234567', url: 'https://example.com/handler')
call_id = call['id']

client.calling.play(call_id, play: [{ 'type' => 'tts', 'text' => 'Hello!' }])
client.calling.record(call_id, beep: true, format: 'mp3')
client.calling.end_call(call_id, reason: 'hangup')
```

### Phone Numbers

```ruby
available = client.phone_numbers.search(area_code: '512', max_results: 3)
number = client.phone_numbers.create(number: '+15125551234')
client.phone_numbers.update(number['id'], name: 'Main Line')
client.phone_numbers.delete(number['id'])
```

### Datasphere -- Document Search

```ruby
doc = client.datasphere.documents.create(url: 'https://example.com/doc.txt', tags: ['support'])
results = client.datasphere.documents.search(query_string: 'billing question', count: 3)
client.datasphere.documents.delete(doc['id'])
```

### Video Rooms

```ruby
room = client.video.rooms.create(name: 'standup', max_members: 10)
token = client.video.room_tokens.create(room_name: 'standup', user_name: 'alice')
client.video.rooms.delete(room['id'])
```

### MFA

```ruby
result = client.mfa.sms(to: '+15551234567', from_: '+15559876543', message: 'Code: {{code}}', token_length: 6)
client.mfa.verify(result['id'], token: '123456')
```

## Documentation

- [Getting Started](docs/getting-started.md) -- installation, configuration, first API call
- [Client Reference](docs/client-reference.md) -- RestClient constructor, namespaces, error handling
- [Fabric Resources](docs/fabric.md) -- managing AI agents, SWML scripts, subscribers, call flows, and more
- [Calling Commands](docs/calling.md) -- REST-based call control (dial, play, record, collect, AI, etc.)
- [Compatibility API](docs/compat.md) -- Twilio-compatible LAML endpoints
- [All Namespaces](docs/namespaces.md) -- phone numbers, video, datasphere, logs, registry, and more

## Examples

- [rest_manage_resources.rb](examples/rest_manage_resources.rb) -- create an AI agent, assign a phone number, and place a test call
- [rest_datasphere_search.rb](examples/rest_datasphere_search.rb) -- upload a document and run a semantic search
- [rest_video_rooms.rb](examples/rest_video_rooms.rb) -- video rooms, sessions, conferences, and streaming

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SIGNALWIRE_PROJECT_ID` | Project ID for authentication |
| `SIGNALWIRE_API_TOKEN` | API token for authentication |
| `SIGNALWIRE_SPACE` | Space hostname (e.g. `example.signalwire.com`) |
| `SIGNALWIRE_LOG_LEVEL` | Log level (`debug` for HTTP request details) |

## Module Structure

```
lib/signalwire/rest/
    signalwire_client.rb  # RestClient -- namespace wiring, env var resolution
    http_client.rb        # HttpClient -- net/http wrapper with auth
    namespaces/
        fabric.rb         # 13 resource types + generic resources + addresses + tokens
        calling.rb        # 37 command dispatch methods
        phone_numbers.rb  # Search, purchase, update, release
        compat.rb         # Twilio-compatible LAML API
        video.rb          # Rooms, sessions, recordings, conferences
        datasphere.rb     # Documents, search, chunks
        ... and 15 more
```
