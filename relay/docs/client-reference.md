# RelayClient Reference

<!-- snippet-setup: every ruby example on this page assumes the RELAY client is required -->
```ruby
require 'signalwire'
require 'signalwire/relay/client'
```

## Constructor

```ruby
SignalWire::Relay::Client.new(
  project:          nil,        # SIGNALWIRE_PROJECT_ID
  token:            nil,        # SIGNALWIRE_API_TOKEN
  jwt_token:        nil,        # SIGNALWIRE_JWT_TOKEN
  host:             nil,        # SIGNALWIRE_SPACE (default: relay.signalwire.com)
  contexts:         ['default'], # Topics to subscribe to
  max_active_calls: nil         # RELAY_MAX_ACTIVE_CALLS (default: 1000)
)
```

Authentication requires either `project` + `token` (legacy) or `jwt_token` (faster, no server roundtrip). All parameters fall back to their corresponding environment variables.

## Methods

### `run()`

Blocking entry point. Connects, authenticates, and runs the event loop with auto-reconnect until interrupted.

```ruby
client.run
```

### `connect` / `stop`

Manual lifecycle control. `connect` brings the WebSocket up and returns without
entering the blocking reconnect loop; `stop` (also exposed as `disconnect`) tears
the connection down gracefully. Use `run` instead when you want the blocking,
auto-reconnecting event loop.

```ruby
client.connect
# ... use client ...
client.stop
```

Wrap the teardown in an `ensure` block so the connection is always closed:

<!-- snippet: no-run calls client.connect, which opens a live RELAY WebSocket unreachable from the standalone snippet harness -->
```ruby
client = SignalWire::Relay::Client.new(contexts: ['default'])
client.connect
begin
  # ... use client ...
ensure
  client.stop
end
```

### `on_call(handler)`

Register the inbound call handler by passing a block. The block receives a `Call` object.

```ruby
client.on_call do |call|
  call.answer
end
```

### `dial(devices, timeout: 120, tag: nil) -> Call`

Place an outbound call. Returns a `Call` once the remote party answers.

- `devices` -- nested list of device objects (serial/parallel dial)
- `tag` -- optional correlation tag (auto-generated if omitted)
- `timeout` -- seconds to wait before raising `RelayError` (default: 120)

```ruby
call = client.dial([
  [{ 'type' => 'phone', 'params' => { 'to_number' => '+15551234567', 'from_number' => '+15559876543' } }]
])
```

### `on_message(handler)`

Register the inbound message handler by passing a block. The block receives a `Message` object.

```ruby
client.on_message do |message|
  puts "SMS from #{message.from_number}: #{message.body}"
end
```

### `send_message(*, to_number, from_number, body=None, media=None, ...) -> Message`

Send an outbound SMS/MMS. Returns a `Message` that tracks delivery state.

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Hello!'
)
event = message.wait # block until delivered/failed
```

See [Messaging](messaging.md) for full details.

### `execute(method, params) -> dict`

Send a raw JSON-RPC request. Used internally by Call methods, but available for custom commands.

### `receive(contexts) / unreceive(contexts)`

Dynamically subscribe to or unsubscribe from contexts after connecting.

```ruby
client.receive(['new-context'])
client.unreceive(['old-context'])
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `relay_protocol` | `str` | Server-assigned protocol string from connect response |
| `project` | `str` | Project ID |
| `host` | `str` | Relay host |
| `contexts` | `list[str]` | Initial contexts |

## Connection Behavior

- **Auto-reconnect**: On connection loss, the client reconnects with exponential backoff (1s to 30s).
- **Ping/pong**: Client sends periodic pings and monitors server pings. After 3 consecutive failures, the connection is force-closed and reconnected.
- **Request queueing**: Requests made while disconnected are queued and sent after re-authentication.
- **Authorization state**: The server sends encrypted auth state via events. On reconnect, this is sent back for fast re-authentication without a full auth roundtrip.
- **Server disconnect**: The server can request a graceful disconnect (e.g. during deployment). The client auto-reconnects afterward.

## Concurrency

Each inbound call handler runs as an independent `asyncio.Task`, so multiple calls are handled concurrently. The `max_active_calls` parameter (default: 1000) caps concurrent calls to prevent unbounded memory growth.

For multiple WebSocket connections in one process, set `RELAY_MAX_CONNECTIONS` (default: 1).

## Error Handling

```ruby
require 'signalwire'

begin
  call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello' } }])
rescue SignalWire::Relay::RelayError => e
  puts "Error #{e.code}: #{e.error_message}"
end
```

`RelayError` is raised when the server returns a non-2xx response code. Errors 404 and 410 (call gone) are silently swallowed by Call methods since the call no longer exists.
