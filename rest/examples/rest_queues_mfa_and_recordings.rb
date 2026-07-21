# frozen_string_literal: true

# Example: Call queues, recording review, and MFA verification.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# --- Queues ---

# 1. Create a queue
puts 'Creating call queue...'
queue_id = nil
queue = safe('Create queue') { client.queues.create(name: 'Support Queue', max_size: 50) }
queue_id = queue && queue['id']

# 2. List queues
puts "\nListing queues..."
queues = client.queues.list
(queues['data'] || []).each do |q|
  puts "  - #{q['id']}: #{q.fetch('friendly_name', q.fetch('name', 'unnamed'))}"
end

# 3. Get and update queue
if queue_id
  detail = client.queues.get(queue_id)
  puts "\nQueue detail: #{detail.fetch('friendly_name', 'N/A')} (max: #{detail.fetch('max_size', 'N/A')})"

  client.queues.update(queue_id, name: 'Priority Support Queue')
  puts '  Updated queue name'
end

# 4. Queue members
if queue_id
  puts "\nListing queue members..."
  begin
    members = client.queues.list_members(queue_id)
    (members['data'] || []).each do |m|
      puts "  - Member: #{m.fetch('call_id', m.fetch('id', 'unknown'))}"
    end

    next_member = client.queues.get_next_member(queue_id)
    puts "  Next member: #{next_member}"
  rescue SignalWire::REST::SignalWireRestError => e
    puts "  Member ops failed (expected if queue empty): #{e.status_code}"
  end
end

# --- Recordings ---

# 5. List recordings
puts "\nListing recordings..."
recordings = client.recordings.list
(recordings['data'] || []).first(5).each do |r|
  puts "  - #{r['id']}: #{r.fetch('duration', 'N/A')}s"
end

# 6. Get recording details
first_rec = (recordings['data'] || [{}]).first
if first_rec && first_rec['id']
  rec_detail = client.recordings.get(first_rec['id'])
  puts "  Recording: #{rec_detail.fetch('duration', 'N/A')}s, #{rec_detail.fetch('format', 'N/A')}"
end

# --- MFA ---

# 7. Send MFA via SMS
puts "\nSending MFA SMS code..."
request_id = nil
begin
  sms_result = client.mfa.sms(
    to:           '+15551234567',
    from:        '+15559876543',
    message:      'Your code is {{code}}',
    token_length: 6
  )
  request_id = sms_result['id'] || sms_result['request_id']
  puts "  MFA SMS sent: #{request_id}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  MFA SMS failed (expected in demo): #{e.status_code}"
end

# 8. Send MFA via voice call
puts "\nSending MFA voice code..."
begin
  voice_result = client.mfa.call(
    to:           '+15551234567',
    from:        '+15559876543',
    message:      'Your verification code is {{code}}',
    token_length: 6
  )
  puts "  MFA call sent: #{voice_result['id'] || voice_result['request_id']}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  MFA call failed (expected in demo): #{e.status_code}"
end

# 9. Verify MFA token
if request_id
  puts "\nVerifying MFA token..."
  safe('Verify token') { client.mfa.verify(request_id, token: '123456') }
end

# 10. Clean up
puts "\nCleaning up..."
safe('Delete queue') { client.queues.delete(queue_id) } if queue_id
