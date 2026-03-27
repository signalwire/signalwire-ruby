# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Document management with search and chunk operations.
      class DatasphereDocuments < CrudResource
        def initialize(http)
          super(http, '/api/datasphere/documents')
        end

        def search(**kwargs)
          @http.post(_path('search'), kwargs)
        end

        def list_chunks(document_id, **params)
          @http.get(_path(document_id, 'chunks'), params.empty? ? nil : params)
        end

        def get_chunk(document_id, chunk_id)
          @http.get(_path(document_id, 'chunks', chunk_id))
        end

        def delete_chunk(document_id, chunk_id)
          @http.delete(_path(document_id, 'chunks', chunk_id))
        end
      end

      # Datasphere API namespace.
      class DatasphereNamespace
        attr_reader :documents

        def initialize(http)
          @documents = DatasphereDocuments.new(http)
        end
      end
    end
  end
end
