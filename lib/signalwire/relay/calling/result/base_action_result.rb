# frozen_string_literal: true

module Signalwire::Relay::Calling
  class BaseActionResult
    attr_reader :successful
    def initialize(result)
      @successful = result
    end
  end
end
