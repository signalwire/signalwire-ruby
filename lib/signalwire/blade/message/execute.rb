# frozen_string_literal: true

module Signalwire::Blade
  class Execute < Message
    # Creates an Execute message
    #
    # @param params [Hash] The "params" portion of the execute
    def initialize(params = {})
      @payload =
        {
          method: 'blade.execute',
          params: params
        }
    end
  end
end
