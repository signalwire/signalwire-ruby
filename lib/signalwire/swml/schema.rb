# frozen_string_literal: true

require 'json'

module SignalWire
  module SWML
    class Schema
      attr_reader :verbs

      def initialize
        @verbs = {}
        load_schema
      end

      # Is +name+ a recognised SWML verb?
      def valid_verb?(name)
        @verbs.key?(name.to_s)
      end

      # Sorted list of all known verb names.
      def verb_names
        @verbs.keys.sort
      end

      # How many verbs are defined in the schema.
      def verb_count
        @verbs.size
      end

      # Return the full definition hash for a verb, or nil.
      def get_verb(name)
        @verbs[name.to_s]
      end

      private

      def load_schema
        schema_path = File.join(__dir__, 'schema.json')
        raise "SWML schema.json not found at #{schema_path}" unless File.exist?(schema_path)

        raw = JSON.parse(File.read(schema_path))
        defs = raw['$defs'] || {}
        swml_method = defs['SWMLMethod'] || {}
        any_of = swml_method['anyOf'] || []

        any_of.each do |entry|
          ref = entry['$ref']
          next unless ref

          # e.g. "#/$defs/Answer" -> "Answer"
          def_name = ref.split('/').last
          defn = defs[def_name]
          next unless defn

          props = defn['properties']
          next unless props && !props.empty?

          # The first property key is the actual verb name (e.g. "answer", "ai")
          actual_verb = props.keys.first
          @verbs[actual_verb] = {
            'name' => actual_verb,
            'schema_name' => def_name,
            'definition' => defn
          }
        end
      end
    end

    # Module-level singleton so the schema is loaded at most once.
    def self.schema
      @schema ||= Schema.new
    end

    # Allow resetting for tests
    def self.reset_schema!
      @schema = nil
    end
  end
end
