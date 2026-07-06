# frozen_string_literal: true

require 'yaml'
require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # Loads Claude SKILL.md files as agent tools.
      #
      # Mirrors the Python reference (`skills/claude_skills/skill.py`): the
      # `skills_path` load-path is validated (exists + is a directory), then
      # each SUBDIRECTORY containing a `SKILL.md` file is discovered, its YAML
      # frontmatter parsed for `name`/`description`, and one SWAIG tool is
      # registered per discovered skill. A loose `.md` file that is NOT a
      # `SKILL.md` inside a skill directory is ignored.
      class ClaudeSkillsSkill < SkillBase
        def name = 'claude_skills'
        def description = 'Load Claude SKILL.md files as agent tools'
        def supports_multiple_instances? = true

        def setup
          # Load-path validation (Python parity: validate_packages then the
          # skills_path exists/is-a-directory checks).
          return false unless validate_packages

          read_params
          return false unless valid_skills_path?

          @discovered = discover_skills
          true
        end

        def instance_key = "claude_skills_#{@skills_path}"

        def register_tools
          @discovered.map { |skill| skill_tool(skill) }
        end

        def get_hints
          @discovered.flat_map { |s| s[:name].split(/[-_]/) }.uniq
        end

        def get_prompt_sections
          @discovered.map do |skill|
            { 'title' => "Claude Skill: #{skill[:name]}", 'body' => skill[:body][0, 200] }
          end
        end

        def get_parameter_schema
          {
            'skills_path' => { 'type' => 'string', 'required' => true },
            'include' => { 'type' => 'array' },
            'exclude' => { 'type' => 'array' },
            'skill_descriptions' => { 'type' => 'object' },
            'tool_prefix' => { 'type' => 'string', 'default' => 'claude_' }
          }
        end

        private

        # Read the configured params onto instance vars (keeps #setup simple).
        def read_params
          @skills_path  = get_param('skills_path')
          @tool_prefix  = get_param('tool_prefix', default: 'claude_')
          @include      = get_param('include') || ['*'] # glob patterns (default: all)
          @exclude      = get_param('exclude') || []    # glob patterns
          @descriptions = get_param('skill_descriptions') || {}
        end

        # The skills_path must be a non-empty existing directory.
        def valid_skills_path?
          @skills_path && !@skills_path.empty? && File.directory?(@skills_path)
        end

        def skill_tool(skill)
          {
            name: "#{@tool_prefix}#{skill[:safe_name]}",
            description: @descriptions[skill[:name]] || skill[:description] ||
              "Execute Claude skill: #{skill[:name]}",
            parameters: { 'arguments' => { 'type' => 'string', 'description' => 'Arguments for the skill' } },
            handler: lambda { |_args, _raw_data|
              Swaig::FunctionResult.new("Skill #{skill[:name]} instructions:\n\n#{skill[:body]}")
            }
          }
        end

        # Discover skill DIRECTORIES (each containing a SKILL.md), mirroring
        # Python's `_discover_skills`: iterate the immediate subdirectories of
        # skills_path, keep those with a SKILL.md, apply include/exclude
        # patterns against the directory name, and parse the frontmatter.
        def discover_skills
          Dir.children(@skills_path).sort.filter_map do |entry|
            dir = File.join(@skills_path, entry)
            next unless File.directory?(dir)

            skill_file = File.join(dir, 'SKILL.md')
            next unless File.exist?(skill_file)
            next unless matches_patterns?(entry)

            skill_entry(entry, skill_file)
          end
        rescue StandardError => _e
          []
        end

        # Include/exclude glob-pattern gate against a skill directory name,
        # mirroring Python's `_matches_patterns` (excludes win, then includes).
        def matches_patterns?(dir_name)
          return false if @exclude.any? { |pat| File.fnmatch(pat, dir_name) }

          @include.any? { |pat| File.fnmatch(pat, dir_name) }
        end

        # Build a skill entry from a SKILL.md, parsing YAML frontmatter for
        # name/description and falling back to the directory name. Mirrors
        # Python's `_parse_skill_md` name-fallback behavior.
        def skill_entry(dir_name, skill_file)
          front, body = parse_skill_md(skill_file)
          skill_name  = front['name'] || dir_name
          {
            name: skill_name,
            description: front['description'],
            safe_name: skill_name.gsub(/[^a-zA-Z0-9_]/, '_').downcase,
            body: body,
            path: skill_file
          }
        end

        # Split a SKILL.md into (frontmatter_hash, body). No frontmatter =>
        # ({}, whole content). Mirrors Python's `---`-delimited split.
        def parse_skill_md(path)
          content = File.read(path, encoding: 'UTF-8')
          return [{}, content.strip] unless content.start_with?('---')

          parts = content.split('---', 3)
          return [{}, content.strip] if parts.length < 3

          front = begin
            YAML.safe_load(parts[1]) || {}
          rescue Psych::SyntaxError
            {}
          end
          [front.is_a?(Hash) ? front : {}, parts[2].strip]
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('claude_skills') do |params|
  SignalWire::Skills::Builtin::ClaudeSkillsSkill.new(params)
end
