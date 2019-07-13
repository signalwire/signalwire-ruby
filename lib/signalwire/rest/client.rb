# frozen_string_literal: true

module Signalwire::REST
  class Client < Twilio::REST::Client
    def initialize(username = nil, password = nil, account_sid = nil, region = nil, http_client = Twilio::HTTP::Client.new, **args)
      signalwire_space_url = args.delete(:signalwire_space_url)

      unless signalwire_space_url.nil?
        Signalwire::Sdk.configure do |config|
          config.hostname = signalwire_space_url
        end
      end

      super(username, password, account_sid, region, http_client)
    end
  end
end
