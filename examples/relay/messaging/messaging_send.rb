# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

# Set logging to debug for testing
Signalwire::Logger.logger.level = ::Logger::DEBUG

class MessageSendConsumer < Signalwire::Relay::Consumer
  def ready
    logger.debug "Sending an SMS to #{ENV['TO_NUMBER']}"
    result = client.messaging.send(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER'], context: 'incoming', body: 'hello world!')
    logger.debug "message id #{result.message_id} was successfully sent" if result.successful
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

MessageSendConsumer.new.run
