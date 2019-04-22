# encoding: utf-8

module Signalwire::Blade
  module Logging

    LOG_LEVELS = %w(TRACE DEBUG INFO WARN ERROR FATAL)

    class ::Logging::Repository
      def delete( key ) @h.delete(to_key(key)) end
    end

    module HasLogger
      def self.logger
        ::Logging.logger[logger_id]
      end

      def logger
        ::Logging.logger[logger_id]
      end

      def logger_id
        self
      end
    end

    class << self
      ::Logging.color_scheme 'bright',
        :levels => {
          :debug => :magenta,
          :info  => :green,
          :warn  => :yellow,
          :error => :red,
          :fatal => [:white, :on_red]
        },
        :date     => [:bold, :blue],
        :logger   => :cyan

      def pattern_options
        {
          :pattern      => '[%d] %-5l %c: %m\n',
          :date_pattern => '%Y-%m-%d %H:%M:%S.%L'
        }
      end

      # Silence logging, printing only FATAL messages
      def silence!
        self.logging_level = :fatal
      end

      def unsilence!(level = :info)
        self.logging_level = level
      end

      def init
        ::Logging.init LOG_LEVELS

        LOG_LEVELS.each do |level|
          Signalwire::Blade::Logging.const_defined?(level) or Signalwire::Blade::Logging.const_set(level, ::Logging::LEVELS[::Logging.levelify(level)])
        end
        DEBUG
        ::Logging.logger.root.appenders = default_appenders
      end

      def start(level = :info, formatter = nil)
        ::Logging.logger.root.level = level

        self.formatter = formatter if formatter
      end

      def default_appenders
        [
          ::Logging.appenders.stdout(
            'stdout',
            layout: ::Logging.layouts.pattern(pattern_options.merge(color_scheme: 'bright')),
            auto_flushing: 2,
            flush_period: 2
          )
        ]
      end

      def logging_level=(new_logging_level)
        ::Logging.logger.root.level = new_logging_level
      end

      alias :level= :logging_level=

      def logging_level
        ::Logging.logger.root.level
      end

      alias :level :logging_level

      def get_logger(logger_name)
        ::Logging::Logger[logger_name]
      end

      def sanitized_logger_name(name)
        name.to_s.gsub(/\W/, '').downcase
      end

      def formatter=(formatter)
        ::Logging.logger.root.appenders.each do |appender|
          appender.layout = formatter
        end
      end

      alias :layout= :formatter=

      def formatter
        ::Logging.logger.root.appenders.first.layout
      end

      alias :layout :formatter

      def edo
        ::Logging.logger[self]
      end
    end

    init unless ::Logging.const_defined? :MAX_LEVEL_LENGTH
  end
end
