# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

module SignalWire
  module Skills
    # Base class for all skills. Subclasses override the metadata methods
    # and +register_tools+ to supply tool hashes.
    class SkillBase
      attr_reader :params

      def name;                       raise NotImplementedError, "#{self.class}#name"; end
      def description;                raise NotImplementedError, "#{self.class}#description"; end
      def version;                    '1.0.0'; end
      def required_env_vars;          []; end
      def supports_multiple_instances?; false; end

      def initialize(params = {})
        @params = (params || {}).transform_keys(&:to_s)
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
