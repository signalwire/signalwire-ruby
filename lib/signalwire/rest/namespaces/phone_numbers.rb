# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Phone number management.
      class PhoneNumbersResource < CrudResource
        self.update_method = 'PUT'

        def initialize(http)
          super(http, '/api/relay/rest/phone_numbers')
        end

        def search(**params)
          @http.get(_path('search'), params.empty? ? nil : params)
        end
      end
    end
  end
end
