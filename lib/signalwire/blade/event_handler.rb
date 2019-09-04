# frozen_string_literal: true

require 'has_guarded_handlers'

module Signalwire::Blade
  module EventHandler
    include HasGuardedHandlers
    alias on register_handler
    alias once register_tmp_handler

    def broadcast(event_type, event)
      trigger_handler event_type, event, broadcast: true, exception_callback: Proc.new { |e| 
        logger.error "#{e.class}: #{e.message}"
        logger.error e.backtrace.join("\n")
      }
    end
  end
end
