# frozen_string_literal: true

require 'forwardable'
require 'concurrent-ruby'

module Signalwire::Relay
  module Calling
    class Instance
      extend Forwardable
      include Signalwire::Logger
      include Signalwire::Common

      def_delegators :@client, :relay_execute, :protocol, :on, :once, :broadcast

      def initialize(client)
        @client = client
      end

      def calls
        @calls ||= Concurrent::Array.new
      end

      def contexts
        @client.contexts
      end

      def receive(context:, &block)
        @client.on :event, event_type: 'calling.call.receive' do |event|
          logger.info "Starting up call for #{event.call_params}"
          call_obj = Signalwire::Relay::Calling::Call.from_event(self, event)
          calls << call_obj
          block.call(call_obj) if block_given?
        end

        @client.setup_context(context)
      end

      def find_call_by_id(call_id)
        calls.find { |call| call.id == call_id }
      end

      def find_call_by_tag(tag)
        calls.find { |call| call.tag == tag }
      end

      def end_call(call_id)
        calls.delete find_call_by_id(call_id)
      end

      def new_call(from:, to:, device_type: 'phone', timeout: 30)
        params = {
          device: {
            type: device_type,
            params: {
              from_number: from,
              to_number: to,
              timeout: timeout
            }
          }
        }
        call = Call.new(self, params)
        calls << call
        call
      end

      def dial(from:, to:, device_type: 'phone', timeout: 30)
        handle = new_call(from: from, to: to, device_type: device_type, timeout: timeout)
        handle.dial
      end
    end
  end
end
