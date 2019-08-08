# frozen_string_literal: true

module Signalwire::REST
  class Client < Twilio::REST::Client
    def initialize(username = nil, password = nil, account_sid = nil, region = nil, http_client = Twilio::HTTP::Client.new, **args)
      host = args.delete(:signalwire_space_url)

      unless host.nil?
        Signalwire::Sdk.configure do |config|
          config.hostname = host
        end
      end

      super(username, password, account_sid, region, http_client)
    end
  end
end
