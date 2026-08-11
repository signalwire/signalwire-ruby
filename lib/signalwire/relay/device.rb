# frozen_string_literal: true

require 'json'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Relay — the RELAY realtime (WebSocket / JSON-RPC 2.0) client surface.
  module Relay
    # A typed RELAY +device+ descriptor: the +{ "type" => ..., "params" => {...} }+
    # object handed to {Call#connect}, {Call#refer}, {Call#tap_audio}, and
    # {Client#dial} (where it nests inside the +devices+ list-of-lists).
    #
    # Across the relay layer this is the single highest-traffic untyped blob:
    # a phone/sip/agora device is hand-built as a raw Hash at every call site.
    # +Device+ types the *shape* — a +type+ discriminant plus a free-form
    # +params+ map — while leaving +type+ a String, because the discriminant
    # ("phone", "sip", "agora", …) is **not** schema-enumerated in the
    # +calling.connect+/+refer+/+dial+/+tap+ RELAY parameters
    # (each declares +type+ as a bare +"string"+). Typing it as an enum would
    # invent a closed set the wire contract does not promise.
    #
    # This is **additive**: every relay method still accepts a raw Hash. A
    # +Device+ is a convenience that yields the *identical* wire Hash via
    # {#to_h}, so callers can build one and pass +device.to_h+ (or pass the
    # +Device+ where a +#to_h+-coercible value is expected). The wire shape is
    # +{ "type" => <type>, "params" => <params> }+ with **string** keys, byte
    # identical to the hand-written literal.
    #
    # Idiomatic Ruby value object, consistent with the Wave-A relay-event
    # idioms ({RelayEvent}): Ruby 3.0 pattern matching
    # (+#deconstruct_keys+/+#deconstruct+), value +#==+/+#eql?+/+#hash+ so two
    # devices carrying the same data are interchangeable Set members / Hash
    # keys, plus +#to_h+/+#to_json+ projections.
    #
    # @example Build a phone device and dial it
    #   dev = SignalWire::Relay::Device.phone(to: "+15551112222", from: "+15553334444")
    #   client.dial([[dev.to_h]], tag: "t1")
    #
    # @example Pattern-match on a device
    #   case dev
    #   in { type: "phone", params: { to_number: } }
    #     puts "dialing #{to_number}"
    #   end
    class Device
      # @return [String] the device discriminant ("phone", "sip", "agora", …);
      #   a free String, not a closed enum (the wire contract does not promise
      #   a fixed set).
      attr_reader :type

      # @return [Hash] the device-specific parameters (string-keyed on the wire).
      attr_reader :params

      # @param type [String, Symbol] the device discriminant.
      # @param params [Hash] device-specific parameters. Keys are stringified
      #   for the wire on {#to_h} so callers may pass symbol keys ergonomically.
      def initialize(type, params = {})
        @type   = type.to_s
        @params = params || {}
      end

      # Build a +phone+ device. Convenience over +new("phone", …)+ that builds
      # the canonical +{ to_number:, from_number:, timeout? }+ params, omitting
      # +timeout+ when unset (so the wire shape matches a hand-built literal).
      #
      # @param to [String] the destination number (+to_number+ on the wire).
      # @param from [String, nil] the caller-id number (+from_number+); omitted when nil.
      # @param timeout [Numeric, nil] ring timeout in seconds; omitted when nil.
      # @return [Device]
      def self.phone(to:, from: nil, timeout: nil)
        params = { 'to_number' => to }
        params['from_number'] = from unless from.nil?
        params['timeout']     = timeout unless timeout.nil?
        new('phone', params)
      end

      # Build a +sip+ device. Convenience over +new("sip", …)+.
      #
      # @param to [String] the destination SIP URI (+to+ on the wire).
      # @param from [String, nil] the originating SIP URI (+from+); omitted when nil.
      # @param headers [Hash, nil] custom SIP headers; omitted when nil.
      # @return [Device]
      def self.sip(to:, from: nil, headers: nil)
        params = { 'to' => to }
        params['from']    = from unless from.nil?
        params['headers'] = headers unless headers.nil?
        new('sip', params)
      end

      # The wire Hash: +{ "type" => <type>, "params" => <params> }+ with string
      # keys, byte identical to the hand-written device literal. Symbol keys in
      # +params+ are stringified (one level) so a +Device+ built with symbol
      # params still serializes the wire spelling.
      #
      # @return [Hash{String => Object}]
      def to_h
        { 'type' => @type, 'params' => stringify(@params) }
      end

      # @return [String] JSON serialization of {#to_h}.
      def to_json(*)
        to_h.to_json(*)
      end

      # Ruby 3.0 hash pattern-matching hook, e.g.
      # +in { type: "phone", params: }+. Returns symbol-keyed +{ type:, params: }+
      # (idiomatic for Ruby pattern matching); when the matcher requests a
      # subset of +keys+, only those are returned.
      #
      # @param keys [Array<Symbol>, nil]
      # @return [Hash{Symbol => Object}]
      def deconstruct_keys(keys)
        h = { type: @type, params: @params }
        return h if keys.nil?

        keys.each_with_object({}) { |k, acc| acc[k] = h[k] if h.key?(k) }
      end

      # Ruby 3.0 array pattern-matching hook, e.g. +in [type, params]+.
      #
      # @return [Array(String, Hash)]
      def deconstruct
        [@type, @params]
      end

      # Value equality: same +type+ and same +params+.
      def ==(other)
        other.is_a?(Device) && other.type == @type && other.params == @params
      end
      alias eql? ==

      # Hash key consistent with {#==}: equal devices share a hash bucket.
      def hash
        [self.class, @type, @params].hash
      end

      # A human-readable summary: the device type and its params.
      #
      # @return [String]
      def to_s
        "Device(type=#{@type}, params=#{@params.inspect})"
      end
      alias inspect to_s

      private

      # Stringify Hash keys one level deep (matching the wire frame's
      # string-keyed top level; nested values pass through unchanged so already
      # string-keyed nested maps stay byte identical).
      def stringify(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end
    end
  end
end
