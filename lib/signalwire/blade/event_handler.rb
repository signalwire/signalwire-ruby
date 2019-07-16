# frozen_string_literal: true

require 'has_guarded_handlers'

module Signalwire::Blade
  module EventHandler
    include HasGuardedHandlers
    alias on register_handler
    alias once register_tmp_handler

    def broadcast(event_type, event)
      trigger_handler event_type, event, broadcast: true
    end
  end
end
