# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'net/http'
require 'uri'
require 'json'

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../utils/url_validator'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # MCP Gateway skill — bridges MCP (Model Context Protocol) servers with
      # SWAIG functions.
      #
      # A CLIENT: it connects to a RUNNING MCP Gateway service over HTTP,
      # authenticates (bearer token OR HTTP-basic), enumerates the gateway's
      # services + tools, and registers each MCP tool as a SWAIG function whose
      # handler proxies the call back through the gateway.
      #
      # This SDK ships the client half only. Running the gateway service itself
      # (the subprocess + sandbox daemon that hosts MCP servers) is out of
      # scope here; point this skill at an already-running gateway.
      class MCPGatewaySkill < SkillBase
        # The name this skill is added under (`agent.add_skill('mcp_gateway')`).
        #
        # @return [String]
        def name = 'mcp_gateway'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Bridge MCP servers with SWAIG functions'
        # This skill's own version, independent of the SDK's.
        #
        # @return [String] '1.0.0'
        def version = '1.0.0'

        # Validate configuration and connectivity. Returns +true+ when the skill
        # is ready. Requires either an auth token OR (auth_user + auth_password)
        # for basic auth, plus a gateway_url that passes SSRF validation and a
        # reachable ``/health`` endpoint.
        #
        # There is no constructor override: all config is read here, and lazily
        # by the hook accessors via {#ensure_config}.
        def setup
          read_config
          return false unless valid_auth?
          return false unless valid_gateway_url?

          healthy?
        end

        # Enumerate the gateway's services + tools and return one SWAIG tool
        # definition hash per MCP tool (the Ruby ``register_tools`` idiom returns
        # the defs; the agent's skill loader calls ``define_tool`` for each).
        #
        # When no services are configured, every available service is queried.
        # @return [Array<Hash>] tool definition hashes for {AgentBase#define_tool}.
        def register_tools
          ensure_config
          resolve_services if @services.empty?

          tools = []
          @services.each do |service_config|
            service_name = service_config['name'] || service_config[:name]
            next unless service_name

            mcp_tools_for(service_name).each do |tool_def|
              tool = build_swaig_tool(service_name, tool_def)
              tools << tool if tool
            end
          end
          tools
        end

        # Speech-recognition hints: the literal terms plus each service name.
        def get_hints
          ensure_config
          hints = %w[MCP gateway]
          hints.concat(@services.filter_map { |s| s['name'] || s[:name] if s.is_a?(Hash) })
          hints
        end

        # Global data for DataMap variable expansion.
        def get_global_data
          ensure_config
          {
            'mcp_gateway_url' => @gateway_url,
            'mcp_session_id' => @session_id,
            'mcp_services' => @services.map { |s| s.is_a?(Hash) ? (s['name'] || s[:name]) : s.to_s }
          }
        end

        # Prompt sections describing the available MCP services.
        def get_prompt_sections
          ensure_config
          descriptions = service_descriptions
          return [] if descriptions.empty?

          [integration_prompt_section(descriptions)]
        end

        # Config schema for GUI / validation.
        def get_parameter_schema
          auth_params_schema
            .merge(services_param_schema)
            .merge(connection_params_schema)
        end

        private

        # gateway_url + the bearer / basic-auth credentials.
        def auth_params_schema
          {
            'gateway_url' => { 'type' => 'string', 'required' => true,
                               'description' => 'URL of the MCP Gateway service' },
            'auth_token' => { 'type' => 'string', 'required' => false, 'hidden' => true,
                              'env_var' => 'MCP_GATEWAY_AUTH_TOKEN',
                              'description' => 'Bearer token for authentication (alternative to basic auth)' },
            'auth_user' => { 'type' => 'string', 'required' => false,
                             'env_var' => 'MCP_GATEWAY_AUTH_USER',
                             'description' => 'Username for basic auth (required if no auth_token)' },
            'auth_password' => { 'type' => 'string', 'required' => false, 'hidden' => true,
                                 'env_var' => 'MCP_GATEWAY_AUTH_PASSWORD',
                                 'description' => 'Password for basic auth (required if no auth_token)' }
          }
        end

        # The nested `services` list-of-{name,tools} param.
        def services_param_schema
          service_item = {
            'type' => 'object',
            'properties' => {
              'name' => { 'type' => 'string', 'description' => 'Service name' },
              'tools' => { 'type' => %w[string array],
                           'description' => "Tools to expose ('*' for all, or list of tool names)" }
            }
          }
          { 'services' => { 'type' => 'array', 'default' => [], 'required' => false, 'items' => service_item,
                            'description' => 'List of MCP services to connect to (empty for all available)' } }
        end

        # Session / retry / timeout / TLS tuning knobs.
        def connection_params_schema
          {
            'session_timeout' => { 'type' => 'integer', 'default' => 300, 'required' => false,
                                   'description' => 'Session timeout in seconds' },
            'tool_prefix' => { 'type' => 'string', 'default' => 'mcp_', 'required' => false,
                               'description' => 'Prefix for registered SWAIG function names' },
            'retry_attempts' => { 'type' => 'integer', 'default' => 3, 'required' => false,
                                  'description' => 'Number of retry attempts for failed requests' },
            'request_timeout' => { 'type' => 'integer', 'default' => 30, 'required' => false,
                                   'description' => 'Request timeout in seconds' },
            'verify_ssl' => { 'type' => 'boolean', 'default' => true, 'required' => false,
                              'description' => 'Verify SSL certificates' }
          }
        end

        # No extra gems are needed — the gateway is reached over plain Net::HTTP.
        #
        # @return [Array<String>] empty
        def required_packages = []

        # Lazily populate config ivars if #setup hasn't run yet, so the hook
        # accessors (get_hints / get_global_data / get_prompt_sections /
        # register_tools) work standalone. Idempotent.
        def ensure_config
          read_config unless @config_read
        end

        # Read every config param off @params (with defaults). Called from
        # #setup and (lazily) from the hook accessors so the ivars are always
        # populated.
        def read_config
          @config_read = true
          read_auth_config
          read_connection_config
          @session_id = nil
        end

        # @api private — read the gateway credentials (bearer token, or basic-auth
        # user + password) and the gateway URL, each falling back to its
        # `MCP_GATEWAY_*` environment variable. Trailing slashes are stripped off the
        # URL so paths compose cleanly.
        def read_auth_config
          @auth_token    = get_param('auth_token', env_var: 'MCP_GATEWAY_AUTH_TOKEN')
          @auth_user     = get_param('auth_user', env_var: 'MCP_GATEWAY_AUTH_USER')
          @auth_password = get_param('auth_password', env_var: 'MCP_GATEWAY_AUTH_PASSWORD')
          @gateway_url   = (get_param('gateway_url', default: '') || '').sub(%r{/+\z}, '')
        end

        # @api private — read the service list, session timeout, tool-name prefix,
        # retry count, request timeout and TLS-verification flag. `verify_ssl` is read
        # STRAIGHT off the params rather than through `get_param`, because
        # `false || default` would resurrect the default and silently re-enable
        # verification the operator explicitly turned off.
        def read_connection_config
          @services        = normalize_services(@params['services'])
          @session_timeout = get_param('session_timeout', default: 300).to_i
          @tool_prefix     = get_param('tool_prefix', default: 'mcp_')
          @retry_attempts  = get_param('retry_attempts', default: 3).to_i
          @request_timeout = get_param('request_timeout', default: 30).to_i
          # SECURE DEFAULT: TLS peer verification is ON unless the operator opts
          # out with verify_ssl: false (for self-signed-cert gateways). Wired to
          # the real Net::HTTP verify_mode in #open_http. Read straight off
          # @params (NOT get_param) because `false || default` in get_param would
          # mask an explicit false — the whole point of the opt-out flag.
          @verify_ssl = @params.fetch('verify_ssl', true) != false
        end

        # @api private — normalise the configured service list, stringifying the keys
        # of each Hash entry so symbol- and string-keyed config both work. A non-Array
        # yields an empty list.
        #
        # @return [Array]
        def normalize_services(services)
          return [] unless services.is_a?(Array)

          services.map { |s| s.is_a?(Hash) ? s.transform_keys(&:to_s) : s }
        end

        # Either a token, or a full basic-auth credential set. Logs the missing
        # names and returns false otherwise.
        def valid_auth?
          return true if @auth_token && !@auth_token.empty?

          missing = %w[gateway_url auth_user auth_password].reject do |k|
            v = instance_variable_get("@#{k}")
            v && !v.to_s.empty?
          end
          return true if missing.empty?

          logger&.error("Missing required parameters: #{missing.inspect}")
          false
        end

        # @api private — the gateway URL must be present AND pass the SSRF validator,
        # which is what stops a config value from pointing the skill at an internal
        # address. Logs the specific reason before returning false.
        #
        # @return [Boolean]
        def valid_gateway_url?
          if @gateway_url.nil? || @gateway_url.empty?
            logger&.error('Missing required parameter: gateway_url')
            return false
          end
          return true if SignalWire::Utils::UrlValidator.validate_url(@gateway_url)

          logger&.error("Gateway URL rejected by SSRF protection: #{@gateway_url}")
          false
        end

        # Probe the gateway's /health endpoint. Returns true on a 2xx.
        def healthy?
          resp = make_request('GET', "#{@gateway_url}/health")
          return log_unhealthy("HTTP #{resp&.code}") unless resp.is_a?(Net::HTTPSuccess)

          logger&.info("Connected to MCP Gateway at #{@gateway_url}")
          true
        rescue StandardError => e
          log_unhealthy(e.message)
        end

        # Log the connection failure and return false (the setup sentinel).
        def log_unhealthy(reason)
          logger&.error("Failed to connect to gateway: #{reason}")
          false
        end

        # Populate @services with every service the gateway advertises.
        def resolve_services
          resp = make_request('GET', "#{@gateway_url}/services")
          return unless resp.is_a?(Net::HTTPSuccess)

          all = JSON.parse(resp.body)
          @services = Array(all).map { |svc_name| { 'name' => svc_name } }
        rescue StandardError => e
          logger&.error("Failed to list services: #{e.message}")
        end

        # Fetch (and filter) the tool definitions for one service.
        def mcp_tools_for(service_name)
          resp = make_request('GET', "#{@gateway_url}/services/#{service_name}/tools")
          return [] unless resp.is_a?(Net::HTTPSuccess)

          tools = JSON.parse(resp.body)['tools'] || []
          filter_tools(tools, service_name)
        rescue StandardError => e
          logger&.error("Failed to get tools for service '#{service_name}': #{e.message}")
          []
        end

        # Keep only the tools named in the service config's `tools` list; '*'
        # (or any non-Array) means all.
        def filter_tools(tools, service_name)
          filter = service_config_for(service_name)&.fetch('tools', '*') || '*'
          return tools unless filter.is_a?(Array)

          tools.select { |t| filter.include?(t['name']) }
        end

        # @api private — the configured entry for a service by name, tolerating both
        # String and Symbol `name` keys.
        #
        # @return [Hash, nil]
        def service_config_for(service_name)
          @services.find { |s| s.is_a?(Hash) && (s['name'] || s[:name]) == service_name }
        end

        # Build a single SWAIG tool-def hash from an MCP tool definition.
        def build_swaig_tool(service_name, tool_def)
          tool_name = tool_def['name']
          return nil unless tool_name

          swaig_name = "#{@tool_prefix}#{service_name}_#{tool_name}"
          input_schema = tool_def['inputSchema'] || {}
          required = input_schema['required'] || []
          logger&.info("Registered SWAIG function: #{swaig_name}")
          {
            name: swaig_name, required: required,
            description: "[#{service_name}] #{tool_def['description'] || tool_name}",
            parameters: swaig_params(input_schema['properties'] || {}, required),
            handler: tool_handler(service_name, tool_name)
          }
        end

        # A SWAIG handler that proxies a call to one MCP tool through the gateway.
        def tool_handler(service_name, tool_name)
          ->(args, raw_data) { call_mcp_tool(service_name, tool_name, args, raw_data) }
        end

        # Convert an MCP inputSchema.properties map into SWAIG parameter defs.
        def swaig_params(properties, required)
          properties.each_with_object({}) do |(prop_name, prop_def), out|
            param = {
              'type' => prop_def['type'] || 'string',
              'description' => prop_def['description'] || ''
            }
            param['enum'] = prop_def['enum'] if prop_def.key?('enum')
            param['default'] = prop_def['default'] if prop_def.key?('default') && !required.include?(prop_name)
            out[prop_name] = param
          end
        end

        # Invoke an MCP tool through the gateway (with retries) and wrap the
        # result in a FunctionResult.
        def call_mcp_tool(service_name, tool_name, args, raw_data)
          session_id = resolve_session_id(raw_data)
          request_body = {
            'tool' => tool_name, 'arguments' => args, 'session_id' => session_id,
            'timeout' => @session_timeout,
            'metadata' => {
              'agent_id' => (@agent.respond_to?(:name) ? @agent.name : nil),
              'timestamp' => raw_data['timestamp'], 'call_id' => raw_data['call_id']
            }
          }
          Swaig::FunctionResult.new(dispatch_with_retry(service_name, tool_name, request_body))
        end

        # @api private — proxy one MCP tool call through the gateway. Every failure —
        # exhausted retries or an unexpected exception — is converted to a spoken
        # failure STRING, so the model always receives something it can say rather than
        # an exception escaping into the SWAIG response.
        #
        # @return [String] the gateway's result, or a failure message
        def dispatch_with_retry(service_name, tool_name, request_body)
          url = "#{@gateway_url}/services/#{service_name}/call"
          result, error = attempt_dispatch(url, request_body)
          return result if result

          "Failed to call #{service_name}.#{tool_name}: #{error}"
        rescue StandardError => e
          logger&.error("Unexpected error: #{e.message}")
          "Failed to call #{service_name}.#{tool_name}: #{e.message}"
        end

        # Run the retry loop; returns [result_or_nil, last_error]. Retries only on
        # a 5xx; a 2xx returns the result and a 4xx is final.
        def attempt_dispatch(url, request_body)
          last_error = nil
          @retry_attempts.times do |attempt|
            resp = make_request('POST', url, json: request_body)
            return [parse_json(resp.body)['result'] || 'No response', nil] if resp.is_a?(Net::HTTPSuccess)

            last_error = error_message(resp)
            break unless retryable?(resp, last_error, attempt)
          end
          [nil, last_error]
        end

        # @api private — only a 5xx is retried: a 4xx is the gateway rejecting the
        # request itself, and retrying it would just repeat the rejection.
        #
        # @return [Boolean]
        def retryable?(resp, last_error, attempt)
          return false unless resp.is_a?(Net::HTTPServerError)

          logger&.warn("Gateway error (attempt #{attempt + 1}): #{last_error}")
          true
        end

        # @api private — the session id sent to the gateway so it can correlate a
        # conversation's tool calls: the agent's `mcp_call_id` global-data value, else
        # the call id, else the literal `"unknown"`.
        #
        # @return [String]
        def resolve_session_id(raw_data)
          global = raw_data['global_data'] || raw_data[:global_data] || {}
          global['mcp_call_id'] || raw_data['call_id'] || 'unknown'
        end

        # @api private — the gateway's `error` field when the body parses, else the
        # bare HTTP status. Never raises on top of the failure it is reporting.
        #
        # @return [String]
        def error_message(resp)
          parsed = parse_json(resp&.body)
          parsed['error'] || "HTTP #{resp&.code}"
        rescue StandardError
          "HTTP #{resp&.code}"
        end

        # @api private — parse a JSON body, yielding an empty Hash rather than raising
        # on malformed input.
        #
        # @return [Hash]
        def parse_json(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        # Service descriptions for the prompt section.
        def service_descriptions
          @services.filter_map { |service| describe_service(service) }
        end

        # @api private — one line describing a configured service for the prompt
        # section: its name plus whether all of its tools or an explicit subset are
        # exposed.
        #
        # @return [String]
        def describe_service(service)
          return service.to_s unless service.is_a?(Hash)

          svc_name = service.fetch('name', service[:name]) || 'Unknown'
          tools = service.fetch('tools', service[:tools]) || '*'
          return "#{svc_name} (all tools)" if tools == '*'

          "#{svc_name} (#{tools.length} tools)" if tools.is_a?(Array)
        end

        # The single prompt section describing the connected gateway + services.
        def integration_prompt_section(descriptions)
          {
            'title' => 'MCP Gateway Integration',
            'body' => 'You have access to external MCP (Model Context Protocol) ' \
                      'services through a gateway.',
            'bullets' => [
              "Connected to gateway at #{@gateway_url}",
              "Available services: #{descriptions.join(', ')}",
              "Functions are prefixed with '#{@tool_prefix}' followed by service name",
              'Each service maintains its own session state throughout the call'
            ]
          }
        end

        # --- HTTP -------------------------------------------------------------

        # Perform an authenticated HTTP request and return the Net::HTTPResponse
        # (or nil on transport failure). Authentication is bearer-token when a
        # token is configured, otherwise HTTP-basic.
        def make_request(method, url, json: nil)
          uri = URI(url)
          req = build_request(method, uri, json)
          open_http(uri).request(req)
        end

        REQUEST_CLASSES = {
          'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'DELETE' => Net::HTTP::Delete
        }.freeze
        private_constant :REQUEST_CLASSES

        # @api private — build the Net::HTTP request for a gateway call, applying the
        # configured auth and the JSON body.
        #
        # @raise [KeyError] for a method outside GET/POST/DELETE
        # @return [Net::HTTPRequest]
        def build_request(method, uri, json)
          req = REQUEST_CLASSES.fetch(method.upcase).new(uri)
          apply_auth(req)
          apply_json_body(req, json)
          req
        end

        # Bearer-token auth when a token is configured, otherwise HTTP-basic.
        def apply_auth(req)
          if @auth_token && !@auth_token.empty?
            req['Authorization'] = "Bearer #{@auth_token}"
          else
            req.basic_auth(@auth_user, @auth_password)
          end
        end

        # @api private — attach a JSON body and its content type. A nil +json+ leaves
        # the request bodiless, which is what a GET wants.
        def apply_json_body(req, json)
          return unless json

          req['Content-Type'] = 'application/json'
          req.body = JSON.generate(json)
        end

        # Build the Net::HTTP transport. TLS verification is threaded from the
        # @verify_ssl config: VERIFY_PEER (secure default) unless the operator
        # opted out with verify_ssl: false, in which case VERIFY_NONE.
        def open_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.verify_mode = @verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          http.open_timeout = @request_timeout
          http.read_timeout = @request_timeout
          http
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('mcp_gateway') do |params|
  SignalWire::Skills::Builtin::MCPGatewaySkill.new(params)
end
