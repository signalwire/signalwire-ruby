# frozen_string_literal: true

require_relative 'http_client'
require_relative 'pagination'
require_relative 'phone_call_handler'
require_relative 'namespaces/generated'

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
    #
    # The flat resources + namespace containers (fabric/calling/video/…) are
    # supplied by the GENERATED ResourceTree module (scripts/generate_rest.py):
    # a lazy accessor per resource + per container, each built off
    # +generated_http_client+ (this client's @http).
    class RestClient
      include Namespaces::Generated::ResourceTree

      attr_reader :project_id, :http

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
        materialize_namespaces!
      end

      # The HttpClient the generated ResourceTree accessors build their resources
      # off of. Named +generated_http_client+ (not just +http+) to match the
      # contract the generated module expects (§8).
      def generated_http_client
        @http
      end

      private

      # Eagerly build every generated resource/container so they exist as instance
      # variables at construction time. The ResourceTree accessors are lazy
      # (memoized on first call); calling each once here populates @fabric,
      # @calling, … so introspection over the live client sees every
      # implemented route.
      def materialize_namespaces!
        Namespaces::Generated::ResourceTree.instance_methods(false).each { |m| send(m) }
      end

      def validate_credentials!(project_id, api_token, space, base_url)
        return unless project_id.empty? || api_token.empty? ||
                      (space.empty? && (base_url.nil? || base_url.empty?))

        raise ArgumentError,
              'project, token, and host are required. ' \
              'Provide them as arguments or set SIGNALWIRE_PROJECT_ID, ' \
              'SIGNALWIRE_API_TOKEN, and SIGNALWIRE_SPACE environment variables.'
      end
    end
  end
end
