# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class ConnectAction < Action
    def result
      ConnectResult.new(@component)
    end
  end
end
