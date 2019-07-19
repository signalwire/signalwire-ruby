# frozen_string_literal: true

module MockHelpers
  def mock_message(obj, message)
    obj.broadcast :message, Signalwire::Blade::Message.new(message)
  end

  def relay_response(id, code = '200', message = 'Some message goes here')
    {
      id: id,
      result: {
        result: {
          code: code,
          message: message
        }
      }
    }
  end

  def mock_call_hash(state = 'created')
    mock_relay_message({
      "event_type": 'calling.call.receive',
      "timestamp": 1558539404.4556861,
      "project_id": 'myproject123',
      "space_id": 'fmyspace345',
      "params": {
        "call_state": state,
        "context": 'incoming',
        "device": {
          "type": 'phone',
          "params": {
            "from_number": '+15556667778',
            "to_number": '15559997777'
          }
        },
        "direction": 'inbound',
        "call_id": 'fb102ad7-4479-42a9-88ac-999999999999',
        "node_id": '2f25c10f-68cd-4b0c-8259-999999999999'
      },
      "event_channel": 'signalwire_calling_abc123'
    })
  end

  def mock_call_state(call_id, state=Relay::CallState::ANSWERED)
    mock_relay_message({
      "event_type": "calling.call.state",
      "event_channel": "signalwire_calling-999999999999",
      "timestamp": 1558539404.79576,
      "project_id": 'fmyspace345',
      "space_id": 'fmyspace345',
      "params": {
        "call_state": state,
        "direction": "inbound",
        "device": {
          "type": "phone",
          "params": {
            "from_number": "+12029085665",
            "to_number": "12069286532"
          }
        },
        "call_id": call_id,
        "node_id": "2f25c10f-68cd-4b0c-8259-999999999999"
      }
    })
  end

  def mock_component_event(call_id, control_id, event_type='calling.call.play', state_property='state', state='finished')
    mock_relay_message({
      "event_type": event_type,
      "event_channel": "signalwire_calling-999999999999",
      "timestamp": 1558539404.79576,
      "project_id": 'myproject123',
      "space_id": 'fmyspace345',
      "params": {
        "#{state_property}": state,
        "call_id": call_id,
        "control_id": control_id,
        "node_id": "2f25c10f-68cd-4b0c-8259-999999999999"
      }
    })
  end

  def mock_relay_message(inner_message, event="relay")
    {
      "jsonrpc": "2.0",
      "id": "43358495-8fe8-43d1-8ed3-999999999999",
      "method": "blade.broadcast",
      "params": {
        "broadcaster_nodeid": "0f469957-9dbb-4492-ad21-999999999999",
        "protocol": "signalwire_calling-999999999999",
        "channel": "notifications",
        "event": event,
        "params": inner_message
      }
    }
  end

  def mock_relay_task(payload, context="incoming")
    mock_relay_message({
      "space_id": "fmyspace345",
      "project_id": "fmyspace345",
      "context": context,
      "message": payload,
      "timestamp": 1563551206
    }, "queuing.relay.tasks")
  end
end
