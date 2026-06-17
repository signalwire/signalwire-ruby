# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../logging'
require_relative 'skill_name'

module SignalWire
  module Skills
    # Global registry mapping skill names to factory lambdas.
    #
    #   SkillRegistry.register('datetime') { |params| DateTimeSkill.new(params) }
    #   factory = SkillRegistry.get_factory('datetime')
    #   skill   = factory.call({ 'timezone' => 'UTC' })
    #
    class SkillRegistry
      @factories = {} # skill_name => lambda { |params| SkillBase }
      @mutex     = Mutex.new

      # Per-instance state for the skill-directory parity surface; the
      # class-method API above is preserved for backwards compatibility,
      # but `add_skill_directory` mirrors Python's instance-method shape
      # exactly (Python's `signalwire.skills.registry.SkillRegistry`).
      def initialize
        @external_paths = []
        @inst_mutex     = Mutex.new
        @logger         = ::SignalWire::Logging.logger('skill_registry')
      end

      # Python parity: ``self.logger = get_logger("skill_registry")``.
      # Per-instance logger; the class-level API uses the same name.
      attr_reader :logger

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
          raise ArgumentError, "Skill directory does not exist: #{path}" unless File.exist?(path)
          raise ArgumentError, "Path is not a directory: #{path}" unless File.directory?(path)

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

      # List all registered skill names (instance form).
      #
      # Python parity: ``SkillRegistry.list_skills(self)`` returns a list of
      # dictionaries describing each skill. Ruby v1 returns the
      # registered names plus available metadata (description / version)
      # when the factory can be instantiated without arguments.
      #
      # @return [Array<Hash>]
      def list_skills
        self.class.send(:_list_skills_full)
      end

      # Ensure built-in skills are discovered/registered (instance form).
      #
      # Python parity: ``SkillRegistry.discover_skills`` is a deprecated
      # no-op there because skills load on-demand. Ruby ships its
      # built-ins explicitly, so the faithful equivalent is to make sure
      # they're registered — idempotent, since {register_builtins!} just
      # re-requires the (already loaded) built-in files. Returns the
      # registered skill names so callers can confirm discovery ran.
      #
      # @return [Array<String>] currently registered skill names.
      def discover_skills
        self.class.discover_skills
      end

      # List skill sources and the skills available from each (instance form).
      #
      # Python parity: ``SkillRegistry.list_all_skill_sources`` returns a
      # hash mapping source type to skill names. This instance form folds
      # in any directories registered via {#add_skill_directory}.
      #
      # @return [Hash{String => Array<String>}]
      def list_all_skill_sources
        self.class.list_all_skill_sources(external_paths: @external_paths)
      end

      # Register a skill class or factory (instance form).
      #
      # Python parity: ``SkillRegistry.register_skill(self, skill_class)``
      # accepts a SkillBase subclass and stores its factory. Ruby
      # accepts either a class with a ``new(params)`` constructor, a
      # ``Proc`` /``Lambda``, or a 2-arg ``(name, factory)`` form for
      # explicit naming. Returns ``self`` for chaining.
      #
      # @param skill_class_or_name [Class, String] either a SkillBase
      #   subclass (Python style) or a string skill name (legacy
      #   2-arg form).
      # @param factory [Proc, nil] explicit factory when first arg
      #   is a string (legacy form).
      def register_skill(skill_class_or_name, factory = nil)
        if skill_class_or_name.is_a?(String)
          # Legacy 2-arg form: register_skill(name, factory)
          self.class.register_skill(skill_class_or_name, factory)
          return self
        end

        skill_class = skill_class_or_name
        unless skill_class.respond_to?(:new)
          raise ArgumentError,
                'register_skill expects a class with .new or a (name, factory) pair'
        end

        # Pull the skill name from a class-level method or constant.
        name = if skill_class.respond_to?(:skill_name)
                 skill_class.skill_name
               elsif skill_class.const_defined?(:SKILL_NAME)
                 skill_class.const_get(:SKILL_NAME)
               else
                 # Try instantiating with no args to read .name from the
                 # instance — Ruby idiom for skills that lack a
                 # class-level constant.
                 begin
                   skill_class.new.name
                 rescue StandardError
                   nil
                 end
               end

        raise ArgumentError, "Cannot determine skill name for #{skill_class}" if name.nil?

        self.class.register_skill(name.to_s, ->(params = {}) { skill_class.new(params) })
        @inst_mutex.synchronize { @last_registered = name.to_s }
        self
      end

      # The most recently registered skill name (instance form).
      attr_reader :last_registered

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

        # Full skill metadata (Python instance-method parity for
        # SkillRegistry.list_skills). Returns one dict per skill with
        # name + description + version when available.
        # @api private
        def _list_skills_full
          @mutex.synchronize do
            @factories.keys.sort.map do |skill_name|
              entry = { 'name' => skill_name }
              factory = @factories[skill_name]
              if factory.respond_to?(:call)
                begin
                  instance = factory.call({})
                  entry['description'] = instance.description if instance.respond_to?(:description)
                  entry['version']     = instance.version     if instance.respond_to?(:version)
                rescue StandardError
                  # Skill needs constructor args; fall back to name-only.
                end
              end
              entry
            end
          end
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
          Dir[File.join(builtin_dir, '*.rb')].each { |f| require f }
        end

        # Skill names this gem ships as built-ins.
        #
        # Single source of truth: this returns {SkillName::ALL}, the named
        # constant set. The +builtin/+ directory is the runtime origin of
        # the actual factories (one file per skill, each calling
        # +SkillRegistry.register+ on require); the spec asserts the
        # directory listing and {SkillName::ALL} stay identical so the
        # named set can never silently drift from what gets registered.
        # @return [Array<String>]
        def builtin_skill_names
          SkillName::ALL.dup
        end
        # Internal helper — not part of the Python surface; reached via
        # discover_skills / list_all_skill_sources.
        private :builtin_skill_names

        # Ensure built-in skills are registered and return their names.
        #
        # Python parity: ``SkillRegistry.discover_skills`` (a no-op there
        # since skills load on-demand). Ruby ships built-ins explicitly,
        # so this guarantees they're registered via {register_builtins!}
        # (idempotent) and returns the registered skill names.
        #
        # @return [Array<String>] currently registered skill names.
        def discover_skills
          register_builtins!
          list_skills
        end

        # List all skill sources and the skills available from each.
        #
        # Python parity: ``SkillRegistry.list_all_skill_sources`` returns
        # a hash keyed by source type. Ruby has no Python-style entry
        # points, so that bucket is always empty; +registered+ holds any
        # skill that isn't a shipped built-in (e.g. registered via
        # {register_skill}). +external_paths+ folds in skill subdirectory
        # names found under any directories passed in.
        #
        # @param external_paths [Array<String>] directories registered via
        #   an instance's #add_skill_directory.
        # @return [Hash{String => Array<String>}]
        def list_all_skill_sources(external_paths: [])
          builtins = builtin_skill_names
          sources = {
            'built-in' => builtins,
            'external_paths' => [],
            'entry_points' => [],
            'registered' => []
          }

          external_paths.each do |path|
            next unless File.directory?(path)

            Dir.children(path).sort.each do |entry|
              child = File.join(path, entry)
              next unless File.directory?(child) && !entry.start_with?('__')

              sources['external_paths'] << entry if File.exist?(File.join(child, 'skill.rb'))
            end
          end

          list_skills.each do |skill_name|
            sources['registered'] << skill_name unless builtins.include?(skill_name)
          end

          sources
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
                  entry['parameters'] = instance.parameter_schema || {} if instance.respond_to?(:parameter_schema)
                  if instance.class.respond_to?(:skill_description)
                    entry['description'] = instance.class.skill_description
                  end
                  entry['version'] = instance.class.skill_version if instance.class.respond_to?(:skill_version)
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
