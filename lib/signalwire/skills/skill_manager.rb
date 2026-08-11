# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative 'skill_base'
require_relative '../logging'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Thread-safe lifecycle manager for loaded skill instances.
    #
    #   manager = SkillManager.new
    #   manager.load('datetime', DateTimeSkill.new)
    #   manager.get('datetime')  #=> <DateTimeSkill>
    #   manager.unload('datetime')
    #
    class SkillManager
      # Attributes:
      # - ``agent`` — owning AgentBase instance (or nil)
      # - ``logger`` — namespaced logger
      attr_reader :agent, :logger

      # SkillManager keeps a back-pointer to its agent so loaded
      # skills can attach prompt sections / SWAIG tools directly.
      # Allows nil for standalone use (tests, registry tools).
      def initialize(agent = nil)
        @agent  = agent
        @skills = {} # instance_key => SkillBase instance
        @mutex  = Mutex.new
        @logger = ::SignalWire::Logging.logger('signalwire.skill_manager')
      end

      # Load a skill instance. Calls +setup+ on the skill; raises if it fails.
      # @param key [String] the instance key
      # @param skill [SkillBase] the skill instance
      # @return [SkillBase] the loaded skill
      def load(key, skill)
        @mutex.synchronize do
          raise ArgumentError, "Skill already loaded: #{key}" if @skills.key?(key)

          raise "Skill setup failed for '#{key}'" unless skill.setup

          @skills[key] = skill
        end
        skill
      end

      # Unload a skill by instance key. Calls +cleanup+ on it.
      # @param key [String]
      # @return [SkillBase, nil] the removed skill, or nil
      def unload(key)
        @mutex.synchronize do
          skill = @skills.delete(key)
          skill&.cleanup
          skill
        end
      end

      # Retrieve a loaded skill.
      # @param key [String]
      # @return [SkillBase, nil]
      def get(key)
        @mutex.synchronize { @skills[key] }
      end

      # @return [Boolean]
      def loaded?(key)
        @mutex.synchronize { @skills.key?(key) }
      end

      # @return [Array<String>]
      def loaded_keys
        @mutex.synchronize { @skills.keys.dup }
      end

      # @return [Integer]
      def size
        @mutex.synchronize { @skills.size }
      end

      # Unload all skills.
      def clear
        @mutex.synchronize do
          @skills.each_value(&:cleanup)
          @skills.clear
        end
      end
    end
  end
end
