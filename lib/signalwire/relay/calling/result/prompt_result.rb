# frozen_string_literal: true

module Signalwire::Relay::Calling
  class PromptResult < Result
    def_delegators :@component, :type, :terminator, :confidence

    def result
      @component.input
    end
  end
end
