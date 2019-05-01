$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

client = Signalwire::Relay::Client.new(project: ENV['SIGNALWIRE_ACCOUNT'], 
  token: ENV['SIGNALWIRE_TOKEN'], signalwire_space_url: ENV['SIGNALWIRE_SPACE_URL'])

client.on(:ready) do |client|
  puts "client is ready"
  msg = Signalwire::Relay::CallBegin.new(protocol: client.protocol, from_number: '+12069286532', to_number: '+12029085665')
  client.execute(msg)
end

client.connect!
