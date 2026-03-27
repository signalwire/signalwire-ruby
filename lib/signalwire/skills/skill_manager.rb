# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'thread'
require_relative 'skill_base'

module SignalWire
  module Skills
    # Thread-safe lifecycle manager for loaded skill instances.
    #
    #   manager = SkillManager.new
    #   manager.load('datetime', DateTimeSkill.new)
    #   manager.get('datetime')  #=> <DateTimeSkill>
    #   manager.unload('datetime')
    #
    class SkillManager
      def initialize
        @skills = {}   # instance_key => SkillBase instance
        @mutex  = Mutex.new
      end

      # Load a skill instance. Calls +setup+ on the skill; raises if it fails.
      # @param key [String] the instance key
      # @param skill [SkillBase] the skill instance
      # @return [SkillBase] the loaded skill
      def load(key, skill)
        @mutex.synchronize do
          raise ArgumentError, "Skill already loaded: #{key}" if @skills.key?(key)

          unless skill.setup
            raise "Skill setup failed for '#{key}'"
          end

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
