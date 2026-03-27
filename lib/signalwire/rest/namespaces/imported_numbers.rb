# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Import externally-hosted phone numbers.
      class ImportedNumbersResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/imported_phone_numbers')
        end

        def create(**kwargs)
          @http.post(@base_path, kwargs)
        end
      end
    end
  end
end
