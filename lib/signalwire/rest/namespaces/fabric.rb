# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Standard fabric resource with CRUD + addresses. Inherits the
      # +list_addresses+ helper from +CrudWithAddresses+ (matching Python's
      # +FabricResource(CrudWithAddresses)+ hierarchy); subclasses that use a
      # singular sub-resource path override +list_addresses+ below.
      class FabricResource < CrudWithAddresses
      end

      # Fabric resource that uses PUT for updates.
      class FabricResourcePUT < FabricResource
        self.update_method = 'PUT'
      end

      # Fabric webhook resource that's normally auto-created by
      # +phone_numbers.set_*_webhook+. Exposed for backwards compatibility.
      #
      # The binding model for these resources is on the phone number (see
      # +phone_numbers.set_swml_webhook+ / +set_cxml_webhook+) -- setting
      # +call_handler+ on a phone number auto-materializes the webhook
      # Fabric resource. Calling +create+ directly here produces an orphan
      # resource that isn't bound to any phone number.
      class AutoMaterializedWebhook < FabricResource
        # Subclasses override to advertise the correct helper in the warning.
        AUTO_HELPER_NAME = 'phone_numbers.set_*_webhook'

        # @deprecated Creating a webhook Fabric resource directly produces an
        #   orphan that isn't bound to any phone number. Use the matching
        #   +phone_numbers.set_*_webhook+ helper instead; it updates the
        #   phone number and the server auto-materializes the resource.
        #   See porting-sdk's +phone-binding.md+.
        def create(**kwargs)
          Kernel.warn(
            'DEPRECATION: creating a webhook Fabric resource directly produces ' \
            'an orphan not bound to any phone number. Use ' \
            "#{self.class::AUTO_HELPER_NAME} instead; it updates the phone " \
            'number and the server auto-materializes the resource. ' \
            "See porting-sdk's phone-binding.md.",
            uplevel: 1
          )
          super
        end
      end

      # SWML webhooks -- auto-materialized by +phone_numbers.set_swml_webhook+.
      class SwmlWebhooksResource < AutoMaterializedWebhook
        AUTO_HELPER_NAME = 'phone_numbers.set_swml_webhook(sid, url: ...)'
      end

      # cXML webhooks -- auto-materialized by +phone_numbers.set_cxml_webhook+.
      class CxmlWebhooksResource < AutoMaterializedWebhook
        AUTO_HELPER_NAME = 'phone_numbers.set_cxml_webhook(sid, url: ...)'
      end

      # Call flows with version management.
      class CallFlowsResource < FabricResourcePUT
        def list_addresses(resource_id, **params)
          path = @base_path.sub('/call_flows', '/call_flow')
          @http.get("#{path}/#{resource_id}/addresses", params.empty? ? nil : params)
        end

        def list_versions(resource_id, **params)
          path = @base_path.sub('/call_flows', '/call_flow')
          @http.get("#{path}/#{resource_id}/versions", params.empty? ? nil : params)
        end

        def deploy_version(resource_id, **kwargs)
          path = @base_path.sub('/call_flows', '/call_flow')
          @http.post("#{path}/#{resource_id}/versions", kwargs)
        end
      end

      # Conference rooms -- uses singular 'conference_room' for sub-resource paths.
      class ConferenceRoomsResource < FabricResourcePUT
        def list_addresses(resource_id, **params)
          path = @base_path.sub('/conference_rooms', '/conference_room')
          @http.get("#{path}/#{resource_id}/addresses", params.empty? ? nil : params)
        end
      end

      # Subscribers with SIP endpoint management.
      class SubscribersResource < FabricResourcePUT
        def list_sip_endpoints(subscriber_id, **params)
          @http.get(_path(subscriber_id, 'sip_endpoints'), params.empty? ? nil : params)
        end

        def create_sip_endpoint(subscriber_id, **kwargs)
          @http.post(_path(subscriber_id, 'sip_endpoints'), kwargs)
        end

        def get_sip_endpoint(subscriber_id, endpoint_id)
          @http.get(_path(subscriber_id, 'sip_endpoints', endpoint_id))
        end

        def update_sip_endpoint(subscriber_id, endpoint_id, **kwargs)
          @http.patch(_path(subscriber_id, 'sip_endpoints', endpoint_id), kwargs)
        end

        def delete_sip_endpoint(subscriber_id, endpoint_id)
          @http.delete(_path(subscriber_id, 'sip_endpoints', endpoint_id))
        end
      end

      # cXML applications -- no create method.
      class CxmlApplicationsResource < FabricResourcePUT
        def create(**_kwargs)
          raise NotImplementedError, 'cXML applications cannot be created via this API'
        end
      end

      # Generic resource operations across all fabric resource types.
      class GenericResources < BaseResource
        def list(**params)
          @http.get(@base_path, params.empty? ? nil : params)
        end

        def get(resource_id)
          @http.get(_path(resource_id))
        end

        def delete(resource_id)
          @http.delete(_path(resource_id))
        end

        def list_addresses(resource_id, **params)
          @http.get(_path(resource_id, 'addresses'), params.empty? ? nil : params)
        end

        # @deprecated For the common binding cases use +phone_numbers.set_*+ helpers.
        #
        # This endpoint (+POST /api/fabric/resources/{id}/phone_routes+) accepts
        # only a narrow set of legacy resource types as the attach target. It
        # *does not work* for +swml_webhook+ / +cxml_webhook+ / +ai_agent+
        # bindings -- those are configured on the phone number and the Fabric
        # resource is auto-materialized (see +phone_numbers.set_swml_webhook+
        # etc.). The authoritative list of accepting resource types lives in
        # the OpenAPI spec; routing here for those types returns 404 or 422.
        def assign_phone_route(resource_id, **kwargs)
          Kernel.warn(
            'DEPRECATION: assign_phone_route does not bind phone numbers to ' \
            'swml_webhook/cxml_webhook/ai_agent resources -- those are ' \
            'configured via phone_numbers.set_swml_webhook / set_cxml_webhook ' \
            '/ set_ai_agent. This method applies only to a narrow set of ' \
            "legacy resource types. See porting-sdk's phone-binding.md.",
            uplevel: 1
          )
          @http.post(_path(resource_id, 'phone_routes'), kwargs)
        end

        def assign_domain_application(resource_id, **kwargs)
          @http.post(_path(resource_id, 'domain_applications'), kwargs)
        end
      end

      # Read-only fabric addresses.
      class FabricAddresses < BaseResource
        def list(**params)
          @http.get(@base_path, params.empty? ? nil : params)
        end

        def get(address_id)
          @http.get(_path(address_id))
        end
      end

      # Subscriber, guest, invite, and embed token creation.
      class FabricTokens < BaseResource
        def initialize(http)
          super(http, '/api/fabric')
        end

        def create_subscriber_token(**kwargs)
          @http.post(_path('subscribers', 'tokens'), kwargs)
        end

        def refresh_subscriber_token(**kwargs)
          @http.post(_path('subscribers', 'tokens', 'refresh'), kwargs)
        end

        def create_invite_token(**kwargs)
          @http.post(_path('subscriber', 'invites'), kwargs)
        end

        def create_guest_token(**kwargs)
          @http.post(_path('guests', 'tokens'), kwargs)
        end

        def create_embed_token(**kwargs)
          @http.post(_path('embeds', 'tokens'), kwargs)
        end
      end

      # Fabric API namespace grouping all resource types.
      class FabricNamespace
        attr_reader :swml_scripts, :relay_applications, :call_flows,
                    :conference_rooms, :freeswitch_connectors, :subscribers,
                    :sip_endpoints, :cxml_scripts, :cxml_applications,
                    :swml_webhooks, :ai_agents, :sip_gateways, :cxml_webhooks,
                    :resources, :addresses, :tokens

        def initialize(http)
          base = '/api/fabric/resources'
          init_put_resources(http, base)
          init_patch_resources(http, base)
          init_special_resources(http, base)
        end

        private

        def init_put_resources(http, base)
          @swml_scripts           = FabricResourcePUT.new(http, "#{base}/swml_scripts")
          @relay_applications     = FabricResourcePUT.new(http, "#{base}/relay_applications")
          @call_flows             = CallFlowsResource.new(http, "#{base}/call_flows")
          @conference_rooms       = ConferenceRoomsResource.new(http, "#{base}/conference_rooms")
          @freeswitch_connectors  = FabricResourcePUT.new(http, "#{base}/freeswitch_connectors")
          @subscribers            = SubscribersResource.new(http, "#{base}/subscribers")
          @sip_endpoints          = FabricResourcePUT.new(http, "#{base}/sip_endpoints")
          @cxml_scripts           = FabricResourcePUT.new(http, "#{base}/cxml_scripts")
          @cxml_applications      = CxmlApplicationsResource.new(http, "#{base}/cxml_applications")
        end

        # swml_webhooks and cxml_webhooks are normally auto-materialized by
        # phone_numbers.set_swml_webhook / set_cxml_webhook. Direct create
        # still works for backcompat but emits a deprecation warning.
        def init_patch_resources(http, base)
          @swml_webhooks = SwmlWebhooksResource.new(http, "#{base}/swml_webhooks")
          @ai_agents     = FabricResource.new(http, "#{base}/ai_agents")
          @sip_gateways  = FabricResource.new(http, "#{base}/sip_gateways")
          @cxml_webhooks = CxmlWebhooksResource.new(http, "#{base}/cxml_webhooks")
        end

        def init_special_resources(http, base)
          @resources = GenericResources.new(http, base)
          @addresses = FabricAddresses.new(http, '/api/fabric/addresses')
          @tokens    = FabricTokens.new(http)
        end
      end
    end
  end
end
