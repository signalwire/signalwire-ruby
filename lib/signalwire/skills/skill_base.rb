# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'
require_relative '../logging'

module SignalWire
  module Skills
    # Base class for all skills. Subclasses override the metadata methods
    # and +register_tools+ to supply tool hashes.
    class SkillBase
      # Python parity:
      # - ``params`` — params hash passed at construction
      # - ``agent`` — owning AgentBase instance (or nil for standalone)
      # - ``logger`` — namespaced logger ``signalwire.skills.<name>``
      # - ``swaig_fields`` — extra SWAIG fields merged into tool defs;
      #   pulled out of ``params`` if provided
      attr_reader :params, :agent, :logger, :swaig_fields

      def name = raise(NotImplementedError, "#{self.class}#name")
      def description = raise(NotImplementedError, "#{self.class}#description")
      def version = '1.0.0'
      def required_env_vars = []
      # Python parity: ``REQUIRED_PACKAGES``. The gem names this skill
      # needs loadable before it can run; consumed by {#validate_packages}.
      def required_packages = []
      private :required_packages # internal hook (mirrors Python REQUIRED_PACKAGES attr); not on the public surface
      def supports_multiple_instances? = false

      # Python parity: ``SkillBase.__init__(self, agent, params=None)``.
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
        # Python: pop swaig_fields out of params for separate access.
        @swaig_fields = @params.delete('swaig_fields') || {}
        @logger = ::SignalWire::Logging.logger("signalwire.skills.#{begin
          name
        rescue NotImplementedError
          self.class.name
        end}")
      end

      # Called once after construction. Return +true+ if the skill is ready.
      def setup = true

      # Return an Array of tool definition hashes. Each hash should have:
      #   :name, :description, :parameters, :handler (lambda/proc)
      def register_tools = []

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
      # Python parity: ``SkillBase.get_skill_data(raw_data)`` — reads
      # ``raw_data["global_data"][namespace]`` and returns it (or an
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
      # Python parity: ``SkillBase.update_skill_data(result, data)`` —
      # wraps +data+ under the skill namespace and calls
      # ``result.update_global_data``. Returns +result+ so callers can
      # chain (mirrors Python returning the result).
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
      # Python parity: ``SkillBase.validate_env_vars`` — returns +false+
      # (and logs the missing names) when any entry of {#required_env_vars}
      # is absent or empty in +ENV+, otherwise +true+.
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
      # Python parity: ``SkillBase.validate_packages`` (Python imports the
      # module; Ruby +require+s the gem). Returns +false+ (and logs the
      # missing names) when any entry of {#required_packages} can't be
      # +require+d, otherwise +true+. A successful +require+ leaves the
      # gem loaded — matching Python's ``importlib.import_module``.
      #
      # @return [Boolean]
      def validate_packages
        missing = required_packages.reject do |package|
          require package
          true
        rescue LoadError
          false
        end
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

      # Namespaced key for this skill instance's global_data slice.
      #
      # Python parity: ``SkillBase._get_skill_namespace`` — uses the
      # ``prefix`` param when present (``"skill:<prefix>"``), otherwise
      # falls back to the instance key (``"skill:<instance_key>"``) so
      # multiple instances don't collide in global_data.
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
