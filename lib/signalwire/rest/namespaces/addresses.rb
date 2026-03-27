# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Address management (no update endpoint).
      class AddressesResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/addresses')
        end

        def list(**params)  = @http.get(@base_path, params.empty? ? nil : params)
        def create(**kwargs) = @http.post(@base_path, kwargs)
        def get(address_id) = @http.get(_path(address_id))
        def delete(address_id) = @http.delete(_path(address_id))
      end
    end
  end
end
