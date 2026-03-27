# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Queue management with member operations.
      class QueuesResource < CrudResource
        self.update_method = 'PUT'

        def initialize(http)
          super(http, '/api/relay/rest/queues')
        end

        def list_members(queue_id, **params)
          @http.get(_path(queue_id, 'members'), params.empty? ? nil : params)
        end

        def get_next_member(queue_id)
          @http.get(_path(queue_id, 'members', 'next'))
        end

        def get_member(queue_id, member_id)
          @http.get(_path(queue_id, 'members', member_id))
        end
      end
    end
  end
end
