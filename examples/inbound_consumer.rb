$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

class MyConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']

  def on_incoming_call(call)
    call.answer
    call.play [{ "type": "tts", "params": { "text": "the quick brown fox jumps over the lazy dog", "language": "en-US", "gender": "male" } }]
    call.hangup
  end
end

MyConsumer.new.run