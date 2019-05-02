module Signalwire::Relay
  module Calling
    def calling
      self
    end

    def contexts
      @contexts ||= []
    end

    def receive(context:, &block)
      relay_execute Signalwire::Relay::CallReceive.new(protocol, context) do |event|
        contexts << context
      end
    end
  end
end
