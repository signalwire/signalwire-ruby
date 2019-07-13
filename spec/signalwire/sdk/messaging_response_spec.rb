# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Sdk::MessagingResponse do
    it 'generates the correct LAML' do
      response = Signalwire::Sdk::MessagingResponse.new do |r|
        r.message body: 'hello from a SignalWire SMS'
      end

      expect(response.to_s).to eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Response>\n"\
        "<Message>hello from a SignalWire SMS</Message>\n</Response>\n"
    end
  end
end
