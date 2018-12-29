# frozen_string_literal: true
require 'twilio-ruby/twiml/fax_response'

module Signalwire::Sdk
  class FaxResponse < Twilio::TwiML::FaxResponse
    # Create a new <Reject> element
    # keyword_args:: additional attributes
    def reject(reason: nil, **keyword_args)
      append(Reject.new(**keyword_args))
    end
    
    # <Leave> TwiML Verb
    class Reject < ::Twilio::TwiML::TwiML
      def initialize(**keyword_args)
        super(**keyword_args)
        @name = 'Reject'

        yield(self) if block_given?
      end
    end
  end
end

