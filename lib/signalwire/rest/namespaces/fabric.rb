# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Standard fabric resource with CRUD + addresses.
      class FabricResource < CrudResource
        def list_addresses(resource_id, **params)
          @http.get(_path(resource_id, 'addresses'), params.empty? ? nil : params)
        end
      end

      # Fabric resource that uses PUT for updates.
      class FabricResourcePUT < FabricResource
        self.update_method = 'PUT'
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

        def assign_phone_route(resource_id, **kwargs)
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

          # PUT-update resources
          @swml_scripts           = FabricResourcePUT.new(http, "#{base}/swml_scripts")
          @relay_applications     = FabricResourcePUT.new(http, "#{base}/relay_applications")
          @call_flows             = CallFlowsResource.new(http, "#{base}/call_flows")
          @conference_rooms       = ConferenceRoomsResource.new(http, "#{base}/conference_rooms")
          @freeswitch_connectors  = FabricResourcePUT.new(http, "#{base}/freeswitch_connectors")
          @subscribers            = SubscribersResource.new(http, "#{base}/subscribers")
          @sip_endpoints          = FabricResourcePUT.new(http, "#{base}/sip_endpoints")
          @cxml_scripts           = FabricResourcePUT.new(http, "#{base}/cxml_scripts")
          @cxml_applications      = CxmlApplicationsResource.new(http, "#{base}/cxml_applications")

          # PATCH-update resources
          @swml_webhooks = FabricResource.new(http, "#{base}/swml_webhooks")
          @ai_agents     = FabricResource.new(http, "#{base}/ai_agents")
          @sip_gateways  = FabricResource.new(http, "#{base}/sip_gateways")
          @cxml_webhooks = FabricResource.new(http, "#{base}/cxml_webhooks")

          # Special resources
          @resources = GenericResources.new(http, base)
          @addresses = FabricAddresses.new(http, '/api/fabric/addresses')
          @tokens    = FabricTokens.new(http)
        end
      end
    end
  end
end
