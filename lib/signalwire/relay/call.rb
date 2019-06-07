module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    attr_reader :id, :device, :type, :node_id, :context, :from, :to, :timeout, :tag, :client, :state, :previous_state

    def self.from_event(client, event)
      self.new(client, event.call_params)
    end

    def initialize(client, call_options)
      @client = client

      @id = call_options[:call_id] || SecureRandom.uuid
      @node_id = call_options[:node_id]
      @context = call_options[:context]
      @previous_state = nil
      @state = call_options[:call_state]
      @previous_connect_state = nil
      @connect_state = call_options[:connect_state]
      @device = call_options[:device]
      @type = @device[:type]

      @from = @device[:params][:from]
      @to = @device[:params][:to]
      @timeout = @device[:params][:timeout] || 30
      @tag = SecureRandom.uuid

      on :event, event_type: 'calling.call.state' do |event| 
        set_call_state(event.call_params[:call_state])
      end

      on :event, event_type: 'calling.call.connect' do |event| 
        set_connect_state(event.event_params[:connect_state])
      end
    end

    # NOTE: begin is a reserved word in Ruby
    def originate
      cmd = Signalwire::Relay::CallBegin.new(
        protocol: @client.protocol,
        from_number: @from,
        to_number: @to,
        timeout: @timeout,
        tag: @tag
      )
      @client.relay_execute(cmd) do |response|
        @id = response[:result][:call_id]
        @state = "created"
      end
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
      logger.info "blocking here"
      # return Signalwire::Relay::Calling::PlayMediaAction.new(call: self, control_id: control_id)
      block_until_response event_type: 'calling.call.play', states: 'finished'
    end

    def set_call_state(call_state)
      @previous_state = @state
      @state = call_state
      broadcast :call_state_change, {previous_state: @previous_state, state: @state}
      client.end_call(self.id) if call_state == 'ended'
    end

    def set_connect_state(new_connect_state)
      @previous_connect_state = @connect_state
      @connect_state = new_connect_state
      broadcast :connect_state_change, {previous_state: @previous_connect_state, state: @connect_state}
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

    def block_until_response(event_type:, states:)
      promise = Concurrent::Promises.resolvable_future
      states = Array(states).compact

      once :event, event_type: event_type do |event|
        if states.include?(event.call_params[:state])
          promise.fulfill event
        end
      end

      promise.wait Signalwire::Relay::SYNC_TIMEOUT

      if promise.fulfilled?
        return promise.value
      else
        logger.error "Response to #{event_type} failed"
        return false
      end
    end
  end
end