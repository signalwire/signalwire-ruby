# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# PomBuilder for creating structured POM prompts for SignalWire AI Agents.

require_relative '../pom/prompt_object_model'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Builder class for creating structured prompts using the Prompt Object
    # Model.
    #
    # A flexible wrapper around {SignalWire::POM::PromptObjectModel} that
    # allows for dynamic creation of sections on demand, adding content to
    # existing sections, nesting subsections, and rendering to Markdown or XML.
    #
    # There are no predefined section types -- you can create any section
    # structure that fits your needs. All mutator methods return +self+ for
    # fluent chaining.
    class PomBuilder
      attr_reader :pom

      # Initialize a new POM builder with an empty POM.
      def initialize
        @pom = SignalWire::POM::PromptObjectModel.new
        @sections = {}
      end

      # Add a new section to the POM.
      #
      # +subsections+ is an optional Array of Hash subsection descriptors,
      # each supporting the keys ``'title'``, ``'body'``, and ``'bullets'``.
      #
      # Returns +self+ for method chaining.
      def add_section(title, body: '', bullets: nil, numbered: false, numbered_bullets: false, subsections: nil)
        section = @pom.add_section(title, body: body, bullets: bullets || [],
                                          numbered: numbered, numbered_bullets: numbered_bullets)
        @sections[title] = section

        (subsections || []).each do |subsection_data|
          next unless subsection_data.key?('title')

          section.add_subsection(subsection_data['title'],
                                 body: subsection_data.fetch('body', ''),
                                 bullets: subsection_data['bullets'] || [])
        end

        self
      end

      # Add content to an existing section, creating it if it doesn't exist
      # (auto-vivification).
      #
      # +body+ is appended to any existing body (separated by a blank line),
      # +bullet+ appends a single bullet, and +bullets+ appends an Array of
      # bullets.
      #
      # Returns +self+ for method chaining.
      def add_to_section(title, body: nil, bullet: nil, bullets: nil)
        add_section(title) unless @sections.key?(title)

        section = @sections[title]
        append_body(section, body) if body && !body.empty?
        section.bullets << bullet if bullet
        section.bullets.concat(bullets) if bullets

        self
      end

      # Add a subsection to an existing section, creating the parent if needed
      # (auto-vivification).
      #
      # Returns +self+ for method chaining.
      def add_subsection(parent_title, title, body: '', bullets: nil)
        add_section(parent_title) unless @sections.key?(parent_title)

        parent = @sections[parent_title]
        parent.add_subsection(title, body: body, bullets: bullets || [])
        self
      end

      # Check if a section with the given title exists.
      def has_section(title)
        @sections.key?(title)
      end

      # Get a section by title, or +nil+ if not found.
      def get_section(title)
        @sections[title]
      end

      # Render the POM as Markdown.
      def render_markdown
        @pom.render_markdown
      end

      # Render the POM as XML.
      def render_xml
        @pom.render_xml
      end

      # Convert the POM to an Array of section Hashes.
      def to_dict
        @pom.to_h
      end

      # Convert the POM to a JSON string.
      def to_json(*_args)
        @pom.to_json
      end

      # Create a PomBuilder from an Array of section Hashes.
      def self.from_sections(sections)
        builder = new
        builder.instance_variable_set(:@pom, SignalWire::POM::PromptObjectModel.from_json(sections))
        builder.pom.sections.each do |section|
          builder.send(:register_section, section.title, section) if section.title
        end
        builder
      end

      private

      # @api private — append body text to a section, separating it from existing
      # text with a blank line. An empty existing body is replaced outright.
      def append_body(section, body)
        section.body = if section.body && !section.body.empty?
                         "#{section.body}\n\n#{body}"
                       else
                         body
                       end
      end

      # @api private — index a section by title, so a later append can find it
      # instead of creating a duplicate.
      def register_section(title, section)
        @sections[title] = section
      end
    end
  end
end
