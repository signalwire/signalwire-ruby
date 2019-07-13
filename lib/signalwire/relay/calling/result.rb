# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class Result
    extend Forwardable
    attr_reader :component

    def_delegators :@component, :successful, :event

    def initialize(component:)
      @component = component
    end
  end
end
