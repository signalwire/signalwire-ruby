# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

Signalwire::Logger.logger.level = ::Logger::DEBUG

class MyConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']

  def on_incoming_call(call)
    call.answer
    fax_result = call.fax_receive
    logger.debug "Received a fax: #{fax_result.document} that is #{fax_result.pages} pages long"
    call.hangup
  end
end

MyConsumer.new.run
