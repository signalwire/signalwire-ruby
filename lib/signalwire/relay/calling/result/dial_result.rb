# frozen_string_literal: true

module Signalwire::Relay::Calling
  class DialResult < Result
    def_delegators :@component, :call
  end
end
