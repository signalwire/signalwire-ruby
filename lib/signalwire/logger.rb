# frozen_string_literal: true

require 'logger'

module Signalwire
  module Logger
    class << self
      # A global logger object
      # @return [Logger] a Logger instance
      def logger
        @logger ||= begin
          logger = ::Logger.new(STDERR, progname: 'SignalWire', level: ::Logger::DEBUG)
          logger.level = ENV.fetch('SIGNALWIRE_LOG_LEVEL', ::Logger::INFO)
          logger
        end
      end
    end

    def logger
      Signalwire::Logger.logger
    end

    def level=(level)
      Signalwire::Logger.logger.level = level
    end
  end
end
