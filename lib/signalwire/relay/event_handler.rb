require 'has_guarded_handlers'

module Signalwire::Relay
  module EventHandler
    include HasGuardedHandlers
    alias_method :on, :register_handler
    alias_method :once, :register_tmp_handler

    def broadcast(event_type, event)
      trigger_handler event_type, event, broadcast: true
    end
  end
end