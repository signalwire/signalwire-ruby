# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'
require_relative '../logging'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Base class for all skills. Subclasses override the metadata methods
    # and +register_tools+ to supply tool hashes.
    class SkillBase
      # Attributes:
      # - ``params`` — params hash passed at construction
      # - ``agent`` — owning AgentBase instance (or nil for standalone)
      # - ``logger`` — namespaced logger ``signalwire.skills.<name>``
      # - ``swaig_fields`` — extra SWAIG fields merged into tool defs;
      #   pulled out of ``params`` if provided
      attr_reader :params, :agent, :logger, :swaig_fields

      # The name this skill is added under. Every subclass MUST override this — the
      # base raises rather than inventing a name.
      #
      # @return [String]
      # @raise [NotImplementedError] when a subclass has not overridden it
      def name = raise(NotImplementedError, "#{self.class}#name")
      # Human-readable summary of what the skill does. Every subclass MUST override
      # this — the base raises rather than inventing one.
      #
      # @return [String]
      # @raise [NotImplementedError] when a subclass has not overridden it
      def description = raise(NotImplementedError, "#{self.class}#description")
      # This skill's own version, independent of the SDK's.
      #
      # @return [String] '1.0.0'
      def version = '1.0.0'
      # The environment variables this skill needs set before it can run; checked by
      # {#validate_env_vars}. Empty by default.
      #
      # @return [Array<String>]
      def required_env_vars = []
      # The gem names this skill needs loadable before it can run;
      # consumed by {#validate_packages}.
      def required_packages = []
      private :required_packages # internal hook; not part of the public API
      # Only one instance of this skill may be loaded per agent.
      #
      # @return [Boolean] false
      def supports_multiple_instances? = false

      # First positional arg is the owning AgentBase (or nil for
      # standalone). The second is the params hash. We accept the legacy
      # 1-arg form for backwards compatibility (``DateTimeSkill.new({...})``).
      def initialize(agent = nil, params = nil)
        # Backwards compat: a single Hash means params-only (no agent).
        if agent.is_a?(Hash) && params.nil?
          params = agent
          agent  = nil
        end
        @agent  = agent
        @params = (params || {}).transform_keys(&:to_s)
        # swaig_fields is removed from params and held separately.
        @swaig_fields = @params.delete('swaig_fields') || {}
        @logger = ::SignalWire::Logging.logger("signalwire.skills.#{logger_name_segment}")
      end

      # Called once after construction. Return +true+ if the skill is ready.
      def setup = true

      # Return an Array of tool definition hashes. Each hash should have:
      #   :name, :description, :parameters, :handler (lambda/proc)
      def register_tools = []

      # Define a SWAIG tool on the owning agent, automatically merging any
      # swaig_fields configured for this skill. Skills should use this instead
      # of calling agent.define_tool directly.
      #
      # @param name [String] tool name
      # @param description [String] tool description
      # @param parameters [Hash] JSON-schema parameters
      # @param kwargs [Hash] extra SWAIG fields (merged with @swaig_fields)
      def define_tool(name:, description:, parameters: {}, **kwargs, &handler)
        raise 'skill has no agent to define tools on' unless @agent

        merged = (@swaig_fields || {}).merge(kwargs)
        # `handler:` is a required keyword; the block IS the handler here, so the
        # explicit slot is nil unless the caller's merged kwargs already set it.
        @agent.define_tool(name: name, description: description,
                           parameters: parameters, handler: nil, **merged, &handler)
      end

      # Speech recognition hints.
      def get_hints = []

      # Global data to merge into the agent.
      def get_global_data = {}

      # Prompt sections to add to the agent.
      def get_prompt_sections = []

      # Called when the skill is unloaded.
      def cleanup; end

      # Unique key for tracking this skill instance.
      def instance_key = name

      # Parameter schema for GUI / validation.
      def get_parameter_schema = {}

      # Read this skill instance's namespaced data out of a raw_data hash.
      #
      # Reads ``raw_data["global_data"][namespace]`` and returns it (or an
      # empty hash when absent). +raw_data+ is the per-call data hash
      # SWAIG handlers receive; +global_data+ is its agent-state bucket.
      # Tolerates symbol or string keys for ``global_data``.
      #
      # @param raw_data [Hash] the raw_data passed to a SWAIG handler.
      # @return [Hash] the namespaced skill state, or +{}+ if not present.
      def get_skill_data(raw_data)
        raw_data ||= {}
        global_data = raw_data['global_data'] || raw_data[:global_data] || {}
        global_data[skill_namespace] || {}
      end

      # Write this skill instance's namespaced data into a FunctionResult.
      #
      # Wraps +data+ under the skill namespace and calls
      # ``result.update_global_data``. Returns +result+ so callers can
      # chain.
      #
      # @param result [SignalWire::Swaig::FunctionResult]
      # @param data [Hash] the skill state to persist under the namespace.
      # @return [SignalWire::Swaig::FunctionResult] +result+, for chaining.
      def update_skill_data(result, data)
        result.update_global_data(skill_namespace => data)
        result
      end

      # Check that every required environment variable is set.
      #
      # Returns +false+ (and logs the missing names) when any entry of
      # {#required_env_vars} is absent or empty in +ENV+, otherwise +true+.
      #
      # @return [Boolean]
      def validate_env_vars
        missing = required_env_vars.reject { |var| ENV.fetch(var, nil) && !ENV[var].empty? }
        unless missing.empty?
          @logger&.error("Missing required environment variables: #{missing.inspect}")
          return false
        end
        true
      end

      # Check that every required gem is loadable.
      #
      # Returns +false+ (and logs the missing names) when any entry of
      # {#required_packages} can't be +require+d, otherwise +true+. A
      # successful +require+ leaves the gem loaded.
      #
      # @return [Boolean]
      def validate_packages
        missing = required_packages.reject { |package| require_package(package) }
        unless missing.empty?
          @logger&.error("Missing required packages: #{missing.inspect}")
          return false
        end
        true
      end

      # Helper to get a param with env-var fallback.
      def get_param(key, env_var: nil, default: nil)
        @params[key.to_s] || @params[key.to_sym.to_s] || (env_var && ENV.fetch(env_var, nil)) || default
      end

      private

      # Resolve a skill's base URL: the +env_var+ override when set and
      # non-empty, otherwise +default+, with any trailing slash stripped so
      # callers can append a path segment cleanly. Centralizes the
      # `ENV.fetch(...) → default → sub(%r{/$}, '')` pattern the HTTP skills
      # each hand-rolled. Private: an internal helper for subclasses, not part
      # of the enumerated public skill surface.
      #
      # @param env_var [String] the override env var name (e.g. "WEATHER_API_BASE_URL")
      # @param default [String] the production host used when the override is absent
      # @return [String] the resolved base URL, without a trailing slash
      def resolved_base_url(env_var, default)
        base = ENV.fetch(env_var, nil)
        base = default if base.nil? || base.empty?
        base.sub(%r{/$}, '')
      end

      # Logger namespace segment: the skill +name+, or the class name when
      # +name+ is still the abstract NotImplementedError raiser.
      def logger_name_segment
        name
      rescue NotImplementedError
        self.class.name
      end

      # +require+ a single gem; returns true on success, false on LoadError.
      def require_package(package)
        require package
        true
      rescue LoadError
        false
      end

      # Namespaced key for this skill instance's global_data slice.
      #
      # Uses the ``prefix`` param when present (``"skill:<prefix>"``),
      # otherwise falls back to the instance key (``"skill:<instance_key>"``)
      # so multiple instances don't collide in global_data.
      #
      # @return [String]
      def skill_namespace
        prefix = get_param('prefix')
        return "skill:#{prefix}" if prefix && !prefix.to_s.empty?

        "skill:#{instance_key}"
      end
    end
  end
end
