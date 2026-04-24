# frozen_string_literal: true

require_relative '../phone_call_handler'

module SignalWire
  module REST
    module Namespaces
      # Phone number management.
      #
      # Supports the standard CRUD surface plus typed helpers for binding an
      # inbound call to a handler (SWML webhook, cXML webhook, AI agent, call
      # flow, RELAY application/topic). The binding model is: set
      # +call_handler+ and the handler-specific companion field on the phone
      # number; the server auto-materializes the matching Fabric resource.
      # See +SignalWire::REST::PhoneCallHandler+ for the enum, and the
      # porting-sdk's +phone-binding.md+ for the full model.
      class PhoneNumbersResource < CrudResource
        self.update_method = 'PUT'

        def initialize(http)
          super(http, '/api/relay/rest/phone_numbers')
        end

        def search(**params)
          @http.get(_path('search'), params.empty? ? nil : params)
        end

        # -- Typed binding helpers -----------------------------------------
        #
        # Each helper is a one-line wrapper over +update+ with the right
        # +call_handler+ value and companion field already set. Pass extra
        # kwargs through for cases the helper doesn't name explicitly (e.g.
        # +call_fallback_url+ on cXML webhooks).

        # Route inbound calls to an SWML webhook URL.
        #
        # Your backend returns an SWML document per call. The server
        # auto-creates a +swml_webhook+ Fabric resource keyed off this URL.
        #
        # @param sid [String] the phone number SID (e.g. +pn-...+)
        # @param url [String] the SWML webhook URL
        # @param extra [Hash] additional fields passed to +update+
        # @return [Hash] the updated phone number representation
        def set_swml_webhook(sid, url:, **extra)
          update(
            sid,
            call_handler: PhoneCallHandler::RELAY_SCRIPT,
            call_relay_script_url: url,
            **extra
          )
        end

        # Route inbound calls to a cXML (Twilio-compat / LAML) webhook.
        #
        # Despite the wire value +laml_webhooks+ being plural, this creates a
        # single +cxml_webhook+ Fabric resource. +fallback_url+ is used when
        # the primary URL fails; +status_callback_url+ receives call status
        # updates.
        def set_cxml_webhook(sid, url:, fallback_url: nil, status_callback_url: nil, **extra)
          body = {
            call_handler: PhoneCallHandler::LAML_WEBHOOKS,
            call_request_url: url
          }
          body[:call_fallback_url]        = fallback_url        unless fallback_url.nil?
          body[:call_status_callback_url] = status_callback_url unless status_callback_url.nil?
          update(sid, **body, **extra)
        end

        # Route inbound calls to an existing cXML application by ID.
        def set_cxml_application(sid, application_id:, **extra)
          update(
            sid,
            call_handler: PhoneCallHandler::LAML_APPLICATION,
            call_laml_application_id: application_id,
            **extra
          )
        end

        # Route inbound calls to an AI Agent Fabric resource by ID.
        def set_ai_agent(sid, agent_id:, **extra)
          update(
            sid,
            call_handler: PhoneCallHandler::AI_AGENT,
            call_ai_agent_id: agent_id,
            **extra
          )
        end

        # Route inbound calls to a Call Flow by ID.
        #
        # +version+ accepts +"working_copy"+ or +"current_deployed"+ (server
        # default when omitted).
        def set_call_flow(sid, flow_id:, version: nil, **extra)
          body = {
            call_handler: PhoneCallHandler::CALL_FLOW,
            call_flow_id: flow_id
          }
          body[:call_flow_version] = version unless version.nil?
          update(sid, **body, **extra)
        end

        # Route inbound calls to a named RELAY application.
        def set_relay_application(sid, name:, **extra)
          update(
            sid,
            call_handler: PhoneCallHandler::RELAY_APPLICATION,
            call_relay_application: name,
            **extra
          )
        end

        # Route inbound calls to a RELAY topic (client subscription).
        def set_relay_topic(sid, topic:, status_callback_url: nil, **extra)
          body = {
            call_handler: PhoneCallHandler::RELAY_TOPIC,
            call_relay_topic: topic
          }
          body[:call_relay_topic_status_callback_url] = status_callback_url unless status_callback_url.nil?
          update(sid, **body, **extra)
        end
      end
    end
  end
end
