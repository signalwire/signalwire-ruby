# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

class OutboundConsumer < Signalwire::Relay::Consumer
  def ready
    call = client.calling.new_call(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER'])
    call.dial
    collect_params = { "initial_timeout": 10.0, "digits": { "max": 1, "digit_timeout": 5.0 } }
    play_params = [{ "type": 'tts', "params": { "text": 'how many hamburgers would you like to order?', "language": 'en-US', "gender": 'male' } }]
    puts "prompting"
    result = call.prompt( collect_params, play_params)

    puts result.result
    call.play [{ "type": 'tts', "params": { "text": "You ordered #{result.result} hamburgers. Thank you!", "language": 'en-US', "gender": 'male' } }]
    call.hangup
  rescue Exception => e
    puts e.inspect
    puts e.backtrace
  end
end

OutboundConsumer.new.run
