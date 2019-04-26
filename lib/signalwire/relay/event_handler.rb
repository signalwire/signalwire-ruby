require 'has_guarded_handlers'

module Signalwire::Relay
  module EventHandler
    include HasGuardedHandlers
    alias_method :on, :register_handler
    alias_method :once, :register_tmp_handler
  end
end