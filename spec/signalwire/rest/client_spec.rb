# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe REST::Client do
    it 'makes the correct request' do
      Signalwire::Sdk.configure do |config|
        config.hostname = 'myswspace.signalwire.com'
      end

      @client = Signalwire::REST::Client.new 'MYSWPROJECT',
                                             'MYSWTOKEN'

      stub = stub_request(:post, 'https://myswspace.signalwire.com/api/laml/2010-04-01/Accounts/MYSWPROJECT/Messages.json')
             .with(body: { 'Body' => 'This is a message from the Signalwire-Ruby library!',
                           'From' => '+15556677999', 'To' => '+15558866555' })

      @message = @client.messages.create(
        from: '+15556677999',
        to: '+15558866555',
        body: 'This is a message from the Signalwire-Ruby library!'
      )

      expect(stub).to have_been_requested
    end
  end
end
