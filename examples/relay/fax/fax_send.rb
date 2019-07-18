# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

Signalwire::Logger.logger.level = ::Logger::DEBUG

class OutboundConsumer < Signalwire::Relay::Consumer
  def ready
    call = client.calling.new_call(from: ENV['FAX_FROM_NUMBER'], to: ENV['FAX_TO_NUMBER'])
    call.dial
    call.fax_send("https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

OutboundConsumer.new.run
