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
    dial_result = client.calling.new_call(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER']).dial
    tts = [{ type: 'tts', params: { text: 'Say something funny!' } }]
    result = dial_result.call.prompt collect: {speech: {language: 'en-US'}}, play: tts
    dial_result.call.play_tts text: "You ordered #{result.result} hamburgers. Thank you!"
    dial_result.call.hangup
  # this makes it so the errors don't stop the process
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

OutboundConsumer.new.run
