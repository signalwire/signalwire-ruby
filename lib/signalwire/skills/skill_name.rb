# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

module SignalWire
  module Skills
    # Named constants for the skills that ship built in with this gem.
    #
    # Skill names are an open *string* set — +add_skill+ takes a bare
    # +str+, which lets callers load custom / third-party skills.
    # {SkillName} gives the built-in skills a named alternative so a typo —
    # +add_skill("datetiem")+ — has a canonical constant to reach for
    # instead, while the string path stays available for custom skills.
    #
    # Each constant's value IS the snake_case wire name the
    # {SkillRegistry} is keyed by (the same string a skill reports from its
    # +#name+), so these are interchangeable:
    #
    #   agent.add_skill(SignalWire::Skills::SkillName::DATETIME) # named
    #   agent.add_skill("datetime")                              # string
    #   agent.add_skill("my_custom_skill")                       # open set: custom ok
    #
    # Single source of truth: {ALL} is exactly the set the registry
    # registers and that +AgentBase#add_skill+ validates against
    # (+SkillRegistry.builtin_skill_names+ is derived from {ALL}). The
    # spec proves the two never drift.
    #
    # Idiom note: mirrors +SignalWire::Relay+'s constants module — flat
    # +NAME = 'value'+ string constants grouped into a frozen +ALL+ array.
    module SkillName
      API_NINJAS_TRIVIA     = 'api_ninjas_trivia'
      CLAUDE_SKILLS         = 'claude_skills'
      CUSTOM_SKILLS         = 'custom_skills'
      DATASPHERE            = 'datasphere'
      DATASPHERE_SERVERLESS = 'datasphere_serverless'
      DATETIME              = 'datetime'
      GOOGLE_MAPS           = 'google_maps'
      INFO_GATHERER         = 'info_gatherer'
      JOKE                  = 'joke'
      MATH                  = 'math'
      NATIVE_VECTOR_SEARCH  = 'native_vector_search'
      PLAY_BACKGROUND_FILE  = 'play_background_file'
      SPIDER                = 'spider'
      SWML_TRANSFER         = 'swml_transfer'
      WEATHER_API           = 'weather_api'
      WEB_SEARCH            = 'web_search'
      WIKIPEDIA_SEARCH      = 'wikipedia_search'

      # Every built-in skill name, sorted to match
      # +SkillRegistry.builtin_skill_names+ (which sorts the +builtin/+
      # directory listing). This is the single source of truth for the
      # built-in set.
      ALL = [
        API_NINJAS_TRIVIA,
        CLAUDE_SKILLS,
        CUSTOM_SKILLS,
        DATASPHERE,
        DATASPHERE_SERVERLESS,
        DATETIME,
        GOOGLE_MAPS,
        INFO_GATHERER,
        JOKE,
        MATH,
        NATIVE_VECTOR_SEARCH,
        PLAY_BACKGROUND_FILE,
        SPIDER,
        SWML_TRANSFER,
        WEATHER_API,
        WEB_SEARCH,
        WIKIPEDIA_SEARCH
      ].freeze

      # @param name [String] a candidate skill name
      # @return [Boolean] true when +name+ is one of the built-in skills.
      #   Custom / third-party skill names return false (the set is open).
      def self.builtin?(name)
        ALL.include?(name)
      end
    end
  end
end
