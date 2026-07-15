# frozen_string_literal: true

require 'json'
require_relative 'constants'

module SignalWire
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

      def initialize(event_type:, params: {}, call_id: '', timestamp: 0.0)
        @event_type = event_type
        @params     = params
        @call_id    = call_id
        @timestamp  = timestamp
      end

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

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(**_base_kwargs(base), **_typed_from(p, TYPED_FIELDS),
            context: _fetch(p, 'context', _fetch(p, 'protocol', '')))
      end

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

      def event_fields
        { call_state: @call_state, direction: @direction, device: @device,
          node_id: @node_id, project_id: @project_id, context: @context,
          segment_id: @segment_id, tag: @tag }
      end
    end

    # calling.call.play
    class PlayEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.record
    class RecordEvent < RelayEvent
      attr_reader :control_id, :state, :url, :duration, :size, :record

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

      def event_fields
        { control_id: @control_id, state: @state, url: @url,
          duration: @duration, size: @size, record: @record }
      end
    end

    # calling.call.collect
    class CollectEvent < RelayEvent
      # The decoded field is +result+ (formerly +result_data+).
      attr_reader :control_id, :state, :result, :final

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

      def initialize(control_id: '', state: '', result: {}, final: nil, **base)
        super(**base)
        @control_id  = control_id
        @state       = state
        @result      = result
        @final       = final
      end

      private

      def event_fields
        { control_id: @control_id, state: @state,
          result: @result, final: @final }
      end
    end

    # calling.call.connect
    class ConnectEvent < RelayEvent
      attr_reader :connect_state, :peer

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          connect_state: p['connect_state'] || '',
          peer: p['peer'] || {}
        )
      end

      def initialize(connect_state: '', peer: {}, **base)
        super(**base)
        @connect_state = connect_state
        @peer          = peer
      end

      private

      def event_fields
        { connect_state: @connect_state, peer: @peer }
      end
    end

    # calling.call.detect
    class DetectEvent < RelayEvent
      attr_reader :control_id, :detect

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          detect: p['detect'] || {}
        )
      end

      def initialize(control_id: '', detect: {}, **base)
        super(**base)
        @control_id = control_id
        @detect     = detect
      end

      private

      def event_fields
        { control_id: @control_id, detect: @detect }
      end
    end

    # calling.call.fax
    class FaxEvent < RelayEvent
      attr_reader :control_id, :fax

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          fax: p['fax'] || {}
        )
      end

      def initialize(control_id: '', fax: {}, **base)
        super(**base)
        @control_id = control_id
        @fax        = fax
      end

      private

      def event_fields
        { control_id: @control_id, fax: @fax }
      end
    end

    # calling.call.tap
    class TapEvent < RelayEvent
      attr_reader :control_id, :state, :tap, :device

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

      def initialize(control_id: '', state: '', tap: {}, device: {}, **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @tap        = tap
        @device     = device
      end

      private

      def event_fields
        { control_id: @control_id, state: @state, tap: @tap, device: @device }
      end
    end

    # calling.call.stream
    class StreamEvent < RelayEvent
      attr_reader :control_id, :state, :url, :name

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

      def initialize(control_id: '', state: '', url: '', name: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @url        = url
        @name       = name
      end

      private

      def event_fields
        { control_id: @control_id, state: @state, url: @url, name: @name }
      end
    end

    # calling.call.send_digits
    class SendDigitsEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.dial
    class DialEvent < RelayEvent
      attr_reader :tag, :dial_state, :call_data

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

      def event_fields
        { tag: @tag, dial_state: @dial_state, call_data: @call_data }
      end
    end

    # calling.call.refer
    class ReferEvent < RelayEvent
      attr_reader :state, :sip_refer_to, :sip_refer_response_code,
                  :sip_notify_response_code

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

      def initialize(state: '', sip_refer_to: '', sip_refer_response_code: '',
                     sip_notify_response_code: '', **base)
        super(**base)
        @state                      = state
        @sip_refer_to               = sip_refer_to
        @sip_refer_response_code    = sip_refer_response_code
        @sip_notify_response_code   = sip_notify_response_code
      end

      private

      def event_fields
        { state: @state, sip_refer_to: @sip_refer_to,
          sip_refer_response_code: @sip_refer_response_code,
          sip_notify_response_code: @sip_notify_response_code }
      end
    end

    # calling.call.denoise
    class DenoiseEvent < RelayEvent
      attr_reader :denoised

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          denoised: p['denoised'] || false
        )
      end

      def initialize(denoised: false, **base)
        super(**base)
        @denoised = denoised
      end

      private

      def event_fields
        { denoised: @denoised }
      end
    end

    # calling.call.pay
    class PayEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          control_id: p['control_id'] || '',
          state: p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end

      private

      def event_fields
        { control_id: @control_id, state: @state }
      end
    end

    # calling.call.queue
    class QueueEvent < RelayEvent
      attr_reader :control_id, :status, :queue_id, :queue_name, :position, :size

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

      def event_fields
        { control_id: @control_id, status: @status, queue_id: @queue_id,
          queue_name: @queue_name, position: @position, size: @size }
      end
    end

    # calling.call.echo
    class EchoEvent < RelayEvent
      attr_reader :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          state: p['state'] || ''
        )
      end

      def initialize(state: '', **base)
        super(**base)
        @state = state
      end

      private

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

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

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

      def event_fields
        { control_id: @control_id, state: @state, url: @url,
          recording_id: @recording_id, duration: @duration, size: @size }
      end
    end

    # calling.call.hold
    class HoldEvent < RelayEvent
      attr_reader :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          state: p['state'] || ''
        )
      end

      def initialize(state: '', **base)
        super(**base)
        @state = state
      end

      private

      def event_fields
        { state: @state }
      end
    end

    # calling.conference
    class ConferenceEvent < RelayEvent
      attr_reader :conference_id, :name, :status

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

      def initialize(conference_id: '', name: '', status: '', **base)
        super(**base)
        @conference_id = conference_id
        @name          = name
        @status        = status
      end

      private

      def event_fields
        { conference_id: @conference_id, name: @name, status: @status }
      end
    end

    # calling.error
    class CallingErrorEvent < RelayEvent
      attr_reader :code, :message

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          **_base_kwargs(base),
          code: p['code'] || '',
          message: p['message'] || ''
        )
      end

      def initialize(code: '', message: '', **base)
        super(**base)
        @code    = code
        @message = message
      end

      private

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

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: [], segments: 0,
                     message_state: '', tags: [], **base)
        super(**base)
        assign_fields(message_id: message_id, context: context, direction: direction,
                      from_number: from_number, to_number: to_number, body: body,
                      media: media, segments: segments, message_state: message_state, tags: tags)
      end

      private

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

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        new(**_base_kwargs(base), **_typed_from(base.params, TYPED_FIELDS))
      end

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
