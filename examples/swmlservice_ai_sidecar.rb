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
  def initialize(public_url: 'https://your-host.example.com/sales-sidecar',
                 host: '0.0.0.0', port: nil)
    super(
      name:  'sales-sidecar',
      route: '/sales-sidecar',
      host:  host,
      port:  port
    )

    # 1. Emit any SWML -- including ai_sidecar. Document#add_verb_to_section
    #    accepts arbitrary verb dicts, so new platform verbs work without
    #    an SDK release.
    answer
    document.add_verb_to_section(
      'main',
      'ai_sidecar',
      {
        'prompt'    => 'You are a real-time sales copilot. Listen to the ' \
                       'call and surface competitor pricing comparisons ' \
                       'when relevant.',
        'lang'      => 'en-US',
        'direction' => %w[remote-caller local-caller],
        # Where the sidecar POSTs lifecycle/transcription events.
        # Optional -- skip if you don't need an event sink.
        'url'       => "#{public_url}/events",
        # Where the sidecar's LLM POSTs SWAIG tool calls. This service's
        # /swaig route answers them. SWAIG hash key is UPPERCASE per spec.
        'SWAIG'     => {
          'defaults' => { 'web_hook_url' => "#{public_url}/swaig" }
        }
      }
    )
    hangup

    # 2. Register tools the sidecar's LLM can call. Same `define_tool`
    #    you'd use on AgentBase -- it lives on SWML::Service.
    define_tool(
      name:        'lookup_competitor',
      description: 'Look up competitor pricing by company name. The sidecar ' \
                   'should call this whenever the caller mentions a competitor.',
      parameters:  {
        'competitor' => {
          'type'        => 'string',
          'description' => "The competitor's company name, e.g. 'ACME'."
        }
      },
      secure: false
    ) do |args, _raw_data|
      competitor = args['competitor'] || '<unknown>'
      {
        'response' => "Pricing for #{competitor}: $99/seat. " \
                      'Our equivalent plan is $79/seat with the same SLA.'
      }
    end

    # 3. (Optional) Mount an event sink for ai_sidecar lifecycle events
    #    at POST /sales-sidecar/events. Comment this out if you don't
    #    need it. The sidecar POSTs each event as JSON.
    register_routing_callback(nil, '/events') do |request_data|
      event_type = request_data && request_data['type']
      warn "[sidecar event] type=#{event_type.inspect} body=#{request_data.inspect}"
      { 'ok' => true }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  SalesSidecar.new.serve
end
