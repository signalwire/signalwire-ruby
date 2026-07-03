#!/usr/bin/env ruby
# frozen_string_literal: true

# rest_audit_harness.rb -- runtime probe for the REST transport.
#
# Driven by porting-sdk's audit_rest_transport.py. Reads:
#   - REST_OPERATION       dotted name (e.g. 'calling.list_calls')
#   - REST_FIXTURE_URL     'http://127.0.0.1:NNNN'
#   - REST_OPERATION_ARGS  JSON dict of args for the operation
#   - SIGNALWIRE_PROJECT_ID, SIGNALWIRE_API_TOKEN
#
# Constructs a RestClient pointed at REST_FIXTURE_URL (NOT through the
# usual https://{space} resolution -- the audit needs to inject its
# loopback fixture URL), invokes the named operation, and prints the
# parsed return value as JSON to stdout. Exits non-zero on any error.
#
# Operations supported by this harness:
#   - calling.list_calls         GET  /api/laml/2010-04-01/Accounts/{proj}/Calls.json
#   - messaging.send             POST /api/laml/2010-04-01/Accounts/{proj}/Messages.json
#   - phone_numbers.list         GET  /api/relay/rest/phone_numbers
#   - fabric.subscribers.list    GET  /api/fabric/resources/subscribers
#   - compatibility.calls.list   GET  /api/laml/2010-04-01/Accounts/{proj}/Calls.json

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

ENV['SIGNALWIRE_LOG_MODE'] ||= 'off'

require 'json'
require 'signalwire/rest/rest_client'

operation   = ENV.fetch('REST_OPERATION', nil)
fixture_url = ENV.fetch('REST_FIXTURE_URL', nil)
project     = ENV.fetch('SIGNALWIRE_PROJECT_ID', nil)
token       = ENV.fetch('SIGNALWIRE_API_TOKEN', nil)

%w[REST_OPERATION REST_FIXTURE_URL SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN].each do |k|
  if ENV[k].nil? || ENV[k].empty?
    warn "rest_audit_harness: #{k} env var required"
    exit 1
  end
end

args_raw = ENV.fetch('REST_OPERATION_ARGS', nil)
args_raw = '{}' if args_raw.nil? || args_raw.empty?
begin
  args = JSON.parse(args_raw)
rescue JSON::ParserError => e
  warn "rest_audit_harness: REST_OPERATION_ARGS not JSON: #{e.message}"
  exit 1
end

client = SignalWire::REST::RestClient.new(
  project: project,
  token: token,
  base_url: fixture_url
)

# Helpers --------------------------------------------------------------

def args_to_kwargs(args)
  args.transform_keys(&:to_sym)
end

# The Twilio-compat (LAML) REST surface has been removed from the SDK, so the
# three LAML-path audit probes (calling.list_calls / messaging.send /
# compatibility.calls.list) no longer have a typed namespace. They still exercise
# the REST transport, so we drive them straight through the client's HttpClient
# on the hand-built LAML path — the audit fixture only checks the path substring
# and the Basic-auth header, not a typed compat resource. Mirrors php commit
# 7f5538a's RestAuditHarness (callingListCalls/messagingSend via getHttp()).
def laml_base(client)
  "/api/laml/2010-04-01/Accounts/#{client.project_id}"
end

# Dispatcher -----------------------------------------------------------

result =
  case operation
  when 'calling.list_calls', 'compatibility.calls.list'
    client.http.get("#{laml_base(client)}/Calls.json", args_to_kwargs(args))
  when 'messaging.send'
    client.http.post("#{laml_base(client)}/Messages.json", args_to_kwargs(args))
  when 'phone_numbers.list'
    client.phone_numbers.list(**args_to_kwargs(args))
  when 'fabric.subscribers.list'
    client.fabric.subscribers.list(**args_to_kwargs(args))
  else
    warn "rest_audit_harness: unsupported operation '#{operation}'"
    exit 1
  end

puts JSON.generate(result)
exit 0
