# frozen_string_literal: true

module Signalwire::REST
  class Client < Twilio::REST::Client
    def initialize(account, token, space = nil)
      unless space.nil?
        Signalwire::Sdk.configure do |config|
          config.hostname = space
        end
      end

      super(account, token)
    end
  end
end
