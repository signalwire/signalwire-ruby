# Call Methods Reference

A `Call` object represents a live phone call. You get one from `client.on_call` (inbound) or `client.dial` (outbound).

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `call_id` | `String` | Unique call identifier |
| `node_id` | `String` | Server node handling the call |
| `state` | `String` | Current state: `created`, `ringing`, `answered`, `ending`, `ended` |
| `direction` | `String` | `inbound` or `outbound` |
| `tag` | `String` | Correlation tag |
| `device` | `Hash` | Device info (type, params) |
| `segment_id` | `String` | Segment identifier |

## Actions: Blocking vs Fire-and-Forget

Methods like `play`, `record`, `detect`, etc. return **Action** objects. The `call.play(...)` call itself only waits for the server to accept the command — the actual operation runs asynchronously on the server (the RELAY client is thread-based). You choose how to handle completion:

### Wait inline (blocking)

```ruby
action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello' } }])
action.wait  # blocks until playback finishes
# execution continues only after play is done
```

### Fire and forget (background)

```ruby
action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello' } }])
# don't call action.wait — continue immediately while audio plays
call.send_digits(digits: '1234')

# check later if needed
puts "Play result: #{action.result}" if action.done?
```

### Fire with callback

```ruby
# Callback passed as a proc via on_completed:
action = call.play(
  [{ 'type' => 'tts', 'params' => { 'text' => 'Hello' } }],
  on_completed: ->(event) { puts "Done: #{event.params}" }
)
# continues immediately; callback fires when playback finishes

# Callback registered via a block on the returned action
action = call.record
action.on_completed do |event|
  puts "Recording URL: #{event.params['url']}"
  call.hangup
end
```

The `on_completed` callback is available on all action-based methods: `play`, `record`, `play_and_collect`, `collect`, `detect`, `pay`, `send_fax`, `receive_fax`, `tap_audio`, `stream`, `transcribe`, and `ai`. It accepts a proc/lambda (via `on_completed:`) or a block (via `action.on_completed`). Errors in callbacks are caught and logged, never crash the client. The callback also fires when the call is gone (404/410).

### Action methods summary

| Method | Returns |
|--------|---------|
| `action.wait(timeout: nil)` | Blocks until the action completes, returns the terminal `RelayEvent` |
| `action.done?` | `true` if the action has completed |
| `action.result` | The terminal `RelayEvent` (or `nil` if not done) |
| `action.completed` | `true` if the action reached a terminal state |
| `action.stop` | Stop the operation on the server |

Some actions also have `pause()`, `resume()`, and `volume()`.

## Lifecycle

### `answer(**kwargs) -> Hash`

Answer an inbound call.

```ruby
call.answer
```

### `hangup(reason: 'hangup') -> Hash`

End the call.

```ruby
call.hangup
call.hangup(reason: 'busy')
```

### `pass_call -> Hash`

Decline control, returning the call to routing. The method is named
`pass_call` in the Ruby port because `pass` is a method on `Object`.

```ruby
call.pass_call
```

## Audio Playback

### `play(media, volume: nil, direction: nil, loop_count: nil, control_id: nil, on_completed: nil, **kwargs) -> PlayAction`

Play audio. Returns a `PlayAction` with `stop()`, `pause()`, `resume()`, `volume()`, and `wait()`.

```ruby
# TTS (or use the convenience helper: call.play_tts('Hello!'))
action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Hello!' } }])
action.wait

# Audio file (or call.play_audio('https://example.com/sound.mp3'))
action = call.play([{ 'type' => 'audio', 'params' => { 'url' => 'https://example.com/sound.mp3' } }])

# Silence (or call.play_silence(2))
action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 2 } }])

# Ringtone (or call.play_ringtone('us'))
action = call.play([{ 'type' => 'ringtone', 'params' => { 'name' => 'us' } }])

# Control playback
action.pause
action.resume
action.volume(-3.0)
action.stop
```

## Recording

### `record(audio: nil, control_id: nil, on_completed: nil, **kwargs) -> RecordAction`

