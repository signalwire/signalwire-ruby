# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Sdk::VoiceResponse do
    it 'generates the correct LAML' do
      response = Signalwire::Sdk::VoiceResponse.new do |r|
        r.say(message: 'hello there', voice: 'alice')
        r.dial(caller_id: '+14159992222') do |d|
          d.client 'jenny'
        end
      end

      expect(response.to_s).to eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Response>\n"\
        "<Say voice=\"alice\">hello there</Say>\n<Dial callerId=\"+14159992222\">\n"\
        "<Client>jenny</Client>\n</Dial>\n</Response>\n"
    end
  end
end
