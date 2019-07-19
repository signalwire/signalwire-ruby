# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class FaxAction < Action
    def result
      FaxResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
