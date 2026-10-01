# frozen_string_literal: true

# Example: IVR input collection, AI operations, and advanced call control.
#
# NOTE: These commands require an active call. The call_id used here is
# illustrative -- in production you would obtain it from a dial response or
# inbound call event.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client' # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

CALL_ID = 'demo-call-id'

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# control_id identifies an in-progress media operation (returned in the command's
# response in production); a demo value keeps these examples self-contained.
CONTROL_ID = 'demo-control-id'

# 1. Collect DTMF input
puts 'Collecting DTMF input...'
safe('Collect') do
  client.calling.collect(
    CALL_ID,
    control_id: CONTROL_ID,
    digits: { 'max' => 4, 'terminators' => '#' }
  )
end
safe('Start input timers') { client.calling.collect_start_input_timers(CALL_ID, control_id: CONTROL_ID) }
safe('Stop collect')       { client.calling.collect_stop(CALL_ID, control_id: CONTROL_ID) }

# 2. Answering machine detection
puts "\nDetecting answering machine..."
safe('Detect')      { client.calling.detect(CALL_ID, detect: { 'type' => 'machine' }) }
safe('Stop detect') { client.calling.detect_stop(CALL_ID, control_id: CONTROL_ID) }

# 3. AI operations
puts "\nAI agent operations..."
safe('AI message') { client.calling.ai_message(CALL_ID, message_text: 'The customer wants to check their balance.') }
safe('AI hold')    { client.calling.ai_hold(CALL_ID) }
safe('AI unhold')  { client.calling.ai_unhold(CALL_ID) }
safe('AI stop')    { client.calling.ai_stop(CALL_ID, control_id: CONTROL_ID) }

# 4. Live transcription and translation
puts "\nLive transcription and translation..."
safe('Live transcribe') { client.calling.live_transcribe(CALL_ID, action: { 'start' => { 'lang' => 'en-US' } }) }
safe('Live translate')  { client.calling.live_translate(CALL_ID, action: { 'start' => { 'to_lang' => 'es' } }) }

# 5. Tap (media fork)
puts "\nTap (media fork)..."
safe('Tap start') do
  client.calling.tap(
    CALL_ID,
    tap: { 'type' => 'audio', 'direction' => 'both' },
    device: { 'type' => 'rtp', 'addr' => '192.168.1.100', 'port' => 9000 }
  )
end
safe('Tap stop') { client.calling.tap_stop(CALL_ID, control_id: CONTROL_ID) }

# 6. Stream (WebSocket)
puts "\nStream (WebSocket)..."
safe('Stream start') { client.calling.stream(CALL_ID, url: 'wss://example.com/audio-stream') }
safe('Stream stop')  { client.calling.stream_stop(CALL_ID, control_id: CONTROL_ID) }

# 7. User event
puts "\nSending user event..."
safe('User event') do
  client.calling.user_event(CALL_ID, event: { 'name' => 'agent_note', 'note' => 'VIP caller' })
end

# 8. SIP refer
puts "\nSIP refer..."
safe('SIP refer') { client.calling.refer(CALL_ID, device: { 'type' => 'sip', 'to' => 'sip:support@example.com' }) }

# 9. Fax stop commands
puts "\nFax stop commands..."
safe('Send fax stop')    { client.calling.send_fax_stop(CALL_ID, control_id: CONTROL_ID) }
safe('Receive fax stop') { client.calling.receive_fax_stop(CALL_ID, control_id: CONTROL_ID) }

# 10. Transfer and disconnect
puts "\nTransfer and disconnect..."
safe('Transfer') { client.calling.transfer(CALL_ID, dest: '+15559999999') }
safe('Update call') { client.calling.update(id: CALL_ID, status: 'completed') }
safe('Disconnect')  { client.calling.disconnect(CALL_ID) }
