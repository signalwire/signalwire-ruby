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
    collect_params = { "initial_timeout": 10.0, "digits": { "max": 1, "digit_timeout": 5.0 } }
    result = dial_result.call.prompt_tts( collect_params, 'how many hamburgers would you like to order?')

    dial_result.call.play_tts "You ordered #{result.result} hamburgers. Thank you!"
    dial_result.call.hangup
  # this makes it so the errors don't stop the process
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

OutboundConsumer.new.run
