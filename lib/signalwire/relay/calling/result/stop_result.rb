# This does not inherit from Result as it only represents a subcommand
#
module Signalwire::Relay::Calling
  attr_reader :successful
  class StopResult
    def initialize(result)
      @successful = result
    end
  end
end