$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
%w[
  bundler/setup
  signalwire
].each { |f| require f }

client = Signalwire::Relay::Client.new(project: ENV['SIGNALWIRE_ACCOUNT'], 
  token: ENV['SIGNALWIRE_TOKEN'], signalwire_space_url: ENV['SIGNALWIRE_SPACE_URL'])

client.on(:ready) do |client|
  client.calling.receive context: 'incoming' do |call|
    puts "CALL JUST CAME IN ==============="
    call.answer
    call.play [{ "type": "tts", "params": { "text": "the quick brown fox jumps over the lazy dog", "language": "en-US", "gender": "male" } }]
    call.hangup
  end
end

client.connect!
