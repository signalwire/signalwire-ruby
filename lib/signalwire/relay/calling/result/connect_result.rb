# frozen_string_literal: true

module Signalwire::Relay::Calling
  class ConnectResult < Result
    def call
      @component.call.peer
    end
  end
end
