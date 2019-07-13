# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Sdk::FaxResponse do
    it 'generates the correct LAML' do
      response = Signalwire::Sdk::FaxResponse.new do |r|
        r.receive(action: '/receive/fax')
      end

      expect(response.to_s).to eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Response>\n"\
        "<Receive action=\"/receive/fax\"/>\n</Response>\n"
    end

    it 'can reject a fax' do
      response = Signalwire::Sdk::FaxResponse.new(&:reject)

      expect(response.to_s).to eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Response>\n"\
        "<Reject/>\n</Response>\n"
    end
  end
end
