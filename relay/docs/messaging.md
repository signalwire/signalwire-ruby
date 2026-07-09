# Messaging

Send and receive SMS/MMS messages through the RELAY client.

## Sending Messages

Use `client.send_message()` to send an outbound SMS or MMS.

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Hello from SignalWire!'
)
```

### Wait for delivery

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Hello!'
)
event = message.wait # blocks until delivered/failed
puts "Final state: #{message.state}"
puts "Reason: #{message.reason}" if message.reason
```

### Fire and forget

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Hello!'
)
# don't call message.wait — continue immediately
```

### Callback on completion

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Hello!',
  on_completed: ->(event) { puts "Delivery: #{event.params['message_state']}" }
)
```

### MMS (media messages)

```ruby
message = client.send_message(
  to_number: '+15552222222',
  from_number: '+15551111111',
  body: 'Check this out!',
  media: ['https://example.com/image.jpg']
)
```

### All parameters

```ruby
message = client.send_message(
  to_number: '+15552222222',       # required — E.164 format
  from_number: '+15551111111',     # required — E.164 format
  body: 'Message text',            # required if no media
  media: ['https://...'],          # required if no body
  context: 'my_context',           # context for state events (default: relay protocol)
  tags: %w[vip support],           # optional tags for searching in UI
  region: 'us',                    # optional origination region
  on_completed: callback           # optional completion callback (a callable)
)
```

## Receiving Messages

Register a handler with `@client.on_message` to receive inbound SMS/MMS.

<!-- snippet: no-run connects to a live RELAY WebSocket via client.run; unreachable from the standalone snippet harness -->
```ruby
require 'signalwire'

client = SignalWire::Relay::Client.new(
  project: 'your-project-id',
  token: 'your-api-token',
  host: 'example.signalwire.com',
  contexts: ['default']
)

client.on_message do |message|
  puts "From: #{message.from_number}"
  puts "To: #{message.to_number}"
  puts "Body: #{message.body}"
  puts "Media: #{message.media}" unless message.media.nil? || message.media.empty?

  # Reply back
  client.send_message(
    to_number: message.from_number,
    from_number: message.to_number,
    body: "You said: #{message.body}"
  )
end

client.run
```

## Message Object

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `message_id` | `str` | Unique message identifier |
| `context` | `str` | Context the message belongs to |
| `direction` | `str` | `inbound` or `outbound` |
| `from_number` | `str` | Sender phone number (E.164) |
| `to_number` | `str` | Recipient phone number (E.164) |
| `body` | `str` | Text body of the message |
| `media` | `list[str]` | Media URLs (MMS) |
| `segments` | `int` | Number of message segments |
| `state` | `str` | Current message state |
| `reason` | `str` | Failure reason (on `undelivered` or `failed`) |
| `tags` | `list[str]` | Tags attached to the message |
| `is_done` | `bool` | `True` if message reached a terminal state |
| `result` | `RelayEvent` | Terminal event (or `None` if not done) |

### Methods

| Method | Description |
|--------|-------------|
| `message.wait(timeout: nil)` | Block until terminal state. Returns the terminal `RelayEvent`. |
| `message.on_event { |event| ... }` | Register a listener block for state change events. |

### Message States

Outbound messages progress through these states:

| State | Description |
|-------|-------------|
| `queued` | Message accepted and queued for sending |
| `initiated` | Sending has started |
| `sent` | Message sent to carrier |
| `delivered` | Message delivered to recipient (terminal) |
| `undelivered` | Delivery failed (terminal) — check `reason` |
| `failed` | Message failed to send (terminal) — check `reason` |

Inbound messages always arrive with state `received`.

## Event Types

| Event | Description |
|-------|-------------|
| `MessageReceiveEvent` | Inbound message received |
| `MessageStateEvent` | Outbound message state change |

```ruby
require 'signalwire'
# SignalWire::Relay::MessageReceiveEvent, SignalWire::Relay::MessageStateEvent
```

## Combining Calls and Messages

The same `RelayClient` handles both calls and messages:

<!-- snippet: no-run connects to a live RELAY WebSocket via client.run; unreachable from the standalone snippet harness -->
```ruby
client = SignalWire::Relay::Client.new(project: '...', token: '...', contexts: ['default'])

client.on_call do |call|
  call.answer
  call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello!' } }])
  call.hangup
end

client.on_message do |message|
  puts "SMS from #{message.from_number}: #{message.body}"
end

client.run
```
