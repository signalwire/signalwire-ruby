# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Verified caller ID management with verification flow.
      class VerifiedCallersResource < CrudResource
        self.update_method = 'PUT'

        def initialize(http)
          super(http, '/api/relay/rest/verified_caller_ids')
        end

        def redial_verification(caller_id)
          @http.post(_path(caller_id, 'verification'))
        end

        def submit_verification(caller_id, **kwargs)
          @http.put(_path(caller_id, 'verification'), kwargs)
        end
      end
    end
  end
end
