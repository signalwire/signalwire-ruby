# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class SendDigitsAction < Action
    def result
      SendDigitsResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
