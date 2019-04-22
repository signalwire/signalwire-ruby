require "securerandom"

module Signalwire::Blade
  class Request
    attr_reader :id, :params

    def initialize(method, params = {})
      @id = new_id
      @method = method
      @params = params
    end

    def to_json
      {
        jsonrpc: '2.0',
        id: id,
        method: method,
        params: params
      }.to_json
    end

    def new_id
      @id = SecureRandom.uuid
    end

    def method
      @method
    end

    def params
      @params
    end
  end
end
