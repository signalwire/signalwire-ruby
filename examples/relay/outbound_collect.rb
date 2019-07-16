# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

class OutboundConsumer < Signalwire::Relay::Consumer
  def ready
    call = client.calling.new_call(from: ENV['FROM_NUMBER'], to: ENV['TO_NUMBER']).dial
    collect_params = { "initial_timeout": 10.0, "digits": { "max": 1, "digit_timeout": 5.0 } }
    result = call.prompt_tts( collect_params, 'how many hamburgers would you like to order?')

    call.play_tts "You ordered #{result.result} hamburgers. Thank you!"
    call.hangup
  end
end

OutboundConsumer.new.run
