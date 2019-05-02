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

        on :event, event_type: 'calling.call.receive' do |event|
          call_obj = Signalwire::Relay::Call::from_event(self, event)

          block.call(call_obj)
        end
      end
    end
  end
end
