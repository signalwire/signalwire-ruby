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

operation   = ENV['REST_OPERATION']
fixture_url = ENV['REST_FIXTURE_URL']
project     = ENV['SIGNALWIRE_PROJECT_ID']
token       = ENV['SIGNALWIRE_API_TOKEN']

%w[REST_OPERATION REST_FIXTURE_URL SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN].each do |k|
  if ENV[k].nil? || ENV[k].empty?
    warn "rest_audit_harness: #{k} env var required"
    exit 1
  end
end

args_raw = ENV['REST_OPERATION_ARGS']
args_raw = '{}' if args_raw.nil? || args_raw.empty?
begin
  args = JSON.parse(args_raw)
rescue JSON::ParserError => e
  warn "rest_audit_harness: REST_OPERATION_ARGS not JSON: #{e.message}"
  exit 1
end

client = SignalWire::REST::RestClient.new(
  project:  project,
  token:    token,
  base_url: fixture_url
)

# Helpers --------------------------------------------------------------

def args_to_kwargs(args)
  args.transform_keys(&:to_sym)
end

# Dispatcher -----------------------------------------------------------

result =
  case operation
  when 'calling.list_calls', 'compatibility.calls.list'
    # The compat namespace handles Twilio-style LAML /Accounts/{proj}/Calls.
    # The audit's expected_path_substring is /api/laml/2010-04-01/Accounts.
    client.compat.calls.list(**args_to_kwargs(args))
  when 'messaging.send'
    body = {}
    args.each do |k, v|
      key = k == 'from_' ? 'From' : k.split('_').map(&:capitalize).join
      body[key] = v
    end
    # Send via the Compat messages endpoint -- POST
    # /Accounts/{proj}/Messages.json. The audit just checks for
    # `Messages` in the path and a Basic auth header.
    client.compat.messages.create(**args_to_kwargs(args))
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
