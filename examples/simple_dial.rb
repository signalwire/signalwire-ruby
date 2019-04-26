$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

client = Signalwire::Relay::Client.new(project: ENV['SIGNALWIRE_ACCOUNT'], 
  token: ENV['SIGNALWIRE_TOKEN'], signalwire_space_url: ENV['SIGNALWIRE_SPACE_URL'])