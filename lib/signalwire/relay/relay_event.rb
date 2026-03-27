# frozen_string_literal: true

module SignalWire
  module Relay
    # Base event wrapper for raw signalwire.event payloads.
    # Subclasses provide typed accessors for specific event types.
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
          params:     p,
          call_id:    p['call_id'] || '',
          timestamp:  p['timestamp'] || 0.0
        )
      end
    end

    # calling.call.state
    class CallStateEvent < RelayEvent
      attr_reader :call_state, :end_reason, :direction, :device

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          call_state: p['call_state'] || '',
          end_reason: p['end_reason'] || '',
          direction:  p['direction'] || '',
          device:     p['device'] || {}
        )
      end

      def initialize(call_state: '', end_reason: '', direction: '', device: {}, **base)
        super(**base)
        @call_state = call_state
        @end_reason = end_reason
        @direction  = direction
        @device     = device
      end
    end

    # calling.call.receive
    class CallReceiveEvent < RelayEvent
      attr_reader :call_state, :direction, :device, :node_id, :project_id,
                  :context, :segment_id, :tag

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          call_state: p['call_state'] || '',
          direction:  p['direction'] || '',
          device:     p['device'] || {},
          node_id:    p['node_id'] || '',
          project_id: p['project_id'] || '',
          context:    p['context'] || p['protocol'] || '',
          segment_id: p['segment_id'] || '',
          tag:        p['tag'] || ''
        )
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
    end

    # calling.call.play
    class PlayEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
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
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || '',
          url:        rec['url'] || p['url'] || '',
          duration:   rec['duration'] || p['duration'] || 0.0,
          size:       rec['size'] || p['size'] || 0,
          record:     rec
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
    end

    # calling.call.collect
    class CollectEvent < RelayEvent
      attr_reader :control_id, :state, :result_data, :final

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id:  p['control_id'] || '',
          state:       p['state'] || '',
          result_data: p['result'] || {},
          final:       p['final']
        )
      end

      def initialize(control_id: '', state: '', result_data: {}, final: nil, **base)
        super(**base)
        @control_id  = control_id
        @state       = state
        @result_data = result_data
        @final       = final
      end
    end

    # calling.call.connect
    class ConnectEvent < RelayEvent
      attr_reader :connect_state, :peer

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          connect_state: p['connect_state'] || '',
          peer:          p['peer'] || {}
        )
      end

      def initialize(connect_state: '', peer: {}, **base)
        super(**base)
        @connect_state = connect_state
        @peer          = peer
      end
    end

    # calling.call.detect
    class DetectEvent < RelayEvent
      attr_reader :control_id, :detect

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          detect:     p['detect'] || {}
        )
      end

      def initialize(control_id: '', detect: {}, **base)
        super(**base)
        @control_id = control_id
        @detect     = detect
      end
    end

    # calling.call.fax
    class FaxEvent < RelayEvent
      attr_reader :control_id, :fax

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          fax:        p['fax'] || {}
        )
      end

      def initialize(control_id: '', fax: {}, **base)
        super(**base)
        @control_id = control_id
        @fax        = fax
      end
    end

    # calling.call.tap
    class TapEvent < RelayEvent
      attr_reader :control_id, :state, :tap, :device

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || '',
          tap:        p['tap'] || {},
          device:     p['device'] || {}
        )
      end

      def initialize(control_id: '', state: '', tap: {}, device: {}, **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @tap        = tap
        @device     = device
      end
    end

    # calling.call.stream
    class StreamEvent < RelayEvent
      attr_reader :control_id, :state, :url, :name

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || '',
          url:        p['url'] || '',
          name:       p['name'] || ''
        )
      end

      def initialize(control_id: '', state: '', url: '', name: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
        @url        = url
        @name       = name
      end
    end

    # calling.call.send_digits
    class SendDigitsEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end
    end

    # calling.call.dial
    class DialEvent < RelayEvent
      attr_reader :tag, :dial_state, :call_data

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          tag:        p['tag'] || '',
          dial_state: p['dial_state'] || '',
          call_data:  p['call'] || {}
        )
      end

      def initialize(tag: '', dial_state: '', call_data: {}, **base)
        super(**base)
        @tag        = tag
        @dial_state = dial_state
        @call_data  = call_data
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
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          state:                      p['state'] || '',
          sip_refer_to:               p['sip_refer_to'] || '',
          sip_refer_response_code:    p['sip_refer_response_code'] || '',
          sip_notify_response_code:   p['sip_notify_response_code'] || ''
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
    end

    # calling.call.denoise
    class DenoiseEvent < RelayEvent
      attr_reader :denoised

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          denoised: p['denoised'] || false
        )
      end

      def initialize(denoised: false, **base)
        super(**base)
        @denoised = denoised
      end
    end

    # calling.call.pay
    class PayEvent < RelayEvent
      attr_reader :control_id, :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          state:      p['state'] || ''
        )
      end

      def initialize(control_id: '', state: '', **base)
        super(**base)
        @control_id = control_id
        @state      = state
      end
    end

    # calling.call.queue
    class QueueEvent < RelayEvent
      attr_reader :control_id, :status, :queue_id, :queue_name, :position, :size

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id: p['control_id'] || '',
          status:     p['status'] || '',
          queue_id:   p['id'] || '',
          queue_name: p['name'] || '',
          position:   p['position'] || 0,
          size:       p['size'] || 0
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
    end

    # calling.call.echo
    class EchoEvent < RelayEvent
      attr_reader :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          state: p['state'] || ''
        )
      end

      def initialize(state: '', **base)
        super(**base)
        @state = state
      end
    end

    # calling.call.transcribe
    class TranscribeEvent < RelayEvent
      attr_reader :control_id, :state, :url, :recording_id, :duration, :size

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          control_id:   p['control_id'] || '',
          state:        p['state'] || '',
          url:          p['url'] || '',
          recording_id: p['recording_id'] || '',
          duration:     p['duration'] || 0.0,
          size:         p['size'] || 0
        )
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
    end

    # calling.call.hold
    class HoldEvent < RelayEvent
      attr_reader :state

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          state: p['state'] || ''
        )
      end

      def initialize(state: '', **base)
        super(**base)
        @state = state
      end
    end

    # calling.conference
    class ConferenceEvent < RelayEvent
      attr_reader :conference_id, :name, :status

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          conference_id: p['conference_id'] || '',
          name:          p['name'] || '',
          status:        p['status'] || ''
        )
      end

      def initialize(conference_id: '', name: '', status: '', **base)
        super(**base)
        @conference_id = conference_id
        @name          = name
        @status        = status
      end
    end

    # calling.error
    class CallingErrorEvent < RelayEvent
      attr_reader :code, :message

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          code:    p['code'] || '',
          message: p['message'] || ''
        )
      end

      def initialize(code: '', message: '', **base)
        super(**base)
        @code    = code
        @message = message
      end
    end

    # messaging.receive
    class MessageReceiveEvent < RelayEvent
      attr_reader :message_id, :context, :direction, :from_number, :to_number,
                  :body, :media, :segments, :message_state, :tags

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          message_id:    p['message_id'] || '',
          context:       p['context'] || '',
          direction:     p['direction'] || '',
          from_number:   p['from_number'] || '',
          to_number:     p['to_number'] || '',
          body:          p['body'] || '',
          media:         p['media'] || [],
          segments:      p['segments'] || 0,
          message_state: p['message_state'] || '',
          tags:          p['tags'] || []
        )
      end

      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: [], segments: 0,
                     message_state: '', tags: [], **base)
        super(**base)
        @message_id    = message_id
        @context       = context
        @direction     = direction
        @from_number   = from_number
        @to_number     = to_number
        @body          = body
        @media         = media
        @segments      = segments
        @message_state = message_state
        @tags          = tags
      end
    end

    # messaging.state
    class MessageStateEvent < RelayEvent
      attr_reader :message_id, :context, :direction, :from_number, :to_number,
                  :body, :media, :segments, :message_state, :reason, :tags

      def self.from_payload(payload)
        base = RelayEvent.from_payload(payload)
        p = base.params
        new(
          event_type: base.event_type, params: base.params,
          call_id: base.call_id, timestamp: base.timestamp,
          message_id:    p['message_id'] || '',
          context:       p['context'] || '',
          direction:     p['direction'] || '',
          from_number:   p['from_number'] || '',
          to_number:     p['to_number'] || '',
          body:          p['body'] || '',
          media:         p['media'] || [],
          segments:      p['segments'] || 0,
          message_state: p['message_state'] || '',
          reason:        p['reason'] || '',
          tags:          p['tags'] || []
        )
      end

      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: [], segments: 0,
                     message_state: '', reason: '', tags: [], **base)
        super(**base)
        @message_id    = message_id
        @context       = context
        @direction     = direction
        @from_number   = from_number
        @to_number     = to_number
        @body          = body
        @media         = media
        @segments      = segments
        @message_state = message_state
        @reason        = reason
        @tags          = tags
      end
    end

    # Map event_type string to typed event class
    EVENT_CLASS_MAP = {
      'calling.call.state'       => CallStateEvent,
      'calling.call.receive'     => CallReceiveEvent,
      'calling.call.play'        => PlayEvent,
      'calling.call.record'      => RecordEvent,
      'calling.call.collect'     => CollectEvent,
      'calling.call.connect'     => ConnectEvent,
      'calling.call.detect'      => DetectEvent,
      'calling.call.fax'         => FaxEvent,
      'calling.call.tap'         => TapEvent,
      'calling.call.stream'      => StreamEvent,
      'calling.call.send_digits' => SendDigitsEvent,
      'calling.call.dial'        => DialEvent,
      'calling.call.refer'       => ReferEvent,
      'calling.call.denoise'     => DenoiseEvent,
      'calling.call.pay'         => PayEvent,
      'calling.call.queue'       => QueueEvent,
      'calling.call.echo'        => EchoEvent,
      'calling.call.transcribe'  => TranscribeEvent,
      'calling.call.hold'        => HoldEvent,
      'calling.conference'       => ConferenceEvent,
      'calling.error'            => CallingErrorEvent,
      'messaging.receive'        => MessageReceiveEvent,
      'messaging.state'          => MessageStateEvent
    }.freeze

    # Parse a raw signalwire.event params hash into a typed event object.
    def self.parse_event(payload)
      event_type = payload['event_type'] || ''
      klass = EVENT_CLASS_MAP[event_type] || RelayEvent
      klass.from_payload(payload)
    end
  end
end
