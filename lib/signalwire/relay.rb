require 'signalwire/blade'
require 'signalwire/relay/event_handler'
require 'signalwire/relay/event'
require 'signalwire/relay/calling'
require 'signalwire/relay/call'
require 'signalwire/relay/client'
require 'signalwire/relay/consumer'
require 'signalwire/relay/requests/protocol_setup_request'
require 'signalwire/relay/requests/subscribe_notifications_request'
require 'signalwire/relay/requests/call_receive'
require 'signalwire/relay/requests/call_begin'
require 'signalwire/relay/requests/call_execute'

module Signalwire
  module Relay
    SYNC_TIMEOUT = ENV.fetch('RELAY_SYNC_TIMEOUT', 5).to_i
  end
end