Record the call. Returns a `RecordAction` with `stop()`, `pause()`, `resume()`, and `wait()`.

```ruby
action = call.record(audio: { 'format' => 'wav', 'stereo' => true, 'direction' => 'both' })
# ... later ...
action.stop
event = action.wait
puts "Recording URL: #{event.params['url']}"
```

## Input Collection

### `play_and_collect(media, collect, volume: nil, control_id: nil, on_completed: nil, **kwargs) -> CollectAction`

Play audio and collect DTMF or speech input. Returns a `CollectAction`.

```ruby
action = call.play_and_collect(
  [{ 'type' => 'tts', 'params' => { 'text' => 'Press 1 for sales, 2 for support.' } }],
  { 'digits' => { 'max' => 1, 'digit_timeout' => 5.0 } }
)
event = action.wait
digit = event.params.dig('result', 'params', 'digits') || ''
```

### `collect(collect_opts, control_id: nil, **kwargs) -> StandaloneCollectAction`

Collect input without playing audio.

```ruby
action = call.collect(
  {
    'digits' => { 'max' => 4, 'terminators' => '#' },
    'speech' => { 'language' => 'en-US' },
    'partial_results' => true
  }
)
event = action.wait
```

## Bridging

### `connect(devices:, **kwargs) -> Hash`

Bridge the call to another destination.

```ruby
call.connect(
  devices: [[{ 'type' => 'phone', 'params' => { 'to_number' => '+15551234567', 'from_number' => '+15559876543' } }]],
  ringback: [{ 'type' => 'ringtone', 'params' => { 'name' => 'us' } }]
)
```

### `disconnect -> Hash`

Unbridge a connected call.

```ruby
call.disconnect
```

## DTMF

### `send_digits(digits:, control_id: nil, **kwargs) -> Hash`

Send DTMF tones.

```ruby
call.send_digits(digits: '1234#')
```

## Detection

### `detect(detect_opts, timeout: nil, control_id: nil, on_completed: nil, **kwargs) -> DetectAction`

Detect machine, fax, or digits.

```ruby
action = call.detect({ 'type' => 'machine' }, timeout: 30.0)
event = action.wait
```

## SIP Refer

### `refer(device:, **kwargs) -> Hash`

Transfer via SIP REFER.

```ruby
call.refer(device: { 'type' => 'sip', 'params' => { 'to' => 'sip:user@example.com' } })
```

## Transfer

### `transfer(dest:, **kwargs) -> Hash`

Transfer call control to another RELAY app or SWML script.

```ruby
call.transfer(dest: 'https://example.com/swml-endpoint')
```

## Fax

### `send_fax(document:, control_id: nil, on_completed: nil, **kwargs) -> FaxAction`

```ruby
action = call.send_fax(document: 'https://example.com/document.pdf', identity: '+15551234567')
event = action.wait
```

### `receive_fax(control_id: nil, on_completed: nil, **kwargs) -> FaxAction`

```ruby
action = call.receive_fax
event = action.wait
```

## Tap (Media Interception)

### `tap_audio(tap_opts, device:, control_id: nil, **kwargs) -> TapAction`

Intercept call media and stream to an RTP endpoint. Named `tap_audio` in the
Ruby port because `tap` is a method on `Object`.

```ruby
action = call.tap_audio(
  { 'type' => 'audio', 'params' => { 'direction' => 'both' } },
  device: { 'type' => 'rtp', 'params' => { 'addr' => '192.168.1.100', 'port' => 5000 } }
)
```

## Streaming

### `stream(url:, control_id: nil, on_completed: nil, **kwargs) -> StreamAction`

Stream call audio to a WebSocket endpoint.

```ruby
action = call.stream(
  url: 'wss://example.com/audio',
  name: 'my_stream',
  codec: 'PCMU',
  track: 'inbound_track'
)
# Stop streaming
action.stop
```

## Payment

### `pay(payment_connector_url:, control_id: nil, on_completed: nil, **kwargs) -> PayAction`

Collect a payment via DTMF.

