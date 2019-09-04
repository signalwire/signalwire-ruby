# frozen_string_literal: true

module Signalwire::Relay
  DEFAULT_URL = 'relay.signalwire.com'
  COMMAND_TIMEOUT = 30
  DEFAULT_CALL_TIMEOUT = 30
  PING_TIMEOUT = 5
  DEFAULT_LANGUAGE = 'en-US'
  DEFAULT_GENDER = 'female'

  module CallState
    NONE = 'none'
    CREATED = 'created'
    RINGING = 'ringing'
    ANSWERED = 'answered'
    ENDING = 'ending'
    ENDED = 'ended'
  end

  CALL_STATES = [
    CallState::NONE,
    CallState::CREATED,
    CallState::RINGING,
    CallState::ANSWERED,
    CallState::ENDING,
    CallState::ENDED
  ].freeze

  module DisconnectReason
    HANGUP = 'hangup'
    CANCEL = 'cancel'
    BUSY = 'busy'
    NO_ANSWER = 'noAnswer'
    DECLINE = 'decline'
    ERROR = 'error'
    FAILED = 'failed'
  end

  module DisconnectSource
    NONE = 'none'
    CLIENT = 'client'
    SERVER = 'server'
    ENDPOINT = 'endpoint'
  end

  module CallType
    PHONE = 'phone'
    SIP = 'sip'
    WEBRTC = 'webrtc'
  end

  module CallConnectState
    DISCONNECTED = 'disconnected'
    CONNECTING = 'connecting'
    CONNECTED = 'connected'
    FAILED = 'failed'
  end

  module CallNotification
    STATE = 'calling.call.state'
    RECEIVE = 'calling.call.receive'
    CONNECT = 'calling.call.connect'
    RECORD = 'calling.call.record'
    PLAY = 'calling.call.play'
    COLLECT = 'calling.call.collect'
    FAX = 'calling.call.fax'
    TAP = 'calling.call.tap'
    DETECT = 'calling.call.detect'
    SEND_DIGITS = 'calling.call.send_digits'
  end

  CALL_EVENT_STATE_FIELDS = {
    CallNotification::STATE => 'state',
    CallNotification::RECEIVE => 'call_state',
    CallNotification::CONNECT => 'connect_state',
    CallNotification::RECORD => 'state',
    CallNotification::PLAY => 'state',
    CallNotification::COLLECT => 'result' # this actually need to be parsed separately
  }.freeze

  module CallPlayState
    PLAYING = 'playing'
    ERROR = 'error'
    FINISHED = 'finished'
  end

  module CallPromptState
    ERROR = 'error'
    NO_INPUT = 'no_input'
    NO_MATCH = 'no_match'
    DIGIT = 'digit'
    SPEECH = 'speech'
  end

  module CallRecordState
    RECORDING = 'recording'
    NO_INPUT = 'no_input'
    FINISHED = 'finished'
  end

  module MessageState
    QUEUED = 'queued'
    INITIATED = 'initiated'
    SENT = 'sent'
    DELIVERED = 'delivered'
    UNDELIVERED = 'undelivered'
    FAILED = 'failed'
  end

  module ComponentMethod
    ANSWER = 'calling.answer'
    CONNECT = 'calling.connect'
    DIAL = 'calling.begin' # BEGIN is a reserved word
    HANGUP = 'calling.end' # END is a reserved word
    PLAY = 'calling.play'
    PROMPT = 'calling.play_and_collect'
    RECORD = 'calling.record'
    SEND_FAX = 'calling.send_fax'
    RECEIVE_FAX = 'calling.receive_fax'
    TAP = 'calling.tap'
    DETECT = 'calling.detect'
    SEND_DIGITS = 'calling.send_digits'
  end

  module CommonState
    SUCCESSFUL = 'successful'
  end

  module CallFaxState
    PAGE = 'page',
    ERROR = 'error',
    FINISHED = 'finished'
  end

  module CallTapState
    TAPPING = 'tapping'
    FINISHED = 'finished'
  end
  
  module CallDetectState
    ERROR = 'error'
    FINISHED = 'finished'
    CED = 'CED'
    CNG = 'CNG'
    MACHINE = 'MACHINE'
    HUMAN = 'HUMAN'
    UNKNOWN = 'UNKNOWN'
    READY = 'READY'
    NOT_READY = 'NOT_READY'
  end

  module CallDetectType
    FAX = "fax"
    MACHINE = "machine"
    DIGIT = "digit"
  end

  module CallSendDigitsState
    FINISHED = 'finished'
  end
end

Relay = Signalwire::Relay
