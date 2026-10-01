# frozen_string_literal: true

require_relative 'http_client'
require_relative 'request_options'
require_relative 'pagination'
require_relative 'phone_call_handler'
require_relative 'namespaces/generated'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # REST — the synchronous REST client and its per-namespace resources.
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
    #   # Opt into retries/timeout for every request (per-request override also
    #   # supported on each verb via request_options:):
    #   client = SignalWire::REST::RestClient.new(
    #     project: '...', token: '...', host: '...',
    #     request_options: SignalWire::REST::RequestOptions.new(retries: 2, timeout: 10)
    #   )
    #
    #   # Use namespaced resources
    #   client.fabric.ai_agents.list
    #   client.calling.play(call_id, play: [...])
    #   client.phone_numbers.search(areacode: '512')
    #   client.video.rooms.create(name: 'standup')
    #
    #   # The Space Administration API (client.space) authenticates with a user's
    #   # Personal Access Token instead of a project token:
    #   admin = SignalWire::REST::RestClient.new(
    #     personal_access_token: 'pat_...', host: 'your-space.signalwire.com'
    #   )
    #   admin.space.members.list
    #
    # The flat resources + namespace containers (fabric/calling/video/…) are
    # supplied by the GENERATED ResourceTree module (scripts/generate_rest.py):
    # a lazy accessor per resource + per container, each built off
    # +generated_http_client+ (this client's @http) — or, for the containers whose
    # spec authenticates only with a Personal Access Token (+space+),
    # +generated_pat_http_client+.
    class RestClient
      include Namespaces::Generated::ResourceTree

      # @api private — raised when a project-scoped resource is called on a client
      # built with only a personal access token.
      PROJECT_CREDENTIAL_MISSING =
        'project and token are required for this resource ' \
        '(SIGNALWIRE_PROJECT_ID / SIGNALWIRE_API_TOKEN); this client has only a ' \
        'personal access token, which authenticates client.space'

      # @api private — raised when +client.space+ is called on a client built
      # without a personal access token.
      PAT_CREDENTIAL_MISSING =
        'personal_access_token is required for client.space ' \
        '(SIGNALWIRE_PERSONAL_ACCESS_TOKEN)'

      # @api private — stands in for the HTTP client of a credential the RestClient
      # was not given. Every request raises ArgumentError naming the missing
      # credential before anything is sent, so a PAT-only client fails loudly on a
      # project resource (and a project-only client on +client.space+) instead of
      # sending a request the server can only refuse.
      class MissingCredentialHttp
        # @param message [String] the error every request raises
        def initialize(message)
          @message = message
        end

        # No endpoint: this stand-in never sends a request.
        def base_url
          nil
        end

        # @api private — every request verb raises before anything is sent.
        def method_missing(_name, *_args, **_kwargs, &)
          raise ArgumentError, @message
        end

        # @api private — the stand-in answers every request verb.
        def respond_to_missing?(_name, _include_private = false)
          true
        end
      end

      attr_reader :project_id, :http

      # +base_url+ overrides the derived +https://{space}+ default. The
      # audit harness uses this to point at the local fixture server.
      # +ca_file+ (optional) names a PEM CA bundle to trust for HTTPS in
      # addition to the system store — for private-CA deployments; forwarded
      # to the underlying HttpClient.
      # +request_options+ (optional) is the client-default {RequestOptions}
      # envelope (timeout / retries / backoff / abort_signal) applied to every
      # request; forwarded to the underlying HttpClient and shallow-overridden
      # by any per-request +request_options:+.
      # +personal_access_token+ (optional; a user's +pat_...+ token, else
      # +SIGNALWIRE_PERSONAL_ACCESS_TOKEN+) authenticates +client.space+, which the
      # platform serves only to a Personal Access Token (HTTP Basic with an EMPTY
      # username). Either credential — a complete +project+ + +token+ pair, or a
      # personal access token — or both may be given; calling a resource whose
      # credential is missing raises +ArgumentError+ before any request is sent.
      def initialize(project: nil, token: nil, host: nil, base_url: nil, ca_file: nil,
                     request_options: nil, personal_access_token: nil)
        creds = resolve_credentials(project, token, host, personal_access_token)
        validate_credentials!(creds, base_url)

        @project_id = creds[:project]
        http_opts = { base_url: base_url, ca_file: ca_file, request_options: request_options }
        @http = build_project_http(creds, http_opts)
        @pat_http = build_pat_http(creds, http_opts)
        materialize_namespaces!
      end

      # Redacted inspect: NEVER print the API token — the default #inspect would
      # dump @http (which holds the raw token + Basic-auth header) and every
      # materialized namespace ivar. Enterprise credential-hygiene (A6 /
      # SECRET-SCRUB): a client leaked into a log / crash dump / REPL must not
      # expose the credential.
      def inspect
        "#<#{self.class.name} project_id=#{@project_id.inspect} " \
          "base_url=#{(@http.base_url || @pat_http.base_url).inspect} token=[REDACTED]>"
      end
      alias to_s inspect

      # The HttpClient the generated ResourceTree accessors build their resources
      # off of. Named +generated_http_client+ (not just +http+) to match the
      # contract the generated module expects (§8).
      def generated_http_client
        @http
      end

      # The HttpClient carrying the Personal Access Token, which the generated
      # ResourceTree builds the PAT-authenticated containers (+space+) off of.
      def generated_pat_http_client
        @pat_http
      end

      private

      # @api private — each credential from its argument, else its environment
      # variable, else empty.
      def resolve_credentials(project, token, host, personal_access_token)
        {
          project: project || ENV.fetch('SIGNALWIRE_PROJECT_ID', ''),
          token: token || ENV.fetch('SIGNALWIRE_API_TOKEN', ''),
          space: host || ENV.fetch('SIGNALWIRE_SPACE', ''),
          pat: personal_access_token || ENV.fetch('SIGNALWIRE_PERSONAL_ACCESS_TOKEN', '')
        }
      end

      # @api private — true when both halves of the project credential are given.
      def project_credential?(creds)
        !creds[:project].empty? && !creds[:token].empty?
      end

      # @api private — the HttpClient carrying the project credential, or a stand-in
      # that refuses every project-scoped request when it was not given.
      def build_project_http(creds, http_opts)
        return MissingCredentialHttp.new(PROJECT_CREDENTIAL_MISSING) unless project_credential?(creds)

        HttpClient.new(creds[:project], creds[:token], creds[:space], **http_opts)
      end

      # @api private — the HttpClient carrying the Personal Access Token (HTTP Basic
      # with an EMPTY username), or a stand-in that refuses every +client.space+
      # request when no token was given.
      def build_pat_http(creds, http_opts)
        return MissingCredentialHttp.new(PAT_CREDENTIAL_MISSING) if creds[:pat].empty?

        HttpClient.new('', creds[:pat], creds[:space], **http_opts)
      end

      # Eagerly build every generated resource/container so they exist as instance
      # variables at construction time. The ResourceTree accessors are lazy
      # (memoized on first call); calling each once here populates @fabric,
      # @calling, … so introspection over the live client sees every
      # implemented route.
      def materialize_namespaces!
        Namespaces::Generated::ResourceTree.instance_methods(false).each { |m| send(m) }
      end

      # @api private — fail before any request when the endpoint is missing, or when
      # neither a complete project + token pair nor a personal access token is
      # given. An explicit `base_url` substitutes for the space, which is what lets
      # a client be pointed at a local endpoint without one. The error names every
      # environment variable, so the failure is self-diagnosing.
      #
      # @raise [ArgumentError]
      def validate_credentials!(creds, base_url)
        has_endpoint = !creds[:space].empty? || !(base_url.nil? || base_url.empty?)
        return if has_endpoint && (project_credential?(creds) || !creds[:pat].empty?)

        raise ArgumentError,
              'project, token, and host are required. ' \
              'Provide them as arguments or set SIGNALWIRE_PROJECT_ID, ' \
              'SIGNALWIRE_API_TOKEN, and SIGNALWIRE_SPACE environment variables ' \
              '(or, for client.space only, host and personal_access_token / ' \
              'SIGNALWIRE_PERSONAL_ACCESS_TOKEN).'
      end
    end
  end
end
