# frozen_string_literal: true

# Shared test helper for the signalwire-ruby suite.
#
# Centralizes the setup that was previously duplicated across the skill,
# CLI, and parity tests:
#
#   - the built-in skill registry is registered exactly once (idempotent),
#   - the canonical built-in skill-name list (BUILTIN_SKILL_NAMES),
#   - global-state reset helpers (ENV save/restore, skill-registry reset)
#     so tests are order-independent and don't leak env vars / registry
#     entries into each other,
#   - the ephemeral-port picker + WEBrick fixture (LocalHTTPFixture) and the
#     server-readiness wait used by the CLI and network-backed skill tests.
#
# This helper only relocates setup; it does NOT change what any test asserts.
# Test files pull it in with `require_relative 'test_helper'` (or
# `'../test_helper'` from a subdir).

require 'minitest/autorun'
require 'socket'
require 'webrick'

require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/datamap/data_map'
require_relative '../lib/signalwire/skills/skill_base'
require_relative '../lib/signalwire/skills/skill_manager'
require_relative '../lib/signalwire/skills/skill_registry'

module TestHelper
  # The canonical list of built-in skills the Ruby port registers.
  #
  # 17 built-ins: mcp_gateway is NOT ported (approved Python-only per §I.1).
  # This is the single source consumed by both skills_test.rb and
  # skills/registry_test.rb. tests/skill_name_test.rb keeps its OWN copy on
  # purpose — it is a deliberate independent cross-check of this set.
  BUILTIN_SKILL_NAMES = %w[
    api_ninjas_trivia
    claude_skills
    custom_skills
    datasphere
    datasphere_serverless
    datetime
    google_maps
    info_gatherer
    joke
    math
    native_vector_search
    play_background_file
    spider
    swml_transfer
    weather_api
    web_search
    wikipedia_search
  ].freeze

  # Register the built-in skills exactly once for the whole test process.
  # SkillRegistry.register_builtins! is idempotent, but calling it from a
  # single place keeps the ordering deterministic regardless of which test
  # file loads first.
  def self.register_builtins!
    SignalWire::Skills::SkillRegistry.register_builtins!
  end

  register_builtins!

  # Mixin of global-state reset + fixture helpers. `include TestHelper::Helpers`
  # in a Minitest::Test to get them.
  module Helpers
    # ── ENV save/restore ────────────────────────────────────────────────
    # Clear +names+ for the duration of the block, restoring prior values
    # afterward (whether the block raises or not). A nil prior value means the
    # var was unset and stays unset.
    def without_env_vars(*names)
      saved = names.flatten.to_h { |k| [k, ENV.delete(k)] }
      yield
    ensure
      saved.each { |k, v| ENV[k] = v if v }
    end

    # Set +name+ to +value+ for the block, restoring the prior value after.
    def with_env_var(name, value)
      saved = ENV.delete(name)
      ENV[name] = value
      yield
    ensure
      ENV.delete(name)
      ENV[name] = saved if saved
    end

    # ── skill registry ──────────────────────────────────────────────────
    # Build a built-in skill instance by name with the given params.
    def build_skill(name, params = {})
      SignalWire::Skills::SkillRegistry.get_factory(name).call(params)
    end

    # Remove a dynamically-registered skill factory so a test that registers
    # its own class does not leak into later tests (the built-ins are left
    # intact).
    def deregister_skill(name)
      factories = SignalWire::Skills::SkillRegistry.instance_variable_get(:@factories)
      factories&.delete(name)
    end

    # ── ephemeral port + server readiness ───────────────────────────────
    # Bind an OS-assigned free loopback port and release it, returning the
    # port number. Callers immediately bind their own server to it.
    def find_available_port
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      port
    end

    # Poll until a TCP server accepts a connection on host:port, or raise once
    # +timeout+ seconds elapse.
    def wait_for_server(host, port, timeout: 5)
      deadline = Time.now + timeout
      loop do
        TCPSocket.new(host, port).close
        return
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        raise "Server did not start within #{timeout}s" if Time.now > deadline

        sleep 0.05
      end
    end
  end

  # A tiny local WEBrick HTTP fixture bound to an ephemeral loopback port.
  # A block decides each response from the request, returning
  # [content_type, body] (or nil for a 404). Used by the network-backed skill
  # tests so they never touch the real network or the shared mock server.
  class LocalHTTPFixture
    attr_reader :port

    def initialize(&handler)
      @handler = handler
      @port = pick_free_port
      @server = build_server(@port)
      @server.mount_proc('/') { |req, res| render_response(req, res) }
      @thread = Thread.new { @server.start }
      wait_until_ready
    end

    def base_url
      "http://127.0.0.1:#{@port}"
    end

    def shutdown
      @server&.shutdown
      @thread&.join(5)
    end

    private

    def build_server(port)
      WEBrick::HTTPServer.new(
        BindAddress: '127.0.0.1',
        Port: port,
        Logger: WEBrick::Log.new(File.open(File::NULL, 'w'), WEBrick::Log::FATAL),
        AccessLog: []
      )
    end

    def render_response(req, res)
      result = @handler.call(req)
      if result.nil?
        res.status = 404
        res.body = 'not found'
      else
        content_type, body = result
        res.status = 200
        res['Content-Type'] = content_type
        res.body = body
      end
    end

    def pick_free_port
      s = TCPServer.new('127.0.0.1', 0)
      port = s.addr[1]
      s.close
      port
    end

    def wait_until_ready
      20.times do
        TCPSocket.new('127.0.0.1', @port).close
        return
      rescue Errno::ECONNREFUSED
        sleep 0.05
      end
    end
  end
end
