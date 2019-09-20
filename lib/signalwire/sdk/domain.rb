# frozen_string_literal: true

module Twilio
  module REST
    class Domain
      def absolute_url(uri)
        if Signalwire::Sdk.configuration.service_provider == 'twilio'
          "#{@base_url.chomp('/')}/#{uri.chomp('/').gsub(/^\//, '')}"
        else
          "#{@base_url.chomp('/')}/#{uri.chomp('/').gsub(%r{^/(api/)/}, '')}"
        end
      end
    end
  end
end
