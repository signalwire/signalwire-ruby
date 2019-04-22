module Signalwire::Blade
  class Event
    attr_accessor :type, :payload
    def initialize(type, payload = nil)
      @type = type
      @payload = payload
    end
  end
end
