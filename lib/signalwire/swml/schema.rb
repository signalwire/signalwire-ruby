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

        defs = JSON.parse(File.read(schema_path))['$defs'] || {}
        any_of = (defs['SWMLMethod'] || {})['anyOf'] || []

        any_of.each { |entry| register_verb(defs, entry) }
      end

      # Register one verb from an SWMLMethod anyOf $ref entry, skipping
      # entries with no resolvable definition or no properties.
      def register_verb(defs, entry)
        return unless (ref = entry['$ref'])

        # e.g. "#/$defs/Answer" -> "Answer"
        def_name = ref.split('/').last
        defn = defs[def_name]
        props = defn && defn['properties']
        return if props.nil? || props.empty?

        # The first property key is the actual verb name (e.g. "answer", "ai")
        actual_verb = props.keys.first
        @verbs[actual_verb] = { 'name' => actual_verb, 'schema_name' => def_name, 'definition' => defn }
      end
    end

    # Module-level singleton so the schema is loaded at most once.
    def self.schema
      return @schema if defined?(@schema)

      @schema = Schema.new
    end

    # Allow resetting for tests
    def self.reset_schema!
      @schema = nil
    end

    # Normalize a vivified verb's positional args + kwargs into its config Hash
    # (string-keyed). This is the strict-render contract for the auto-vivified
    # (method_missing / __getattr__-analog) verb path, shared by SWMLService and
    # SWMLBuilder so both behave identically:
    #
    #   verb(k: v)                 -> {"k" => v}          (kwargs)
    #   verb({"k" => v})           -> {"k" => v}          (a single positional
    #                                                      Hash — the SDK's own
    #                                                      documented string-key
    #                                                      hash style)
    #   verb({"k" => v}, k2: w)    -> {"k" => v, "k2" => w}  (merge; kwargs win)
    #   verb("x")   / verb(h1, h2) -> ArgumentError        (misshapen — RAISE,
    #                                                      never a silent {})
    #
    # Silently dropping a positional Hash (the previous behavior) produced an
    # empty verb — e.g. `svc.play({'url'=>...})` rendered `{"play":{}}` with no
    # warning (ruby_R5 N2). A misshapen call now fails loudly instead.
    # Underscore-prefixed: an internal helper shared by SWMLService + SWMLBuilder,
    # not part of the public reference surface (the enumerator skips single-`_`
    # names).
    def self._verb_config(verb_name, args, kwargs)
      kw = kwargs.transform_keys(&:to_s)
      positional = _positional_config!(verb_name, args)
      # positional Hash is the base; kwargs override on a key collision.
      positional.merge(kw).compact
    end

    # The config Hash from a vivified verb's positional args (empty when none).
    # Accepts exactly zero or one positional, and it must be a Hash — anything
    # else RAISES (never a silent empty verb). Internal (see _verb_config).
    def self._positional_config!(verb_name, args)
      return {} if args.nil? || args.empty?

      unless args.length == 1 && args.first.is_a?(Hash)
        raise ArgumentError,
              "#{verb_name}: expected keyword args or a single config Hash, " \
              "got #{args.length} positional argument(s) " \
              "(#{args.map { |a| a.class.name }.join(', ')})"
      end

      args.first.transform_keys(&:to_s)
    end
  end
end
