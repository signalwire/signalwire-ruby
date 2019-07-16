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
class MyConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']

  def on_incoming_call(call)
    call.answer
    call.play_tts 'the quick brown fox jumps over the lazy dog'

    call.hangup
  end
end

MyConsumer.new.run
