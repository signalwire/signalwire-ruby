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

      def name;                       raise NotImplementedError, "#{self.class}#name"; end
      def description;                raise NotImplementedError, "#{self.class}#description"; end
      def version;                    '1.0.0'; end
      def required_env_vars;          []; end
      def supports_multiple_instances?; false; end

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
      def setup; true; end

      # Return an Array of tool definition hashes. Each hash should have:
      #   :name, :description, :parameters, :handler (lambda/proc)
      def register_tools; []; end

      # Speech recognition hints.
      def get_hints; []; end

      # Global data to merge into the agent.
      def get_global_data; {}; end

      # Prompt sections to add to the agent.
      def get_prompt_sections; []; end

      # Called when the skill is unloaded.
      def cleanup; end

      # Unique key for tracking this skill instance.
      def instance_key; name; end

      # Parameter schema for GUI / validation.
      def get_parameter_schema; {}; end

      # Helper to get a param with env-var fallback.
      def get_param(key, env_var: nil, default: nil)
        @params[key.to_s] || @params[key.to_sym.to_s] || (env_var && ENV[env_var]) || default
      end
    end
  end
end