```ruby
action = call.pay(
  payment_connector_url: 'https://pay.example.com',
  charge_amount: '25.99',
  currency: 'usd',
  input_method: 'dtmf'
)
event = action.wait
```

## Conference

### `join_conference(name:, **kwargs) -> Hash`

```ruby
call.join_conference(name: 'my_conference', muted: false, beep: 'onEnter')
```

### `leave_conference(conference_id:) -> Hash`

```ruby
call.leave_conference(conference_id: 'conf-123')
```

## Hold

### `hold -> Hash` / `unhold -> Hash`

```ruby
call.hold
# ... later ...
call.unhold
```

## Denoise

### `denoise -> Hash` / `denoise_stop -> Hash`

```ruby
call.denoise
# ... later ...
call.denoise_stop
```

## Transcription

### `transcribe(control_id: nil, on_completed: nil, **kwargs) -> TranscribeAction`

```ruby
action = call.transcribe(status_url: 'https://example.com/transcription')
# ... later ...
action.stop
```

## Live Transcribe / Translate

### `live_transcribe(action:, **kwargs) -> Hash`

```ruby
call.live_transcribe(action: { 'start' => { 'language' => 'en-US' } })
```

### `live_translate(action:, status_url: nil, **kwargs) -> Hash`

```ruby
call.live_translate(action: { 'start' => { 'source' => 'en-US', 'target' => 'es' } })
```

## Echo

### `echo(**kwargs) -> Hash`

Echo audio back to the caller (useful for testing).

```ruby
call.echo(timeout: 30.0)
```

## AI Agent

### `ai(control_id: nil, on_completed: nil, **kwargs) -> AIAction`

Start an AI agent session on the call.

```ruby
action = call.ai(
  prompt: { 'text' => 'You are a helpful support agent.' },
  SWAIG: { 'functions' => [] },
  ai_params: { 'end_of_speech_timeout' => 3000 }
)
event = action.wait
```

### `amazon_bedrock(**kwargs) -> Hash`

Connect to an Amazon Bedrock AI agent. Pass `prompt:`, `SWAIG:`, etc. as keyword arguments.

### `ai_message(**kwargs) -> Hash`

Send a message to an active AI session. Pass `message_text:`, `role:`, etc. as keyword arguments.

### `ai_hold(**kwargs) -> Hash` / `ai_unhold(**kwargs) -> Hash`

Put an AI session on/off hold. Pass `timeout:`, `prompt:`, etc. as keyword arguments.

## Rooms

### `join_room(name:, **kwargs) -> Hash`

```ruby
call.join_room(name: 'my_room')
```

### `leave_room -> Hash`

```ruby
call.leave_room
```

## Queue

### `queue_enter(queue_name:, control_id: nil, **kwargs) -> Hash`

```ruby
call.queue_enter(queue_name: 'support')
```

### `queue_leave(queue_name:, control_id: nil, **kwargs) -> Hash`

```ruby
call.queue_leave(queue_name: 'support', queue_id: 'q-123')
```

## Digit Bindings

### `bind_digit(digits:, bind_method:, **kwargs) -> Hash`

Bind a DTMF sequence to trigger a RELAY method.

```ruby
call.bind_digit(
  digits: '*1',
  bind_method: 'calling.play',
  bind_params: { 'play' => [{ 'type' => 'tts', 'params' => { 'text' => 'You pressed star-1' } }] }
)
```

### `clear_digit_bindings(**kwargs) -> Hash`

```ruby
call.clear_digit_bindings
```

## User Events

### `user_event(event: nil, **kwargs) -> Hash`

Send a custom event.

```ruby
call.user_event(event: 'order_placed', order_id: '12345')
```

## Event Handling

### `on(event_type, &handler)`

Register an event listener on this call. The handler is passed as a block.

```ruby
call.on('calling.call.play') do |event|
  puts "Play state: #{event.params['state']}"
end
```

### `wait_for_ended(timeout: nil) -> RelayEvent`

Wait for the call to end.

```ruby
event = call.wait_for_ended
puts "End reason: #{event.params['end_reason']}"
```
