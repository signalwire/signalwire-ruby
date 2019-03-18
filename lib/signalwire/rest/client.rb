# frozen_string_literal: true

module Signalwire::REST
  class Client < Twilio::REST::Client
    def initialize(account, token, signalwire_space_url: nil)
      unless signalwire_space_url.nil?
        Signalwire::Sdk.configure do |config|
          config.hostname = signalwire_space_url
        end
      end

      super(account, token)
    end
  end
end
