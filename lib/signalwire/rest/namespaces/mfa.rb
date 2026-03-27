# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Multi-factor authentication via SMS or phone call.
      class MfaResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/mfa')
        end

        def sms(**kwargs)
          @http.post(_path('sms'), kwargs)
        end

        def call(**kwargs)
          @http.post(_path('call'), kwargs)
        end

        def verify(request_id, **kwargs)
          @http.post(_path(request_id, 'verify'), kwargs)
        end
      end
    end
  end
end
