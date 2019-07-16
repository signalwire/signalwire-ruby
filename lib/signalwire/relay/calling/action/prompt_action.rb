# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class PromptAction < Action
    def result
      PromptResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
