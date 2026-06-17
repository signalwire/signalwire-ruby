# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_video_mock.py.
#
# Exercises the Video API surface against the in-process mock_signalwire
# server: room sessions, room recordings, conference tokens, conference
# streams, and individual stream lifecycle.
#
# Each test calls a single SDK method and asserts on:
#   1. The shape of the parsed response body.
#   2. The mock request journal: HTTP method + path the SDK actually sent.

require 'minitest/autorun'
require_relative 'mock_test'

class VideoMockTest < Minitest::Test
  VIDEO_BASE = '/api/video'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- Rooms — streams sub-resource -----------------------------------

  def test_rooms_list_streams_returns_data_collection
    body = @client.video.rooms.list_streams('room-1')

    assert_kind_of Hash, body
    # /api/video/rooms/{id}/streams returns a paginated list ('data').
    assert(body.key?('data'),
           "missing 'data' in body keys #{body.keys.sort.inspect}")
    assert_kind_of Array, body['data']

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/rooms/room-1/streams", last.path
    refute_nil last.matched_route, 'spec gap: rooms streams list'
  end

  def test_rooms_create_stream_posts_kwargs_in_body
    body = @client.video.rooms.create_stream('room-1', url: 'rtmp://example.com/live')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{VIDEO_BASE}/rooms/room-1/streams", last.path
    assert_kind_of Hash, last.body
    assert_equal 'rtmp://example.com/live', last.body['url']
  end

  # ---- Room Sessions --------------------------------------------------

  def test_room_sessions_list_returns_data_collection
    body = @client.video.room_sessions.list

    assert_kind_of Hash, body
    assert(body.key?('data'),
           "missing 'data' in body keys #{body.keys.sort.inspect}")
    assert_kind_of Array, body['data']

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_sessions", last.path
  end

  def test_room_sessions_get_returns_session_object
    body = @client.video.room_sessions.get('sess-abc')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_sessions/sess-abc", last.path
    refute_nil last.matched_route
  end

  def test_room_sessions_list_events_uses_events_subpath
    body = @client.video.room_sessions.list_events('sess-1')

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_sessions/sess-1/events", last.path
  end

  def test_room_sessions_list_recordings_uses_recordings_subpath
    body = @client.video.room_sessions.list_recordings('sess-2')

    assert_kind_of Hash, body
    assert body.key?('data')

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_sessions/sess-2/recordings", last.path
  end

  # ---- Room Recordings ------------------------------------------------

  def test_room_recordings_list_returns_data_collection
    body = @client.video.room_recordings.list

    assert_kind_of Hash, body
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_recordings", last.path
  end

  def test_room_recordings_get_returns_single_recording
    body = @client.video.room_recordings.get('rec-xyz')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_recordings/rec-xyz", last.path
  end

  def test_room_recordings_delete_returns_empty_dict_for_204
    # The mock synthesises 204/empty for DELETE which the SDK turns into {}.
    body = @client.video.room_recordings.delete('rec-del')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{VIDEO_BASE}/room_recordings/rec-del", last.path
    refute_nil last.matched_route
  end

  def test_room_recordings_list_events_uses_events_subpath
    body = @client.video.room_recordings.list_events('rec-1')

    assert_kind_of Hash, body
    assert body.key?('data')

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/room_recordings/rec-1/events", last.path
  end

  # ---- Conferences sub-collections (tokens, streams) ------------------

  def test_conferences_list_conference_tokens
    body = @client.video.conferences.list_conference_tokens('conf-1')

    assert_kind_of Hash, body
    # Token-collection endpoints return 'data' arrays.
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/conferences/conf-1/conference_tokens", last.path
  end

  def test_conferences_list_streams
    body = @client.video.conferences.list_streams('conf-2')

    assert_kind_of Hash, body
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/conferences/conf-2/streams", last.path
  end

  # ---- Conference Tokens ----------------------------------------------

  def test_conference_tokens_get_returns_single_token
    body = @client.video.conference_tokens.get('tok-1')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/conference_tokens/tok-1", last.path
    refute_nil last.matched_route
  end

  def test_conference_tokens_reset_posts_to_reset_subpath
    body = @client.video.conference_tokens.reset('tok-2')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{VIDEO_BASE}/conference_tokens/tok-2/reset", last.path
    # reset is a no-body POST.
    assert(last.body.nil? || last.body == {} || last.body == '',
           "expected empty body, got #{last.body.inspect}")
  end

  # ---- Streams (top-level) --------------------------------------------

  def test_streams_get_returns_stream_resource
    body = @client.video.streams.get('stream-1')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/streams/stream-1", last.path
  end

  def test_streams_update_uses_put_with_kwargs
    body = @client.video.streams.update('stream-2', url: 'rtmp://example.com/new')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'PUT', last.method
    assert_equal "#{VIDEO_BASE}/streams/stream-2", last.path
    assert_kind_of Hash, last.body
    assert_equal 'rtmp://example.com/new', last.body['url']
  end

  def test_streams_delete
    body = @client.video.streams.delete('stream-3')

    assert_kind_of Hash, body # SDK turns 204 into {}

    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{VIDEO_BASE}/streams/stream-3", last.path
    refute_nil last.matched_route
  end
end
