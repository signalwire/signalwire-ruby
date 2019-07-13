# frozen_string_literal: true

module Twilio
  module REST
    class Api < Domain
      def initialize(twilio)
        super

        @host = ENV['SIGNALWIRE_SPACE_URL'] ||
                ENV['SIGNALWIRE_API_HOSTNAME'] ||
                Signalwire::Sdk.configuration.hostname ||
                raise(ArgumentError,
                      'SignalWire Space URL is not configured. Enter your SignalWire Space domain via the '\
                      'SIGNALWIRE_SPACE_URL or SIGNALWIRE_API_HOSTNAME environment variables, '\
                      'or hostname in the configuration.')

        @base_url = "https://#{@host}/api/laml"
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
