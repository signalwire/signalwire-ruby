# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'thread'

module SignalWire
  module Skills
    # Global registry mapping skill names to factory lambdas.
    #
    #   SkillRegistry.register('datetime') { |params| DateTimeSkill.new(params) }
    #   factory = SkillRegistry.get_factory('datetime')
    #   skill   = factory.call({ 'timezone' => 'UTC' })
    #
    class SkillRegistry
      @factories = {}  # skill_name => lambda { |params| SkillBase }
      @mutex     = Mutex.new

      class << self
        # Register a skill factory.
        # @param skill_name [String]
        # @yield [params] block that receives params hash and returns a SkillBase
        def register(skill_name, &block)
          @mutex.synchronize do
            @factories[skill_name.to_s] = block
          end
        end

        # Register with an explicit lambda / proc instead of a block.
        # @param skill_name [String]
        # @param factory [Proc]
        def register_skill(skill_name, factory)
          @mutex.synchronize do
            @factories[skill_name.to_s] = factory
          end
        end

        # Get the factory for a skill.
        # @param skill_name [String]
        # @return [Proc, nil]
        def get_factory(skill_name)
          @mutex.synchronize { @factories[skill_name.to_s] }
        end

        # List all registered skill names.
        # @return [Array<String>]
        def list_skills
          @mutex.synchronize { @factories.keys.dup }
        end

        # Check if a skill is registered.
        # @param skill_name [String]
        # @return [Boolean]
        def registered?(skill_name)
          @mutex.synchronize { @factories.key?(skill_name.to_s) }
        end

        # Clear all registrations (primarily for testing).
        def reset!
          @mutex.synchronize { @factories.clear }
        end

        # Register all built-in skills. Called at load time.
        def register_builtins!
          # Each builtin file calls SkillRegistry.register on require.
          # We just need to require them all.
          builtin_dir = File.join(__dir__, 'builtin')
          Dir[File.join(builtin_dir, '*.rb')].sort.each { |f| require f }
        end
      end
    end
  end
end
