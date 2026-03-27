# frozen_string_literal: true

require_relative 'http_client'
require_relative 'namespaces/fabric'
require_relative 'namespaces/calling'
require_relative 'namespaces/phone_numbers'
require_relative 'namespaces/addresses'
require_relative 'namespaces/queues'
require_relative 'namespaces/recordings'
require_relative 'namespaces/number_groups'
require_relative 'namespaces/verified_callers'
require_relative 'namespaces/sip_profile'
require_relative 'namespaces/lookup'
require_relative 'namespaces/short_codes'
require_relative 'namespaces/imported_numbers'
require_relative 'namespaces/mfa'
require_relative 'namespaces/registry'
require_relative 'namespaces/datasphere'
require_relative 'namespaces/video'
require_relative 'namespaces/logs'
require_relative 'namespaces/project'
require_relative 'namespaces/pubsub'
require_relative 'namespaces/chat'
require_relative 'namespaces/compat'

module SignalWire
  module REST
    # REST client for the SignalWire platform APIs.
    #
    # Usage:
    #   client = SignalWire::REST::RestClient.new(
    #     project: 'your-project-id',
    #     token:   'your-api-token',
    #     host:    'your-space.signalwire.com'
    #   )
    #
    #   # Or use environment variables:
    #   #   SIGNALWIRE_PROJECT_ID, SIGNALWIRE_API_TOKEN, SIGNALWIRE_SPACE
    #   client = SignalWire::REST::RestClient.new
    #
    #   # Use namespaced resources
    #   client.fabric.ai_agents.list
    #   client.calling.play(call_id, play: [...])
    #   client.phone_numbers.search(area_code: '512')
    #   client.video.rooms.create(name: 'standup')
    #   client.compat.calls.list
    class RestClient
      attr_reader :fabric, :calling, :phone_numbers, :datasphere, :video,
                  :compat, :addresses, :queues, :recordings, :number_groups,
                  :verified_callers, :sip_profile, :lookup, :short_codes,
                  :imported_numbers, :mfa, :registry, :logs, :project,
                  :pubsub, :chat

      def initialize(project: nil, token: nil, host: nil)
        project_id = project || ENV['SIGNALWIRE_PROJECT_ID'] || ''
        api_token  = token || ENV['SIGNALWIRE_API_TOKEN'] || ''
        space      = host || ENV['SIGNALWIRE_SPACE'] || ''

        if project_id.empty? || api_token.empty? || space.empty?
          raise ArgumentError,
                'project, token, and host are required. ' \
                'Provide them as arguments or set SIGNALWIRE_PROJECT_ID, ' \
                'SIGNALWIRE_API_TOKEN, and SIGNALWIRE_SPACE environment variables.'
        end

        @project_id = project_id
        @http = HttpClient.new(project_id, api_token, space)

        # Fabric API
        @fabric = Namespaces::FabricNamespace.new(@http)

        # Calling API
        @calling = Namespaces::CallingNamespace.new(@http)

        # Relay REST resources
        @phone_numbers    = Namespaces::PhoneNumbersResource.new(@http)
        @addresses        = Namespaces::AddressesResource.new(@http)
        @queues           = Namespaces::QueuesResource.new(@http)
        @recordings       = Namespaces::RecordingsResource.new(@http)
        @number_groups    = Namespaces::NumberGroupsResource.new(@http)
        @verified_callers = Namespaces::VerifiedCallersResource.new(@http)
        @sip_profile      = Namespaces::SipProfileResource.new(@http)
        @lookup           = Namespaces::LookupResource.new(@http)
        @short_codes      = Namespaces::ShortCodesResource.new(@http)
        @imported_numbers = Namespaces::ImportedNumbersResource.new(@http)
        @mfa              = Namespaces::MfaResource.new(@http)
        @registry         = Namespaces::RegistryNamespace.new(@http)

        # Datasphere API
        @datasphere = Namespaces::DatasphereNamespace.new(@http)

        # Video API
        @video = Namespaces::VideoNamespace.new(@http)

        # Logs
        @logs = Namespaces::LogsNamespace.new(@http)

        # Project management
        @project = Namespaces::ProjectNamespace.new(@http)

        # PubSub & Chat
        @pubsub = Namespaces::PubSubResource.new(@http)
        @chat   = Namespaces::ChatResource.new(@http)

        # Compatibility (Twilio-compatible) API
        @compat = Namespaces::CompatNamespace.new(@http, project_id)
      end
    end
  end
end
