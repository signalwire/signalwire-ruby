# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Recording management (read-only + delete).
      class RecordingsResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/recordings')
        end

        def list(**params)       = @http.get(@base_path, params.empty? ? nil : params)
        def get(recording_id)    = @http.get(_path(recording_id))
        def delete(recording_id) = @http.delete(_path(recording_id))
      end
    end
  end
end
