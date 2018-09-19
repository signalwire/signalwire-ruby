# frozen_string_literal: true

module Twilio
  module REST
    class Domain
      def absolute_url(uri)
        "#{@base_url.chomp('/')}/#{uri.chomp('/').gsub(%r{^/(api/)/}, '')}"
      end
    end
  end
end
