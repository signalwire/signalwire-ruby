# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class TapAction < Action
    def_delegators :@component, :source_device

    def result
      TapResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
