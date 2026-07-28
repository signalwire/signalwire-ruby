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

# The WebService Authorization guard, over the real WEBrick listener.
#
# RFC 7235 makes the auth-scheme token case-INSENSITIVE and RFC 7617 requires a
# colon in the decoded Basic payload. The reference (fastapi.security.http
# HTTPBasic) partitions the header on the FIRST space, compares
# `scheme.lower() != "basic"`, then does
# `username, separator, password = data.partition(":")` and raises when
# `separator` is empty. Ruby used a fixed-offset `header[6..]` slice (which both
# hardcoded the scheme length and could not match a lowercase scheme) and
# discarded the separator into `_sep`, so `Basic <b64("webuser")>` -- no colon
# at all -- parsed as username "webuser" with a defaulted empty password.
class WebWebServiceAuthSchemeTest < Minitest::Test
  USER = WebWebServiceTest::USER
  PASS = WebWebServiceTest::PASS

  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'hello.txt'), 'hello world')
    @services = []
  end

  def teardown
    @services.each(&:stop)
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  # Start a WebService on an ephemeral port; returns the port. Registered for
  # teardown so nothing is left listening.
  def serve(password)
    svc = SignalWire::Web::WebService.new(basic_auth: [USER, password])
    svc.add_directory('/static', @dir)
    port = svc.start(host: '127.0.0.1', port: 0)
    @services << svc
    port
  end

  def get_with_header(port, header)
    uri = URI("http://127.0.0.1:#{port}/static/hello.txt")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = header
    Net::HTTP.start(uri.host, uri.port, read_timeout: 5) { |http| http.request(req) }
  end

  def basic(scheme, payload)
    "#{scheme} #{Base64.strict_encode64(payload)}"
  end

  # --- case-insensitive scheme: ACCEPT ---------------------------------------

  def test_lowercase_basic_scheme_is_accepted
    port = serve(PASS)

    %w[basic BASIC BaSiC Basic].each do |scheme|
      res = get_with_header(port, basic(scheme, "#{USER}:#{PASS}"))

      assert_equal '200', res.code, "scheme #{scheme.inspect} must authenticate (RFC 7235)"
    end
  end

  # --- case-insensitive scheme: still REJECT the wrong ones ------------------

  def test_wrong_schemes_are_still_rejected
    port = serve(PASS)

    %w[Digest Negotiate Basicx basicx Bearer].each do |scheme|
      res = get_with_header(port, basic(scheme, "#{USER}:#{PASS}"))

      assert_equal '401', res.code, "scheme #{scheme.inspect} must NOT authenticate"
    end
  end

  def test_schemeless_header_is_rejected
    port = serve(PASS)
    res = get_with_header(port, Base64.strict_encode64("#{USER}:#{PASS}"))

    assert_equal '401', res.code
  end

  # --- the colon is mandatory ------------------------------------------------

  def test_colonless_basic_payload_is_rejected
    port = serve('')
    res = get_with_header(port, basic('Basic', USER))

    assert_equal '401', res.code, 'a colon-less Basic payload must be rejected'
  end

  def test_explicit_trailing_colon_is_a_valid_empty_password
    port = serve('')
    res = get_with_header(port, basic('Basic', "#{USER}:"))

    assert_equal '200', res.code, 'an explicit trailing colon IS a separator'
  end

  def test_password_containing_a_colon_keeps_everything_after_the_first
    port = serve('p:a:s:s')
    res = get_with_header(port, basic('Basic', "#{USER}:p:a:s:s"))

    assert_equal '200', res.code
  end
end
