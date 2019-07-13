# frozen_string_literal: true

require 'securerandom'

module Signalwire::Blade
  class Message
    extend Forwardable
    def_delegators :@payload, :[], :[]=, :dig

    def initialize(params = {})
      @payload = params
      @id = params[:id]
    end

    def id
      @id ||= SecureRandom.uuid
    end

    def payload
      @payload ||= {}
    end

    def build_request
      payload.merge(
        jsonrpc: '2.0',
        id: id
      )
    end

    def self.from_json(json_hash)
      new JSON.parse(json_hash, symbolize_names: true)
    end

    def to_s
      inspect
    end
  end
end
