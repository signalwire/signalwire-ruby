# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Phone number lookup (carrier, CNAM).
      class LookupResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/lookup')
        end

        def phone_number(e164, **params)
          @http.get(_path('phone_number', e164), params.empty? ? nil : params)
        end
      end
    end
  end
end
