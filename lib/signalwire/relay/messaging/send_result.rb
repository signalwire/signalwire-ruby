module Signalwire::Relay::Messaging
  attr_accessor :event
  class SendResult < Signalwire::Relay::Event
    def initialize(event)
      super(event.payload)
      @event = event
    end

    def code
      dig(:result, :result, :code)
    end

    def message_id
      dig(:result, :result, :message_id)
    end

    def message
      dig(:result, :result, :message)
    end

    def successful
      code == "200"
    end
  end
end