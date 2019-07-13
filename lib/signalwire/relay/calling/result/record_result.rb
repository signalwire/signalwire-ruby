# frozen_string_literal: true

module Signalwire::Relay::Calling
  class RecordResult < Result
    def_delegators :@component, :url, :duration, :size
  end
end
