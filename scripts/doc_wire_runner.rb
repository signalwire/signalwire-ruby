# frozen_string_literal: true

# doc_wire_runner.rb — the DOC-WIRE fixture runner for signalwire-ruby.
#
# The DOC-WIRE gate (porting-sdk scripts/doc_wire.py) spawns mock_signalwire in
# flag mode, exports MOCK_SIGNALWIRE_PORT, then runs THIS command; it then reads
# the mock journal and fails on any wire_violations. Our job is only to DRIVE the
# documented REST calls against the mock so the mock journals what the documented
# fixtures actually put on the wire.
#
# We replay the REST calls shown in the README / rest quickstart + rest/docs +
# rest/examples (the wire-bearing doc fixtures) — the exact kwargs the docs teach
# — so a doc lie like area_code= (spec areacode) or a flat {type:tts,text} play
# item shows up as a journaled violation and fails the gate. The blocking
# agent/relay quickstarts are covered by EXAMPLES-RUN, not here.
#
# RestClient.new accepts base_url: directly, so we point it at the mock exactly
# as tests/rest/mock_test.rb does.

require 'base64'
require 'securerandom'
require_relative '../lib/signalwire/rest/rest_client'

def build_client(base_url)
  project = "test_proj_#{SecureRandom.hex(6)}"
  SignalWire::REST::RestClient.new(
    project: project, token: 'test_tok', base_url: base_url
  )
end

CALL_ID = 'call-doc-wire'

def tts(text)
  [{ 'type' => 'tts', 'params' => { 'text' => text } }]
end

# README.md + examples/quickstart_rest.rb (region: rest), then rest/README.md +
# rest/docs/namespaces.md phone-number search.
def replay_quickstart(client)
  client.fabric.ai_agents.create(name: 'Support Bot', prompt: { 'text' => 'You are helpful.' })
  client.calling.play(CALL_ID, play: tts('Hello!'))
  client.phone_numbers.search(areacode: '512')
  client.datasphere.documents.search(query_string: 'billing policy')
  client.phone_numbers.search(areacode: '512', number_type: 'local')
end

# rest/docs/calling.md play (nested params:{text}), then
# rest/examples/rest_calling_play_and_record.rb + ivr_and_ai.rb.
def replay_play(client)
  client.calling.play(CALL_ID, play: tts('Hello!'), volume: 5.0)
  client.calling.play(CALL_ID, play: tts('Welcome to SignalWire.'))
  client.calling.play(CALL_ID, play: tts('Enter your PIN followed by pound.'))
end

# rest/README.md end + rest/docs/calling.md end/record, then live transcribe &
# translate (action:{start:{}}).
def replay_record_end_and_live(client)
  client.calling.record(CALL_ID, audio: { 'format' => 'mp3', 'beep' => true })
  client.calling.end(CALL_ID, reason: 'hangup')
  client.calling.live_transcribe(CALL_ID, action: { 'start' => { 'lang' => 'en-US' } })
  client.calling.live_translate(CALL_ID,
                                action: { 'start' => { 'from_lang' => 'en-US',
                                                       'to_lang' => 'es-ES' } })
end

# The mock's base URL, or nil when the gate did not export a port.
def mock_base_url
  port = ENV.fetch('MOCK_SIGNALWIRE_PORT', nil)
  return nil if port.nil? || port.empty?

  ENV.fetch('SIGNALWIRE_MOCK_URL', "http://127.0.0.1:#{port}")
end

def replay_all(client)
  replay_quickstart(client)
  replay_play(client)
  replay_record_end_and_live(client)
end

def main
  base_url = mock_base_url
  if base_url.nil?
    warn 'doc_wire_runner: MOCK_SIGNALWIRE_PORT not set'
    return 2
  end
  replay_all(build_client(base_url))
  puts 'doc_wire_runner: replayed documented REST fixtures against the mock'
  0
end

exit(main) if $PROGRAM_NAME == __FILE__
