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

# Dispatch logic differs for handler-based vs DataMap-based skills.
def dispatch_handler(tool_defs, tool_name, args)
  td = tool_defs.find { |t| (t[:name] || t['name']) == tool_name }
  unless td
    warn "skills_audit_harness: tool '#{tool_name}' not registered"
    exit 1
  end
  handler = td[:handler] || td['handler']
  unless handler
    warn "skills_audit_harness: tool '#{tool_name}' has no handler"
    exit 1
  end
  handler.call(args, {})
end

def expand_template(template, args)
  out = String.new
  i = 0
  while i < template.length
    if template[i] == '%' && template[i + 1] == '{'
      close = template.index('}', i + 2)
      if close
        key = template[(i + 2)...close]
        if key.start_with?('args.')
          v = args[key.sub('args.', '')]
          out << v.to_s if v
        else
          out << template[i..close]
        end
        i = close + 1
        next
      end
    end
    out << template[i]
    i += 1
  end
  out
end

def execute_datamap(tool_defs, tool_name, args)
  # DataMap skills register definitions under :datamap (Ruby) — find
  # the matching one, extract its first webhook URL, and execute the
  # request the same way the SignalWire platform would.
  td = tool_defs.find do |t|
    dm = t[:datamap] || t['datamap']
    dm && (dm['function'] == tool_name || dm[:function] == tool_name)
  end
  unless td
    warn "skills_audit_harness: DataMap tool '#{tool_name}' not registered"
    exit 1
  end
  dm = td[:datamap] || td['datamap']

  webhook = (dm['data_map'] || dm[:data_map] || {})['webhooks']&.first ||
            (dm['data_map'] || dm[:data_map] || {})[:webhooks]&.first
  unless webhook
    warn "skills_audit_harness: DataMap tool '#{tool_name}' has no webhook"
    exit 1
  end

  url     = expand_template(webhook['url'] || webhook[:url], args)
  method  = (webhook['method'] || webhook[:method] || 'GET').upcase
  headers = webhook['headers'] || webhook[:headers] || {}

  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')

  req = case method
        when 'GET'  then Net::HTTP::Get.new(uri)
        when 'POST' then Net::HTTP::Post.new(uri)
        else
          warn "skills_audit_harness: unsupported method '#{method}'"
          exit 1
        end

  headers.each { |k, v| req[k.to_s] = v.to_s }
  req.body = '' if method == 'POST'

  resp = http.request(req)
  body = begin
    JSON.parse(resp.body || '')
  rescue JSON::ParserError
    resp.body
  end
  { 'status' => resp.code.to_i, 'url' => url, 'body' => body }
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
