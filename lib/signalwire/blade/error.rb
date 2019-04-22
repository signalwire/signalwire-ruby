module Signalwire::Blade
  class Error < Request
    attr_reader :error

    def initialize(id, error)
      @id = id
      @error = error
    end

    def [](key)
      @error[key]
    end

    def to_json
      {
        jsonrpc: '2.0',
        id: @id,
        error: @error
      }.to_json
    end
  end
end
