module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    attr_reader :id, :device, :type, :node_id, :context, :from, :to, :timeout, :tag, :client, :state

    def self.from_event(client, event)
      self.new(client, event.params[:params][:params])
    end

    def initialize(client, call_options)
      @client = client

      @id = call_options[:call_id] || SecureRandom.uuid
      @node_id = call_options[:node_id]
      @context = call_options[:context]
      @state = call_options[:call_state]
      @device = call_options[:device]
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
      execute_call_command method: 'call.end', params: params
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
      return Signalwire::Relay::Calling::PlayMediaAction.new(call: self, control_id: control_id)
    end

    def execute_call_command(method:, params:)
      promise = Concurrent::Promises.resolvable_future

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