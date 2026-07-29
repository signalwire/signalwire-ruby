# frozen_string_literal: true

require 'base64'

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # The DataSphere search as a DataMap tool: the search runs ON SignalWire's
      # servers rather than through a webhook back to this agent, so there is no
      # round trip to the agent process and no handler to time out. Same credentials
      # and document as {DatasphereSkill}.
      class DatasphereServerlessSkill < SkillBase
        # The name this skill is added under (`agent.add_skill('datasphere_serverless')`).
        #
        # @return [String]
        def name = 'datasphere_serverless'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Search knowledge using SignalWire DataSphere with serverless DataMap execution'
        # This skill may be loaded more than once on one agent — each instance
        # is distinguished by its `prefix` param, which also namespaces its
        # tools and its slice of `global_data`.
        #
        # @return [Boolean] true
        def supports_multiple_instances? = true

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          load_params
          return false unless required_params_present?

          @api_url     = "https://#{@space_name}.signalwire.com/api/datasphere/documents/search"
          @auth_header = Base64.strict_encode64("#{@project_id}:#{@token}")
          true
        end

        # The key this instance is tracked under — `datasphere_serverless_<tool_name>` — so several
        # instances can coexist on one agent without colliding.
        #
        # @return [String]
        def instance_key = "datasphere_serverless_#{@tool_name}"

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          dm = DataMap.new(@tool_name)
                      .description('Search the knowledge base for information on any topic and return relevant results')
                      .parameter('query', 'string', 'The search query', required: true)
                      .webhook('POST', @api_url, headers: webhook_headers)
                      .params(search_params)
                      .foreach(foreach_config)
                      .output(Swaig::FunctionResult.new('I found results for "${args.query}":\n\n${formatted_results}'))
                      .error_keys(%w[error])
                      .fallback_output(Swaig::FunctionResult.new(@no_results_msg))

          [{ datamap: dm.to_swaig_function }]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        # Data this skill merges into the agent's `global_data`, so its prompts
        # and tools can reference the values as `${global_data.*}`.
        #
        # @return [Hash]
        def get_global_data
          {
            'datasphere_serverless_enabled' => true,
            'document_id' => @document_id,
            'knowledge_provider' => 'SignalWire DataSphere (Serverless)'
          }
        end

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          [
            {
              'title' => 'Knowledge Search Capability (Serverless)',
              'body' => "You can search a knowledge base for information using the #{@tool_name} tool.",
              'bullets' => prompt_bullets
            }
          ]
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          {
            'space_name' => { 'type' => 'string', 'required' => true },
            'project_id' => { 'type' => 'string', 'required' => true },
            'token' => { 'type' => 'string', 'required' => true, 'hidden' => true },
            'document_id' => { 'type' => 'string', 'required' => true },
            'count' => { 'type' => 'integer', 'default' => 1 },
            'distance' => { 'type' => 'number', 'default' => 3.0 }
          }
        end

        private

        # @api private — read the space, credentials (falling back to
        # `SIGNALWIRE_PROJECT_ID` / `SIGNALWIRE_API_TOKEN`), document id, result count
        # and distance threshold, tool name, and the no-results message.
        def load_params
          @space_name  = get_param('space_name')
          @project_id  = get_param('project_id', env_var: 'SIGNALWIRE_PROJECT_ID')
          @token       = get_param('token', env_var: 'SIGNALWIRE_API_TOKEN')
          @document_id = get_param('document_id')
          @count       = get_param('count', default: 1).to_i
          @distance    = get_param('distance', default: 3.0).to_f
          @tool_name   = get_param('tool_name', default: 'search_knowledge')
          @no_results_msg = get_param('no_results_message',
                                      default: "I couldn't find any relevant information in the knowledge base.")
        end

        # @api private — the prompt bullets, naming this instance's CONFIGURED tool
        # name.
        def prompt_bullets
          [
            "Use the #{@tool_name} tool when users ask for information",
            'Search for relevant information using clear, specific queries',
            'Summarize search results in a clear, helpful way',
            'This tool executes on SignalWire servers for optimal performance'
          ]
        end

        # @api private — whether the space, project id, token and document id are all
        # set. All four are required; the skill refuses to load otherwise.
        #
        # @return [Boolean]
        def required_params_present?
          %w[space_name project_id token document_id].all? do |k|
            v = instance_variable_get("@#{k}")
            !v.nil? && !v.to_s.empty?
          end
        end

        # @api private — the headers SignalWire's servers send on the DataMap webhook:
        # JSON content type plus the pre-encoded HTTP-basic credentials. These
        # credentials travel INTO the emitted SWML, so the platform can call DataSphere
        # on this project's behalf.
        #
        # @return [Hash{String => String}]
        def webhook_headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => "Basic #{@auth_header}"
          }
        end

        # @api private — the DataSphere search body embedded in the DataMap. The query
        # is the SWML expression `${args.query}`, substituted server-side from the
        # model's tool arguments rather than by this process.
        #
        # @return [Hash{String => Object}]
        def search_params
          {
            'document_id' => @document_id,
            'query_string' => '${args.query}',
            'count' => @count,
            'distance' => @distance
          }
        end

        # @api private — the DataMap `foreach` that renders the response server-side:
        # iterate the response's `chunks`, cap at the configured count, and append each
        # chunk's text as a delimited result block into `formatted_results`.
        #
        # @return [Hash{String => Object}]
        def foreach_config
          {
            'input_key' => 'chunks',
            'output_key' => 'formatted_results',
            'max' => @count,
            'append' => "=== RESULT ===\n${this.text}\n#{'=' * 50}\n\n"
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datasphere_serverless') do |params|
  SignalWire::Skills::Builtin::DatasphereServerlessSkill.new(params)
end
