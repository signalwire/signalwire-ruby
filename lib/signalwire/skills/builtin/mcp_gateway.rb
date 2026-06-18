# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # Bridge MCP servers with SWAIG functions.
      class McpGatewaySkill < SkillBase
        def name = 'mcp_gateway'
        def description = 'Bridge MCP servers with SWAIG functions'

        def setup
          @gateway_url   = get_param('gateway_url')
          @auth_token    = get_param('auth_token')
          @auth_user     = get_param('auth_user')
          @auth_password = get_param('auth_password')
          @services      = get_param('services') || []
          @tool_prefix   = get_param('tool_prefix', default: 'mcp_')
          @timeout       = get_param('request_timeout', default: 30).to_i

          return false unless @gateway_url && !@gateway_url.empty?

          # Discover tools from gateway
          @mcp_tools = discover_tools
          true
        end

        def register_tools
          @mcp_tools.map do |tool|
            {
              name: tool[:name],
              description: tool[:description],
              parameters: tool[:parameters] || {},
              handler: lambda { |args, _raw_data|
                execute_mcp_tool(tool[:service], tool[:original_name], args)
              }
            }
          end
        end

        def get_hints
          hints = %w[MCP gateway]
          @services&.each { |s| hints << (s.is_a?(Hash) ? s['name'] : s.to_s) }
          hints
        end

        def get_global_data
          {
            'mcp_gateway_url' => @gateway_url,
            'mcp_session_id' => nil,
            'mcp_services' => @services
          }
        end

        def get_prompt_sections
          service_names = @services.map { |s| s.is_a?(Hash) ? s['name'] : s.to_s }
          [
            {
              'title' => 'MCP Gateway Integration',
              'body' => "Connected MCP services: #{service_names.join(', ')}",
              'bullets' => @mcp_tools.map { |t| "#{t[:name]}: #{t[:description]}" }
            }
          ]
        end

        def get_parameter_schema
          {
            'gateway_url' => { 'type' => 'string', 'required' => true },
            'auth_token' => { 'type' => 'string', 'hidden' => true },
            'auth_user' => { 'type' => 'string' },
            'auth_password' => { 'type' => 'string', 'hidden' => true },
            'services' => { 'type' => 'array' },
            'tool_prefix' => { 'type' => 'string', 'default' => 'mcp_' },
            'request_timeout' => { 'type' => 'integer', 'default' => 30 }
          }
        end

        private

        def discover_tools
          # In a real implementation, this would query the MCP gateway for available tools.
          # For the port, we return an empty list since we don't have a gateway to query.
          []
        rescue StandardError => _e
          []
        end

        def execute_mcp_tool(service, tool_name, args)
          uri  = URI("#{@gateway_url}/execute")
          req  = build_execute_request(uri, service, tool_name, args)
          resp = build_http(uri).request(req)
          data = JSON.parse(resp.body)
          Swaig::FunctionResult.new(data['result'] || data.to_json)
        rescue StandardError => e
          Swaig::FunctionResult.new("MCP tool error: #{e.message}")
        end

        def build_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = @timeout
          http.read_timeout = @timeout
          http
        end

        def build_execute_request(uri, service, tool_name, args)
          req = Net::HTTP::Post.new(uri.path)
          req['Content-Type'] = 'application/json'
          req['Authorization'] = "Bearer #{@auth_token}" if @auth_token
          req.basic_auth(@auth_user, @auth_password) if @auth_user
          req.body = { service: service, tool: tool_name, arguments: args }.to_json
          req
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('mcp_gateway') do |params|
  SignalWire::Skills::Builtin::McpGatewaySkill.new(params)
end
