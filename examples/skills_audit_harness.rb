#!/usr/bin/env ruby
# frozen_string_literal: true

# skills_audit_harness.rb -- runtime probe for the skills system.
#
# Driven by porting-sdk's audit_skills_dispatch.py. Reads:
#   - SKILL_NAME            e.g. 'web_search', 'datasphere'
#   - SKILL_FIXTURE_URL     'http://127.0.0.1:NNNN'
#   - SKILL_HANDLER_ARGS    JSON dict of args for the handler
#   - per-skill upstream env (e.g. WEB_SEARCH_BASE_URL); the audit
#     sets these to redirect the skill at the loopback fixture
#   - per-skill credential env vars (e.g. GOOGLE_API_KEY)
#
# For handler-based skills (web_search, wikipedia_search, datasphere,
# spider) we instantiate the skill directly and dispatch its handler
# with the parsed args. The skill's handler issues real HTTP through
# Net::HTTP (proven by the audit fixture seeing the request).
#
# For DataMap-based skills (api_ninjas_trivia, weather_api) the
# SignalWire platform — not the SDK — would normally fetch the
# configured webhook URL. The harness simulates the platform by
# extracting the webhook URL from the registered DataMap and issuing
# the HTTP call itself, satisfying the audit's contract that "the
# SDK contacted the upstream" via real bytes on the wire.
#
# Exit codes:
#   - 0 on success (skill registered, handler returned, output JSON
#     printed to stdout)
#   - 1 on any error

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

ENV['SIGNALWIRE_LOG_MODE'] ||= 'off'

require 'json'
require 'uri'
require 'net/http'

require 'signalwire/skills/skill_registry'
require 'signalwire/swaig/function_result'

skill_name = ENV.fetch('SKILL_NAME', nil)
if skill_name.nil? || skill_name.empty?
  warn 'skills_audit_harness: SKILL_NAME required'
  exit 1
end

args_raw = ENV.fetch('SKILL_HANDLER_ARGS', nil)
args_raw = '{}' if args_raw.nil? || args_raw.empty?
begin
  args = JSON.parse(args_raw)
rescue JSON::ParserError => e
  warn "skills_audit_harness: SKILL_HANDLER_ARGS not JSON: #{e.message}"
  exit 1
end

# Wire skill-specific construction params from the audit-mandated env
# vars (mirrors what a deployed agent would read).
skill_params = {}
case skill_name
when 'web_search'
  skill_params['api_key']           = ENV['GOOGLE_API_KEY']           if ENV['GOOGLE_API_KEY']
  skill_params['search_engine_id']  = ENV['GOOGLE_CSE_ID']            if ENV['GOOGLE_CSE_ID']
when 'datasphere'
  # The skill validates project_id / space_name / document_id even
  # though the actual upstream URL comes from DATASPHERE_BASE_URL.
  skill_params['space_name']  = 'audit-space'
  skill_params['project_id']  = 'audit-project'
  skill_params['document_id'] = 'audit-doc'
  skill_params['token']       = ENV['DATASPHERE_TOKEN'] if ENV['DATASPHERE_TOKEN']
when 'weather_api'
  skill_params['api_key'] = ENV['WEATHER_API_KEY'] if ENV['WEATHER_API_KEY']
when 'api_ninjas_trivia'
  skill_params['api_key'] = ENV['API_NINJAS_KEY'] if ENV['API_NINJAS_KEY']
end

# Load and instantiate the skill.
SignalWire::Skills::SkillRegistry.register_builtins!
factory = SignalWire::Skills::SkillRegistry.get_factory(skill_name)
unless factory
  warn "skills_audit_harness: skill '#{skill_name}' is not registered"
  exit 1
end

skill = factory.call(skill_params)
unless skill.setup
  warn "skills_audit_harness: skill '#{skill_name}' setup() returned false"
  exit 1
end

tool_defs = skill.register_tools
unless tool_defs.is_a?(Array) && !tool_defs.empty?
  warn "skills_audit_harness: skill '#{skill_name}' did not register any tools"
  exit 1
end

# Read a key that may be present in either the String or the Symbol spelling
# (the tool-def / DataMap tree mixes both depending on how the skill built it).
def either(hash, key)
  hash[key.to_s] || hash[key.to_sym]
end

