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
    
    tap_arguments = { type: "audio", params: { direction: "listen" } }
    device_arguments = { type: "rtp", params: { addr: "127.0.0.1", port: 1234 } }

    call.tap_media(tap: tap_arguments, device: device_arguments)

    call.hangup
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

OutboundConsumer.new.run
