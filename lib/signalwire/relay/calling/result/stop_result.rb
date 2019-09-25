# This does not inherit from Result as it only represents a subcommand
#
module Signalwire::Relay::Calling
  class StopResult
    attr_reader :successful
    def initialize(result)
      @successful = result
    end
  end
end