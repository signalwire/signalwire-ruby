# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

# Set logging to debug for testing
Signalwire::Logger.logger.level = ::Logger::DEBUG

class OutboundConsumer < Signalwire::Relay::Consumer
  def ready
    logger.info 'Dialing out'
    call = client.calling.new_call(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER'])
    call.dial
    call.play_tts sentence: 'please leave your message after the beep. Press pound when done.'
    result = call.record({"audio": { "beep": "true", "terminators": "#"}})
    call.play_tts sentence: 'you said:'
    call.play_audio result.url
    call.hangup
  end
end

OutboundConsumer.new.run
