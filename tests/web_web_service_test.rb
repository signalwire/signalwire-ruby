# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'net/http'
require 'base64'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Real-behavior tests for SignalWire::Core -> SignalWire::Web::WebService
# (parity with Python's signalwire.web.web_service.WebService). The service
# actually binds WEBrick on an ephemeral port and serves real files; each test
# starts and stops the server so nothing hangs.
class WebWebServiceTest < Minitest::Test
  USER = 'webuser'
  PASS = 'webpass'

  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'hello.txt'), 'hello world')
    File.write(File.join(@dir, 'page.html'), '<h1>hi</h1>')
    File.write(File.join(@dir, '.env'), 'SECRET=1')
    @svc = SignalWire::Web::WebService.new(basic_auth: [USER, PASS])
    @svc.add_directory('/static', @dir)
    @port = @svc.start(host: '127.0.0.1', port: 0)
  end

  def teardown
    @svc.stop
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def get(path, auth: true)
    uri = URI("http://127.0.0.1:#{@port}#{path}")
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(USER, PASS) if auth
    Net::HTTP.start(uri.host, uri.port, read_timeout: 5) { |http| http.request(req) }
  end

  def test_serves_real_file_contents
    res = get('/static/hello.txt')

    assert_equal '200', res.code
    assert_equal 'hello world', res.body
  end

  def test_serves_html_with_security_headers
    res = get('/static/page.html')

    assert_equal '200', res.code
    assert_includes res.body, '<h1>hi</h1>'
    assert_equal 'nosniff', res['X-Content-Type-Options']
    assert_equal 'public, max-age=3600', res['Cache-Control']
  end

  def test_missing_file_is_not_found
    res = get('/static/does-not-exist.txt')

    assert_equal '404', res.code
  end

  def test_blocked_extension_is_forbidden
    res = get('/static/.env')

    assert_equal '403', res.code
  end

  def test_path_traversal_denied
    # Try to escape the served directory.
    res = get('/static/../../etc/passwd')

    assert_includes %w[403 404 400], res.code
    refute_includes res.body.to_s, 'root:'
  end

  def test_requires_auth
    res = get('/static/hello.txt', auth: false)

    assert_equal '401', res.code
  end

  def test_wrong_auth_rejected
    uri = URI("http://127.0.0.1:#{@port}/static/hello.txt")
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(USER, 'wrongpass')
    res = Net::HTTP.start(uri.host, uri.port, read_timeout: 5) { |http| http.request(req) }

    assert_equal '401', res.code
  end

  def test_remove_directory_stops_serving_new_routes
    # remove_directory drops it from the map; a fresh server won't mount it.
    @svc.remove_directory('/static')

    refute @svc.directories.key?('/static')
  end

  def test_file_allowed_predicate
    assert @svc.file_allowed?(File.join(@dir, 'hello.txt'))
    refute @svc.file_allowed?(File.join(@dir, '.env'))
  end

  def test_start_returns_bound_ephemeral_port
    assert_operator @port, :>, 0
  end

  # The DEFAULT host must be '0.0.0.0' (listen on all interfaces), matching the
  # Python reference. Exercises the default path: start() is called with NO host:
  # kwarg, and we read back the address WEBrick was actually bound to.
  def test_default_host_binds_all_interfaces
    svc = SignalWire::Web::WebService.new(basic_auth: [USER, PASS])
    svc.add_directory('/static', @dir)
    svc.start(port: 0)

    server = svc.instance_variable_get(:@server)

    assert_equal '0.0.0.0', server.config[:BindAddress]
    assert_includes server.listeners.map { |l| l.addr[3] }, '0.0.0.0'
  ensure
    svc&.stop
  end

  # An explicit host: must still be honoured -- only the DEFAULT changed.
  def test_explicit_host_overrides_default
    svc = SignalWire::Web::WebService.new(basic_auth: [USER, PASS])
    svc.add_directory('/static', @dir)
    svc.start(host: '127.0.0.1', port: 0)

    server = svc.instance_variable_get(:@server)

    assert_equal '127.0.0.1', server.config[:BindAddress]
  ensure
    svc&.stop
  end
end
