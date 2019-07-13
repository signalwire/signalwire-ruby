# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class PlayAction < Action
    def result
      PlayResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
