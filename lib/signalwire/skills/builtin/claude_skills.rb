# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # Loads Claude SKILL.md files as agent tools.
      class ClaudeSkillsSkill < SkillBase
        def name = 'claude_skills'
        def description = 'Load Claude SKILL.md files as agent tools'
        def supports_multiple_instances? = true

        def setup
          @skills_path  = get_param('skills_path')
          @tool_prefix  = get_param('tool_prefix', default: 'claude_')
          @include      = get_param('include')  # glob patterns
          @exclude      = get_param('exclude')  # glob patterns
          @descriptions = get_param('skill_descriptions') || {}

          return false unless @skills_path && !@skills_path.empty?
          return false unless File.directory?(@skills_path)

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
            { 'title' => "Claude Skill: #{skill[:name]}", 'body' => skill[:content][0, 200] }
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

        def skill_tool(skill)
          {
            name: "#{@tool_prefix}#{skill[:safe_name]}",
            description: @descriptions[skill[:name]] || "Execute Claude skill: #{skill[:name]}",
            parameters: {
              'arguments' => { 'type' => 'string', 'description' => 'Arguments for the skill' }
            },
            handler: lambda { |_args, _raw_data|
              Swaig::FunctionResult.new("Skill #{skill[:name]} instructions:\n\n#{skill[:content]}")
            }
          }
        end

        def discover_skills
          md_files = Dir.glob(File.join(@skills_path, '**', '*.md'))

          md_files.filter_map { |path| skill_entry(path) }
        rescue StandardError => _e
          []
        end

        # Build a skill entry hash for +path+, or nil if filtered out.
        def skill_entry(path)
          rel = path.sub("#{@skills_path}/", '')
          return nil if @include&.none? { |pat| File.fnmatch(pat, rel) }
          return nil if @exclude&.any? { |pat| File.fnmatch(pat, rel) }

          file_name = File.basename(path, '.md')
          { name: file_name,
            safe_name: file_name.gsub(/[^a-zA-Z0-9_]/, '_').downcase,
            content: File.read(path, encoding: 'UTF-8'),
            path: path }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('claude_skills') do |params|
  SignalWire::Skills::Builtin::ClaudeSkillsSkill.new(params)
end
