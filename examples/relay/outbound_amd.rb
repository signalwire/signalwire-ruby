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
    result = call.amd(timeout: 10, wait_for_beep: true)
    pp "---------------------------------- Detect AM result was:"
    pp result.type
    pp result.result
    pp result.successful

    call.hangup
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

OutboundConsumer.new.run
