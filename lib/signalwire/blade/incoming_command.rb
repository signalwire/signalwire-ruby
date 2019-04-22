module Signalwire::Blade
  # This is created FROM JSON upon receiving a command
  class IncomingCommand < Request
    attr_reader :id, :method, :params

    def initialize(id, method, params = {})
      @id = id
      @method = method
      @params = params
    end
  end
end
