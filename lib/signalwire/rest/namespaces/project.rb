# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Project API token management.
      class ProjectTokens < BaseResource
        def initialize(http)
          super(http, '/api/project/tokens')
        end

        def create(**kwargs) = @http.post(@base_path, kwargs)

        def update(token_id, **kwargs)
          @http.patch(_path(token_id), kwargs)
        end

        def delete(token_id)
          @http.delete(_path(token_id))
        end
      end

      # Project API namespace.
      class ProjectNamespace
        attr_reader :tokens

        def initialize(http)
          @tokens = ProjectTokens.new(http)
        end
      end
    end
  end
end
