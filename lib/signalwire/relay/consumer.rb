module Signalwire::Relay
  class Consumer
    include ::Signalwire::Blade::Logging::HasLogger
    attr_accessor :client
  
    class << self
      def contexts(val = nil)
        if val.nil?
          @contexts || []
        else
          @contexts = val
        end
      end
    end
  
    def initialize
      @client = Signalwire::Relay::Client.new(project: ENV['SIGNALWIRE_ACCOUNT'], 
        token: ENV['SIGNALWIRE_TOKEN'], signalwire_space_url: ENV['SIGNALWIRE_SPACE_URL'])
    end
  
    def setup
      # do stuff here.
    end
  
    def teardown
      # do stuff here. Maybe raise if not implemented?
    end
  
    def on_event(event)
      # all-events firespout
    end
  
    def on_incoming_call(call)
    end
  
    def run
      client.on :ready do
        setup
        setup_receive_listeners
        setup_all_events_listener
        # not sure if ordering matters
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
          self.on_incoming_call(call)
        end
      end
    end
  
    def setup_all_events_listener
      client.on :event do |evt| 
        self.on_event(evt)
      end
    end
  end
end