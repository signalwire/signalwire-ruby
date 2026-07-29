# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../logging'
require_relative 'skill_name'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # @api private — class-method helpers that introspect registered skill
    # factories. Extracted from {SkillRegistry} (which +extend+s it) so the
    # registry class stays focused on its public API; runs with the registry
    # class as +self+, so it reads the same +@factories+ store.
    module SkillIntrospection
      # { 'name', ('description'), ('version') } for one skill; name-only when
      # the factory needs constructor args.
      def skill_summary(skill_name)
        entry = { 'name' => skill_name }
        factory = @factories[skill_name]
        return entry unless factory.respond_to?(:call)

        begin
          instance = factory.call({})
          entry['description'] = instance.description if instance.respond_to?(:description)
          entry['version']     = instance.version     if instance.respond_to?(:version)
        rescue StandardError
          # Skill needs constructor args; fall back to name-only.
        end
        entry
      end

      # Names of skill subdirectories (containing skill.rb) directly under
      # +path+, sorted; [] when +path+ isn't a directory.
      def skill_dirs_under(path)
        return [] unless File.directory?(path)

        Dir.children(path).sort.select do |entry|
          child = File.join(path, entry)
          File.directory?(child) && !entry.start_with?('__') &&
            File.exist?(File.join(child, 'skill.rb'))
        end
      end

      # { 'name', 'parameters', ('description'), ('version') } for one skill;
      # minimal entry when it can't be instantiated bare.
      def skill_schema_entry(name)
        entry = { 'name' => name, 'parameters' => {} }
        factory = @factories[name]
        return entry unless factory.respond_to?(:call)

        begin
          enrich_schema_entry(entry, factory.call({}))
        rescue StandardError
          # Can't instantiate without params; fall back to the minimal entry.
        end
        entry
      end

      # Fold parameter_schema / description / version off a bare skill instance
      # into +entry+ (only when the instance exposes them).
      def enrich_schema_entry(entry, instance)
        entry['parameters'] = instance.parameter_schema || {} if instance.respond_to?(:parameter_schema)
        entry['description'] = instance.class.skill_description if instance.class.respond_to?(:skill_description)
        entry['version'] = instance.class.skill_version if instance.class.respond_to?(:skill_version)
        entry
      end
    end

    # Global registry mapping skill names to factory lambdas.
    #
    #   SkillRegistry.register('datetime') { |params| DateTimeSkill.new(params) }
    #   factory = SkillRegistry.get_factory('datetime')
    #   skill   = factory.call({ 'timezone' => 'UTC' })
    #
    class SkillRegistry
      extend SkillIntrospection

      @factories = {} # skill_name => lambda { |params| SkillBase }
      @mutex     = Mutex.new

      # Per-instance state for the skill-directory API; the class-method
      # API above is preserved for backwards compatibility, while
      # `add_skill_directory` exposes the same behavior in instance form.
      def initialize
        @external_paths = []
        @inst_mutex     = Mutex.new
        @logger         = ::SignalWire::Logging.logger('skill_registry')
      end

      # Per-instance logger; the class-level API uses the same name.
      attr_reader :logger

      # Effective external skill directories: the ones registered via
      # {#add_skill_directory} PLUS any supplied through the
      # `SIGNALWIRE_SKILL_PATHS` environment variable (colon-separated,
      # deduped, registered paths first).
      #
      # Mirrors the Python reference `SkillRegistry`, which appends
      # `os.environ["SIGNALWIRE_SKILL_PATHS"]` (split on `os.pathsep`) to its
      # registered `_external_paths` when resolving/discovering skills
      # (`registry.py` `_load_skill_on_demand` + `get_all_skills_schema`). The
      # env var is read on every call so a value set after construction still
      # takes effect, matching Python's search-time read.
      #
      # @return [Array<String>]
      def external_paths
        paths = @inst_mutex.synchronize { @external_paths.dup }
        self.class.send(:env_skill_paths).each { |p| paths << p unless paths.include?(p) }
        paths
      end

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
      def get_all_skills_schema = self.class.get_all_skills_schema

      # List all registered skill names (instance form).
      #
      # Returns the registered skill names plus available metadata
      # (description / version) when the factory can be instantiated
      # without arguments.
      #
      # @return [Array<Hash>]
      def list_skills = self.class.send(:list_skills_full)

      # Ensure built-in skills are discovered/registered (instance form).
      #
      # Ensures the built-in skills are registered — idempotent, since
      # {register_builtins!} just re-requires the (already loaded) built-in
      # files. Returns the registered skill names so callers can confirm
      # discovery ran.
      #
      # @return [Array<String>] currently registered skill names.
      def discover_skills = self.class.discover_skills

      # List skill sources and the skills available from each (instance form).
      #
      # Returns a hash mapping source type to skill names. This instance
      # form folds in any directories registered via {#add_skill_directory}.
      #
      # @return [Hash{String => Array<String>}]
      def list_all_skill_sources = self.class.list_all_skill_sources(external_paths: external_paths)

      # Register a skill class or factory (instance form).
      #
      # Accepts either a SkillBase subclass with a ``new(params)``
      # constructor, a ``Proc`` /``Lambda``, or a 2-arg ``(name, factory)``
      # form for explicit naming. Returns ``self`` for chaining.
      #
      # @param skill_class_or_name [Class, String] either a SkillBase
      #   subclass or a string skill name (legacy 2-arg form).
      # @param factory [Proc, nil] explicit factory when first arg
      #   is a string (legacy form).
      def register_skill(skill_class_or_name, factory = nil)
        if skill_class_or_name.is_a?(String)
          # Legacy 2-arg form: register_skill(name, factory)
          self.class.register_skill(skill_class_or_name, factory)
          return self
        end

        skill_class = skill_class_or_name
        name = require_skill_name(skill_class)
        self.class.register_skill(name, ->(params = {}) { skill_class.new(params) })
        @inst_mutex.synchronize { @last_registered = name }
        self
      end

      # Resolve and validate the registrable name for +skill_class+ (raising
      # ArgumentError when the class can't be constructed or named).
      def require_skill_name(skill_class)
        unless skill_class.respond_to?(:new)
          raise ArgumentError, 'register_skill expects a class with .new or a (name, factory) pair'
        end

        name = resolve_skill_name(skill_class)
        raise ArgumentError, "Cannot determine skill name for #{skill_class}" if name.nil?

        name.to_s
      end
      private :require_skill_name

      # The most recently registered skill name (instance form).
      attr_reader :last_registered

      # Pull the skill name from a class-level method, a SKILL_NAME constant,
      # or (Ruby idiom) a no-arg instance's #name. Returns nil if none apply.
      def resolve_skill_name(skill_class)
        return skill_class.skill_name if skill_class.respond_to?(:skill_name)
        return skill_class.const_get(:SKILL_NAME) if skill_class.const_defined?(:SKILL_NAME)

        begin
          skill_class.new.name
        rescue StandardError
          nil
        end
      end
      private :resolve_skill_name

      class << self
        # Register a skill factory.
        # @param skill_name [String]
        # @yield [params] block that receives params hash and returns a SkillBase
        def register(skill_name, &block)
          @mutex.synchronize { @factories[skill_name.to_s] = block }
        end

        # Register with an explicit lambda / proc instead of a block.
        # @param skill_name [String]
        # @param factory [Proc]
        def register_skill(skill_name, factory)
          @mutex.synchronize { @factories[skill_name.to_s] = factory }
        end

        # Get the factory for a skill.
        # @param skill_name [String]
        # @return [Proc, nil]
        def get_factory(skill_name) = @mutex.synchronize { @factories[skill_name.to_s] }

        # List all registered skill names.
        # @return [Array<String>]
        def list_skills = @mutex.synchronize { @factories.keys.dup }

        # Full skill metadata backing the instance-method {#list_skills}.
        # Returns one dict per skill with name + description + version when
        # available.
        # @api private
        def list_skills_full
          register_builtins! # parity: Python auto-discovers builtins (idempotent)
          @mutex.synchronize { @factories.keys.sort.map { |skill_name| skill_summary(skill_name) } }
        end

        # Check if a skill is registered.
        # @param skill_name [String]
        # @return [Boolean]
        def registered?(skill_name) = @mutex.synchronize { @factories.key?(skill_name.to_s) }

        # Clear all registrations (primarily for testing).
        def reset! = @mutex.synchronize { @factories.clear }

        # Directories named by the `SIGNALWIRE_SKILL_PATHS` environment variable
        # (path-separator-delimited, empty entries dropped).
        #
        # Mirrors the Python reference, which reads
        # `os.environ.get("SIGNALWIRE_SKILL_PATHS", "").split(os.pathsep)` and
        # folds those directories into the skill search path (`registry.py:59`
        # and `:387`). Read fresh on every call so a var set after startup still
        # takes effect, matching Python's search-time read.
        #
        # @return [Array<String>]
        def env_skill_paths
          ENV.fetch('SIGNALWIRE_SKILL_PATHS', '').split(File::PATH_SEPARATOR).reject(&:empty?)
        end

        # Register all built-in skills. Called at load time. Each builtin file
        # calls SkillRegistry.register on require, so we just require them all.
        def register_builtins!
          Dir[File.join(__dir__, 'builtin', '*.rb')].each { |f| require f }
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
        def builtin_skill_names = SkillName::ALL.dup
        # Internal helper — not part of the Python surface; reached via
        # discover_skills / list_all_skill_sources.
        private :builtin_skill_names, :list_skills_full, :env_skill_paths

        # Ensure built-in skills are registered and return their names.
        #
        # Guarantees the built-in skills are registered via
        # {register_builtins!} (idempotent) and returns the registered
        # skill names.
        #
        # @return [Array<String>] currently registered skill names.
        def discover_skills
          register_builtins!
          list_skills
        end

        # List all skill sources and the skills available from each.
        #
        # Returns a hash keyed by source type. The +entry_points+ bucket
        # is always empty; +registered+ holds any skill that isn't a
        # shipped built-in (e.g. registered via {register_skill}).
        # +external_paths+ folds in skill subdirectory names found under
        # any directories passed in.
        #
        # @param external_paths [Array<String>] directories registered via
        #   an instance's #add_skill_directory.
        # @return [Hash{String => Array<String>}]
        def list_all_skill_sources(external_paths: [])
          builtins = builtin_skill_names
          {
            'built-in' => builtins,
            'external_paths' => external_paths.flat_map { |path| skill_dirs_under(path) },
            'entry_points' => [],
            'registered' => list_skills.reject { |name| builtins.include?(name) }
          }
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
          register_builtins! # parity: Python auto-discovers builtins here (idempotent)
          @mutex.synchronize do
            @factories.keys.sort.to_h { |name| [name, skill_schema_entry(name)] }
          end
        end
      end
    end
  end
end
