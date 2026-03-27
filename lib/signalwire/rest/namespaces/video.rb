# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Video room management with streams.
      class VideoRooms < CrudResource
        self.update_method = 'PUT'

        def list_streams(room_id, **params)
          @http.get(_path(room_id, 'streams'), params.empty? ? nil : params)
        end

        def create_stream(room_id, **kwargs)
          @http.post(_path(room_id, 'streams'), kwargs)
        end
      end

      # Video room token generation.
      class VideoRoomTokens < BaseResource
        def create(**kwargs)
          @http.post(@base_path, kwargs)
        end
      end

      # Video room session management.
      class VideoRoomSessions < BaseResource
        def list(**params)
          @http.get(@base_path, params.empty? ? nil : params)
        end

        def get(session_id)
          @http.get(_path(session_id))
        end

        def list_events(session_id, **params)
          @http.get(_path(session_id, 'events'), params.empty? ? nil : params)
        end

        def list_members(session_id, **params)
          @http.get(_path(session_id, 'members'), params.empty? ? nil : params)
        end

        def list_recordings(session_id, **params)
          @http.get(_path(session_id, 'recordings'), params.empty? ? nil : params)
        end
      end

      # Video room recording management.
      class VideoRoomRecordings < BaseResource
        def list(**params)
          @http.get(@base_path, params.empty? ? nil : params)
        end

        def get(recording_id)
          @http.get(_path(recording_id))
        end

        def delete(recording_id)
          @http.delete(_path(recording_id))
        end

        def list_events(recording_id, **params)
          @http.get(_path(recording_id, 'events'), params.empty? ? nil : params)
        end
      end

      # Video conference management with tokens and streams.
      class VideoConferences < CrudResource
        self.update_method = 'PUT'

        def list_conference_tokens(conference_id, **params)
          @http.get(_path(conference_id, 'conference_tokens'), params.empty? ? nil : params)
        end

        def list_streams(conference_id, **params)
          @http.get(_path(conference_id, 'streams'), params.empty? ? nil : params)
        end

        def create_stream(conference_id, **kwargs)
          @http.post(_path(conference_id, 'streams'), kwargs)
        end
      end

      # Video conference token management.
      class VideoConferenceTokens < BaseResource
        def get(token_id)
          @http.get(_path(token_id))
        end

        def reset(token_id)
          @http.post(_path(token_id, 'reset'))
        end
      end

      # Video stream management.
      class VideoStreams < BaseResource
        def get(stream_id)
          @http.get(_path(stream_id))
        end

        def update(stream_id, **kwargs)
          @http.put(_path(stream_id), kwargs)
        end

        def delete(stream_id)
          @http.delete(_path(stream_id))
        end
      end

      # Video API namespace.
      class VideoNamespace
        attr_reader :rooms, :room_tokens, :room_sessions, :room_recordings,
                    :conferences, :conference_tokens, :streams

        def initialize(http)
          base = '/api/video'
          @rooms              = VideoRooms.new(http, "#{base}/rooms")
          @room_tokens        = VideoRoomTokens.new(http, "#{base}/room_tokens")
          @room_sessions      = VideoRoomSessions.new(http, "#{base}/room_sessions")
          @room_recordings    = VideoRoomRecordings.new(http, "#{base}/room_recordings")
          @conferences        = VideoConferences.new(http, "#{base}/conferences")
          @conference_tokens  = VideoConferenceTokens.new(http, "#{base}/conference_tokens")
          @streams            = VideoStreams.new(http, "#{base}/streams")
        end
      end
    end
  end
end
