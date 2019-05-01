RSpec.shared_context :mock_connection, :shared_context => :metadata do
  before do
    class MockConnection
      def start
      end
    end

    allow(Signalwire::Blade::Connection).to receive(:new).and_return(MockConnection.new)
  end
end