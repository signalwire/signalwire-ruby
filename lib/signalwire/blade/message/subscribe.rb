# frozen_string_literal: true

module Signalwire::Blade
  class Subscribe < Message
    # Creates a Subscribe message
    #
    # @param params   [Hash] The "params" portion of the message
    def initialize(params = {})
      @payload = {
        method: 'blade.subscription',
        params: params
      }
    end
  end
end
