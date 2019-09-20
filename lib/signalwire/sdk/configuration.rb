# frozen_string_literal: true

module Signalwire
  module Sdk
    class Configuration
      attr_accessor :hostname, :service_provider

      def initialize
        @service_provider = 'signalwire' if self.service_provider.nil?
      end

      def configure
        yield self
      end


      def reset_config
        configure do |config|
          config.service_provider = 'signalwire'
        end
      end
    end
  end
end
