# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

class OutboundConsumer < Signalwire::Relay::Consumer
  def ready
    logger.info 'Dialing out'
    call = client.calling.new_call(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER'])
    call.dial
    call.play [{ "type": 'tts', "params": { "text": 'the quick brown fox jumps over the lazy dog', "language": 'en-US', "gender": 'male' } }]
    call.hangup
  end
end

OutboundConsumer.new.run
