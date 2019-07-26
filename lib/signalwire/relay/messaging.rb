# frozen_string_literal: true

require 'forwardable'
require 'concurrent-ruby'

module Signalwire::Relay
  module Messaging
    class Instance
      extend Forwardable
      include Signalwire::Logger
      include Signalwire::Common

      def_delegators :@client, :relay_execute, :protocol, :on, :once, :broadcast

      def initialize(client)
        @client = client
        setup_events
      end

      def send(from_number:, to_number:, context:, **params)
        body = params.delete(:body)
        media = params.delete(:media)
        payload = params

        raise ArgumentError, "You need to specify either :body or :media" unless body || media

        payload[:body] = @body if @body
        payload[:media] = @media if @media

        params = payload.merge({
          from_number: from_number,
          to_number: to_number,
          context: context
        })

        params[:body] = body if body
        params[:media] = body if media

        messaging_send = {
          protocol: protocol,
          method: 'messaging.send',
          params: params
        }

        response = nil
        relay_execute messaging_send do |event|
          response = Signalwire::Relay::Messaging::SendResult.new(event)
        end
        response
      end

      def setup_events
        @client.on :event, event_type: 'messaging.receive' do |event|
          broadcast :message_received, Signalwire::Relay::Messaging::Message.new(event.payload)
        end

        @client.on :event, event_type: 'messaging.state' do |event|
          broadcast :message_state_change, Signalwire::Relay::Messaging::Message.new(event.payload)
        end
      end
    end
  end
end