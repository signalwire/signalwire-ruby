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

      # Get complete schema for all registered skills (instance form).
      #
      # Mirrors Python's instance-method
      # ``SkillRegistry.get_all_skills_schema()`` — returns a hash keyed
      # by skill name, each value containing parameter metadata. Ruby
      # skills don't carry rich Python-style parameter introspection in
      # v1, so the value defaults to a minimal shape with the skill
      # name; built-ins that expose ``parameter_schema`` get richer
      # detail.
      #
      # @return [Hash{String => Hash}]
      def get_all_skills_schema
        self.class.get_all_skills_schema
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

        # Get complete schema for all registered skills.
        #
        # Mirrors Python's
        # ``SkillRegistry.get_all_skills_schema()`` — returns a hash
        # keyed by skill name, with each value containing parameter
        # metadata. Ruby skills don't carry rich Python-style parameter
        # introspection in v1, so the value defaults to a minimal shape
        # with the skill name; built-in skills that expose
        # ``parameter_schema`` get richer detail.
        #
        # @return [Hash{String => Hash}]
        def get_all_skills_schema
          @mutex.synchronize do
            @factories.keys.sort.each_with_object({}) do |name, h|
              entry = { 'name' => name, 'parameters' => {} }
              factory = @factories[name]
              if factory.respond_to?(:call)
                begin
                  instance = factory.call({})
                  if instance.respond_to?(:parameter_schema)
                    entry['parameters'] = instance.parameter_schema || {}
                  end
                  if instance.class.respond_to?(:skill_description)
                    entry['description'] = instance.class.skill_description
                  end
                  if instance.class.respond_to?(:skill_version)
                    entry['version'] = instance.class.skill_version
                  end
                rescue StandardError
                  # If we can't instantiate without params, fall back to
                  # the minimal entry.
                end
              end
              h[name] = entry
            end
          end
        end
      end
    end
  end
end
