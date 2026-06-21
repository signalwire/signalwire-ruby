# frozen_string_literal: true

# Full success + error coverage for the `video` REST spec group.
#
# Companion to video_mock_test.rb: that file covers the shape-focused happy
# paths; this file drives EVERY coverable canonical `video.*` route to both a
# SUCCESS test (on the correct method + path, asserting the matched_route the
# mock resolved) and an ERROR test (a pushed scenario forcing a non-2xx that
# the SDK surfaces as SignalWire::REST::SignalWireRestError with .status_code).
#
# Coverable routes: 30 of 33. Accepted gaps (no SDK surface / routing
# collision, not faked here):
#   - video.list_logs  / video.get_log : no `logs` accessor on the Video
#     namespace (the SDK exposes no logs resource).
#   - video.get_room : GET /api/video/rooms/{id} collides with
#     video.get_room_by_name (identical template length + literal segments);
#     the mock resolves the pair deterministically to get_room_by_name, which
#     this file covers. get_room is left as an accepted gap rather than faked.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared fixture + assertion helpers for the video coverage classes.
module VideoCoverageHelpers
  # Parallelize: each test's client uses a unique project + auth-scoped harness,
  # so the shared mock is concurrency-safe. Parallelism stress-proves isolation.
  def self.included(base)
    base.parallelize_me!
  end

  VIDEO_BASE = '/api/video'

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # Assert the last journalled request's method + path + matched_route, and
  # return the entry for any further per-field assertions.
  def assert_last_request(method, path, route)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
    last
  end

  # Assert +body+ is a paginated collection: a Hash with an Array 'data' key.
  def assert_data_collection(body)
    assert_kind_of Hash, body
    assert(body.key?('data'), "missing 'data' in body keys #{body.keys.sort.inspect}")
    assert_kind_of Array, body['data']
  end

  # Push a one-shot failure for +endpoint_id+, invoke +block+, and assert the
  # SDK raised SignalWireRestError carrying +status+ and that the journal shows
  # the matched route + response status.
  def assert_error(endpoint_id, status, route, &)
    @mock.push_scenario(endpoint_id, status: status, response: { 'error' => 'boom' })
    err = assert_raises(SignalWire::REST::SignalWireRestError, &)

    assert_equal status, err.status_code
    assert_equal status, @mock.last.response_status
    assert_equal route, @mock.last.matched_route
  end
end

# Rooms collection + streams sub-resource, and Room Tokens.
class VideoRoomsCoverageMockTest < Minitest::Test
  include VideoCoverageHelpers

  # ---- list_rooms -----------------------------------------------------

  def test_list_rooms_success
    assert_data_collection(@client.video.rooms.list)
    assert_last_request('GET', "#{VIDEO_BASE}/rooms", 'video.list_rooms')
  end

  def test_list_rooms_error
    assert_error('video.list_rooms', 500, 'video.list_rooms') { @client.video.rooms.list }
  end

  # ---- create_room ----------------------------------------------------

  def test_create_room_success
    body = @client.video.rooms.create(name: 'demo')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{VIDEO_BASE}/rooms", 'video.create_room')

    assert_equal 'demo', last.body['name']
  end

  def test_create_room_error
    assert_error('video.create_room', 422, 'video.create_room') do
      @client.video.rooms.create(name: 'bad')
    end
  end

  # ---- get_room_by_name (covers the room-by-id GET; get_room is a gap) -

  def test_get_room_by_name_success
    assert_kind_of Hash, @client.video.rooms.get('room-1')
    assert_last_request('GET', "#{VIDEO_BASE}/rooms/room-1", 'video.get_room_by_name')
  end

  def test_get_room_by_name_error
    assert_error('video.get_room_by_name', 404, 'video.get_room_by_name') do
      @client.video.rooms.get('missing')
    end
  end

  # ---- update_room (PUT) ----------------------------------------------

  def test_update_room_success
    body = @client.video.rooms.update('room-2', display_name: 'New')

    assert_kind_of Hash, body
    last = assert_last_request('PUT', "#{VIDEO_BASE}/rooms/room-2", 'video.update_room')

    assert_equal 'New', last.body['display_name']
  end

  def test_update_room_error
    assert_error('video.update_room', 409, 'video.update_room') do
      @client.video.rooms.update('room-2', display_name: 'X')
    end
  end

  # ---- delete_room ----------------------------------------------------

  def test_delete_room_success
    assert_kind_of Hash, @client.video.rooms.delete('room-3') # SDK turns 204 into {}
    assert_last_request('DELETE', "#{VIDEO_BASE}/rooms/room-3", 'video.delete_room')
  end

  def test_delete_room_error
    assert_error('video.delete_room', 404, 'video.delete_room') do
      @client.video.rooms.delete('room-3')
    end
  end

  # ---- list_room_streams ----------------------------------------------

  def test_list_room_streams_success
    assert_data_collection(@client.video.rooms.list_streams('room-1'))
    assert_last_request('GET', "#{VIDEO_BASE}/rooms/room-1/streams", 'video.list_room_streams')
  end

  def test_list_room_streams_error
    assert_error('video.list_room_streams', 500, 'video.list_room_streams') do
      @client.video.rooms.list_streams('room-1')
    end
  end

  # ---- create_room_stream ---------------------------------------------

  def test_create_room_stream_success
    body = @client.video.rooms.create_stream('room-1', url: 'rtmp://example.com/live')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{VIDEO_BASE}/rooms/room-1/streams", 'video.create_room_stream')

    assert_equal 'rtmp://example.com/live', last.body['url']
  end

  def test_create_room_stream_error
    assert_error('video.create_room_stream', 422, 'video.create_room_stream') do
      @client.video.rooms.create_stream('room-1', url: 'bad')
    end
  end

  # ---- create_room_token ----------------------------------------------

  def test_create_room_token_success
    body = @client.video.room_tokens.create(room_name: 'demo', user_name: 'alice')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{VIDEO_BASE}/room_tokens", 'video.create_room_token')

    assert_equal 'demo', last.body['room_name']
  end

  def test_create_room_token_error
    assert_error('video.create_room_token', 422, 'video.create_room_token') do
      @client.video.room_tokens.create(room_name: 'demo')
    end
  end
