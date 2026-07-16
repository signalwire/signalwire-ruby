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

def main
  port = ENV.fetch('MOCK_SIGNALWIRE_PORT', nil)
  if port.nil? || port.empty?
    warn 'doc_wire_runner: MOCK_SIGNALWIRE_PORT not set'
    return 2
  end
  base_url = ENV.fetch('SIGNALWIRE_MOCK_URL', "http://127.0.0.1:#{port}")
  client = build_client(base_url)

  call_id = 'call-doc-wire'

  # --- README.md + examples/quickstart_rest.rb (region: rest) ----------------
  client.fabric.ai_agents.create(name: 'Support Bot', prompt: { 'text' => 'You are helpful.' })
  client.calling.play(call_id, play: [{ 'type' => 'tts', 'params' => { 'text' => 'Hello!' } }])
  client.phone_numbers.search(areacode: '512')
  client.datasphere.documents.search(query_string: 'billing policy')

  # --- rest/README.md + rest/docs/namespaces.md phone-number search ----------
  client.phone_numbers.search(areacode: '512', number_type: 'local')

  # --- rest/docs/calling.md play (nested params:{text}) ----------------------
  client.calling.play(call_id, play: [{ 'type' => 'tts', 'params' => { 'text' => 'Hello!' } }], volume: 5.0)

  # --- rest/examples/rest_calling_play_and_record.rb + ivr_and_ai.rb ---------
  client.calling.play(call_id, play: [{ 'type' => 'tts', 'params' => { 'text' => 'Welcome to SignalWire.' } }])
  client.calling.play(call_id,
                      play: [{ 'type' => 'tts', 'params' => { 'text' => 'Enter your PIN followed by pound.' } }])

  # --- rest/README.md end + rest/docs/calling.md end/record ------------------
  client.calling.record(call_id, audio: { 'format' => 'mp3', 'beep' => true })
  client.calling.end(call_id, reason: 'hangup')

  # --- rest/docs/calling.md live transcribe & translate (action:{start:{}}) --
  client.calling.live_transcribe(call_id, action: { 'start' => { 'lang' => 'en-US' } })
  client.calling.live_translate(call_id, action: { 'start' => { 'from_lang' => 'en-US', 'to_lang' => 'es-ES' } })

  puts 'doc_wire_runner: replayed documented REST fixtures against the mock'
  0
end

exit(main) if $PROGRAM_NAME == __FILE__
