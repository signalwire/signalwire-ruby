# frozen_string_literal: true

require_relative 'http_client'
require_relative 'pagination'
require_relative 'phone_call_handler'
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
                  :pubsub, :chat, :project_id, :http

      # +base_url+ overrides the derived +https://{space}+ default. The
      # audit harness uses this to point at the local fixture server.
      # +ca_file+ (optional) names a PEM CA bundle to trust for HTTPS in
      # addition to the system store — for private-CA deployments; forwarded
      # to the underlying HttpClient.
      def initialize(project: nil, token: nil, host: nil, base_url: nil, ca_file: nil)
        project_id = project || ENV['SIGNALWIRE_PROJECT_ID'] || ''
        api_token  = token || ENV['SIGNALWIRE_API_TOKEN'] || ''
        space      = host || ENV['SIGNALWIRE_SPACE'] || ''
        validate_credentials!(project_id, api_token, space, base_url)

        @project_id = project_id
        @http = HttpClient.new(project_id, api_token, space, base_url: base_url, ca_file: ca_file)
        init_namespaces(project_id)
      end

      # ivar name → namespace class for the single-arg (@http) namespaces.
      # +compat+ is wired separately (it also takes the project id).
      SIMPLE_NAMESPACES = {
        fabric: Namespaces::FabricNamespace, calling: Namespaces::CallingNamespace,
        phone_numbers: Namespaces::PhoneNumbersResource, addresses: Namespaces::AddressesResource,
        queues: Namespaces::QueuesResource, recordings: Namespaces::RecordingsResource,
        number_groups: Namespaces::NumberGroupsResource,
        verified_callers: Namespaces::VerifiedCallersResource,
        sip_profile: Namespaces::SipProfileResource, lookup: Namespaces::LookupResource,
        short_codes: Namespaces::ShortCodesResource,
        imported_numbers: Namespaces::ImportedNumbersResource, mfa: Namespaces::MfaResource,
        registry: Namespaces::RegistryNamespace, datasphere: Namespaces::DatasphereNamespace,
        video: Namespaces::VideoNamespace, logs: Namespaces::LogsNamespace,
        project: Namespaces::ProjectNamespace, pubsub: Namespaces::PubSubResource,
        chat: Namespaces::ChatResource
      }.freeze

      private

      def validate_credentials!(project_id, api_token, space, base_url)
        return unless project_id.empty? || api_token.empty? ||
                      (space.empty? && (base_url.nil? || base_url.empty?))

        raise ArgumentError,
              'project, token, and host are required. ' \
              'Provide them as arguments or set SIGNALWIRE_PROJECT_ID, ' \
              'SIGNALWIRE_API_TOKEN, and SIGNALWIRE_SPACE environment variables.'
      end

      def init_namespaces(project_id)
        SIMPLE_NAMESPACES.each do |name, klass|
          instance_variable_set("@#{name}", klass.new(@http))
        end
        @compat = Namespaces::CompatNamespace.new(@http, project_id)
      end
    end
  end
end
