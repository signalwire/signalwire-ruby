# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Message log queries.
      class MessageLogs < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def get(log_id)    = @http.get(_path(log_id))
      end

      # Voice log queries.
      class VoiceLogs < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def get(log_id)    = @http.get(_path(log_id))

        def list_events(log_id, **params)
          @http.get(_path(log_id, 'events'), params.empty? ? nil : params)
        end
      end

      # Fax log queries.
      class FaxLogs < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def get(log_id)    = @http.get(_path(log_id))
      end

      # Conference log queries.
      class ConferenceLogs < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
      end

      # Logs API namespace.
      class LogsNamespace
        attr_reader :messages, :voice, :fax, :conferences

        def initialize(http)
          @messages    = MessageLogs.new(http, '/api/messaging/logs')
          @voice       = VoiceLogs.new(http, '/api/voice/logs')
          @fax         = FaxLogs.new(http, '/api/fax/logs')
          @conferences = ConferenceLogs.new(http, '/api/logs/conferences')
        end
      end
    end
  end
end
