# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Short code management (read + update only).
      class ShortCodesResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/short_codes')
        end

        def list(**params)
          @http.get(@base_path, params.empty? ? nil : params)
        end

        def get(short_code_id)
          @http.get(_path(short_code_id))
        end

        def update(short_code_id, **kwargs)
          @http.put(_path(short_code_id), kwargs)
        end
      end
    end
  end
end
