# frozen_string_literal: true

# CONSTRUCTION-READBACK (porting-sdk ALLOWLIST_DISCIPLINE.md §15 / class B2):
# if the reference lets a caller PASS a value at construction and READ it back,
# this port must too. Every accessor pinned here was, until this commit, either
# absent or below the public surface — so a Ruby caller could set the value and
# not read it, a capability Python callers had and Ruby callers did not.
#
# These are read-BACK assertions on purpose: the failure mode the gate exists to
# catch is a member being hidden (moved to private, dropped from the enumerator)
# to make a parity gate green. A test that only checks the constructor accepts
# the keyword would still pass after someone re-hid the reader.

require 'minitest/autorun'
require 'base64'
require 'openssl'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require 'signalwire'
require_relative '../lib/signalwire/relay/client'
require_relative '../lib/signalwire/rest/rest_client'
require_relative '../lib/signalwire/ai_chat'
require_relative '../lib/signalwire/pom/prompt_object_model'
require_relative '../lib/signalwire/core/config_loader'
require_relative '../lib/signalwire/core/agent/prompt/manager'
require_relative '../lib/signalwire/core/agent/tools/registry'
require_relative '../lib/signalwire/security/session_manager'
require_relative '../lib/signalwire/contexts/context_builder'

# One test class per CONSTRUCTION-READBACK subject would scatter the contract;
# keeping the read-back assertions together is the point of the file.
class ConstructionReadbackTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  # --- RelayClient: token / jwt_token / contexts were behind `private` --------
  # The reference sets all three as public attributes from the same-named ctor
  # params (relay/client.py:171-175).

  def relay_client(**over)
    SignalWire::Relay::Client.new(
      project: 'p-1', token: 't-1', host: 'space.example.com', **over
    )
  end

  def test_relay_client_token_readable_back
    assert_equal 't-1', relay_client.token
  end

  def test_relay_client_contexts_readable_back
    assert_equal %w[office support], relay_client(contexts: %w[office support]).contexts
  end

  def test_relay_client_jwt_token_readable_back
    client = SignalWire::Relay::Client.new(jwt_token: 'jwt-abc', host: 'space.example.com')

    assert_equal 'jwt-abc', client.jwt_token
  end

  def test_relay_client_project_readable_back
    assert_equal 'p-1', relay_client.project_id
  end

  # The three readers must be PUBLIC, not merely defined — the whole point.
  def test_relay_client_connection_config_readers_are_public
    public_methods = SignalWire::Relay::Client.public_instance_methods(false)

    %i[token jwt_token contexts project_id].each do |m|
      assert_includes public_methods, m, "#{m} must be public on Relay::Client"
    end
  end

  # --- SessionManager: secret_key / token_expiry_secs -------------------------
  # Reading the secret back is what lets a caller verify or reproduce a token
  # minted elsewhere; the reference keys every HMAC with this string's bytes.

  def test_session_manager_secret_key_readable_back
    mgr = SignalWire::Security::SessionManager.new(secret_key: 'deadbeef' * 8)

    assert_equal 'deadbeef' * 8, mgr.secret_key
  end

  def test_session_manager_generated_secret_key_readable_back
    mgr = SignalWire::Security::SessionManager.new

    # `SecureRandom.hex(32)` — a 64-CHARACTER HEX STRING, matching the
    # reference's `secrets.token_hex(32)`. Not 32 raw bytes: the HMAC is keyed
    # with this string's bytes, so the length is interop-visible and four other
    # ports shipped the wrong convention here.
    assert_equal 64, mgr.secret_key.length
    assert_match(/\A[0-9a-f]{64}\z/, mgr.secret_key)
  end

  def test_session_manager_token_expiry_secs_readable_back
    assert_equal 900, SignalWire::Security::SessionManager.new(token_expiry_secs: 900)
                                                          .token_expiry_secs
  end

  def test_session_manager_token_expiry_secs_reflects_the_clamp
    # The stored value is not always the value passed, which is exactly why the
    # reader matters.
    assert_equal 1, SignalWire::Security::SessionManager.new(token_expiry_secs: 0)
                                                        .token_expiry_secs
  end

  # The secret the reader returns must be the key the HMAC actually uses —
  # otherwise the reader is decorative and cross-port verification fails.
  def test_session_manager_secret_key_is_the_hmac_key
    secret = 'a1b2c3d4' * 8
    mgr = SignalWire::Security::SessionManager.new(secret_key: secret, token_expiry_secs: 600)
    token = mgr.create_token('lookup', 'call-1')

    parts = Base64.urlsafe_decode64(token).split('.')
    call_id, function, expiry, nonce, signature = parts
    expected = OpenSSL::HMAC.hexdigest(
      'SHA256', mgr.secret_key, "#{call_id}:#{function}:#{expiry}:#{nonce}"
    )

    assert_equal expected, signature
  end

  # --- ConfigLoader: config_paths ---------------------------------------------

  def test_config_loader_config_paths_readable_back
    loader = SignalWire::Core::ConfigLoader.new(['/nope/one.json', '/nope/two.json'])

    assert_equal ['/nope/one.json', '/nope/two.json'], loader.config_paths
  end

  def test_config_loader_default_config_paths_readable_back
    # The reference resolves the default list into the same attribute, so which
    # paths a loader is consulting is readable either way.
    assert_equal SignalWire::Core::ConfigLoader::DEFAULT_PATHS,
                 SignalWire::Core::ConfigLoader.new(nil).config_paths
  end

  # --- PromptManager / ToolRegistry: the agent back-reference -----------------

  def test_prompt_manager_agent_readable_back
    agent = Object.new
    mgr = SignalWire::Core::Agent::Prompt::PromptManager.new(agent)

    assert_same agent, mgr.agent
  end

  def test_prompt_manager_agent_nil_when_standalone
    assert_nil SignalWire::Core::Agent::Prompt::PromptManager.new.agent
  end

  def test_tool_registry_agent_readable_back
    agent = Object.new
    reg = SignalWire::Core::Agent::Tools::ToolRegistry.new(agent)

    assert_same agent, reg.agent
  end

  def test_tool_registry_agent_nil_when_standalone
    assert_nil SignalWire::Core::Agent::Tools::ToolRegistry.new.agent
  end

  # --- Error types: the ctor'd code/message pair -----------------------------
  # Ruby cannot name these readers `message` (`Exception#message` is stdlib), so
  # the port spells them error_message / server_message and the enumerators
  # RENAME them onto the reference identity. Both halves must be readable.

  def test_relay_error_code_and_message_readable_back
    err = SignalWire::Relay::RelayError.new(-32_000, 'boom')

    assert_equal(-32_000, err.code)
    assert_equal 'boom', err.error_message
  end

  def test_relay_error_preserves_the_raw_server_message_undecorated
    # The decorated `message` carries the code prefix; the raw server text must
    # survive separately (a sibling port discarded it).
    err = SignalWire::Relay::RelayError.new(42, 'raw text')

    assert_equal 'raw text', err.error_message
    assert_includes err.message, 'raw text'
  end

  def test_ai_chat_error_code_and_message_readable_back
    err = SignalWire::AIChat::AIChatError.new(-32_009, 'unauthorized')

    assert_equal(-32_009, err.code)
    assert_equal 'unauthorized', err.server_message
  end

  # --- Section.numberedBullets ------------------------------------------------
  # The oracle records the POM WIRE KEY camelCase verbatim; Ruby spells the
  # reader snake_case. The value must round-trip either way.

  def test_section_numbered_bullets_readable_back
    section = SignalWire::POM::Section.new('T', numbered_bullets: true)

    assert section.numbered_bullets
  end

  def test_section_numbered_bullets_round_trips_to_the_camel_case_wire_key
    section = SignalWire::POM::Section.new('T', numbered_bullets: true)

    assert_equal true, section.to_h['numberedBullets']
  end

  # --- GatherQuestion.isolated ------------------------------------------------

  def test_gather_question_isolated_readable_back
    q = SignalWire::Contexts::GatherQuestion.new(key: 'k', question: 'Q?', isolated: true)

    assert q.isolated
  end

  def test_gather_question_isolated_is_tri_state
    build = lambda do |**over|
      SignalWire::Contexts::GatherQuestion.new(key: 'k', question: 'Q?', **over)
    end

    assert_nil build.call.isolated, 'nil inherits the gather default'
    assert_equal false, build.call(isolated: false).isolated
    assert_equal true, build.call(isolated: true).isolated
  end

  # --- AIChatClient.url -------------------------------------------------------

  def test_ai_chat_client_url_readable_back
    client = SignalWire::AIChatClient.new(
      project: 'p', token: 't', url: 'wss://chat.example.com/rpc'
    )

    assert_equal 'wss://chat.example.com/rpc', client.url
  end

  # --- SignalWireRestError.method --------------------------------------------
  # `method` is `Object#method` in Ruby, so the reader is `method_name`.

  def test_rest_error_method_readable_back
    err = SignalWire::REST::SignalWireRestError.new(404, 'boom', 'https://x/y', 'GET')

    assert_equal 'GET', err.method_name
    assert_equal 404, err.status_code
    assert_equal 'https://x/y', err.url
  end
end
