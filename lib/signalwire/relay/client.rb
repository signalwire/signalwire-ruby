module Signalwire::Relay
  class Client
    attr_accessor :calls, :project
    def initialize(project:, token:, signalwire_space_url: nil)
      @project = project
      @token = token
      @space_url = signalwire_space_url || ENV.fetch['SIGNALWIRE_SPACE_URL'] ||
      raise(ArgumentError,
        'SignalWire Space URL is not configured. Enter your SignalWire Space domain via the '\
        'SIGNALWIRE_SPACE_URL environment variables, or the signalwire_space_url parameter')
      @calls = {}
    end
  end
end