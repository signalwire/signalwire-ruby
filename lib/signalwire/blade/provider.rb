module Signalwire::Blade
  module Provider
    def self.included(base)
      base.extend(Signalwire::Blade::Logging::HasLogger)
      base.include(Signalwire::Blade::Logging::HasLogger)
      base.extend(ClassMethods)
    end

    def initialize(id, method)
      @id = id
      @method = method
    end

    def respond(response)
      raise ArgumentError.new("Provider should respond with a Hash. #{response.class} given.") unless response.is_a?(Hash)
      if response.has_key? :error
        self.class.session.execute(Blade::Error.new(@id, response[:error]))
      elsif response.has_key? :result
        self.class.session.execute(Blade::Result.new(@id, response[:result]))
      else
        logger.error "Unknown response: #{response}."
      end
    end

    module ClassMethods
      def provides(*providers)
        @providers = providers
      end

      def run
        check_requirements
        connect
      end

      def dispatch(id:, method:, params:)
        instance = self.new(id, method)
        instance.process(params: params.to_h)
      rescue => exception
        logger.error "Provider dispatch exception: #{exception.inspect} #{exception.backtrace}"
      end

      def session
        @session ||= Session.new
      end

      private

      def connect
        session.once :connected do
          register_providers
        end

        session.start!
      end

      def register_providers
        @providers.each do |provider|
          session.on :incomingcommand, method: provider do |payload|
            dispatch(id: payload.id, method: payload.method, params: payload.params)
          end
        end
      end

      def check_requirements
        raise ArgumentError, "At least one provider is required." if @providers.nil? || @providers.count == 0
      end

    end
  end
end
