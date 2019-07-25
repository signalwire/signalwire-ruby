# frozen_string_literal: true

module Signalwire::Relay::Messaging
  class Message < Signalwire::Relay::Event
    def initialize(from_number:, to_number:, context:, **params)
      @body = params.delete(:body)
      @media = params.delete(:media)
      @from_number = from_number
      @to_number = to_number
      @context = context
      @payload = params
      raise ArgumentError, "You need to specify either :body or :media" unless @body || @media

      
    end

    def send_request(protocol)
      @payload[:body] = @body if @body
      @payload[:media] = @media if @media

      params = @payload.merge[:from_number] = @from_number
      @payload[:to_number] = @to_number
      @payload[:context] = @context

      {
        protocol: protocol,
        method: 'messaging.send',
        params: params
      }
    end
  end
end