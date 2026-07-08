# SignalWire RELAY Client (Ruby)

Real-time call control and messaging over WebSocket using Ruby threads. The RELAY client connects to SignalWire via the Blade protocol (JSON-RPC 2.0 over WebSocket) and gives you imperative control over live phone calls and SMS/MMS messaging.

## Quick Start

```ruby
require 'signalwire'

client = SignalWire::Relay::Client.new(
  project:  'your-project-id',
  token:    'your-api-token',
  space:    'example.signalwire.com',
  contexts: ['default']
)

client.on_call do |call|
  call.answer
  action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire!' } }])
  action.wait
  call.hangup
end

client.run
```

## Features

- Thread-safe with auto-reconnect and exponential backoff
- All 57+ calling methods: play, record, collect, connect, detect, fax, tap, stream, AI, conferencing, queues, and more
- SMS/MMS messaging: send outbound messages, receive inbound messages, track delivery state
- Action objects with `wait`, `stop`, `pause`, `resume` for controllable operations
- JWT and legacy authentication
- Dynamic context subscription/unsubscription

## API Examples

### Answer and Play TTS

```ruby
client.on_call do |call|
  call.answer
  action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello!' } }])
  action.wait
  call.hangup
end
```

### Outbound Dial

```ruby
devices = [[{ 'type' => 'phone', 'params' => { 'to_number' => '+15551234567', 'from_number' => '+15559876543' } }]]
call = client.dial(devices)
puts "Call answered: #{call.call_id}"

action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome!' } }])
action.wait
call.hangup
```

### Collect DTMF

```ruby
client.on_call do |call|
  call.answer
  action = call.play_and_collect(
    media: [{ 'type' => 'tts', 'params' => { 'text' => 'Press 1 for sales, 2 for support.' } }],
    collect: { 'digits' => { 'max' => 1, 'digit_timeout' => 5.0 }, 'initial_timeout' => 10.0 }
  )
  result = action.wait
  digits = result.params.dig('result', 'params', 'digits')
  puts "User pressed: #{digits}"
  call.hangup
end
```

### Send SMS

```ruby
msg = client.send_message(
  to:   '+15551234567',
  from: '+15559876543',
  body: 'Hello from SignalWire!'
)
puts "Message queued: #{msg.message_id}"
```

### Connect (Transfer)

```ruby
call.connect(
  devices: [[{ 'type' => 'phone', 'params' => { 'to_number' => '+15559999999', 'from_number' => '+15551234567' } }]],
  ringback: [{ 'type' => 'tts', 'params' => { 'text' => 'Please wait while we connect your call.' } }]
)
call.wait_for_ended
```

## Documentation

- [Getting Started](docs/getting-started.md) -- installation, configuration, first call
- [Call Methods Reference](docs/call-methods.md) -- every method available on a Call object
- [Events](docs/events.md) -- event types, call states
- [Messaging](docs/messaging.md) -- sending and receiving SMS/MMS messages
- [Client Reference](docs/client-reference.md) -- Client configuration, methods, connection behavior

## Examples

- [relay_answer_and_welcome.rb](examples/relay_answer_and_welcome.rb) -- answer an inbound call and play a TTS greeting
- [relay_dial_and_play.rb](examples/relay_dial_and_play.rb) -- dial outbound and play TTS
- [relay_ivr_connect.rb](examples/relay_ivr_connect.rb) -- IVR menu with DTMF and call connect

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SIGNALWIRE_PROJECT_ID` | Project ID for authentication |
| `SIGNALWIRE_API_TOKEN` | API token for authentication |
| `SIGNALWIRE_JWT_TOKEN` | JWT token (alternative to project/token) |
| `SIGNALWIRE_SPACE` | Space hostname (default: `relay.signalwire.com`) |
| `SIGNALWIRE_LOG_LEVEL` | Log level (`debug` for WebSocket traffic) |

## Module Structure

```
lib/signalwire/relay/
    client.rb       # Client -- WebSocket connection, auth, event dispatch
    call.rb         # Call object -- all calling methods and Action classes
    action.rb       # Action object -- wait, stop, pause, resume
    message.rb      # Message object -- SMS/MMS message tracking
    relay_event.rb  # Event data class
    constants.rb    # Protocol constants, call states, event types
```
