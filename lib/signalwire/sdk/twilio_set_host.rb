# frozen_string_literal: true

module Twilio
  module REST
    class Api < Domain
      def initialize(twilio)
        super

        return if Signalwire::Sdk.configuration.service_provider == 'twilio'

        @host = ENV['SIGNALWIRE_HOST'] || ENV['SIGNALWIRE_API_HOSTNAME'] || Signalwire::Sdk.configuration.hostname ||
                raise(ArgumentError,
                      'SignalWire Space URL is not configured. Enter your SignalWire Space domain via the '\
                      'SIGNALWIRE_HOST or SIGNALWIRE_API_HOSTNAME environment variables, '\
                      'or hostname in the configuration.')

        @base_url = "https://#{@host}"
        @port = 443

        # Versions
        @v2010 = nil
      end

      def hostname
        @host
      end

      def service_provider
        Signalwire::Sdk.configuration.service_provider
      end
    end
  end
end
