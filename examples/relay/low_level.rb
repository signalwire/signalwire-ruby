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
    call.play [{ "type": 'tts', "params": { "text": 'the quick brown fox jumps over the lazy dog', "language": 'en-US', "gender": 'male' } }]

    # async example
    # action = call.play! [{ "type": "tts", "params": { "text": "the quick brown fox jumps over the lazy dog" * 5, "language": "en-US", "gender": "male" } }]
    # sleep 5
    # action.stop

    call.hangup
  end
end

MyConsumer.new.run
