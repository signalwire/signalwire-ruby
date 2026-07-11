# Getting Started with RELAY

The RELAY client connects to SignalWire over a WebSocket and gives you real-time,
imperative control over phone calls. The Ruby client is **thread-based** (it uses
`Mutex`/`ConditionVariable` internally, not async/await): call-control methods block
the calling thread until the server accepts the command, and each inbound call or
message handler runs on its own thread.

## Installation

The RELAY client ships in the `signalwire-sdk` gem:

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

Alternatively, you can authenticate with a JWT token:

| Parameter | Env Var | Description |
|-----------|---------|-------------|
| `jwt_token` | `SIGNALWIRE_JWT_TOKEN` | A SignalWire JWT auth token |

## Minimal Example

<!-- snippet: no-run connects to a live RELAY WebSocket via client.run; unreachable from the standalone snippet harness -->
```ruby
require 'signalwire'

client = SignalWire::Relay::Client.new(
  project:  'your-project-id',
  token:    'your-api-token',
  host:     'example.signalwire.com',
  contexts: ['default']
)

client.on_call do |call|
  call.answer
  action = call.play_tts('Hello!')
  action.wait
  call.hangup
end

client.run
```

Or use environment variables and skip the constructor args:

```bash
export SIGNALWIRE_PROJECT_ID=your-project-id
export SIGNALWIRE_API_TOKEN=your-api-token
export SIGNALWIRE_SPACE=example.signalwire.com
```

<!-- snippet: no-run connects to a live RELAY WebSocket via client.run; unreachable from the standalone snippet harness -->
```ruby
require 'signalwire'

client = SignalWire::Relay::Client.new(contexts: ['default'])

client.on_call do |call|
  call.answer
  call.hangup
end

client.run
```

## Contexts

Contexts are topics your client subscribes to for receiving inbound calls. When a
call arrives on a context you're subscribed to, your `on_call` handler is invoked.

<!-- snippet: no-run illustrative fragment: calls client.receive/unreceive on a client that never connected to a live RELAY server -->
```ruby
# Subscribe at connect time
client = SignalWire::Relay::Client.new(contexts: %w[sales support])

# Or dynamically after connecting
client.receive(['billing'])
client.unreceive(['sales'])
```

## Making Outbound Calls

Use `client.dial` to place an outbound call. It returns a live `Call` once answered:

```ruby
call = client.dial([
  [{ 'type' => 'phone', 'params' => { 'to_number' => '+15551234567', 'from_number' => '+15559876543' } }]
])
# call is now a live Call object
action = call.play_tts('This is an outbound call.')
action.wait
call.hangup
```

The outer list represents serial attempts; the inner list represents parallel
attempts. For example, to try two numbers simultaneously:

```ruby
call = client.dial([
  [
    { 'type' => 'phone', 'params' => { 'to_number' => '+15551111111', 'from_number' => '+15559876543' } },
    { 'type' => 'phone', 'params' => { 'to_number' => '+15552222222', 'from_number' => '+15559876543' } }
  ]
])
```

## Debug Logging

Set the log level to see WebSocket traffic:

```bash
export SIGNALWIRE_LOG_LEVEL=debug
```

## Shutting Down

`client.run` blocks until you stop it. Call `client.stop` (e.g. from a signal
handler or another thread) for a graceful shutdown:

```ruby
trap('INT') { client.stop }
client.run
```

## Next Steps

- [Call Methods Reference](call-methods.md) -- all methods available on a Call object
- [Events](events.md) -- handling real-time call events
- [Client Reference](client-reference.md) -- Client configuration and methods
```
