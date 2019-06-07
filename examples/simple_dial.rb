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
    sleep 2
    call.hangup
  end
# begin
#   puts 'dialing'
#   call = client.calling.new_call(from: '+12069286532', to: '+12029085665')
#   puts 'call created'
#   call.originate
#   puts 'after originate?'
# rescue Exception => e
#   puts e.inspect
# end
end

client.connect!

# TODO
# call begin
# Idle/disconnect