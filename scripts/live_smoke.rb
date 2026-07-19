# frozen_string_literal: true

# live_smoke.rb — 6.5 real-server smoke: exercise the four load-bearing paths
# against the REAL SignalWire platform (NOT the mock). Opt-in via SWSDK_LIVE_TESTS=1
# and gated on real credentials; it SKIPS cleanly (exit 0) when either is absent,
# so the nightly workflow is a no-op without secrets.
#
#   1. auth       — construct a REST client from env creds
#   2. REST list  — one real list call (phone_numbers)
#   3. SWML render — render a trivial agent's SWML document (no network)
#   4. RELAY connect — open + close a RELAY WebSocket session
#
# Env:
#   SWSDK_LIVE_TESTS=1                        opt in (else skip)
#   SIGNALWIRE_PROJECT_ID / _API_TOKEN / _SPACE   real creds (else skip)

require_relative '../lib/signalwire'
require_relative '../lib/signalwire/rest/rest_client'
require_relative '../lib/signalwire/relay/client'

def skip(reason)
  warn "live_smoke: SKIP — #{reason}"
  exit 0
end

def creds
  vals = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN SIGNALWIRE_SPACE].map { |k| ENV.fetch(k, nil) }
  skip('real credentials absent') if vals.any? { |v| v.nil? || v.empty? }
  vals
end

# 1. auth + 2. REST read — construct the client and make one real GET.
def rest_read(project, token, space)
  client = SignalWire::REST::RestClient.new(project: project, token: token, host: space)
  warn 'live_smoke: [1/4] REST client constructed'
  result = client.phone_numbers.search(areacode: '212')
  warn "live_smoke: [2/4] REST read ok (#{(result['data'] || []).length} rows)"
end

# 3. SWML render — no network; proves document generation end to end.
def swml_render
  agent = SignalWire::AgentBase.new(name: 'live-smoke')
  agent.prompt_add_section('Role', 'You are a smoke test.')
  swml = agent.render_swml
  raise 'SWML render produced no version' unless swml.is_a?(String) && swml.include?('version')

  warn 'live_smoke: [3/4] SWML render ok'
end

# 4. RELAY connect — open + close a WS session.
def relay_connect(project, token, space)
  relay = SignalWire::Relay::Client.new(project: project, token: token, host: space)
  relay.connect
  relay.stop
  warn 'live_smoke: [4/4] RELAY connect ok'
end

def main
  skip('SWSDK_LIVE_TESTS not set') unless ENV['SWSDK_LIVE_TESTS'] == '1'
  project, token, space = creds

  rest_read(project, token, space)
  swml_render
  relay_connect(project, token, space)

  puts 'live_smoke: PASS (auth + REST read + SWML render + RELAY connect)'
  0
end

exit(main) if $PROGRAM_NAME == __FILE__
