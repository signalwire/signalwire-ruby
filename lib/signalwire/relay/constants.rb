# frozen_string_literal: true

module SignalWire
  # Relay — the RELAY realtime (WebSocket / JSON-RPC 2.0) client surface.
  module Relay
    # Protocol version sent during signalwire.connect
    PROTOCOL_VERSION = { 'major' => 2, 'minor' => 0, 'revision' => 0 }.freeze
    AGENT_STRING = 'signalwire-agents-ruby/1.0'

    # JSON-RPC methods
    METHOD_SIGNALWIRE_CONNECT    = 'signalwire.connect'
    METHOD_SIGNALWIRE_EVENT      = 'signalwire.event'
    METHOD_SIGNALWIRE_PING       = 'signalwire.ping'
    METHOD_SIGNALWIRE_DISCONNECT = 'signalwire.disconnect'
    METHOD_SIGNALWIRE_RECEIVE    = 'signalwire.receive'
    METHOD_SIGNALWIRE_UNRECEIVE  = 'signalwire.unreceive'

    # Authorization state event
    EVENT_AUTHORIZATION_STATE = 'signalwire.authorization.state'

    # Call states
    CALL_STATE_CREATED  = 'created'
    CALL_STATE_RINGING  = 'ringing'
    CALL_STATE_ANSWERED = 'answered'
    CALL_STATE_ENDING   = 'ending'
    CALL_STATE_ENDED    = 'ended'

    CALL_STATES = [
      CALL_STATE_CREATED,
      CALL_STATE_RINGING,
      CALL_STATE_ANSWERED,
      CALL_STATE_ENDING,
      CALL_STATE_ENDED
    ].freeze

    # Named, frozen view over the call-state vocabulary. Additive: the wire
    # value stays a bare String everywhere (the events carry +call_state+ as a
    # String, +Call#state+ is a String), and the flat +CALL_STATE_*+ constants
    # above remain the single source of the literals. This module wraps them
    # with a frozen +ALL+ ordered list, a frozen
    # +TERMINAL+ set, and a +terminal?+ predicate — so callers can ask
    # +CallState.terminal?(state)+ instead of hard-coding +== "ended"+.
    #
    # The set is closed — these are the only states the server emits. +ended+
    # is the one terminal state (the call is gone; {Call#wait_for_ended}
    # resolves on it).
    module CallState
      CREATED  = CALL_STATE_CREATED
      RINGING  = CALL_STATE_RINGING
      ANSWERED = CALL_STATE_ANSWERED
      ENDING   = CALL_STATE_ENDING
      ENDED    = CALL_STATE_ENDED

      # @return [Array<String>] every call state, in lifecycle order.
      ALL = CALL_STATES

      # @return [Array<String>] states from which the call never advances.
      TERMINAL = [CALL_STATE_ENDED].freeze

      # @param state [String, nil] a +call_state+ string.
      # @return [Boolean] true when +state+ is a terminal call state.
      def self.terminal?(state)
        TERMINAL.include?(state)
      end

      # @param state [String, nil]
      # @return [Boolean] true when +state+ is a known call state.
      def self.valid?(state)
        ALL.include?(state)
      end
    end

    # End reasons
    END_REASON_HANGUP       = 'hangup'
    END_REASON_CANCEL       = 'cancel'
    END_REASON_BUSY         = 'busy'
    END_REASON_NO_ANSWER    = 'noAnswer'
    END_REASON_DECLINE      = 'decline'
    END_REASON_ERROR        = 'error'
    END_REASON_ABANDONED    = 'abandoned'
    END_REASON_MAX_DURATION = 'max_duration'
    END_REASON_NOT_FOUND    = 'not_found'

    # Connect states
    CONNECT_STATE_CONNECTING   = 'connecting'
    CONNECT_STATE_CONNECTED    = 'connected'
    CONNECT_STATE_DISCONNECTED = 'disconnected'
    CONNECT_STATE_FAILED       = 'failed'

    # Dial states (the +dial_state+ field on calling.call.dial events)
    DIAL_STATE_DIALING  = 'dialing'
    DIAL_STATE_ANSWERED = 'answered'
    DIAL_STATE_FAILED   = 'failed'

    # Named, frozen view over the outbound-dial vocabulary. The +dial_state+
    # field on a +calling.call.dial+ event carries exactly one of +dialing+,
    # +answered+ or +failed+. This module names them (+DIAL_STATE_*+ above are
    # the single source of the literals) and adds +ALL+ + +TERMINAL+ +
    # +terminal?+.
    #
    # Both +answered+ and +failed+ are terminal: {Client#dial} resolves to a
    # {Call} on +answered+ and raises {RelayError} on +failed+; +dialing+ is
    # the only in-flight state.
    module DialState
      DIALING  = DIAL_STATE_DIALING
      ANSWERED = DIAL_STATE_ANSWERED
      FAILED   = DIAL_STATE_FAILED

      # @return [Array<String>] every dial state.
      ALL = [
        DIAL_STATE_DIALING,
        DIAL_STATE_ANSWERED,
        DIAL_STATE_FAILED
      ].freeze

      # @return [Array<String>] dial states that resolve the dial (success or failure).
      TERMINAL = [
        DIAL_STATE_ANSWERED,
        DIAL_STATE_FAILED
      ].freeze

      # @param state [String, nil] a +dial_state+ string.
      # @return [Boolean] true when +state+ resolves the dial.
      def self.terminal?(state)
        TERMINAL.include?(state)
      end

      # @param state [String, nil]
      # @return [Boolean] true when +state+ is a known dial state.
      def self.valid?(state)
        ALL.include?(state)
      end
    end

    # Event types — calling
    EVENT_CALL_STATE      = 'calling.call.state'
    EVENT_CALL_RECEIVE    = 'calling.call.receive'
    EVENT_CALL_CONNECT    = 'calling.call.connect'
    EVENT_CALL_PLAY       = 'calling.call.play'
    EVENT_CALL_COLLECT    = 'calling.call.collect'
    EVENT_CALL_RECORD     = 'calling.call.record'
    EVENT_CALL_DETECT     = 'calling.call.detect'
    EVENT_CALL_FAX        = 'calling.call.fax'
    EVENT_CALL_TAP        = 'calling.call.tap'
    EVENT_CALL_SEND_DIGITS = 'calling.call.send_digits'
    EVENT_CALL_DIAL       = 'calling.call.dial'
    EVENT_CALL_REFER      = 'calling.call.refer'
    EVENT_CALL_DENOISE    = 'calling.call.denoise'
    EVENT_CALL_PAY        = 'calling.call.pay'
    EVENT_CALL_QUEUE      = 'calling.call.queue'
    EVENT_CALL_STREAM     = 'calling.call.stream'
    EVENT_CALL_ECHO       = 'calling.call.echo'
    EVENT_CALL_TRANSCRIBE = 'calling.call.transcribe'
    EVENT_CONFERENCE      = 'calling.conference'
    EVENT_CALLING_ERROR   = 'calling.error'

    # Messaging event types
    EVENT_MESSAGING_RECEIVE = 'messaging.receive'
    EVENT_MESSAGING_STATE   = 'messaging.state'

    # Message states
    MESSAGE_STATE_QUEUED       = 'queued'
    MESSAGE_STATE_INITIATED    = 'initiated'
    MESSAGE_STATE_SENT         = 'sent'
    MESSAGE_STATE_DELIVERED    = 'delivered'
    MESSAGE_STATE_UNDELIVERED  = 'undelivered'
    MESSAGE_STATE_FAILED       = 'failed'
    MESSAGE_STATE_RECEIVED     = 'received'

    MESSAGE_TERMINAL_STATES = [
      MESSAGE_STATE_DELIVERED,
      MESSAGE_STATE_UNDELIVERED,
      MESSAGE_STATE_FAILED
    ].freeze

    # Named, frozen view over the messaging-state vocabulary. Additive: the
    # wire value stays a bare String (+Message#state+, the +message_state+
    # event field). Wraps the flat +MESSAGE_STATE_*+ constants (the single
    # source of the literals) with +ALL+ + +TERMINAL+ + +terminal?+, so callers
    # can ask +MessageState.terminal?(state)+ instead of re-deriving the set.
    #
    # The terminal set is +MESSAGE_TERMINAL_STATES+ ({delivered, undelivered,
    # failed}) — reaching any of the three resolves a sent message's final
    # outcome.
    module MessageState
      QUEUED      = MESSAGE_STATE_QUEUED
      INITIATED   = MESSAGE_STATE_INITIATED
      SENT        = MESSAGE_STATE_SENT
      DELIVERED   = MESSAGE_STATE_DELIVERED
      UNDELIVERED = MESSAGE_STATE_UNDELIVERED
      FAILED      = MESSAGE_STATE_FAILED
      RECEIVED    = MESSAGE_STATE_RECEIVED

      # @return [Array<String>] every messaging state.
      ALL = [
        MESSAGE_STATE_QUEUED,
        MESSAGE_STATE_INITIATED,
        MESSAGE_STATE_SENT,
        MESSAGE_STATE_DELIVERED,
        MESSAGE_STATE_UNDELIVERED,
        MESSAGE_STATE_FAILED,
        MESSAGE_STATE_RECEIVED
      ].freeze

      # @return [Array<String>] states after which a message will not change.
      TERMINAL = MESSAGE_TERMINAL_STATES

      # @param state [String, nil] a +message_state+ string.
      # @return [Boolean] true when +state+ is a terminal messaging state.
      def self.terminal?(state)
        TERMINAL.include?(state)
      end

      # @param state [String, nil]
      # @return [Boolean] true when +state+ is a known messaging state.
      def self.valid?(state)
        ALL.include?(state)
      end
    end

    # Play states
    PLAY_STATE_PLAYING  = 'playing'
    PLAY_STATE_PAUSED   = 'paused'
    PLAY_STATE_FINISHED = 'finished'
    PLAY_STATE_ERROR    = 'error'

    # Record states
    RECORD_STATE_RECORDING = 'recording'
    RECORD_STATE_PAUSED    = 'paused'
    RECORD_STATE_FINISHED  = 'finished'
    RECORD_STATE_NO_INPUT  = 'no_input'

    # Detect types
    DETECT_TYPE_MACHINE = 'machine'
    DETECT_TYPE_FAX     = 'fax'
    DETECT_TYPE_DIGIT   = 'digit'

    # Join room states
    ROOM_STATE_JOINING = 'joining'
    ROOM_STATE_JOIN    = 'join'
    ROOM_STATE_LEAVING = 'leaving'
    ROOM_STATE_LEAVE   = 'leave'

    # Reconnect settings
    RECONNECT_MIN_DELAY      = 1.0
    RECONNECT_MAX_DELAY      = 30.0
    RECONNECT_BACKOFF_FACTOR = 2.0

    # Default host
    DEFAULT_RELAY_HOST = 'relay.signalwire.com'
  end
end
