# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class SendDigitsAction < Action
    def result
      SendDigitsResult.new(component: @component)
    end
  end
end
