# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class Action
    extend Forwardable
    attr_reader :component

    def_delegators :@component, :control_id, :payload, :completed, :state

    def initialize(component:)
      @component = component
    end
  end
end
