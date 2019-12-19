# frozen_string_literal: true

module Signalwire::Blade
    class Ping < Message
      # Creates a Ping message
      #

      def initialize
        @payload = {
          method: 'blade.ping',
          params: {}
        }
      end
    end
  end
  