end

# Room Sessions + Room Recordings.
class VideoRoomSessionsCoverageMockTest < Minitest::Test
  include VideoCoverageHelpers

  # ---- list_room_sessions ---------------------------------------------

  def test_list_room_sessions_success
    assert_data_collection(@client.video.room_sessions.list)
    assert_last_request('GET', "#{VIDEO_BASE}/room_sessions", 'video.list_room_sessions')
  end

  def test_list_room_sessions_error
    assert_error('video.list_room_sessions', 500, 'video.list_room_sessions') do
      @client.video.room_sessions.list
    end
  end

  # ---- get_room_session -----------------------------------------------

  def test_get_room_session_success
    assert_kind_of Hash, @client.video.room_sessions.get('sess-1')
    assert_last_request('GET', "#{VIDEO_BASE}/room_sessions/sess-1", 'video.get_room_session')
  end

  def test_get_room_session_error
    assert_error('video.get_room_session', 404, 'video.get_room_session') do
      @client.video.room_sessions.get('missing')
    end
  end

  # ---- list_room_session_events ---------------------------------------

  def test_list_room_session_events_success
    assert_data_collection(@client.video.room_sessions.list_events('sess-1'))
    assert_last_request('GET', "#{VIDEO_BASE}/room_sessions/sess-1/events", 'video.list_room_session_events')
  end

  def test_list_room_session_events_error
    assert_error('video.list_room_session_events', 500, 'video.list_room_session_events') do
      @client.video.room_sessions.list_events('sess-1')
    end
  end

  # ---- list_room_session_members --------------------------------------

  def test_list_room_session_members_success
    assert_data_collection(@client.video.room_sessions.list_members('sess-1'))
    assert_last_request('GET', "#{VIDEO_BASE}/room_sessions/sess-1/members", 'video.list_room_session_members')
  end

  def test_list_room_session_members_error
    assert_error('video.list_room_session_members', 500, 'video.list_room_session_members') do
      @client.video.room_sessions.list_members('sess-1')
    end
  end

  # ---- list_room_session_recordings -----------------------------------

  def test_list_room_session_recordings_success
    assert_data_collection(@client.video.room_sessions.list_recordings('sess-2'))
    assert_last_request('GET', "#{VIDEO_BASE}/room_sessions/sess-2/recordings",
                        'video.list_room_session_recordings')
  end

  def test_list_room_session_recordings_error
    assert_error('video.list_room_session_recordings', 500, 'video.list_room_session_recordings') do
      @client.video.room_sessions.list_recordings('sess-2')
    end
  end

  # ---- list_room_recordings -------------------------------------------

  def test_list_room_recordings_success
    assert_data_collection(@client.video.room_recordings.list)
    assert_last_request('GET', "#{VIDEO_BASE}/room_recordings", 'video.list_room_recordings')
  end

  def test_list_room_recordings_error
    assert_error('video.list_room_recordings', 500, 'video.list_room_recordings') do
      @client.video.room_recordings.list
    end
  end

  # ---- get_room_recording ---------------------------------------------

  def test_get_room_recording_success
    assert_kind_of Hash, @client.video.room_recordings.get('rec-1')
    assert_last_request('GET', "#{VIDEO_BASE}/room_recordings/rec-1", 'video.get_room_recording')
  end

  def test_get_room_recording_error
    assert_error('video.get_room_recording', 404, 'video.get_room_recording') do
      @client.video.room_recordings.get('missing')
    end
  end

  # ---- delete_room_recording ------------------------------------------

  def test_delete_room_recording_success
    assert_kind_of Hash, @client.video.room_recordings.delete('rec-del') # 204 -> {}
    assert_last_request('DELETE', "#{VIDEO_BASE}/room_recordings/rec-del", 'video.delete_room_recording')
  end

  def test_delete_room_recording_error
    assert_error('video.delete_room_recording', 404, 'video.delete_room_recording') do
      @client.video.room_recordings.delete('rec-del')
    end
  end

  # ---- list_room_recording_events -------------------------------------

  def test_list_room_recording_events_success
    assert_data_collection(@client.video.room_recordings.list_events('rec-1'))
    assert_last_request('GET', "#{VIDEO_BASE}/room_recordings/rec-1/events", 'video.list_room_recording_events')
  end

  def test_list_room_recording_events_error
    assert_error('video.list_room_recording_events', 500, 'video.list_room_recording_events') do
      @client.video.room_recordings.list_events('rec-1')
    end
  end
