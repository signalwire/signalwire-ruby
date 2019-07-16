# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

# Setup your ENV with:
# SIGNALWIRE_ACCOUNT=YOUR_SIGNALWIRE_ACCOUNT_ID
# SIGNALWIRE_TOKEN=YOUR_SIGNALWIRE_ACCOUNT_TOKEN
#
# Set logging to debug for testing
Signalwire::Logger.logger.level = ::Logger::DEBUG

class MyConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']

  def on_incoming_call(call)
    call.answer
    call.play_tts 'connecting you to the clock service'
    call.connect [[{ type: 'phone', params: { to_number: '+12027621401', from_number: ENV['FROM_NUMBER'], timeout: 30 } }]]
    sleep 20
    call.hangup
  end
end

MyConsumer.new.run
