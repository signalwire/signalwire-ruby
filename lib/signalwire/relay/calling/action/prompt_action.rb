# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class PromptAction < Action
    def result
      PromptResult.new(component: @component)
    end

    def stop
      @component.stop
    end

    def volume(setting)
      @component.volume setting
    end
  end
end
