# frozen_string_literal: true

module Signalwire::Relay::Calling
  class FaxResult < Result
    def_delegators :@component, :direction, :identity, :remote_identity, :document, :pages
  end
end
