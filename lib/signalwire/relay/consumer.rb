# frozen_string_literal: true

module Signalwire::Relay
  class Consumer
    include Signalwire::Logger
    attr_reader :client, :project, :token

    class << self
      def contexts(val = nil)
        if val.nil?
          @contexts || []
        else
          @contexts = val
        end
      end
    end

    # Creates a Consumer instance ready to be run
    #
    # The initialization parameters can also be supplied via ENV variables
    # (SIGNALWIRE_ACCOUNT, SIGNALWIRE_TOKEN and SIGNALWIRE_HOST)
    # Passed-in values override the environment ones.
    #
    # @param project [String] Your SignalWire project identifier
    # @param token [String] Your SignalWire secret token
    # @param SIGNALWIRE_HOST [String] Your SignalWire space URL (not needed for production usage)

    def initialize(project: nil, token: nil, host: nil)
      @project = project   || ENV['SIGNALWIRE_ACCOUNT']
      @token =   token     || ENV['SIGNALWIRE_TOKEN']
      @url =     host  || ENV['SIGNALWIRE_HOST'] || Signalwire::Relay::DEFAULT_URL
      @client = Signalwire::Relay::Client.new(project: @project,
        token: @token, host: @url)
    end

    def setup
      # do stuff here.
    end

    def ready
      # do stuff here.
    end

    def teardown
      # do stuff here.
    end

    def on_task(task); end

    def on_message(message); end

    def on_event(event)
      # all-events firespout
    end

    def on_incoming_call(call); end

    def run
      setup
      client.once :ready do
        setup_receive_listeners
        setup_all_events_listener
        setup_task_listeners
        setup_messaging_listeners
        ready
      end
      client.connect!
    end

    def stop
      teardown
      client.disconnect!
    end

  private

    def setup_receive_listeners
      self.class.contexts.each do |cxt|
        client.calling.receive context: cxt do |call|
          on_incoming_call(call)
        end
      end
    end

    def setup_task_listeners
      client.on :task do |task|
        on_task(task)
      end
    end

    def setup_all_events_listener
      client.on :event do |evt|
        on_event(evt)
      end
    end

    def setup_messaging_listeners
      client.messaging.on :message_received do |evt|
        on_message(evt)
      end
    end
  end
end
