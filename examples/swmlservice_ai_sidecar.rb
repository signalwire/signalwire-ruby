# frozen_string_literal: true

# Example: SWML::Service emitting `ai_sidecar` and hosting SWAIG tools.
#
# Proves that SignalWire::SWML::Service can emit the `ai_sidecar` verb,
# register SWAIG tools the sidecar's LLM can call, and dispatch them
# end-to-end -- without any AgentBase code path.
#
# The `ai_sidecar` verb runs an AI listener alongside an in-progress
# call (real-time copilot, transcription analyzer, compliance monitor,
# etc.). It does NOT own the call, so the right host is SWML::Service,
# not AgentBase.
#
# Run:
#     ruby examples/swmlservice_ai_sidecar.rb
#
# What this serves:
#     GET  /sales-sidecar           -- SWML doc with the ai_sidecar verb
#     POST /sales-sidecar/swaig     -- SWAIG tool dispatch (used by sidecar's LLM)
#     POST /sales-sidecar/events    -- ai_sidecar lifecycle/transcription events

require 'signalwire'

# SWML::Service subclass that emits <ai_sidecar> and hosts the tools its
# LLM calls. No AgentBase in the inheritance chain.
class SalesSidecar < SignalWire::SWML::Service
  SIDECAR_PROMPT = 'You are a real-time sales copilot. Listen to the call ' \
                   'and surface competitor pricing comparisons when relevant.'

  COMPETITOR_PARAMS = {
    'competitor' => {
      'type' => 'string',
      'description' => "The competitor's company name, e.g. 'ACME'."
    }
  }.freeze

  COMPETITOR_TOOL_DESCRIPTION = 'Look up competitor pricing by company name. ' \
                                'The sidecar should call this whenever the ' \
                                'caller mentions a competitor.'

  def initialize(public_url: 'https://your-host.example.com/sales-sidecar',
                 host: '0.0.0.0', port: nil)
    super(
      name: 'sales-sidecar',
      route: '/sales-sidecar',
      host: host,
      port: port
    )

    build_document(public_url)
    register_lookup_competitor
    mount_event_sink
  end

  private

  # 1. Emit any SWML -- including ai_sidecar. Service#add_verb_to_section
  #    validates the config against the SWML schema, so a typo'd key or an
  #    out-of-enum value fails here instead of shipping an invalid document.
  #    (Document#add_verb_to_section is the raw path and skips that check --
  #    do not reach for it.)
  def build_document(public_url)
    answer
    add_verb_to_section('main', 'ai_sidecar', sidecar_config(public_url))
    hangup
  end

  # `url` is where the sidecar POSTs lifecycle/transcription events (optional --
  # skip if you don't need an event sink). `SWAIG.defaults.web_hook_url` is where
  # the sidecar's LLM POSTs tool calls; this service's /swaig route answers them.
  # The SWAIG hash key is UPPERCASE per spec.
  def sidecar_config(public_url)
    {
      'prompt' => SIDECAR_PROMPT,
      'lang' => 'en-US',
      'direction' => %w[remote-caller local-caller],
      'url' => "#{public_url}/events",
      'SWAIG' => { 'defaults' => { 'web_hook_url' => "#{public_url}/swaig" } }
    }
  end

  # 2. Register tools the sidecar's LLM can call. Same `define_tool`
  #    you'd use on AgentBase -- it lives on SWML::Service.
  def register_lookup_competitor
    define_tool(
      name: 'lookup_competitor',
      description: COMPETITOR_TOOL_DESCRIPTION,
      parameters: COMPETITOR_PARAMS,
      secure: false
    ) do |args, _raw_data|
      competitor = args['competitor'] || '<unknown>'
      { 'response' => "Pricing for #{competitor}: $99/seat. " \
                      'Our equivalent plan is $79/seat with the same SLA.' }
    end
  end

  # 3. (Optional) Mount an event sink for ai_sidecar lifecycle events
  #    at POST /sales-sidecar/events. Comment this out if you don't
  #    need it. The sidecar POSTs each event as JSON.
  def mount_event_sink
    register_routing_callback(nil, '/events') do |request_data|
      event_type = request_data && request_data['type']
      warn "[sidecar event] type=#{event_type.inspect} body=#{request_data.inspect}"
      { 'ok' => true }
    end
  end
end

SalesSidecar.new.serve if __FILE__ == $PROGRAM_NAME
