# frozen_string_literal: true

module Signalwire::Relay::Calling
  class TapResult < Result
    def_delegators :@component, :tap_media, :source_device, :device
  end
end
