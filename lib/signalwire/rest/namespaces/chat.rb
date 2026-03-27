# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Chat token generation.
      class ChatResource < BaseResource
        def initialize(http)
          super(http, '/api/chat/tokens')
        end

        def create_token(**kwargs)
          @http.post(@base_path, kwargs)
        end
      end
    end
  end
end
