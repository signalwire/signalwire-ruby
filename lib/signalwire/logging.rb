# frozen_string_literal: true

module SignalWire
  module Logging
    LEVELS = { debug: 0, info: 1, warn: 2, error: 3, off: 4 }.freeze

    # Returns the current global log level, derived from:
    #   1. SIGNALWIRE_LOG_MODE=off  -> :off  (suppresses everything)
    #   2. SIGNALWIRE_LOG_LEVEL env  -> the named level
    #   3. Default                   -> :info
    def self.global_level
      @global_level || resolve_level_from_env
    end

    def self.global_level=(level)
      level = level.to_sym if level.is_a?(String)
      raise ArgumentError, "Unknown log level: #{level}" unless LEVELS.key?(level)

      @global_level = level
    end

    def self.reset!
      @global_level = nil
    end

    def self.suppressed?
      global_level == :off
    end

    # Convenience factory
    def self.logger(name)
      Logger.new(name)
    end

    # -------------------------------------------------------------------
    class Logger
      attr_reader :name

      def initialize(name)
        @name = name
        @output = $stderr
      end

      def debug(msg)
        log(:debug, msg)
      end

      def info(msg)
        log(:info, msg)
      end

      def warn(msg)
        log(:warn, msg)
      end

      def error(msg)
        log(:error, msg)
      end

      private

      def log(level, msg)
        return if Logging.suppressed?
        return if LEVELS[level] < LEVELS[Logging.global_level]

        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        # Scrub control characters BEFORE emitting — log-injection defence, and the
        # reason the reference registers strip_control_chars in both of its structlog
        # processor chains. A port that merely EXPOSES the scrub without putting it on
        # the emission path offers no protection at all: a caller-supplied "\u0000" or
        # an "\e[" escape reaches the terminal verbatim and can forge log lines.
        safe = Core::LoggingConfig.strip_control_chars_value(msg.to_s)
        @output.puts "[#{timestamp}] #{level.upcase} [#{@name}] #{safe}"
      end
    end

    # -------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------
    private_class_method def self.resolve_level_from_env
      if ENV['SIGNALWIRE_LOG_MODE']&.downcase == 'off'
        @global_level = :off
        return :off
      end

      level_from_env_var || :info # default — not cached so env changes take effect
    end

    private_class_method def self.level_from_env_var
      raw = ENV.fetch('SIGNALWIRE_LOG_LEVEL', nil)
      return nil unless raw

      sym = raw.downcase.to_sym
      return nil unless LEVELS.key?(sym)

      @global_level = sym
    end
  end
end
