# frozen_string_literal: true

# Example: SWML::Service hosting SWAIG functions WITHOUT AgentBase.
#
# Proves that SignalWire::SWML::Service -- by itself, with NO AgentBase --
# can host SWAIG functions and serve them on its own /swaig endpoint.
#
# This is the path you take when you want a SWAIG-callable HTTP service
# that isn't an `<ai>` agent: the SWAIG verb is a generic LLM-tool surface
# and SWML::Service is the host. AgentBase is just a SWML::Service subclass
# that *also* layers in prompts, AI config, dynamic config, and token
# validation.
#
# Run:
#     ruby examples/swmlservice_swaig_standalone.rb
#
# Then exercise the endpoints:
#     curl -u USER:PASS http://localhost:3000/standalone        # GET SWML doc
#     curl -u USER:PASS http://localhost:3000/standalone/swaig \
#         -H 'Content-Type: application/json' \
#         -d '{"function":"lookup_competitor","argument":{"parsed":[{"competitor":"ACME"}]}}'
#
# (USER/PASS come from SWML_BASIC_AUTH_USER/SWML_BASIC_AUTH_PASSWORD or the
# auto-generated pair logged on startup.)

require 'signalwire'

# SWML::Service subclass that registers SWAIG tools and serves them
# on /swaig. No AgentBase in the inheritance chain.
class StandaloneSwaig < SignalWire::SWML::Service
  def initialize(host: '0.0.0.0', port: nil)
    super(
      name: 'standalone-swaig',
      route: '/standalone',
      host: host,
      port: port
    )

    # 1. Build a minimal SWML document. Any verbs are fine -- the SWAIG
    #    HTTP surface is independent of what the document contains.
    answer
    hangup

    # 2. Register a SWAIG function. `define_tool` lives on SWML::Service,
    #    not just AgentBase. The handler block receives parsed arguments
    #    plus the raw POST body.
    define_tool(
      name: 'lookup_competitor',
      description: 'Look up competitor pricing by company name. Use this ' \
                   "when the user asks how a competitor's price compares to ours.",
      parameters: {
        'competitor' => {
          'type' => 'string',
          'description' => "The competitor's company name, e.g. 'ACME'."
        }
      },
      secure: false # standalone services don't validate session tokens by default
    ) do |args, _raw_data|
      competitor = args['competitor'] || '<unknown>'
      { 'response' => "#{competitor} pricing is $99/seat; we're $79/seat." }
    end
  end
end

StandaloneSwaig.new.serve if __FILE__ == $PROGRAM_NAME
