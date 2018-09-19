# frozen_string_literal: true

module Twilio
  module REST
    class Api < Domain
      def initialize(twilio)
        super

        @host = ENV['SIGNALWIRE_API_HOSTNAME'] || Signalwire::Sdk.configuration.hostname || raise(ArgumentError,
          'Signalwire API Hostname is not configured. Enter your Signalwire hostname via the '\
          'SIGNALWIRE_API_HOSTNAME environment variable, or hostname in the configuration.')
        @base_url = "https://#{@host}/api"
        @port = 443

        # Versions
        @v2010 = nil
      end

      def hostname
        @host
      end
    end
  end
end
