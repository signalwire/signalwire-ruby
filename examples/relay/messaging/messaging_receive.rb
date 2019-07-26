# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

# Set logging to debug for testing
Signalwire::Logger.logger.level = ::Logger::DEBUG

class MessageSendConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']

  def on_message(message)
    logger.info "Received message from #{message.from_number}: #{message.body}"
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

MessageSendConsumer.new.run
