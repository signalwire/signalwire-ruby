# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class RecordAction < Action
    def result
      RecordResult.new(@component)
    end

    def stop
      @component.stop
    end
  end
end
