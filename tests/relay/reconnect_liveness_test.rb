# frozen_string_literal: true

require 'minitest/autorun'
require 'socket'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../../lib/signalwire'
require_relative '../../lib/signalwire/relay/client'

# F3 reconnect-liveness: the websocket-client-simple gem does NOT surface a peer
# close on its read thread (on EOF getc returns nil and it just sleeps+retries,
# never emitting :close), so the client must detect a peer TCP close itself and
# tear down so the reconnect loop runs. peer_closed? is that detector — a
# NON-consuming MSG_PEEK: a socket that peeks empty is at EOF (closed); a socket
# with bytes pending is a live frame the gem will read; a live idle socket is
# neither readable nor closed.
class ReconnectLivenessTest < Minitest::Test
  def setup
    ENV['SIGNALWIRE_RELAY_SCHEME'] = 'ws'
    @client = SignalWire::Relay::Client.new(project: 'p', token: 't', host: '127.0.0.1')
  end

  def test_peer_closed_true_when_socket_at_eof
    a, b = UNIXSocket.pair
    @client.instance_variable_set(:@ws, FakeWs.new(a))
    b.close # peer closed → a is at EOF

    assert @client.send(:peer_closed?), 'a socket whose peer closed must read as peer_closed?'
  ensure
    a&.close
  end

  def test_peer_closed_false_on_live_idle_socket
    a, b = UNIXSocket.pair
    @client.instance_variable_set(:@ws, FakeWs.new(a))

    refute @client.send(:peer_closed?), 'a live idle socket must not read as peer_closed?'
  ensure
    a&.close
    b&.close
  end

  def test_peer_closed_false_when_bytes_pending_not_consumed
    a, b = UNIXSocket.pair
    @client.instance_variable_set(:@ws, FakeWs.new(a))
    b.write('frame-bytes')

    refute @client.send(:peer_closed?), 'pending bytes are a live frame, not a close'
    # MSG_PEEK must not have consumed them — the gem still reads the full frame.
    assert_equal 'frame-bytes', a.read(11)
  ensure
    a&.close
    b&.close
  end

  def test_peer_closed_true_when_no_socket
    @client.instance_variable_set(:@ws, nil)

    assert @client.send(:peer_closed?)
  end

  # Minimal stand-in exposing @socket like websocket-client-simple's Client.
  class FakeWs
    def initialize(socket)
      @socket = socket
    end
  end
end
