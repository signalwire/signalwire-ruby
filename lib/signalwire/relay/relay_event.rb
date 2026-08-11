# frozen_string_literal: true

require 'json'
require_relative 'constants'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Relay — the RELAY realtime (WebSocket / JSON-RPC 2.0) client surface.
  module Relay
    # Base event wrapper for raw signalwire.event payloads.
    # Subclasses provide typed accessors for specific event types.
    #
    # Idiomatic Ruby surface (defined once here, inherited by every typed
    # subclass so the cross-language audit only counts it on the base):
    #
    #   * +#to_h+ / +#to_json+ — a clean, semantic Hash/JSON view of the
    #     event (the common +event_type+/+call_id+/+timestamp+ fields plus
    #     whatever typed fields the subclass declares).
    #   * +#deconstruct_keys+ / +#deconstruct+ — Ruby 3.0 pattern matching,
    #     so callers can write
    #         case event
    #         in { event_type: "calling.call.state", call_state: }
    #           ...
    #         end
    #   * value +#==+ / +#eql?+ / +#hash+ — two events carrying the same
    #     semantic data compare equal and hash equal, so events work as
    #     Set members and Hash keys.
    #
    # Subclasses contribute their typed fields by overriding the private
    # +#event_fields+ hook (underscore-prefixed, so it stays off the
    # public surface); they never redefine +#to_h+/+#==+/etc. themselves.
    class RelayEvent
      attr_reader :event_type, :params, :call_id, :timestamp

      # Build an event from already-decoded envelope fields. Subclasses forward
      # these through +**base+ after decoding their own typed fields.
      #
      # @param event_type [String] the RELAY `event_type` string, e.g. `"calling.call.state"`
      # @param params [Hash] the raw `params` map from the wire frame, kept verbatim
      # @param call_id [String] the call this event belongs to (`params['call_id']`), '' when absent
      # @param timestamp [Float] the server-side event time (`params['timestamp']`), 0.0 when absent
      def initialize(event_type:, params: {}, call_id: '', timestamp: 0.0)
        @event_type = event_type
        @params     = params
        @call_id    = call_id
        @timestamp  = timestamp
      end

      # Decode a raw `signalwire.event` payload into a bare {RelayEvent}, reading
      # `event_type` from the frame and `call_id`/`timestamp` out of its `params`.
      # Absent fields fall back to the empty/zero default rather than nil.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [RelayEvent]
      def self.from_payload(payload)
        et = payload['event_type'] || ''
        p  = payload['params'] || {}
        new(
          event_type: et,
          params: p,
          call_id: p['call_id'] || '',
          timestamp: p['timestamp'] || 0.0
        )
      end

      # @api private — the shared envelope kwargs a subclass forwards to +new+
      # from the base event decoded by {RelayEvent.from_payload}.
      def self._base_kwargs(base)
        { event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp }
      end
      private_class_method :_base_kwargs

      # @api private — +params[key] || default+. Keeps the nil-coalescing out
      # of subclass +from_payload+ bodies (one call, no branch in the caller).
      def self._fetch(params, key, default)
        params[key] || default
      end
      private_class_method :_fetch

      # @api private — build typed kwargs from a +{ sym_field => default }+
      # table, reading +params[field.to_s]+ with the table's default. Keeps
      # subclass +from_payload+ bodies short and branch-free.
      def self._typed_from(params, fields)
        fields.each_with_object({}) do |(field, default), kwargs|
          kwargs[field] = _fetch(params, field.to_s, default)
        end
      end
      private_class_method :_typed_from

      # Semantic Hash view: the shared envelope fields plus the subclass's
      # typed fields. Raw +params+ are intentionally excluded — +#to_h+ is
      # the friendly, typed projection, not the wire frame (which stays
      # available via +#params+). Keys are symbols, idiomatic for Ruby.
      #
      # @return [Hash{Symbol => Object}]
      def to_h
        {
          event_type: @event_type,
          call_id: @call_id,
          timestamp: @timestamp
        }.merge(event_fields)
      end

      # @return [String] JSON serialization of {#to_h}.
      def to_json(*)
        to_h.to_json(*)
      end

      # Ruby 3.0 pattern-matching hook for +in { key: }+ / +in { key: }+.
      # Returns the same Symbol-keyed map as {#to_h}. When the matcher
      # requests a specific subset of +keys+, only those are computed/returned
      # (the contract +deconstruct_keys+ promises the pattern matcher).
      #
      # @param keys [Array<Symbol>, nil] keys the pattern is matching, or nil
      # @return [Hash{Symbol => Object}]
      def deconstruct_keys(keys)
        h = to_h
        return h if keys.nil?

        keys.each_with_object({}) do |k, acc|
          acc[k] = h[k] if h.key?(k)
        end
      end

      # Ruby 3.0 array pattern-matching hook for +in [a, b, c]+. The stable,
      # cross-event positional triple is the envelope: event type, call id,
      # timestamp.
      #
      # @return [Array]
      def deconstruct
        [@event_type, @call_id, @timestamp]
      end

      # Value equality: same concrete class carrying the same semantic data.
      # Exact-class (not +is_a?+) so a typed event never equals a bare
      # +RelayEvent+ that happens to share the envelope.
      def ==(other)
        other.class == self.class && other.to_h == to_h
      end
      alias eql? ==

      # Hash key consistent with {#==}: equal events share a hash bucket, so
      # they behave correctly as Set members and Hash keys.
      def hash
        [self.class, to_h].hash
      end

      private

      # @api private — set @<key> = value for each kwarg, so wide-field
      # subclasses keep their full +initialize+ signature without a long
      # assignment body. Keys must match the subclass's +attr_reader+ names.
      def assign_fields(**fields)
        fields.each { |key, value| instance_variable_set("@#{key}", value) }
      end

      # Typed fields contributed by a subclass to {#to_h} / pattern matching.
      # The base event has none beyond the shared envelope.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        {}
      end
    end

    # calling.call.state
    class CallStateEvent < RelayEvent
      attr_reader :call_state, :end_reason, :direction, :device

      # Decode a `calling.call.state` frame into a {CallStateEvent}, reading the call state, end reason, direction and
      # device
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [CallStateEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          call_state: p['call_state'] || '',
          end_reason: p['end_reason'] || '',
          direction: p['direction'] || '',
          device: p['device'] || {}
        )
      end

      # @param call_state [String] the new call state (see {CallState}); '' when absent
      # @param end_reason [String] why the call ended, set on the terminal transition; '' otherwise
      # @param direction [String] `"inbound"` or `"outbound"` as reported by the server
      # @param device [Hash] the raw device descriptor (`type` plus its per-type params)
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(call_state: '', end_reason: '', direction: '', device: {}, **base)
        super(**base)
        @call_state = call_state
        @end_reason = end_reason
        @direction  = direction
        @device     = device
      end

      # Typed predicate over {#call_state}, alongside the bare string.
      # Agrees with {CallState.terminal?} — true exactly when the call has
      # ended ({CallState::ENDED}).
      #
      # @return [Boolean]
      def terminal?
        CallState.terminal?(@call_state)
      end

      private

      # The `calling.call.state` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { call_state: @call_state, end_reason: @end_reason,
          direction: @direction, device: @device }
      end
    end

    # calling.call.receive
    class CallReceiveEvent < RelayEvent
      attr_reader :call_state, :direction, :device, :node_id, :project_id,
                  :context, :segment_id, :tag

      TYPED_FIELDS = {
        call_state: '', direction: '', device: {}, node_id: '',
        project_id: '', segment_id: '', tag: ''
      }.freeze

      # Decode a `calling.call.receive` frame into a {CallReceiveEvent}, reading the call state, direction, device and
      # routing identifiers
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [CallReceiveEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(**_base_kwargs(base), **_typed_from(p, TYPED_FIELDS),
            context: _fetch(p, 'context', _fetch(p, 'protocol', '')))
      end

      # @param call_state [String] the state the inbound call arrived in (see {CallState})
      # @param direction [String] `"inbound"` or `"outbound"`
      # @param device [Hash] the raw device descriptor for the leg
      # @param node_id [String] the RELAY node that owns this call; needed to address it
      # @param project_id [String] the SignalWire project the call belongs to
      # @param context [String] the context the call was received on — decoded from
      #   `params['context']`, falling back to the legacy `params['protocol']` key
      # @param segment_id [String] the call-segment identifier
      # @param tag [String] the caller-supplied correlation tag, when one was set
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(call_state: '', direction: '', device: {}, node_id: '',
                     project_id: '', context: '', segment_id: '', tag: '', **base)
        super(**base)
        @call_state = call_state
        @direction  = direction
        @device     = device
        @node_id    = node_id
        @project_id = project_id
        @context    = context
        @segment_id = segment_id
        @tag        = tag
      end

      private

      # The `calling.call.receive` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { call_state: @call_state, direction: @direction, device: @device,
          node_id: @node_id, project_id: @project_id, context: @context,
          segment_id: @segment_id, tag: @tag }
      end
    end

    # calling.call.play
    class PlayEvent < RelayEvent
      attr_reader :control_id, :state

      # Decode a `calling.call.play` frame into a {PlayEvent}, reading the playback control id and state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [PlayEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      # @param control_id [String] identifies the playback this event reports on
      # @param state [String] the playback state, e.g. `"playing"` / `"finished"`
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      # The `calling.call.play` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.record
    class RecordEvent < RelayEvent
      attr_reader :control_id, :state, :url, :duration, :size, :record

      # Decode a `calling.call.record` frame into a {RecordEvent}. The recording's
      # `url`, `duration` and `size` are read from the nested `params['record']`
      # object when present, falling back to the same keys at the top level (the
      # server has emitted both shapes).
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [RecordEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        rec = p['record'] || {}
        new(
          **_base_kwargs(base),
          control_id: _fetch(p, 'control_id', ''), state: _fetch(p, 'state', ''),
          url: _fetch(rec, 'url', _fetch(p, 'url', '')),
          duration: _fetch(rec, 'duration', _fetch(p, 'duration', 0.0)),
          size: _fetch(rec, 'size', _fetch(p, 'size', 0)), record: rec
        )
      end

      # @param control_id [String] identifies the recording this event reports on
      # @param state [String] the recording state, e.g. `"recording"` / `"finished"`
      # @param url [String] where the finished recording can be fetched
      # @param duration [Float] recording length in seconds
      # @param size [Integer] recording size in bytes
      # @param record [Hash] the raw nested `record` object, kept verbatim
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', url: '', duration: 0.0, size: 0, record: {}, **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @url        = url
        @duration   = duration
        @size       = size
        @record     = record
      end

      private

      # The `calling.call.record` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state, url: @url,
          duration: @duration, size: @size, record: @record }
      end
    end

    # calling.call.collect
    class CollectEvent < RelayEvent
      # The decoded field is +result+ (formerly +result_data+).
      attr_reader :control_id, :state, :result, :final

      # Decode a `calling.call.collect` frame into a {CollectEvent}, reading the collect control id, state and result
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [CollectEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || '',
          result: p['result'] || {},
          final: p['final']
        )
      end

      # @param control_id [String] identifies the collect this event reports on
      # @param state [String] the collect state, e.g. `"collecting"` / `"finished"`
      # @param result [Hash] the collected result object (type plus its digits/speech payload)
      # @param final [Boolean, nil] whether this is the last result for the collect;
      #   nil when the server did not send the field
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', result: {}, final: nil, **base)
        super(**base)
        @control_id  = control_id
        @state       = state
        @result      = result
        @final       = final
      end

      private

      # The `calling.call.collect` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state,
          result: @result, final: @final }
      end
    end

    # calling.call.connect
    class ConnectEvent < RelayEvent
      attr_reader :connect_state, :peer

      # Decode a `calling.call.connect` frame into a {ConnectEvent}, reading the connect state and peer descriptor
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [ConnectEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          connect_state: p['connect_state'] || '',
          peer: p['peer'] || {}
        )
      end

      # @param connect_state [String] the connect state, e.g. `"connecting"` / `"connected"` / `"failed"`
      # @param peer [Hash] the raw peer descriptor (the far leg's call/node identifiers)
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(connect_state: '', peer: {}, **base)
        super(**base)
        @connect_state = connect_state
        @peer          = peer
      end

      private

      # The `calling.call.connect` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { connect_state: @connect_state, peer: @peer }
      end
    end

    # calling.call.detect
    class DetectEvent < RelayEvent
      attr_reader :control_id, :detect

      # Decode a `calling.call.detect` frame into a {DetectEvent}, reading the detect control id and detector result
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [DetectEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          detect: p['detect'] || {}
        )
      end

      # @param control_id [String] identifies the detect this event reports on
      # @param detect [Hash] the raw detector result (`type` plus its per-detector params)
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', detect: {}, **base)
        super(**base)
        @control_id = control_id
        @detect     = detect
      end

      private

      # The `calling.call.detect` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, detect: @detect }
      end
    end

    # calling.call.fax
    class FaxEvent < RelayEvent
      attr_reader :control_id, :fax

      # Decode a `calling.call.fax` frame into a {FaxEvent}, reading the fax control id and fax result
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [FaxEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          fax: p['fax'] || {}
        )
      end

      # @param control_id [String] identifies the fax this event reports on
      # @param fax [Hash] the raw fax result object (direction, pages, identity, document)
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', fax: {}, **base)
        super(**base)
        @control_id = control_id
        @fax        = fax
      end

      private

      # The `calling.call.fax` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, fax: @fax }
      end
    end

    # calling.call.tap
    class TapEvent < RelayEvent
      attr_reader :control_id, :state, :tap, :device

      # Decode a `calling.call.tap` frame into a {TapEvent}, reading the tap control id, state, tap and device
      # descriptors
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [TapEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || '',
          tap: p['tap'] || {},
          device: p['device'] || {}
        )
      end

      # @param control_id [String] identifies the tap this event reports on
      # @param state [String] the tap state, e.g. `"tapping"` / `"finished"`
      # @param tap [Hash] the raw tap descriptor (what media is being tapped and how)
      # @param device [Hash] the raw destination device the tapped media is sent to
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', tap: {}, device: {}, **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @tap        = tap
        @device     = device
      end

      private

      # The `calling.call.tap` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state, tap: @tap, device: @device }
      end
    end

    # calling.call.stream
    class StreamEvent < RelayEvent
      attr_reader :control_id, :state, :url, :name

      # Decode a `calling.call.stream` frame into a {StreamEvent}, reading the stream control id, state, url and name
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [StreamEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || '',
          url: p['url'] || '',
          name: p['name'] || ''
        )
      end

      # @param control_id [String] identifies the stream this event reports on
      # @param state [String] the stream state, e.g. `"streaming"` / `"finished"`
      # @param url [String] the stream destination URL
      # @param name [String] the caller-supplied stream name, when one was set
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', url: '', name: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @url        = url
        @name       = name
      end

      private

      # The `calling.call.stream` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state, url: @url, name: @name }
      end
    end

    # calling.call.send_digits
    class SendDigitsEvent < RelayEvent
      attr_reader :control_id, :state

      # Decode a `calling.call.send_digits` frame into a {SendDigitsEvent}, reading the send-digits control id and state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [SendDigitsEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      # @param control_id [String] identifies the send-digits operation this event reports on
      # @param state [String] the send-digits state, e.g. `"finished"`
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      # The `calling.call.send_digits` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.dial
    class DialEvent < RelayEvent
      attr_reader :tag, :dial_state, :call_data

      # Decode a `calling.call.dial` frame into a {DialEvent}. The dialed call's
      # descriptor arrives under the wire key `call` and is exposed as {#call_data}
      # (`call` would shadow nothing useful and reads ambiguously in Ruby).
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [DialEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          tag: p['tag'] || '',
          dial_state: p['dial_state'] || '',
          call_data: p['call'] || {}
        )
      end

      # @param tag [String] the correlation tag the dial was issued with
      # @param dial_state [String] the dial state (see {DialState})
      # @param call_data [Hash] the resulting call descriptor from the wire key `call`;
      #   empty until the dial resolves
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(tag: '', dial_state: '', call_data: {}, **base)
        super(**base)
        @tag        = tag
        @dial_state = dial_state
        @call_data  = call_data
      end

      # Typed predicate over {#dial_state}, alongside the bare string.
      # Agrees with {DialState.terminal?} — true when the dial has resolved
      # (answered or failed).
      #
      # @return [Boolean]
      def terminal?
        DialState.terminal?(@dial_state)
      end

      # @return [Boolean] true when the dial succeeded ({DialState::ANSWERED}).
      def answered?
        @dial_state == DialState::ANSWERED
      end

      # @return [Boolean] true when the dial failed ({DialState::FAILED}).
      def failed?
        @dial_state == DialState::FAILED
      end

      private

      # The `calling.call.dial` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { tag: @tag, dial_state: @dial_state, call_data: @call_data }
      end
    end

    # calling.call.refer
    class ReferEvent < RelayEvent
      attr_reader :state, :sip_refer_to, :sip_refer_response_code,
                  :sip_notify_response_code

      # Decode a `calling.call.refer` frame into a {ReferEvent}, reading the refer state and the SIP REFER/NOTIFY
      # response codes
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [ReferEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          state: p['state'] || '',
          sip_refer_to: p['sip_refer_to'] || '',
          sip_refer_response_code: p['sip_refer_response_code'] || '',
          sip_notify_response_code: p['sip_notify_response_code'] || ''
        )
      end

      # @param state [String] the refer state, e.g. `"referring"` / `"completed"` / `"failed"`
      # @param sip_refer_to [String] the SIP URI the call was referred to
      # @param sip_refer_response_code [String] the response code the far end returned to the REFER
      # @param sip_notify_response_code [String] the response code carried by the follow-up NOTIFY,
      #   which is what reports whether the transfer actually succeeded
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(state: '', sip_refer_to: '', sip_refer_response_code: '',
                     sip_notify_response_code: '', **base)
        super(**base)
        @state                      = state
        @sip_refer_to               = sip_refer_to
        @sip_refer_response_code    = sip_refer_response_code
        @sip_notify_response_code   = sip_notify_response_code
      end

      private

      # The `calling.call.refer` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { state: @state, sip_refer_to: @sip_refer_to,
          sip_refer_response_code: @sip_refer_response_code,
          sip_notify_response_code: @sip_notify_response_code }
      end
    end

    # calling.call.denoise
    class DenoiseEvent < RelayEvent
      attr_reader :denoised

      # Decode a `calling.call.denoise` frame into a {DenoiseEvent}, reading the denoise flag
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [DenoiseEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          denoised: p['denoised'] || false
        )
      end

      # @param denoised [Boolean] whether denoising is currently active on the call
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(denoised: false, **base)
        super(**base)
        @denoised = denoised
      end

      private

      # The `calling.call.denoise` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { denoised: @denoised }
      end
    end

    # calling.call.pay
    class PayEvent < RelayEvent
      attr_reader :control_id, :state

      # Decode a `calling.call.pay` frame into a {PayEvent}, reading the pay control id and state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [PayEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      # @param control_id [String] identifies the pay session this event reports on
      # @param state [String] the pay state reported by the server
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      # The `calling.call.pay` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.queue
    class QueueEvent < RelayEvent
      attr_reader :control_id, :status, :queue_id, :queue_name, :position, :size

      # Decode a `calling.call.queue` frame into a {QueueEvent}. The queue's
      # identifier and name arrive under the generic wire keys `id` and `name`
      # and are exposed as {#queue_id} / {#queue_name}.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [QueueEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: _fetch(p, 'control_id', ''), status: _fetch(p, 'status', ''),
          queue_id: _fetch(p, 'id', ''), queue_name: _fetch(p, 'name', ''),
          position: _fetch(p, 'position', 0), size: _fetch(p, 'size', 0)
        )
      end

      # @param control_id [String] identifies the queue operation this event reports on
      # @param status [String] the queue status reported by the server
      # @param queue_id [String] the queue's identifier, from the wire key `id`
      # @param queue_name [String] the queue's name, from the wire key `name`
      # @param position [Integer] this call's position in the queue
      # @param size [Integer] how many calls are currently in the queue
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', status: '', queue_id: '', queue_name: '',
                     position: 0, size: 0, **base)
        super(**base)
        @control_id = control_id
        @status     = status
        @queue_id   = queue_id
        @queue_name = queue_name
        @position   = position
        @size       = size
      end

      private

      # The `calling.call.queue` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, status: @status, queue_id: @queue_id,
          queue_name: @queue_name, position: @position, size: @size }
      end
    end

    # calling.call.echo
    class EchoEvent < RelayEvent
      attr_reader :state

      # Decode a `calling.call.echo` frame into a {EchoEvent}, reading the echo state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [EchoEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          state: p['state'] || ''
        )
      end

      # @param state [String] the echo state reported by the server
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(state: '', **base)
        super(**base)
        @state = state
      end

      private

      # The `calling.call.echo` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { state: @state }
      end
    end

    # calling.call.transcribe
    class TranscribeEvent < RelayEvent
      attr_reader :control_id, :state, :url, :recording_id, :duration, :size

      TYPED_FIELDS = {
        control_id: '', state: '', url: '', recording_id: '', duration: 0.0, size: 0
      }.freeze

      # Decode a `calling.call.transcribe` frame into a {TranscribeEvent}, reading the transcribe control id, state and
      # recording metadata
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [TranscribeEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

      # @param control_id [String] identifies the transcription this event reports on
      # @param state [String] the transcribe state reported by the server
      # @param url [String] where the transcription artifact can be fetched
      # @param recording_id [String] the recording the transcription was produced from
      # @param duration [Float] transcribed length in seconds
      # @param size [Integer] artifact size in bytes
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(control_id: '', state: '', url: '', recording_id: '',
                     duration: 0.0, size: 0, **base)
        super(**base)
        @control_id   = control_id
        @state        = state
        @url          = url
        @recording_id = recording_id
        @duration     = duration
        @size         = size
      end

      private

      # The `calling.call.transcribe` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { control_id: @control_id, state: @state, url: @url,
          recording_id: @recording_id, duration: @duration, size: @size }
      end
    end

    # calling.call.hold
    class HoldEvent < RelayEvent
      attr_reader :state

      # Decode a `calling.call.hold` frame into a {HoldEvent}, reading the hold state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [HoldEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          state: p['state'] || ''
        )
      end

      # @param state [String] the hold state reported by the server
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(state: '', **base)
        super(**base)
        @state = state
      end

      private

      # The `calling.call.hold` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { state: @state }
      end
    end

    # calling.conference
    class ConferenceEvent < RelayEvent
      attr_reader :conference_id, :name, :status

      # Decode a `calling.conference` frame into a {ConferenceEvent}, reading the conference id, name and status
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [ConferenceEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          conference_id: p['conference_id'] || '',
          name: p['name'] || '',
          status: p['status'] || ''
        )
      end

      # @param conference_id [String] the conference this event reports on
      # @param name [String] the conference's name
      # @param status [String] the conference status reported by the server
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(conference_id: '', name: '', status: '', **base)
        super(**base)
        @conference_id = conference_id
        @name          = name
        @status        = status
      end

      private

      # The `calling.conference` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { conference_id: @conference_id, name: @name, status: @status }
      end
    end

    # calling.error
    class CallingErrorEvent < RelayEvent
      attr_reader :code, :message

      # Decode a `calling.error` frame into a {CallingErrorEvent}, reading the error code and message
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [CallingErrorEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          code: p['code'] || '',
          message: p['message'] || ''
        )
      end

      # @param code [String] the server-supplied error code
      # @param message [String] the human-readable error text
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(code: '', message: '', **base)
        super(**base)
        @code    = code
        @message = message
      end

      private

      # The `calling.error` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { code: @code, message: @message }
      end
    end

    # messaging.receive
    class MessageReceiveEvent < RelayEvent
      attr_reader :message_id, :context, :direction, :from_number, :to_number,
                  :body, :media, :segments, :message_state, :tags

      TYPED_FIELDS = {
        message_id: '', context: '', direction: '', from_number: '', to_number: '',
        body: '', media: [], segments: 0, message_state: '', tags: []
      }.freeze

      # Decode a `messaging.receive` frame into a {MessageReceiveEvent}, reading the message identity, addressing and
      # body
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [MessageReceiveEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

      # @param message_id [String] the inbound message's identifier
      # @param context [String] the messaging context the message arrived on
      # @param direction [String] `"inbound"` or `"outbound"`
      # @param from_number [String] the sender in E.164
      # @param to_number [String] the recipient in E.164
      # @param body [String] the message text
      # @param media [Array<String>] MMS media URLs attached to the message
      # @param segments [Integer] how many SMS segments the message was split into
      # @param message_state [String] the delivery state (see {MessageState})
      # @param tags [Array<String>] caller-supplied correlation tags
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: [], segments: 0,
                     message_state: '', tags: [], **base)
        super(**base)
        assign_fields(message_id: message_id, context: context, direction: direction,
                      from_number: from_number, to_number: to_number, body: body,
                      media: media, segments: segments, message_state: message_state, tags: tags)
      end

      private

      # The `messaging.receive` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { message_id: @message_id, context: @context, direction: @direction,
          from_number: @from_number, to_number: @to_number, body: @body,
          media: @media, segments: @segments, message_state: @message_state,
          tags: @tags }
      end
    end

    # messaging.state
    class MessageStateEvent < RelayEvent
      attr_reader :message_id, :context, :direction, :from_number, :to_number,
                  :body, :media, :segments, :message_state, :reason, :tags

      TYPED_FIELDS = {
        message_id: '', context: '', direction: '', from_number: '', to_number: '',
        body: '', media: [], segments: 0, message_state: '', reason: '', tags: []
      }.freeze

      # Decode a `messaging.state` frame into a {MessageStateEvent}, reading the message identity, addressing, body and
      # delivery state
      # out of the event's `params`.
      #
      # @param payload [Hash] the wire frame's decoded `params` object
      # @return [MessageStateEvent]
      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

      # @param message_id [String] the message whose delivery state changed
      # @param context [String] the messaging context the message belongs to
      # @param direction [String] `"inbound"` or `"outbound"`
      # @param from_number [String] the sender in E.164
      # @param to_number [String] the recipient in E.164
      # @param body [String] the message text
      # @param media [Array<String>] MMS media URLs attached to the message
      # @param segments [Integer] how many SMS segments the message was split into
      # @param message_state [String] the new delivery state (see {MessageState})
      # @param reason [String] why delivery failed, set on the failure transition; '' otherwise
      # @param tags [Array<String>] caller-supplied correlation tags
      # @param base [Hash] the shared envelope kwargs forwarded to {RelayEvent#initialize}
      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: [], segments: 0,
                     message_state: '', reason: '', tags: [], **base)
        super(**base)
        assign_fields(message_id: message_id, context: context, direction: direction,
                      from_number: from_number, to_number: to_number, body: body,
                      media: media, segments: segments, message_state: message_state,
                      reason: reason, tags: tags)
      end

      # Typed predicate over {#message_state}, alongside the bare string.
      # Agrees with {MessageState.terminal?} — true when the message has
      # reached a final delivery outcome (delivered / undelivered / failed).
      #
      # @return [Boolean]
      def terminal?
        MessageState.terminal?(@message_state)
      end

      private

      # The `messaging.state` typed fields contributed to {#to_h} and pattern matching.
      #
      # @return [Hash{Symbol => Object}]
      def event_fields
        { message_id: @message_id, context: @context, direction: @direction,
          from_number: @from_number, to_number: @to_number, body: @body,
          media: @media, segments: @segments, message_state: @message_state,
          reason: @reason, tags: @tags }
      end
    end

    # Map event_type string to typed event class
    EVENT_CLASS_MAP = {
      'calling.call.state' => CallStateEvent,
      'calling.call.receive' => CallReceiveEvent,
      'calling.call.play' => PlayEvent,
      'calling.call.record' => RecordEvent,
      'calling.call.collect' => CollectEvent,
      'calling.call.connect' => ConnectEvent,
      'calling.call.detect' => DetectEvent,
      'calling.call.fax' => FaxEvent,
      'calling.call.tap' => TapEvent,
      'calling.call.stream' => StreamEvent,
      'calling.call.send_digits' => SendDigitsEvent,
      'calling.call.dial' => DialEvent,
      'calling.call.refer' => ReferEvent,
      'calling.call.denoise' => DenoiseEvent,
      'calling.call.pay' => PayEvent,
      'calling.call.queue' => QueueEvent,
      'calling.call.echo' => EchoEvent,
      'calling.call.transcribe' => TranscribeEvent,
      'calling.call.hold' => HoldEvent,
      'calling.conference' => ConferenceEvent,
      'calling.error' => CallingErrorEvent,
      'messaging.receive' => MessageReceiveEvent,
      'messaging.state' => MessageStateEvent
    }.freeze

    # Parse a raw signalwire.event params hash into a typed event object.
    def self.parse_event(payload)
      event_type = payload['event_type'] || ''
      klass = EVENT_CLASS_MAP[event_type] || RelayEvent
      klass.from_payload(payload)
    end
  end
end
