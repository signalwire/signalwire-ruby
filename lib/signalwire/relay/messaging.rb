# frozen_string_literal: true

require 'forwardable'
require 'concurrent-ruby'

module Signalwire::Relay
  module Messaging
    class Instance
      extend Forwardable
      include Signalwire::Logger
      include Signalwire::Common

      def_delegators :@client, :relay_execute, :protocol, :on, :once, :broadcast

      def initialize(client)
        @client = client
      end
    end
  end
end