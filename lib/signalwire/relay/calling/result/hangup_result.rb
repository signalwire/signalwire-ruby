# frozen_string_literal: true

module Signalwire::Relay::Calling
  class HangupResult < Result
    def_delegators :@component, :reason
  end
end
