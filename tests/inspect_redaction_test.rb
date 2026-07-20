# frozen_string_literal: true

require 'minitest/autorun'
require 'base64'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative '../lib/signalwire/rest/rest_client'
require_relative '../lib/signalwire/relay/client'

# Enterprise credential-hygiene (A6 / SECRET-SCRUB): the SDK clients must NEVER
# expose raw credentials via #inspect / #to_s — the default #inspect dumps every
# ivar (token, JWT, Basic-auth header, the server's authorization_state re-auth
# blob), leaking them into logs, crash dumps, and REPL sessions.
class InspectRedactionTest < Minitest::Test
  TOKEN = 'SECRET_TOKEN_9f9f'
  JWT = 'JWTSECRET_abcd'
  AUTHSTATE = 'AUTHSTATE_xyz'

  def test_rest_client_inspect_redacts_token
    rc = SignalWire::REST::RestClient.new(project: 'PJ', token: TOKEN, host: 'acme')
    auth_header = Base64.strict_encode64("PJ:#{TOKEN}")

    refute_includes rc.inspect, TOKEN, 'RestClient#inspect leaked the raw token'
    refute_includes rc.to_s, TOKEN, 'RestClient#to_s leaked the raw token'
    assert_includes rc.inspect, '[REDACTED]'
    # The nested HttpClient must not leak the token or the Basic-auth header.
    http = rc.instance_variable_get(:@http)

    refute_includes http.inspect, TOKEN, 'HttpClient#inspect leaked the raw token'
    refute_includes http.inspect, auth_header, 'HttpClient#inspect leaked the auth header'
    # Non-secret identity is still shown for debuggability.
    assert_includes rc.inspect, 'PJ'
  end

  def test_relay_client_inspect_redacts_all_credentials
    cl = SignalWire::Relay::Client.new(project: 'PJ', token: TOKEN, host: 'example.com')
    cl.instance_variable_set(:@jwt_token, JWT)
    cl.instance_variable_set(:@authorization_state, AUTHSTATE)

    %w[token jwt authorization-state].zip([TOKEN, JWT, AUTHSTATE]).each do |_label, secret|
      refute_includes cl.inspect, secret, "RelayClient#inspect leaked #{secret}"
      refute_includes cl.to_s, secret, "RelayClient#to_s leaked #{secret}"
    end
    assert_includes cl.inspect, '[REDACTED]'
    assert_includes cl.inspect, 'PJ' # non-secret identity retained
  end
end
