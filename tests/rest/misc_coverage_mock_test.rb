# frozen_string_literal: true

# Full success + error coverage for the SMALL REST spec groups: datasphere,
# project, the four logs sub-APIs (voice / fax / message / conferences),
# calling.dial, chat, and pubsub.
#
# Mirrors tests/rest/fabric_mock_test.rb EXACTLY: each canonical route gets a
# SUCCESS test (call the real SDK method against the live mock; assert the
# parsed body shape AND the journal entry's method + exact canonical path +
# matched_route) and an ERROR test (arm a 4xx/5xx via
# +@mock.push_scenario(endpoint_id, status:, response:)+, assert the SDK raises
# SignalWire::REST::SignalWireRestError with the right status_code, and that the
# journal recorded the route with the error status).
#
# 23 canonical routes across nine specs — ZERO accepted gaps in these groups.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared fixture + journal-assertion helpers for the misc coverage classes.
module MiscCoverageHelpers
  # Parallelize: each test's client uses a unique project + auth-scoped harness,
  # so the shared mock is concurrency-safe. Parallelism stress-proves isolation.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # Assert the last journalled request's method, exact path, and matched_route.
  # Returns the entry for any further per-field assertions.
  def assert_request(method, path, route)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
    last
  end

  # Arm a non-2xx for +route+, assert the SDK raises with +status+, and that the
  # journal recorded the route with that error status.
  def assert_error(route, status, &)
    @mock.push_scenario(route, status: status, response: { 'error' => 'boom' })
    err = assert_raises(SignalWire::REST::SignalWireRestError, &)

    assert_equal status, err.status_code
    last = @mock.last

    assert_equal status, last.response_status
    assert_equal route, last.matched_route
  end
end

# Datasphere documents — CRUD + search + chunk sub-resources (9 routes).
class DatasphereCoverageMockTest < Minitest::Test
  include MiscCoverageHelpers

  DOCS = '/api/datasphere/documents'

  def test_list_success
    assert_kind_of Hash, @client.datasphere.documents.list
    assert_request('GET', DOCS, 'datasphere.list_documents')
  end

  def test_list_error
    assert_error('datasphere.list_documents', 500) { @client.datasphere.documents.list }
  end

  def test_create_success
    body = @client.datasphere.documents.create(url: 'https://example.com/doc.pdf')

    assert_kind_of Hash, body
    last = assert_request('POST', DOCS, 'datasphere.create_document')

    assert_equal 'https://example.com/doc.pdf', last.body['url']
  end

  def test_create_error
    assert_error('datasphere.create_document', 422) { @client.datasphere.documents.create }
  end

  def test_search_success
    body = @client.datasphere.documents.search(query_string: 'hello')

    assert_kind_of Hash, body
    last = assert_request('POST', "#{DOCS}/search", 'datasphere.search_documents')

    assert_equal 'hello', last.body['query_string']
  end

  def test_search_error
    assert_error('datasphere.search_documents', 422) { @client.datasphere.documents.search }
  end

  def test_list_chunks_success
    assert_kind_of Hash, @client.datasphere.documents.list_chunks('doc-1001')
    assert_request('GET', "#{DOCS}/doc-1001/chunks", 'datasphere.list_document_chunks')
  end

  def test_list_chunks_error
    assert_error('datasphere.list_document_chunks', 404) do
      @client.datasphere.documents.list_chunks('missing')
    end
  end

  def test_get_chunk_success
    assert_kind_of Hash, @client.datasphere.documents.get_chunk('doc-1001', 'ch-1')
    assert_request('GET', "#{DOCS}/doc-1001/chunks/ch-1", 'datasphere.get_document_chunk')
  end

  def test_get_chunk_error
    assert_error('datasphere.get_document_chunk', 404) do
      @client.datasphere.documents.get_chunk('doc-1001', 'missing')
    end
  end

  def test_delete_chunk_success
    assert_kind_of Hash, @client.datasphere.documents.delete_chunk('doc-1001', 'ch-1') # 204 -> {}
    assert_request('DELETE', "#{DOCS}/doc-1001/chunks/ch-1", 'datasphere.delete_document_chunk')
  end

  def test_delete_chunk_error
    assert_error('datasphere.delete_document_chunk', 404) do
      @client.datasphere.documents.delete_chunk('doc-1001', 'missing')
    end
  end

  def test_get_success
    assert_kind_of Hash, @client.datasphere.documents.get('doc-1001')
    assert_request('GET', "#{DOCS}/doc-1001", 'datasphere.get_document')
  end

  def test_get_error
    assert_error('datasphere.get_document', 404) { @client.datasphere.documents.get('missing') }
  end

  def test_update_uses_patch_success
    body = @client.datasphere.documents.update('doc-1001', tags: %w[x])

    assert_kind_of Hash, body
    last = assert_request('PATCH', "#{DOCS}/doc-1001", 'datasphere.update_document')

    assert_equal %w[x], last.body['tags']
  end

  def test_update_error
    assert_error('datasphere.update_document', 404) do
      @client.datasphere.documents.update('missing', tags: %w[x])
    end
  end

  def test_delete_success
    assert_kind_of Hash, @client.datasphere.documents.delete('doc-1001') # 204 -> {}
    assert_request('DELETE', "#{DOCS}/doc-1001", 'datasphere.delete_document')
  end

  def test_delete_error
    assert_error('datasphere.delete_document', 404) { @client.datasphere.documents.delete('missing') }
  end
end

