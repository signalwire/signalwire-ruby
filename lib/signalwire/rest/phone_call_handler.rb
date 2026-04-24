# frozen_string_literal: true

module SignalWire
  module REST
    # PhoneCallHandler -- enum-like constants of the +call_handler+ values
    # accepted by +phone_numbers.update+.
    #
    # Named +PhoneCallHandler+ (not +CallHandler+) to avoid colliding with
    # the RELAY client's inbound-call-handler callback (+Relay::Client#on_call+).
    #
    # Setting a phone number's +call_handler+ together with the handler-specific
    # companion field routes inbound calls and auto-materializes the matching
    # Fabric resource on the server. See the high-level helpers on
    # +SignalWire::REST::Namespaces::PhoneNumbersResource+.
    #
    # === Mapping
    #
    #   Constant          | Companion field (required)     | Auto-creates resource
    #   ------------------+--------------------------------+----------------------
    #   RELAY_SCRIPT      | call_relay_script_url          | swml_webhook
    #   LAML_WEBHOOKS     | call_request_url               | cxml_webhook
    #   LAML_APPLICATION  | call_laml_application_id       | cxml_application
    #   AI_AGENT          | call_ai_agent_id               | ai_agent
    #   CALL_FLOW         | call_flow_id                   | call_flow
    #   RELAY_APPLICATION | call_relay_application         | relay_application
    #   RELAY_TOPIC       | call_relay_topic               | (routes via RELAY)
    #   RELAY_CONTEXT     | call_relay_context             | (legacy, prefer topic)
    #   RELAY_CONNECTOR   | (connector config)             | (internal)
    #   VIDEO_ROOM        | call_video_room_id             | (routes to Video API)
    #   DIALOGFLOW        | call_dialogflow_agent_id       | (none)
    #
    # Note: +LAML_WEBHOOKS+ (wire value +laml_webhooks+) produces a *cXML*
    # handler despite the plural name, not a generic webhook. For SWML, use
    # +RELAY_SCRIPT+.
    module PhoneCallHandler
      RELAY_SCRIPT      = 'relay_script'
      LAML_WEBHOOKS     = 'laml_webhooks'
      LAML_APPLICATION  = 'laml_application'
      AI_AGENT          = 'ai_agent'
      CALL_FLOW         = 'call_flow'
      RELAY_APPLICATION = 'relay_application'
      RELAY_TOPIC       = 'relay_topic'
      RELAY_CONTEXT     = 'relay_context'
      RELAY_CONNECTOR   = 'relay_connector'
      VIDEO_ROOM        = 'video_room'
      DIALOGFLOW        = 'dialogflow'

      # All supported wire values, in the same order as the constants.
      ALL = [
        RELAY_SCRIPT, LAML_WEBHOOKS, LAML_APPLICATION, AI_AGENT, CALL_FLOW,
        RELAY_APPLICATION, RELAY_TOPIC, RELAY_CONTEXT, RELAY_CONNECTOR,
        VIDEO_ROOM, DIALOGFLOW
      ].freeze
    end
  end
end
