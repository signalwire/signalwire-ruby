# frozen_string_literal: true

require 'json'

module SignalWire
  module Relay
    # A typed RELAY +collect+ configuration: the known-shape options object the
    # input-collection wrappers ({Call#collect}, {Call#play_and_collect},
    # {Call#prompt_tts}, {Call#prompt_audio}) currently take as a raw Hash and
    # pass through verbatim onto the +calling.collect+ /
    # +calling.play_and_collect+ wire frame.
    #
    # The shape is fully grounded in
    # +porting-sdk/relay-protocol/calling.collect.params.json+: a +digits+
    # sub-object (+max+, +min+, +digit_timeout+, +terminators+), a +speech+
    # sub-object (+end_silence_timeout+, +hints+, +language+, +model+,
    # +speech_timeout+), and top-level toggles (+initial_timeout+,
    # +partial_results+, +continuous+, +send_start_of_input+,
    # +start_input_timers+). +CollectConfig+ types that shape so callers stop
    # hand-building nested Hashes.
    #
    # **No closed-set enum is folded in here:** the collect shape carries *no*
    # schema-enumerated value sets — +terminators+ is a free DTMF string,
    # +language+/+model+ are open vocabularies (ASR language tags / model
    # names). Inventing an enum would contradict the wire contract. (This is
    # why ruby's named Tier-3 collect item types only the *shape*; the Tier-1
    # enum integration lives in the record/tap/SWAIG items, where the sets
    # genuinely *are* closed.)
    #
    # This is **additive**: every wrapper still accepts a raw Hash. A
    # +CollectConfig+ yields the *identical* wire Hash via {#to_h} (string
    # keys, only the provided fields present — unset optionals are omitted, so
    # the frame is byte identical to the hand-built literal the wrapper tests
    # assert).
    #
    # Idiomatic Ruby value object, consistent with the Wave-A relay-event
    # idioms: Ruby 3.0 pattern matching (+#deconstruct_keys+), value
    # +#==+/+#eql?+/+#hash+, and +#to_h+/+#to_json+ projections.
    #
    # @example Collect 4 DTMF digits terminated by '#'
    #   cfg = SignalWire::Relay::CollectConfig.new(
    #     digits: { max: 4, terminators: "#" }, initial_timeout: 5.0
    #   )
    #   call.collect(cfg.to_h)
    #
    # @example Speech collection
    #   cfg = SignalWire::Relay::CollectConfig.new(
    #     speech: { end_silence_timeout: 1.0, language: "en-US" }
    #   )
    #   call.prompt_tts("Say something", cfg.to_h)
    class CollectConfig
      # @return [Hash, nil] the +digits+ sub-config, or nil.
      attr_reader :digits

      # @return [Hash, nil] the +speech+ sub-config, or nil.
      attr_reader :speech

      # @return [Numeric, nil]
      attr_reader :initial_timeout, :partial_results, :continuous,
                  :send_start_of_input, :start_input_timers

      # @param digits [Hash, nil] DTMF options: +max+ (required when present),
      #   +min+, +digit_timeout+, +terminators+. Keys may be symbols.
      # @param speech [Hash, nil] ASR options: +end_silence_timeout+, +hints+,
      #   +language+, +model+, +speech_timeout+. Keys may be symbols.
      # @param initial_timeout [Numeric, nil] seconds to wait for first input.
      # @param partial_results [Boolean, nil] emit interim results.
      # @param continuous [Boolean, nil] keep collecting after a result.
      # @param send_start_of_input [Boolean, nil] emit a start-of-input event.
      # @param start_input_timers [Boolean, nil] start input timers immediately.
      def initialize(digits: nil, speech: nil, initial_timeout: nil,
                     partial_results: nil, continuous: nil,
                     send_start_of_input: nil, start_input_timers: nil)
        @digits              = digits
        @speech              = speech
        @initial_timeout     = initial_timeout
        @partial_results     = partial_results
        @continuous          = continuous
        @send_start_of_input = send_start_of_input
        @start_input_timers  = start_input_timers
      end

      # The wire Hash, string-keyed, with **only the provided fields present**
      # (unset optionals omitted). +digits+/+speech+ sub-Hashes are
      # key-stringified one level deep. Byte identical to the collect literal a
      # caller would hand-write and the wrapper tests assert on the journal.
      #
      # @return [Hash{String => Object}]
      def to_h
        out = {}
        out['digits']              = stringify(@digits) unless @digits.nil?
        out['speech']              = stringify(@speech) unless @speech.nil?
        out['initial_timeout']     = @initial_timeout unless @initial_timeout.nil?
        out['partial_results']     = @partial_results unless @partial_results.nil?
        out['continuous']          = @continuous unless @continuous.nil?
        out['send_start_of_input'] = @send_start_of_input unless @send_start_of_input.nil?
        out['start_input_timers']  = @start_input_timers unless @start_input_timers.nil?
        out
      end

      # @return [String] JSON serialization of {#to_h}.
      def to_json(*)
        to_h.to_json(*)
      end

      # Ruby 3.0 hash pattern-matching hook. Returns symbol-keyed config with
      # only the *set* fields (mirroring {#to_h}'s omit-when-nil contract); a
      # subset of +keys+ returns only those that are both requested and set.
      #
      # @param keys [Array<Symbol>, nil]
      # @return [Hash{Symbol => Object}]
      def deconstruct_keys(keys)
        h = {}
        h[:digits]              = @digits unless @digits.nil?
        h[:speech]              = @speech unless @speech.nil?
        h[:initial_timeout]     = @initial_timeout unless @initial_timeout.nil?
        h[:partial_results]     = @partial_results unless @partial_results.nil?
        h[:continuous]          = @continuous unless @continuous.nil?
        h[:send_start_of_input] = @send_start_of_input unless @send_start_of_input.nil?
        h[:start_input_timers]  = @start_input_timers unless @start_input_timers.nil?
        return h if keys.nil?

        keys.each_with_object({}) { |k, acc| acc[k] = h[k] if h.key?(k) }
      end

      # Value equality: same projected wire shape.
      def ==(other)
        other.is_a?(CollectConfig) && other.to_h == to_h
      end
      alias eql? ==

      # Hash key parity with {#==}.
      def hash
        [self.class, to_h].hash
      end

      def to_s
        "CollectConfig(#{to_h.inspect})"
      end
      alias inspect to_s

      private

      def stringify(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end
    end
  end
end
