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
    call.play [{ "type": 'tts', "params": { "text": 'please leave your message after the beep. Press pound when done.', "language": 'en-US', "gender": 'male' } }]
    result = call.record({"audio": { "beep": "true", "terminators": "#"}})
    call.play [{ "type": 'tts', "params": { "text": 'you said:', "language": 'en-US', "gender": 'male' } }]
    call.play [{ "type": 'audio', "params": { "url": result.url } }]
    call.hangup
  end
end

OutboundConsumer.new.run
