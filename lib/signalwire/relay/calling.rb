module Signalwire::Relay
  module Calling
    def calling
      self
    end

    def contexts
      @contexts ||= []
    end

    def receive(context:, &block)
      on :event, event_type: 'calling.call.receive' do |event|
        logger.info "Starting up call for #{event}"
        call_obj = Signalwire::Relay::Call::from_event(self, event)

        block.call(call_obj)
      end

      relay_execute Signalwire::Relay::CallReceive.new(protocol, context) do |event|
        contexts << context
      end
    end
  end
end
