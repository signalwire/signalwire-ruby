require 'signalwire/relay/calling/base_action'
require 'signalwire/relay/calling/play_media_action'

module Signalwire::Relay
  module Calling
    def calling
      self
    end

    def calls
      @calls ||= {}
    end

    def contexts
      @contexts ||= []
    end

    def receive(context:, &block)
      on :event, event_type: 'calling.call.receive' do |event|
        logger.info "Starting up call for #{event}"
        call_obj = Signalwire::Relay::Call::from_event(self, event)
        self.calls[call_obj.id] = call_obj

        block.call(call_obj)
      end

      relay_execute Signalwire::Relay::CallReceive.new(protocol, context) do |event|
        contexts << context
      end
    end

    def new_call(from:, to:, device_type: 'phone', timeout: 30)
      params = {
        device: {
          type: device_type,
          params: {
            from: from,
            to: to
          }
        }
      }
      return Call.new(self, params)
    end
  end
end
