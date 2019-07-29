$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire/relay/task
].each { |f| require f }

task = Signalwire::Relay::Task.new(
  project: ENV['SIGNALWIRE_PROJECT_KEY'],
  token: ENV['SIGNALWIRE_TOKEN'],
  host: ENV['SIGNALWIRE_HOST']
)

task.deliver(context: 'incoming', message: { foo: 'bar' })