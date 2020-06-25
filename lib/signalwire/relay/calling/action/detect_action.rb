# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class DetectAction < Action
    def result
      DetectResult.new(component: @component)
    end

    def stop
      @component.stop
    end
  end
end