end

# Conferences collection + sub-resources, Conference Tokens, and Streams.
class VideoConferencesCoverageMockTest < Minitest::Test
  include VideoCoverageHelpers

  # ---- list_video_conferences -----------------------------------------

  def test_list_video_conferences_success
    assert_data_collection(@client.video.conferences.list)
    assert_last_request('GET', "#{VIDEO_BASE}/conferences", 'video.list_video_conferences')
  end

  def test_list_video_conferences_error
    assert_error('video.list_video_conferences', 500, 'video.list_video_conferences') do
      @client.video.conferences.list
    end
  end

  # ---- create_video_conference ----------------------------------------

  def test_create_video_conference_success
    body = @client.video.conferences.create(name: 'standup')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{VIDEO_BASE}/conferences", 'video.create_video_conference')

    assert_equal 'standup', last.body['name']
  end

  def test_create_video_conference_error
    assert_error('video.create_video_conference', 422, 'video.create_video_conference') do
      @client.video.conferences.create(name: 'bad')
    end
  end

  # ---- get_video_conference -------------------------------------------

  def test_get_video_conference_success
    assert_kind_of Hash, @client.video.conferences.get('conf-1')
    assert_last_request('GET', "#{VIDEO_BASE}/conferences/conf-1", 'video.get_video_conference')
  end

  def test_get_video_conference_error
    assert_error('video.get_video_conference', 404, 'video.get_video_conference') do
      @client.video.conferences.get('missing')
    end
  end

  # ---- update_video_conference (PUT) ----------------------------------

  def test_update_video_conference_success
    body = @client.video.conferences.update('conf-2', display_name: 'Daily')

    assert_kind_of Hash, body
    last = assert_last_request('PUT', "#{VIDEO_BASE}/conferences/conf-2", 'video.update_video_conference')

    assert_equal 'Daily', last.body['display_name']
  end

  def test_update_video_conference_error
    assert_error('video.update_video_conference', 409, 'video.update_video_conference') do
      @client.video.conferences.update('conf-2', display_name: 'X')
    end
  end

  # ---- delete_video_conference ----------------------------------------

  def test_delete_video_conference_success
    assert_kind_of Hash, @client.video.conferences.delete('conf-3') # 204 -> {}
    assert_last_request('DELETE', "#{VIDEO_BASE}/conferences/conf-3", 'video.delete_video_conference')
  end

  def test_delete_video_conference_error
    assert_error('video.delete_video_conference', 404, 'video.delete_video_conference') do
      @client.video.conferences.delete('conf-3')
    end
  end

  # ---- list_conference_tokens -----------------------------------------

  def test_list_conference_tokens_success
    assert_data_collection(@client.video.conferences.list_conference_tokens('conf-1'))
    assert_last_request('GET', "#{VIDEO_BASE}/conferences/conf-1/conference_tokens",
                        'video.list_conference_tokens')
  end

  def test_list_conference_tokens_error
    assert_error('video.list_conference_tokens', 500, 'video.list_conference_tokens') do
      @client.video.conferences.list_conference_tokens('conf-1')
    end
  end

  # ---- list_conference_streams ----------------------------------------

  def test_list_conference_streams_success
    assert_data_collection(@client.video.conferences.list_streams('conf-2'))
    assert_last_request('GET', "#{VIDEO_BASE}/conferences/conf-2/streams", 'video.list_conference_streams')
  end

  def test_list_conference_streams_error
    assert_error('video.list_conference_streams', 500, 'video.list_conference_streams') do
      @client.video.conferences.list_streams('conf-2')
    end
  end

  # ---- create_conference_stream ---------------------------------------

  def test_create_conference_stream_success
    body = @client.video.conferences.create_stream('conf-1', url: 'rtmp://example.com/live')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{VIDEO_BASE}/conferences/conf-1/streams",
                               'video.create_conference_stream')

    assert_equal 'rtmp://example.com/live', last.body['url']
  end

  def test_create_conference_stream_error
    assert_error('video.create_conference_stream', 422, 'video.create_conference_stream') do
      @client.video.conferences.create_stream('conf-1', url: 'bad')
    end
  end
