$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

Signalwire::Logger.logger.level = ::Logger::DEBUG

MY_NUMBER = "+12027621401"

class MyConsumer < Signalwire::Relay::Consumer
  contexts ['incoming']
  def on_incoming_call(call)
    call.answer
    call.play_tts 'Welcome to Relay'
    dial = call.connect [[{ type: 'phone', params: { to_number: MY_NUMBER, from_number: call.from, timeout: 30 } }]]
    pp "Connected"
    pp dial.successful
    dial.call.play_tts "Hello!" if dial.successful
    pp "Waiting on Ending"
    dial.call.wait_for_ending
    call.play_tts 'finished. hanging up.'
    call.hangup
  rescue StandardError => e
    logger.error e.inspect
    logger.error e.backtrace
  end
end

MyConsumer.new.run