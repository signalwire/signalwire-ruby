# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Compat account/subproject management.
      class CompatAccounts < BaseResource
        def initialize(http)
          super(http, '/api/laml/2010-04-01/Accounts')
        end

        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def create(**kwargs) = @http.post(@base_path, kwargs)
        def get(sid)         = @http.get(_path(sid))
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)
      end

      # Compat call management with recording and stream sub-resources.
      class CompatCalls < CrudResource
        def update(sid, **kwargs)
          @http.post(_path(sid), kwargs)
        end

        def start_recording(call_sid, **kwargs)
          @http.post(_path(call_sid, 'Recordings'), kwargs)
        end

        def update_recording(call_sid, recording_sid, **kwargs)
          @http.post(_path(call_sid, 'Recordings', recording_sid), kwargs)
        end

        def start_stream(call_sid, **kwargs)
          @http.post(_path(call_sid, 'Streams'), kwargs)
        end

        def stop_stream(call_sid, stream_sid, **kwargs)
          @http.post(_path(call_sid, 'Streams', stream_sid), kwargs)
        end
      end

      # Compat message management with media sub-resources.
      class CompatMessages < CrudResource
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)

        def list_media(message_sid, **params)
          @http.get(_path(message_sid, 'Media'), params.empty? ? nil : params)
        end

        def get_media(message_sid, media_sid)
          @http.get(_path(message_sid, 'Media', media_sid))
        end

        def delete_media(message_sid, media_sid)
          @http.delete(_path(message_sid, 'Media', media_sid))
        end
      end

      # Compat fax management with media sub-resources.
      class CompatFaxes < CrudResource
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)

        def list_media(fax_sid, **params)
          @http.get(_path(fax_sid, 'Media'), params.empty? ? nil : params)
        end

        def get_media(fax_sid, media_sid)
          @http.get(_path(fax_sid, 'Media', media_sid))
        end

        def delete_media(fax_sid, media_sid)
          @http.delete(_path(fax_sid, 'Media', media_sid))
        end
      end

      # Compat conference management.
      class CompatConferences < BaseResource
        def list(**params)     = @http.get(@base_path, params.empty? ? nil : params)
        def get(sid)           = @http.get(_path(sid))
        def update(sid, **params) = @http.post(_path(sid), params)

        # Participants
        def list_participants(conference_sid, **params)
          @http.get(_path(conference_sid, 'Participants'), params.empty? ? nil : params)
        end

        def get_participant(conference_sid, call_sid)
          @http.get(_path(conference_sid, 'Participants', call_sid))
        end

        def update_participant(conference_sid, call_sid, **kwargs)
          @http.post(_path(conference_sid, 'Participants', call_sid), kwargs)
        end

        def remove_participant(conference_sid, call_sid)
          @http.delete(_path(conference_sid, 'Participants', call_sid))
        end

        # Conference recordings
        def list_recordings(conference_sid, **params)
          @http.get(_path(conference_sid, 'Recordings'), params.empty? ? nil : params)
        end

        def get_recording(conference_sid, recording_sid)
          @http.get(_path(conference_sid, 'Recordings', recording_sid))
        end

        def update_recording(conference_sid, recording_sid, **kwargs)
          @http.post(_path(conference_sid, 'Recordings', recording_sid), kwargs)
        end

        def delete_recording(conference_sid, recording_sid)
          @http.delete(_path(conference_sid, 'Recordings', recording_sid))
        end

        # Conference streams
        def start_stream(conference_sid, **kwargs)
          @http.post(_path(conference_sid, 'Streams'), kwargs)
        end

        def stop_stream(conference_sid, stream_sid, **kwargs)
          @http.post(_path(conference_sid, 'Streams', stream_sid), kwargs)
        end
      end

      # Compat phone number management.
      class CompatPhoneNumbers < BaseResource
        def initialize(http, base)
          super
          @available_base = base.sub('/IncomingPhoneNumbers', '/AvailablePhoneNumbers')
        end

        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def purchase(**kwargs) = @http.post(@base_path, kwargs)
        def get(sid) = @http.get(_path(sid))
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)
        def delete(sid) = @http.delete(_path(sid))

        def import_number(**kwargs)
          path = @base_path.sub('/IncomingPhoneNumbers', '/ImportedPhoneNumbers')
          @http.post(path, kwargs)
        end

        def list_available_countries(**params)
          @http.get(@available_base, params.empty? ? nil : params)
        end

        def search_local(country, **params)
          @http.get("#{@available_base}/#{country}/Local", params.empty? ? nil : params)
        end

        def search_toll_free(country, **params)
          @http.get("#{@available_base}/#{country}/TollFree", params.empty? ? nil : params)
        end
      end

      # Compat application management.
      class CompatApplications < CrudResource
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)
      end

      # Compat cXML/LaML script management.
      class CompatLamlBins < CrudResource
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)
      end

      # Compat queue management with members.
      class CompatQueues < CrudResource
        def update(sid, **kwargs) = @http.post(_path(sid), kwargs)

        def list_members(queue_sid, **params)
          @http.get(_path(queue_sid, 'Members'), params.empty? ? nil : params)
        end

        def get_member(queue_sid, call_sid)
          @http.get(_path(queue_sid, 'Members', call_sid))
        end

        def dequeue_member(queue_sid, call_sid, **kwargs)
          @http.post(_path(queue_sid, 'Members', call_sid), kwargs)
        end
      end

      # Compat recording management.
      class CompatRecordings < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def get(sid)       = @http.get(_path(sid))
        def delete(sid)    = @http.delete(_path(sid))
      end

      # Compat transcription management.
      class CompatTranscriptions < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def get(sid)       = @http.get(_path(sid))
        def delete(sid)    = @http.delete(_path(sid))
      end

      # Compat API token management.
      class CompatTokens < BaseResource
        def create(**kwargs) = @http.post(@base_path, kwargs)
        def update(token_id, **kwargs) = @http.patch(_path(token_id), kwargs)
        def delete(token_id) = @http.delete(_path(token_id))
      end

      # Twilio-compatible LAML API namespace.
      class CompatNamespace
        attr_reader :accounts, :calls, :messages, :faxes, :conferences,
                    :phone_numbers, :applications, :laml_bins, :queues,
                    :recordings, :transcriptions, :tokens

        def initialize(http, account_sid)
          base = "/api/laml/2010-04-01/Accounts/#{account_sid}"

          @accounts       = CompatAccounts.new(http)
          @calls          = CompatCalls.new(http, "#{base}/Calls")
          @messages       = CompatMessages.new(http, "#{base}/Messages")
          @faxes          = CompatFaxes.new(http, "#{base}/Faxes")
          @conferences    = CompatConferences.new(http, "#{base}/Conferences")
          @phone_numbers  = CompatPhoneNumbers.new(http, "#{base}/IncomingPhoneNumbers")
          init_remaining_resources(http, base)
        end

        private

        def init_remaining_resources(http, base)
          @applications   = CompatApplications.new(http, "#{base}/Applications")
          @laml_bins      = CompatLamlBins.new(http, "#{base}/LamlBins")
          @queues         = CompatQueues.new(http, "#{base}/Queues")
          @recordings     = CompatRecordings.new(http, "#{base}/Recordings")
          @transcriptions = CompatTranscriptions.new(http, "#{base}/Transcriptions")
          @tokens         = CompatTokens.new(http, "#{base}/tokens")
        end
      end
    end
  end
end
