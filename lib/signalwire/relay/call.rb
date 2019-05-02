module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    attr_reader :id, :device, :type, :node_id, :context, :from, :to, :timeout, :tag

    def self.from_event(client, event)
      self.new(client, event.params)
    end

    def initialize(client, options)
      @client = client

      @id = options[:call_id]
      @node_id = options[:node_id]
      @context = options[:context]
      @device = options[:params][:device]
      @type = device[:type]

      @from = device[:params][:from]
      @to = device[:params][:to]
      @timeout = device[:params][:timeout] || 30
      @tag = SecureRandom.uuid
    end
  end
end