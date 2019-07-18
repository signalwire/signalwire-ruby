# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

# Setup your ENV with:
# SIGNALWIRE_ACCOUNT=YOUR_SIGNALWIRE_ACCOUNT_ID
# SIGNALWIRE_TOKEN=YOUR_SIGNALWIRE_ACCOUNT_TOKEN
#
Signalwire::Logger.logger.level = ::Logger::DEBUG

class MyConsumer < Signalwire::Relay::Consumer
end

MyConsumer.new.run