# Project API tokens (3 routes) + calling.dial + chat + pubsub (1 each).
class MiscSmallSpecsCoverageMockTest < Minitest::Test
  include MiscCoverageHelpers

  TOKENS = '/api/project/tokens'

  def test_project_create_token_success
    body = @client.project.tokens.create(name: 'tok-1')

    assert_kind_of Hash, body
    last = assert_request('POST', TOKENS, 'project.create_token')

    assert_equal 'tok-1', last.body['name']
  end

  def test_project_create_token_error
    assert_error('project.create_token', 422) { @client.project.tokens.create }
  end

  def test_project_update_token_uses_patch_success
    body = @client.project.tokens.update('tok-1', name: 'renamed')

    assert_kind_of Hash, body
    last = assert_request('PATCH', "#{TOKENS}/tok-1", 'project.update_token')

    assert_equal 'renamed', last.body['name']
  end

  def test_project_update_token_error
    assert_error('project.update_token', 404) { @client.project.tokens.update('missing', name: 'x') }
  end

  def test_project_delete_token_success
    assert_kind_of Hash, @client.project.tokens.delete('tok-1') # 204 -> {}
    assert_request('DELETE', "#{TOKENS}/tok-1", 'project.delete_token')
  end

  def test_project_delete_token_error
    assert_error('project.delete_token', 404) { @client.project.tokens.delete('missing') }
  end

  # ---- calling.dial -> POST /api/calling/calls -----------------------

  def test_calling_dial_success
    body = @client.calling.dial(url: 'https://example.com/swml', to: '+15551234567')

    assert_kind_of Hash, body
    last = assert_request('POST', '/api/calling/calls', 'calling.call-commands')

    assert_equal 'dial', last.body['command']
  end

  def test_calling_dial_error
    assert_error('calling.call-commands', 422) do
      @client.calling.dial(url: 'https://example.com/swml', to: '+15551234567')
    end
  end

  # ---- chat.create_token -> POST /api/chat/tokens --------------------

  def test_chat_create_token_success
    body = @client.chat.create_token(channels: %w[room-1])

    assert_kind_of Hash, body
    last = assert_request('POST', '/api/chat/tokens', 'chat.create_chat_token')

    assert_equal %w[room-1], last.body['channels']
  end

  def test_chat_create_token_error
    assert_error('chat.create_chat_token', 422) { @client.chat.create_token }
  end

  # ---- pubsub.create_token -> POST /api/pubsub/tokens ----------------

  def test_pubsub_create_token_success
    body = @client.pubsub.create_token(channels: %w[ch-1])

    assert_kind_of Hash, body
    last = assert_request('POST', '/api/pubsub/tokens', 'pubsub.create_token')

    assert_equal %w[ch-1], last.body['channels']
  end

  def test_pubsub_create_token_error
    assert_error('pubsub.create_token', 422) { @client.pubsub.create_token }
  end
end

# Logs: voice (list/get/list_events), fax (list/get), message (list/get),
# conferences (list) — across four spec docs.
class LogsCoverageMockTest < Minitest::Test
  include MiscCoverageHelpers

  def test_voice_list_success
    assert_kind_of Hash, @client.logs.voice.list
    assert_request('GET', '/api/voice/logs', 'voice.list_voice_logs')
  end

  def test_voice_list_error
    assert_error('voice.list_voice_logs', 500) { @client.logs.voice.list }
  end

  def test_voice_get_success
    assert_kind_of Hash, @client.logs.voice.get('vl-99')
    assert_request('GET', '/api/voice/logs/vl-99', 'voice.get_voice_log')
  end

  def test_voice_get_error
    assert_error('voice.get_voice_log', 404) { @client.logs.voice.get('missing') }
  end

  def test_voice_list_events_success
    assert_kind_of Hash, @client.logs.voice.list_events('vl-99')
    assert_request('GET', '/api/voice/logs/vl-99/events', 'voice.list_voice_log_events')
  end

  def test_voice_list_events_error
    assert_error('voice.list_voice_log_events', 404) { @client.logs.voice.list_events('missing') }
  end

  def test_fax_list_success
    assert_kind_of Hash, @client.logs.fax.list
    assert_request('GET', '/api/fax/logs', 'fax.list_fax_logs')
  end

  def test_fax_list_error
    assert_error('fax.list_fax_logs', 500) { @client.logs.fax.list }
  end

  def test_fax_get_success
    assert_kind_of Hash, @client.logs.fax.get('fl-7')
    assert_request('GET', '/api/fax/logs/fl-7', 'fax.get_fax_log')
  end

  def test_fax_get_error
    assert_error('fax.get_fax_log', 404) { @client.logs.fax.get('missing') }
  end

  def test_message_list_success
    assert_kind_of Hash, @client.logs.messages.list
    assert_request('GET', '/api/messaging/logs', 'message.list_message_logs')
  end

  def test_message_list_error
    assert_error('message.list_message_logs', 500) { @client.logs.messages.list }
  end

  def test_message_get_success
    assert_kind_of Hash, @client.logs.messages.get('ml-42')
    assert_request('GET', '/api/messaging/logs/ml-42', 'message.get_message_log')
  end

  def test_message_get_error
    assert_error('message.get_message_log', 404) { @client.logs.messages.get('missing') }
  end

  def test_conferences_list_success
    assert_kind_of Hash, @client.logs.conferences.list
    assert_request('GET', '/api/logs/conferences', 'logs.list_conferences')
  end

  def test_conferences_list_error
    assert_error('logs.list_conferences', 500) { @client.logs.conferences.list }
  end
end
