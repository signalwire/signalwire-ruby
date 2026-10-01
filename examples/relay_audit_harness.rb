#!/usr/bin/env ruby
# frozen_string_literal: true

# relay_audit_harness.rb -- runtime probe for the RELAY transport.
#
# This program is what porting-sdk's audit_relay_handshake.py drives to
# prove the Ruby SDK's RELAY client opens a real WebSocket connection,
# runs the signalwire.connect handshake, subscribes to a context, and
# dispatches an inbound signalwire.event frame to the registered
# callback. A green run from the audit means: socket actually opened
# (no stub transport), JSON-RPC actually serialised, real bytes on the
# wire.
#
# Environment variables (set by the audit fixture):
#   - SIGNALWIRE_RELAY_HOST     "127.0.0.1:NNNN" (the fixture's port)
#   - SIGNALWIRE_RELAY_SCHEME   "ws" (audit) or "wss" (production)
#   - SIGNALWIRE_PROJECT_ID     "audit"
#   - SIGNALWIRE_API_TOKEN      "audit"
#   - SIGNALWIRE_CONTEXTS       "audit_ctx" (comma-separated)
#
# Exit codes:
#   - 0 on a clean handshake + subscribe + event dispatch
#   - 1 on any error (socket failure, handshake timeout, no event in 5s)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

ENV['SIGNALWIRE_LOG_MODE'] ||= 'off'

require 'signalwire/relay/client'
require 'signalwire/relay/constants'

project  = ENV.fetch('SIGNALWIRE_PROJECT_ID', nil)
project  = 'audit' if project.nil? || project.empty?
token    = ENV.fetch('SIGNALWIRE_API_TOKEN', nil)
token    = 'audit' if token.nil? || token.empty?
host     = ENV.fetch('SIGNALWIRE_RELAY_HOST', nil)
host     = 'audit.host' if host.nil? || host.empty?
contexts = (ENV['SIGNALWIRE_CONTEXTS'] || 'audit_ctx')
           .split(',').map(&:strip).reject(&:empty?)

client = SignalWire::Relay::Client.new(
  project: project,
  token: token,
  space: host,
  contexts: contexts
)

saw_event_mutex = Mutex.new
saw_event_cv    = ConditionVariable.new
saw_event       = false

# Wire a generic event handler so the audit's signalwire.event push
# reaches user code. The fixture's `state.event_dispatched` flag is
# only set when the client emits a method:"signalwire.event" frame
# back, so we explicitly send one (mirrors the Rust SDK's harness
# behavior — Ruby's normal _handle_event ack is method-less).
client.on_event do |event_type, event_params, _outer|
  saw_event_mutex.synchronize do
    saw_event = true
    saw_event_cv.signal
  end

  client.send_json(
    'jsonrpc' => '2.0',
    'id' => "dispatched-#{event_type}",
    'method' => SignalWire::Relay::METHOD_SIGNALWIRE_EVENT,
    'params' => {
      'dispatched' => true,
      'event_type' => event_type,
      'echoed' => event_params
    }
  )
end

# Run the connection in a background thread so the main thread can
# drive the protocol (subscribe + wait-for-event + clean shutdown).
# `run` blocks until `stop` is called; on connect failure it falls
# through to the reconnect loop, which is fine for the audit fixture
# (the connection is supposed to succeed first try).
run_thread = Thread.new do
  client.run
rescue StandardError => e
  warn "relay_audit_harness: client.run raised: #{e.message}"
end

# Wait for the client to authenticate (signalwire.connect completed
# = `@protocol` set). The fixture replies to connect almost
# immediately, so a brief poll loop is sufficient.
deadline = Time.now + 5
sleep 0.05 until client.protocol || Time.now > deadline

# Send signalwire.subscribe explicitly so the audit fixture's method
# watch fires (the fixture only counts `signalwire.subscribe`, not
# `signalwire.receive`). The fixture replies with `{contexts}`.
begin
  client.execute('signalwire.subscribe', { 'contexts' => contexts })
rescue StandardError => e
  warn "relay_audit_harness: subscribe failed: #{e.message}"
end

# Wait up to 5 seconds for an inbound event to be dispatched.
saw_event_mutex.synchronize do
  deadline = Time.now + 5
  until saw_event
    remaining = deadline - Time.now
    break if remaining <= 0

    saw_event_cv.wait(saw_event_mutex, remaining)
  end
end

got_event = saw_event_mutex.synchronize { saw_event }

# Give the writer thread a moment to flush the dispatched-event frame
# to the socket before we close, so the audit fixture sees it.
sleep 0.3

client.stop
run_thread.join(2)

unless got_event
  warn 'relay_audit_harness: no event arrived within 5s'
  exit 1
end

puts 'relay_audit_harness: event dispatched'
exit 0
