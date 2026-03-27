# frozen_string_literal: true

# Example: Twilio-compatible LAML migration -- phone numbers, messaging, calls,
# conferences, queues, recordings, project tokens, PubSub/Chat, and logs.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# --- Compat Phone Numbers ---

# 1. Search available numbers
puts 'Searching compat phone numbers...'
safe('Search local')      { client.compat.phone_numbers.search_local('US', AreaCode: '512') }
safe('Search toll-free')  { client.compat.phone_numbers.search_toll_free('US') }
safe('List countries')    { client.compat.phone_numbers.list_available_countries }

# 2. Purchase a number (demo -- will fail without valid number)
puts "\nPurchasing compat number..."
num = safe('Purchase') { client.compat.phone_numbers.purchase(PhoneNumber: '+15125551234') }
num_sid = num && num['sid']

# --- LaML Bin & Application ---

# 3. Create a LaML bin and application
puts "\nCreating LaML resources..."
laml = safe('LaML bin') do
  client.compat.laml_bins.create(
    Name:     'Hold Music',
    Contents: '<Response><Say>Please hold.</Say></Response>'
  )
end
laml_sid = laml && laml['sid']

app = safe('Application') do
  client.compat.applications.create(
    FriendlyName: 'Demo App',
    VoiceUrl:     'https://example.com/voice'
  )
end
app_sid = app && app['sid']

# --- Messaging ---

# 4. Send an SMS (demo -- requires valid numbers)
puts "\nMessaging operations..."
msg = safe('Send SMS') do
  client.compat.messages.create(
    From: '+15559876543', To: '+15551234567', Body: 'Hello from SignalWire!'
  )
end
msg_sid = msg && msg['sid']

# 5. List and get messages
safe('List messages') { client.compat.messages.list }
if msg_sid
  safe('Get message')  { client.compat.messages.get(msg_sid) }
  safe('List media')   { client.compat.messages.list_media(msg_sid) }
end

# --- Calls ---

# 6. Outbound call with recording and streaming
puts "\nCall operations..."
call = safe('Create call') do
  client.compat.calls.create(
    From: '+15559876543', To: '+15551234567',
    Url:  'https://example.com/voice-handler'
  )
end
call_sid = call && call['sid']

if call_sid
  safe('Start recording') { client.compat.calls.start_recording(call_sid) }
  safe('Start stream')    { client.compat.calls.start_stream(call_sid, Url: 'wss://example.com/stream') }
end

# --- Conferences ---

# 7. Conference operations
puts "\nConference operations..."
confs = safe('List conferences') { client.compat.conferences.list }
conf_sid = confs && (confs['data'] || []).first&.dig('sid')

if conf_sid
  safe('Get conference')     { client.compat.conferences.get(conf_sid) }
  safe('List participants')  { client.compat.conferences.list_participants(conf_sid) }
  safe('List conf recordings') { client.compat.conferences.list_recordings(conf_sid) }
end

# --- Queues ---

# 8. Queue operations
puts "\nQueue operations..."
queue = safe('Create queue') { client.compat.queues.create(FriendlyName: 'compat-support-queue') }
q_sid = queue && queue['sid']

if q_sid
  safe('List queue members') { client.compat.queues.list_members(q_sid) }
end

# --- Recordings & Transcriptions ---

# 9. Recordings and transcriptions
puts "\nRecordings and transcriptions..."
recs = safe('List recordings') { client.compat.recordings.list }
first_rec_sid = recs && (recs['data'] || []).first&.dig('sid')
safe('Get recording') { client.compat.recordings.get(first_rec_sid) } if first_rec_sid

trans = safe('List transcriptions') { client.compat.transcriptions.list }
first_trans_sid = trans && (trans['data'] || []).first&.dig('sid')
safe('Get transcription') { client.compat.transcriptions.get(first_trans_sid) } if first_trans_sid

# --- Faxes ---

# 10. Fax operations
puts "\nFax operations..."
fax = safe('Create fax') do
  client.compat.faxes.create(
    From: '+15559876543', To: '+15551234567',
    MediaUrl: 'https://example.com/document.pdf'
  )
end
fax_sid = fax && fax['sid']
safe('Get fax') { client.compat.faxes.get(fax_sid) } if fax_sid

# --- Compat Accounts & Tokens ---

# 11. Accounts and compat tokens
puts "\nAccounts and compat tokens..."
safe('List accounts') { client.compat.accounts.list }
compat_token = safe('Create compat token') { client.compat.tokens.create(name: 'demo-token') }
if compat_token && compat_token['id']
  safe('Delete compat token') { client.compat.tokens.delete(compat_token['id']) }
end

# --- Project Tokens ---

# 12. Project token management
puts "\nProject tokens..."
proj_token = safe('Create project token') do
  client.project.tokens.create(name: 'CI Token', permissions: %w[calling messaging video])
end
if proj_token && proj_token['id']
  safe('Update project token') { client.project.tokens.update(proj_token['id'], name: 'CI Token (updated)') }
  safe('Delete project token') { client.project.tokens.delete(proj_token['id']) }
end

# --- PubSub & Chat Tokens ---

# 13. PubSub and Chat tokens
puts "\nPubSub and Chat tokens..."
safe('PubSub token') do
  client.pubsub.create_token(channels: { 'notifications' => { 'read' => true, 'write' => true } }, ttl: 3600)
end
safe('Chat token') do
  client.chat.create_token(
    member_id: 'user-alice',
    channels:  { 'general' => { 'read' => true, 'write' => true } },
    ttl:       3600
  )
end

# --- Logs ---

# 14. Log queries
puts "\nQuerying logs..."
safe('Message logs')    { client.logs.messages.list }
safe('Voice logs')      { client.logs.voice.list }
safe('Fax logs')        { client.logs.fax.list }
safe('Conference logs') { client.logs.conferences.list }

voice_logs = safe('Voice log list') { client.logs.voice.list } || {}
first_voice = (voice_logs['data'] || [{}]).first
if first_voice && first_voice['id']
  safe('Voice log detail') { client.logs.voice.get(first_voice['id']) }
  safe('Voice log events') { client.logs.voice.list_events(first_voice['id']) }
end

# --- Clean up ---

puts "\nCleaning up..."
safe('Delete queue')       { client.compat.queues.delete(q_sid) } if q_sid
safe('Delete application') { client.compat.applications.delete(app_sid) } if app_sid
safe('Delete LaML bin')    { client.compat.laml_bins.delete(laml_sid) } if laml_sid
safe('Delete number')      { client.compat.phone_numbers.delete(num_sid) } if num_sid
