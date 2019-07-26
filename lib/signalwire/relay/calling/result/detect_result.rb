# frozen_string_literal: true

module Signalwire::Relay::Calling
  class DetectResult < Result
    def_delegators :@component, :type, :result
  end
end
