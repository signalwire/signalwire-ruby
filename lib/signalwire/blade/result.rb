module Signalwire::Blade
  class Result
    attr_reader :id, :result

    def initialize(id, result)
      @id = id
      @result = result
    end

    def [](key)
      @result[key]
    end

    def to_json
      {
        jsonrpc: '2.0',
        id: id,
        result: result
      }.to_json
    end
  end
end