# +value+, or a fatal "skills_audit_harness: <what>" exit when it is absent.
def require_present(value, what)
  return value if value

  warn "skills_audit_harness: #{what}"
  exit 1
end

# Dispatch logic differs for handler-based vs DataMap-based skills.
def dispatch_handler(tool_defs, tool_name, args)
  td = require_present(tool_defs.find { |t| either(t, :name) == tool_name },
                       "tool '#{tool_name}' not registered")
  handler = require_present(either(td, :handler),
                            "tool '#{tool_name}' has no handler")
  handler.call(args, {})
end

# Substitute one `%{args.NAME}` placeholder starting at +idx+. Returns
# [text_to_append, next_index], or nil when +idx+ does not open a placeholder.
def expand_placeholder(template, args, idx)
  return nil unless template[idx] == '%' && template[idx + 1] == '{'

  close = template.index('}', idx + 2)
  return nil unless close

  key = template[(idx + 2)...close]
  return [template[idx..close], close + 1] unless key.start_with?('args.')

  # A falsy arg expands to the empty string (the original `<< v.to_s if v`),
  # so `%{args.missing}` disappears rather than becoming "" / "false".
  value = args[key.sub('args.', '')]
  [value ? value.to_s : '', close + 1]
end

def expand_template(template, args)
  out = +''
  i = 0
  while i < template.length
    expansion = expand_placeholder(template, args, i)
    text, i = expansion || [template[i], i + 1]
    out << text
  end
  out
end

# Locate the registered DataMap for +tool_name+ and return its first webhook.
def datamap_webhook(tool_defs, tool_name)
  td = require_present(
    tool_defs.find { |t| (dm = either(t, :datamap)) && either(dm, :function) == tool_name },
    "DataMap tool '#{tool_name}' not registered"
  )
  data_map = either(either(td, :datamap), :data_map) || {}
  require_present(either(data_map, :webhooks)&.first,
                  "DataMap tool '#{tool_name}' has no webhook")
end

# Build the Net::HTTP request the SignalWire platform would issue for +webhook+.
def datamap_request(webhook, url, method)
  req = case method
        when 'GET'  then Net::HTTP::Get.new(URI(url))
        when 'POST' then Net::HTTP::Post.new(URI(url))
        else
          warn "skills_audit_harness: unsupported method '#{method}'"
          exit 1
        end

  (either(webhook, :headers) || {}).each { |k, v| req[k.to_s] = v.to_s }
  req.body = '' if method == 'POST'
  req
end

# Issue +req+ to +url+ and return [status, parsed-or-raw body].
def datamap_fetch(url, req)
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'

  resp = http.request(req)
  body = begin
    JSON.parse(resp.body || '')
  rescue JSON::ParserError
    resp.body
  end
  [resp.code.to_i, body]
end

def execute_datamap(tool_defs, tool_name, args)
  # DataMap skills register definitions under :datamap (Ruby) — find
  # the matching one, extract its first webhook URL, and execute the
  # request the same way the SignalWire platform would.
  webhook = datamap_webhook(tool_defs, tool_name)
  url     = expand_template(either(webhook, :url), args)
  method  = (either(webhook, :method) || 'GET').upcase

  status, body = datamap_fetch(url, datamap_request(webhook, url, method))
  { 'status' => status, 'url' => url, 'body' => body }
end

result =
  case skill_name
  when 'web_search'        then dispatch_handler(tool_defs, 'web_search',         args)
  when 'wikipedia_search'  then dispatch_handler(tool_defs, 'search_wiki',        args)
  when 'datasphere'        then dispatch_handler(tool_defs, 'search_knowledge',   args)
  when 'spider'            then dispatch_handler(tool_defs, 'scrape_url',         args)
  when 'weather_api'       then execute_datamap(tool_defs,  'get_weather',        args)
  when 'api_ninjas_trivia'
    # The audit doesn't pass a `category` arg but the URL template
    # requires one — synthesize 'general' so the GET still goes out.
    args['category'] = 'general' unless args.key?('category')
    execute_datamap(tool_defs, 'get_trivia', args)
  else
    warn "skills_audit_harness: unsupported skill '#{skill_name}'"
    exit 1
  end

# `dispatch_handler` returns a SwaigFunctionResult; serialize via to_h.
serialised =
  if result.respond_to?(:to_h)
    result.to_h
  else
    result
  end

puts JSON.generate(serialised)
exit 0
