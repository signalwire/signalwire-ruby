# frozen_string_literal: true

require 'twilio-ruby'

require 'signalwire/sdk/configuration'
require 'signalwire/sdk/twilio_set_host'
require 'signalwire/sdk/twilio_set_fax'
require 'signalwire/sdk/domain'
require 'signalwire/sdk/voice_response'
require 'signalwire/sdk/fax_response'
require 'signalwire/sdk/messaging_response'
require 'signalwire/rest/client'

module Signalwire
  module Sdk
    class << self
      attr_accessor :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def reset
        @configuration = Configuration.new
      end

      def configure
        yield(configuration)
      end
    end
  end
end
