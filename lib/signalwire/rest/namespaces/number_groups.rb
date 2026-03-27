# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Number group management with membership operations.
      class NumberGroupsResource < CrudResource
        self.update_method = 'PUT'

        def initialize(http)
          super(http, '/api/relay/rest/number_groups')
        end

        def list_memberships(group_id, **params)
          @http.get(_path(group_id, 'number_group_memberships'), params.empty? ? nil : params)
        end

        def add_membership(group_id, **kwargs)
          @http.post(_path(group_id, 'number_group_memberships'), kwargs)
        end

        def get_membership(membership_id)
          @http.get("/api/relay/rest/number_group_memberships/#{membership_id}")
        end

        def delete_membership(membership_id)
          @http.delete("/api/relay/rest/number_group_memberships/#{membership_id}")
        end
      end
    end
  end
end
