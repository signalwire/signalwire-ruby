require 'spec_helper'

describe Signalwire::Relay::Calling::Detect do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  let(:detect) do
    {
      "type": "machine",
      "params": {
        "initial_timeout": 5.0
      }
    }
  end

  let(:wait_for_beep) { false }
  subject { described_class.new(call: call, detect: detect, wait_for_beep: wait_for_beep) }

  context "No wait for beep" do

    describe "#execute_params" do
      it "has the correct payload" do
        expect(subject.execute_params).to eq({
          method: subject.method,
          protocol: client.protocol,
          params: {
            call_id: call.id,
            control_id: subject.control_id,
            detect: detect,
            node_id:call.node_id,
            timeout: 30
          }
        })
      end
    end

    describe "#notification_handler" do
      let(:mock_detect_event) do
        Signalwire::Relay::Event.new({
          params: { params: { params: {
            detect: {
              type: event_type,
              params: {
                event: event_value
              }
            }
          }}}
        })
      end

      describe "digits" do
        let(:detect) { { type: :digit, params: {} } }
        let(:event_type) { 'digit' }
        let(:event_value) { '1' }

        it "unblocks on a digit" do
          subject.notification_handler(mock_detect_event)
          expect(subject.state).to eq '1'
          expect(subject.completed).to eq true
        end
      end


      describe "machine" do
        let(:detect) { { type: :machine, params: {} } }
        let(:event_type) { 'machine' }
        let(:event_value) { 'MACHINE' }

        it "unblocks on a READY" do
          subject.notification_handler(mock_detect_event)
          expect(subject.state).to eq 'MACHINE'
        end
      end
    end
  end

  context "Finishing calls" do
    describe "On complete" do
      let(:detect) { { type: :machine, params: {} } }
      let(:event_type) { 'machine' }
      let(:event_value) { 'finished' }

      let(:mock_detect_event) do
        Signalwire::Relay::Event.new({
          params: { params: { params: {
            detect: {
              type: event_type,
              params: {
                event: event_value
              }
            }
          }}}
        })
      end

      it "returns successful as true" do
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:has_blocker?).and_return(true)
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:unblock)

        subject.notification_handler(mock_detect_event)

        expect(subject.successful).to be true
      end

      it "returns type as machine" do
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:has_blocker?).and_return(true)
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:unblock)

        subject.notification_handler(mock_detect_event)

        expect(subject.type).to eq 'machine'
      end

      it "returns result as 'finished'" do
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:has_blocker?).and_return(true)
        allow_any_instance_of(Signalwire::Relay::Calling::Detect).to receive(:unblock)

        subject.notification_handler(mock_detect_event)

        expect(subject.result).to eq 'finished'
      end
    end
  end
end
