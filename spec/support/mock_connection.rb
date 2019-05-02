RSpec.shared_context :mock_connection, :shared_context => :metadata do
  before do
    class MockConnection
      def start
      end

      def transmit(message)
      end
    end

    def trigger_handler_on_session(event, obj)
      subject.session.trigger_handler event, obj
    end

    allow(Signalwire::Blade::Connection).to receive(:new).and_return(MockConnection.new)
  end
end