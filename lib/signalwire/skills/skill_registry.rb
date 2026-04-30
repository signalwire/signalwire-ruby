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

      # Per-instance state for the skill-directory parity surface; the
      # class-method API above is preserved for backwards compatibility,
      # but `add_skill_directory` mirrors Python's instance-method shape
      # exactly (Python's `signalwire.skills.registry.SkillRegistry`).
      def initialize
        @external_paths = []
        @inst_mutex     = Mutex.new
      end

      # External skill directories registered via #add_skill_directory.
      # Mirrors Python's `_external_paths` accessor surface.
      attr_reader :external_paths

      # Add a directory to search for skills.
      #
      # Mirrors Python's `SkillRegistry.add_skill_directory`: validate
      # that the path exists and is a directory, then append it
      # (de-duplicated) to `@external_paths`. Raises `ArgumentError`
      # (the Ruby analog of Python's `ValueError`) for invalid input.
      #
      # @param path [String] absolute or relative path to a directory
      # @return [void]
      # @raise [ArgumentError] when the path doesn't exist or isn't a
      #   directory.
      def add_skill_directory(path)
        @inst_mutex.synchronize do
          unless File.exist?(path)
            raise ArgumentError, "Skill directory does not exist: #{path}"
          end
          unless File.directory?(path)
            raise ArgumentError, "Path is not a directory: #{path}"
          end
          @external_paths << path unless @external_paths.include?(path)
        end
      end

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