end

# Conference Tokens + top-level Streams.
class VideoStreamsCoverageMockTest < Minitest::Test
  include VideoCoverageHelpers

  # ---- get_conference_token -------------------------------------------

  def test_get_conference_token_success
    assert_kind_of Hash, @client.video.conference_tokens.get('tok-1')
    assert_last_request('GET', "#{VIDEO_BASE}/conference_tokens/tok-1", 'video.get_conference_token')
  end

  def test_get_conference_token_error
    assert_error('video.get_conference_token', 404, 'video.get_conference_token') do
      @client.video.conference_tokens.get('missing')
    end
  end

  # ---- reset_conference_token -----------------------------------------

  def test_reset_conference_token_success
    assert_kind_of Hash, @client.video.conference_tokens.reset('tok-2')
    assert_last_request('POST', "#{VIDEO_BASE}/conference_tokens/tok-2/reset", 'video.reset_conference_token')
  end

  def test_reset_conference_token_error
    assert_error('video.reset_conference_token', 404, 'video.reset_conference_token') do
      @client.video.conference_tokens.reset('tok-2')
    end
  end

  # ---- get_stream -----------------------------------------------------

  def test_get_stream_success
    assert_kind_of Hash, @client.video.streams.get('stream-1')
    assert_last_request('GET', "#{VIDEO_BASE}/streams/stream-1", 'video.get_stream')
  end

  def test_get_stream_error
    assert_error('video.get_stream', 404, 'video.get_stream') do
      @client.video.streams.get('missing')
    end
  end

  # ---- update_stream (PUT) --------------------------------------------

  def test_update_stream_success
    body = @client.video.streams.update('stream-2', url: 'rtmp://example.com/new')

    assert_kind_of Hash, body
    last = assert_last_request('PUT', "#{VIDEO_BASE}/streams/stream-2", 'video.update_stream')

    assert_equal 'rtmp://example.com/new', last.body['url']
  end

  def test_update_stream_error
    assert_error('video.update_stream', 409, 'video.update_stream') do
      @client.video.streams.update('stream-2', url: 'rtmp://example.com/new')
    end
  end

  # ---- delete_stream --------------------------------------------------

  def test_delete_stream_success
    assert_kind_of Hash, @client.video.streams.delete('stream-3') # 204 -> {}
    assert_last_request('DELETE', "#{VIDEO_BASE}/streams/stream-3", 'video.delete_stream')
  end

  def test_delete_stream_error
    assert_error('video.delete_stream', 404, 'video.delete_stream') do
      @client.video.streams.delete('stream-3')
    end
  end
end
