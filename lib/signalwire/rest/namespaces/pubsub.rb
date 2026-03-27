# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # PubSub token generation.
      class PubSubResource < BaseResource
        def initialize(http)
          super(http, '/api/pubsub/tokens')
        end

        def create_token(**kwargs)
          @http.post(@base_path, kwargs)
        end
      end
    end
  end
end
