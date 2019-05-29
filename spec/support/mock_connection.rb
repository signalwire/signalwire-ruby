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

    def receive_relay_result(id, code = 200)
      payload = { result: {
        code: code.to_s,
        message: "Some message"
        } 
      }

      result = be Signalwire::Blade::Result.new(id, payload)

      trigger_handler_on_session :event, result
    end

    def mock_call_hash(state = 'created')
      {
        params: { 
          event_type: "calling.call.receive",
          timestamp: 1556806325.677053,
          project_id: "myproject123",
          space_id: "myspace345",
          params: {
            call_state: state,
            context: "incoming",
            device: {
                type: "phone",
                params: {
                  from_number: "+15556667778",
                  to_number: "+15559997777"
                }
              },
            direction: "inbound",
            call_id: "0495a5a7-ce9b-40e8-94ce-67e616c98d1c",
            node_id: "some-node-id" 
          }
        }
      } 
    end

    allow(Signalwire::Blade::Connection).to receive(:new).and_return(MockConnection.new)
  end
end