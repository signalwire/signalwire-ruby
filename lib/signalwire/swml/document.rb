# frozen_string_literal: true

require 'json'

module SignalWire
  module SWML
    class Document
      attr_reader :version, :sections

      def initialize
        @version = '1.0.0'
        @sections = { 'main' => [] }
        @mutex = Mutex.new
      end

      # Reset the document to its initial empty state.
      def reset
        @mutex.synchronize do
          @sections = { 'main' => [] }
        end
      end

      # Add a new named section. Returns true if created, false if it already exists.
      def add_section(name)
        name = name.to_s
        @mutex.synchronize do
          return false if @sections.key?(name)

          @sections[name] = []
          true
        end
      end

      # Check whether a section exists.
      def has_section?(name)
        @sections.key?(name.to_s)
      end

      # Append a verb to the *main* section.
      #
      #   add_verb('answer', {})
      #   add_verb('sleep', 2000)
      def add_verb(verb_name, config)
        add_verb_to_section('main', verb_name, config)
      end

      # Append a verb to an arbitrary section.
      def add_verb_to_section(section, verb_name, config)
        section = section.to_s
        @mutex.synchronize do
          unless @sections.key?(section)
            raise ArgumentError, "Section '#{section}' does not exist"
          end

          @sections[section] << { verb_name.to_s => config }
          true
        end
      end

      # Return the list of verb hashes for a section.
      def get_verbs(section = 'main')
        @sections.fetch(section.to_s, []).dup
      end

      # Produce a plain Ruby hash suitable for JSON serialization.
      def to_h
        {
          'version' => @version,
          'sections' => @sections.transform_values(&:dup)
        }
      end

      # Compact JSON string.
      def render
        JSON.generate(to_h)
      end

      # Pretty-printed JSON string.
      def render_pretty
        JSON.pretty_generate(to_h)
      end
    end
  end
end
