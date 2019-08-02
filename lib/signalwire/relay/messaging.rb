# frozen_string_literal: true

require 'forwardable'
require 'concurrent-ruby'

module Signalwire::Relay
  module Messaging
    class Instance
      extend Forwardable
      include Signalwire::Logger
      include Signalwire::Common

      alias_method :object_send, :send

      def_delegators :@client, :relay_execute, :protocol, :on, :once, :broadcast

      def initialize(client)
        @client = client
        setup_events
      end

      def send(from:, to:, context:, body: nil, media: nil, tags: nil, region: nil)
        params = {
          from_number: from,
          to_number: to,
          context: context
        }

        params[:body] = body if body
        params[:media] = media if media
        params[:tags] = tags if tags
        params[:region] = region if region

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