module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    attr_reader :id, :device, :type, :node_id, :context, :from, :to, :timeout, :tag

    def self.from_event(client, event)
      puts  event.params.inspect
      self.new(client, event.params)
    end

    def initialize(client, options)
      @client = client

      @id = options[:call_id]
      @node_id = options[:node_id]
      @context = options[:context]
      @device = options[:params][:params][:device]
      @type = @device[:type]

      @from = @device[:params][:from]
      @to = @device[:params][:to]
      @timeout = @device[:params][:timeout] || 30
      @tag = SecureRandom.uuid
    end

    def answer
      params = {node_id: node_id, call_id: id}
      execute_call_command method: 'call.answer', params: params
    end

    def hangup
      params = {node_id: node_id, call_id: id, reason: 'hangup'}
      execute_call_command method: 'call.hangup', params: params
    end

    def play(media)
      control_id = SecureRandom.uuid

      params = {
        node_id: node_id,
        call_id: id,
        control_id: control_id,
        play: media
      }

      execute_call_command method: 'call.play', params: params
    end

    def execute_call_command(method:, params:)
      future = Concurrent::Promises.resolvable_future

      @client.relay_execute Signalwire::Relay::CallExecute.new(protocol: @client.protocol, method: method, params: params) do |response|
        promise.fulfill response
      end

      promise.wait Signalwire::Relay::SYNC_TIMEOUT

      if promise.fulfilled?
        logger.debug "Response to #{method} with #{params}: #{promise.value}"
        return promise.value
      else
        logger.error "Requesting #{method} with #{params} failed"
        return false
      end
    end
  end
end