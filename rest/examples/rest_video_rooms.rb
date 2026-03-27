# frozen_string_literal: true

# Example: Video rooms for team standup and conference streaming.
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

# --- Video Rooms ---

# 1. Create a video room
puts 'Creating video room...'
room = client.video.rooms.create(
  name:         'daily-standup',
  display_name: 'Daily Standup',
  max_members:  10,
  layout:       'grid-responsive'
)
room_id = room['id']
puts "  Created room: #{room_id}"

# 2. List video rooms
puts "\nListing video rooms..."
rooms = client.video.rooms.list
(rooms['data'] || []).first(5).each do |r|
  puts "  - #{r['id']}: #{r.fetch('name', 'unnamed')}"
end

# 3. Generate a join token
puts "\nGenerating room token..."
safe('Room token') do
  token = client.video.room_tokens.create(
    room_name:   'daily-standup',
    user_name:   'alice',
    permissions: %w[room.self.audio_mute room.self.video_mute]
  )
  puts "  Token: #{token.fetch('token', '')[0, 40]}..."
end

# --- Sessions ---

# 4. List room sessions
puts "\nListing room sessions..."
sessions = client.video.room_sessions.list
(sessions['data'] || []).first(3).each do |s|
  puts "  - Session #{s['id']}: #{s.fetch('status', 'unknown')}"
end

# 5. Get session details with members, events, recordings
first_session = (sessions['data'] || [{}]).first
if first_session && first_session['id']
  sid = first_session['id']
  detail = client.video.room_sessions.get(sid)
  puts "  Session: #{detail.fetch('name', 'N/A')} (#{detail.fetch('status', 'N/A')})"

  members = client.video.room_sessions.list_members(sid)
  puts "  Members: #{(members['data'] || []).size}"

  events = client.video.room_sessions.list_events(sid)
  puts "  Events: #{(events['data'] || []).size}"

  recs = client.video.room_sessions.list_recordings(sid)
  puts "  Recordings: #{(recs['data'] || []).size}"
end

# --- Room Recordings ---

# 6. List and get room recordings
puts "\nListing room recordings..."
room_recs = client.video.room_recordings.list
(room_recs['data'] || []).first(3).each do |rr|
  puts "  - Recording #{rr['id']}: #{rr.fetch('duration', 'N/A')}s"
end

first_rec = (room_recs['data'] || [{}]).first
if first_rec && first_rec['id']
  rec_detail = client.video.room_recordings.get(first_rec['id'])
  puts "  Recording detail: #{rec_detail.fetch('duration', 'N/A')}s"

  rec_events = client.video.room_recordings.list_events(first_rec['id'])
  puts "  Recording events: #{(rec_events['data'] || []).size}"
end

# --- Video Conferences ---

# 7. Create a video conference
puts "\nCreating video conference..."
conf_id = nil
conf = safe('Create conference') do
  client.video.conferences.create(name: 'all-hands-stream', display_name: 'All Hands Meeting')
end
conf_id = conf && conf['id']

# 8. List conference tokens
if conf_id
  puts "\nListing conference tokens..."
  safe('Conference tokens') do
    tokens = client.video.conferences.list_conference_tokens(conf_id)
    (tokens['data'] || []).each do |t|
      puts "  - Token: #{t.fetch('id', 'unknown')}"
    end
  end
end

# 9. Create a stream on the conference
stream_id = nil
if conf_id
  puts "\nCreating stream on conference..."
  stream = safe('Create stream') do
    client.video.conferences.create_stream(conf_id, url: 'rtmp://live.example.com/stream-key')
  end
  stream_id = stream && stream['id']
end

# 10. Get and update stream
if stream_id
  puts "\nManaging stream #{stream_id}..."
  safe('Stream ops') do
    s_detail = client.video.streams.get(stream_id)
    puts "  Stream URL: #{s_detail.fetch('url', 'N/A')}"

    client.video.streams.update(stream_id, url: 'rtmp://backup.example.com/stream-key')
    puts '  Stream URL updated'
  end
end

# 11. Clean up
puts "\nCleaning up..."
safe('Delete stream')     { client.video.streams.delete(stream_id) } if stream_id
safe('Delete conference') { client.video.conferences.delete(conf_id) } if conf_id
client.video.rooms.delete(room_id)
puts "  Deleted room #{room_id}"
