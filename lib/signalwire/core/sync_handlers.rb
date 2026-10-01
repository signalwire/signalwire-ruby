# frozen_string_literal: true

require 'monitor'

# Running synchronous user code — tool handlers, the per-request configuration
# callback, routing callbacks — from the agent's web endpoints.
#
# The built-in server (WEBrick, via {SignalWire::AgentBase#serve}) and any
# threaded Rack server serve each request on its own thread, so a synchronous
# handler that blocks (an HTTP request, say) holds up only its own request:
# handlers for different calls run concurrently and must guard shared state.
#
# Setting +SWML_SYNC_HANDLERS_INLINE+ to +1+, +true+ or +yes+ runs that user
# code one call at a time instead (serialized across requests), as earlier
# single-loop releases did.
module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # SyncHandlers — how the endpoints call synchronous user code.
    module SyncHandlers
      # Serializes user code when {sync_handlers_inline} is on. A Monitor, not a
      # Mutex, so a handler that itself runs another handler does not deadlock.
      INLINE_LOCK = Monitor.new
      private_constant :INLINE_LOCK

      module_function

      # True when +SWML_SYNC_HANDLERS_INLINE+ asks for one-call-at-a-time
      # (inline) handling.
      #
      # @return [Boolean]
      def sync_handlers_inline
        %w[1 true yes].include?(ENV.fetch('SWML_SYNC_HANDLERS_INLINE', '').strip.downcase)
      end

      # True for a callable whose invocation only STARTS the work, handing back
      # something to wait on (Python's +async def+). Ruby has no such callable:
      # a Proc, Method or +#call+ object runs to completion when called, so
      # nothing an endpoint is handed needs awaiting and this is always false.
      #
      # @param _obj [Object] the callable to inspect
      # @return [Boolean] false
      def is_async_callable(_obj)
        false
      end

      # Call +func+ with +args+: directly on the calling request's thread, or —
      # when {sync_handlers_inline} is set — one call at a time across requests.
      # The callable's exception, if any, propagates unchanged.
      #
      # @param func [#call] the synchronous callable
      # @param args [Array] its positional arguments
      # @param kwargs [Hash] its keyword arguments
      # @return [Object] the callable's result
      def run_sync_handler(func, *args, **kwargs)
        return func.call(*args, **kwargs) unless sync_handlers_inline

        INLINE_LOCK.synchronize { func.call(*args, **kwargs) }
      end
    end
  end
end
