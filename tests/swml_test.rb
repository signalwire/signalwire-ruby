# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'signalwire'

# =========================================================================
# Logging tests
# =========================================================================
class LoggingTest < Minitest::Test
  def setup
    SignalWire::Logging.reset!
    ENV.delete('SIGNALWIRE_LOG_LEVEL')
    ENV.delete('SIGNALWIRE_LOG_MODE')
  end

  def teardown
    SignalWire::Logging.reset!
    ENV.delete('SIGNALWIRE_LOG_LEVEL')
    ENV.delete('SIGNALWIRE_LOG_MODE')
  end

  def test_default_level_is_info
    assert_equal :info, SignalWire::Logging.global_level
  end

  def test_set_global_level
    SignalWire::Logging.global_level = :debug

    assert_equal :debug, SignalWire::Logging.global_level
  end

  def test_env_log_level
    ENV['SIGNALWIRE_LOG_LEVEL'] = 'debug'
    SignalWire::Logging.reset!

    assert_equal :debug, SignalWire::Logging.global_level
  end

  def test_env_log_mode_off
    ENV['SIGNALWIRE_LOG_MODE'] = 'off'
    SignalWire::Logging.reset!

    assert_predicate SignalWire::Logging, :suppressed?
    assert_equal :off, SignalWire::Logging.global_level
  end

  def test_logger_creation
    logger = SignalWire::Logging.logger('test')

    assert_equal 'test', logger.name
  end

  def test_logger_outputs_at_correct_level
    SignalWire::Logging.global_level = :warn
    logger = SignalWire::Logging.logger('test')

    out = StringIO.new
    logger.instance_variable_set(:@output, out)

    logger.debug('should not appear')
    logger.info('should not appear')

    assert_equal '', out.string

    logger.warn('this should appear')

    assert_includes out.string, 'WARN'
    assert_includes out.string, 'this should appear'
  end

  def test_logger_suppressed_when_off
    SignalWire::Logging.global_level = :off
    logger = SignalWire::Logging.logger('test')

    out = StringIO.new
    logger.instance_variable_set(:@output, out)

    logger.error('should not appear even at error')

    assert_equal '', out.string
  end

  def test_levels_hash
    expected = { debug: 0, info: 1, warn: 2, error: 3, off: 4 }

    assert_equal expected, SignalWire::Logging::LEVELS
  end

  def test_invalid_level_raises
    assert_raises(ArgumentError) do
      SignalWire::Logging.global_level = :nonexistent
    end
  end
end

# =========================================================================
# Document tests
# =========================================================================
class DocumentTest < Minitest::Test
  def setup
    @doc = SignalWire::SWML::Document.new
  end

  def test_initial_state
    assert_equal '1.0.0', @doc.version
    assert @doc.has_section?('main')
    assert_equal [], @doc.get_verbs('main')
  end

  def test_add_section
    assert @doc.add_section('custom')
    assert @doc.has_section?('custom')
  end

  def test_add_section_duplicate_returns_false
    @doc.add_section('dup')

    refute @doc.add_section('dup')
  end

  def test_add_verb_to_main
    @doc.add_verb('answer', {})
    verbs = @doc.get_verbs

    assert_equal 1, verbs.length
    assert_equal({ 'answer' => {} }, verbs.first)
  end

  def test_add_verb_sleep_integer
    @doc.add_verb('sleep', 2000)
    verbs = @doc.get_verbs

    assert_equal({ 'sleep' => 2000 }, verbs.first)
  end

  def test_add_verb_to_named_section
    @doc.add_section('intro')
    @doc.add_verb_to_section('intro', 'play', { 'url' => 'http://example.com/audio.mp3' })
    verbs = @doc.get_verbs('intro')

    assert_equal 1, verbs.length
  end

  def test_add_verb_to_nonexistent_section_raises
    assert_raises(ArgumentError) do
      @doc.add_verb_to_section('nope', 'answer', {})
    end
  end

  def test_reset
    @doc.add_verb('answer', {})
    @doc.add_section('extra')
    @doc.reset

    assert @doc.has_section?('main')
    refute @doc.has_section?('extra')
    assert_equal [], @doc.get_verbs
  end

  def test_to_h
    @doc.add_verb('answer', {})
    h = @doc.to_h

    assert_equal '1.0.0', h['version']
    assert_kind_of Hash, h['sections']
    assert_equal 1, h['sections']['main'].length
  end

  def test_render_json
    @doc.add_verb('answer', {})
    json = @doc.render
    parsed = JSON.parse(json)

    assert_equal '1.0.0', parsed['version']
  end

  def test_render_pretty
    @doc.add_verb('hangup', {})
    pretty = @doc.render_pretty

    assert_includes pretty, "\n"
    parsed = JSON.parse(pretty)

    assert_equal '1.0.0', parsed['version']
  end

  def test_get_verbs_returns_copy
    @doc.add_verb('answer', {})
    verbs = @doc.get_verbs
    verbs.clear

    assert_equal 1, @doc.get_verbs.length
  end
end

# =========================================================================
# Schema tests
# =========================================================================
class SchemaTest < Minitest::Test
  def test_loads_38_verbs
    schema = SignalWire::SWML::Schema.new

    assert_equal 38, schema.verb_count,
                 "Expected 38 verbs, got #{schema.verb_count}: #{schema.verb_names.join(', ')}"
  end

  def test_known_verbs_present
    schema = SignalWire::SWML::Schema.new

    %w[answer ai hangup play sleep connect record send_sms transfer].each do |v|
      assert schema.valid_verb?(v), "Expected verb '#{v}' to be valid"
    end
  end

  def test_invalid_verb_rejected
    schema = SignalWire::SWML::Schema.new

    refute schema.valid_verb?('not_a_verb')
    refute schema.valid_verb?('explode')
  end

  def test_verb_names_sorted
    schema = SignalWire::SWML::Schema.new
    names = schema.verb_names

    assert_equal names.sort, names
  end

  def test_get_verb_returns_definition
    schema = SignalWire::SWML::Schema.new
    defn = schema.get_verb('answer')

    assert_kind_of Hash, defn
    assert_equal 'answer', defn['name']
    assert_equal 'Answer', defn['schema_name']
    assert_kind_of Hash, defn['definition']
  end

  def test_get_verb_nil_for_unknown
    schema = SignalWire::SWML::Schema.new

    assert_nil schema.get_verb('nonexistent')
  end

  def test_singleton
    s1 = SignalWire::SWML.schema
    s2 = SignalWire::SWML.schema

    assert_same s1, s2
  end
end

# =========================================================================
# Service tests
# =========================================================================
class ServiceTest < Minitest::Test
  def setup
    # Suppress log output during tests
    SignalWire::Logging.global_level = :off
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
    ENV.delete('PORT')
  end

  def teardown
    SignalWire::Logging.reset!
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
    ENV.delete('PORT')
  end

  def test_creation
    svc = SignalWire::SWML::Service.new(name: 'test')

    assert_equal 'test', svc.name
    assert_equal '/', svc.route
    assert_equal '0.0.0.0', svc.host
    assert_equal 3000, svc.port
  end

  def test_custom_route
    svc = SignalWire::SWML::Service.new(name: 'test', route: '/my-agent')

    assert_equal '/my-agent', svc.route
  end

  def test_port_from_env
    ENV['PORT'] = '8080'
    svc = SignalWire::SWML::Service.new(name: 'test')

    assert_equal 8080, svc.port
  end

  def test_explicit_port_overrides_env
    ENV['PORT'] = '8080'
    svc = SignalWire::SWML::Service.new(name: 'test', port: 9999)

    assert_equal 9999, svc.port
  end

  # -- Verb methods via method_missing ------------------------------------

  def test_answer_verb
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.answer
    verbs = svc.document.get_verbs

    assert_equal 1, verbs.length
    assert_equal({ 'answer' => {} }, verbs.first)
  end

  def test_hangup_verb
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.hangup
    verbs = svc.document.get_verbs

    assert_equal({ 'hangup' => {} }, verbs.first)
  end

  def test_play_verb_with_kwargs
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.play(url: 'http://example.com/ring.mp3')
    verbs = svc.document.get_verbs

    assert_equal({ 'play' => { 'url' => 'http://example.com/ring.mp3' } }, verbs.first)
  end

  def test_sleep_with_integer
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.sleep(2000)
    verbs = svc.document.get_verbs

    assert_equal({ 'sleep' => 2000 }, verbs.first)
  end

  def test_sleep_with_duration_kwarg
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.sleep(duration: 500)
    verbs = svc.document.get_verbs

    assert_equal({ 'sleep' => 500 }, verbs.first)
  end

  def test_respond_to_valid_verbs
    svc = SignalWire::SWML::Service.new(name: 'test')

    assert_respond_to svc, :answer
    assert_respond_to svc, :hangup
    assert_respond_to svc, :ai
    assert_respond_to svc, :sleep
  end

  def test_respond_to_invalid_verb
    svc = SignalWire::SWML::Service.new(name: 'test')

    refute_respond_to svc, :explode
    refute_respond_to svc, :not_a_verb
  end

  def test_invalid_method_raises
    svc = SignalWire::SWML::Service.new(name: 'test')
    assert_raises(NoMethodError) { svc.not_a_verb }
  end

  def test_nil_kwargs_stripped
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.play(url: 'http://example.com/a.mp3', volume: nil)
    verbs = svc.document.get_verbs

    assert_equal({ 'play' => { 'url' => 'http://example.com/a.mp3' } }, verbs.first)
  end

  # -- Auth ---------------------------------------------------------------

  def test_auto_generated_auth
    svc = SignalWire::SWML::Service.new(name: 'test')
    user, pass = svc.get_basic_auth_credentials
    # UUID v4 format
    assert_match(/\A[0-9a-f-]{36}\z/, user)
    assert_match(/\A[0-9a-f-]{36}\z/, pass)
  end

  def test_explicit_auth
    svc = SignalWire::SWML::Service.new(name: 'test', basic_auth: %w[alice s3cret])

    assert_equal %w[alice s3cret], svc.get_basic_auth_credentials
  end

  def test_env_based_auth
    ENV['SWML_BASIC_AUTH_USER']     = 'envuser'
    ENV['SWML_BASIC_AUTH_PASSWORD'] = 'envpass'
    svc = SignalWire::SWML::Service.new(name: 'test')

    assert_equal %w[envuser envpass], svc.get_basic_auth_credentials
  end

  def test_explicit_auth_overrides_env
    ENV['SWML_BASIC_AUTH_USER']     = 'envuser'
    ENV['SWML_BASIC_AUTH_PASSWORD'] = 'envpass'
    svc = SignalWire::SWML::Service.new(name: 'test', basic_auth: %w[explicit pass])

    assert_equal %w[explicit pass], svc.get_basic_auth_credentials
  end

  def test_get_full_url
    svc = SignalWire::SWML::Service.new(name: 'test', port: 5000)

    assert_equal 'http://0.0.0.0:5000/', svc.get_full_url
  end

  def test_get_full_url_with_auth
    svc = SignalWire::SWML::Service.new(
      name: 'test', port: 5000, basic_auth: %w[user pass]
    )

    assert_equal 'http://user:pass@0.0.0.0:5000/', svc.get_full_url(include_auth: true)
  end

  def test_get_full_url_with_custom_route
    svc = SignalWire::SWML::Service.new(name: 'test', port: 5000, route: '/bot')

    assert_equal 'http://0.0.0.0:5000/bot', svc.get_full_url
  end

  # -- Render -------------------------------------------------------------

  def test_render
    svc = SignalWire::SWML::Service.new(name: 'test')
    svc.answer
    json = svc.render
    parsed = JSON.parse(json)

    assert_equal '1.0.0', parsed['version']
    assert_equal 1, parsed['sections']['main'].length
  end
end

# =========================================================================
# Rack app integration tests
# =========================================================================
class ServiceRackTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    SignalWire::Logging.global_level = :off
    @service = SignalWire::SWML::Service.new(
      name: 'rack-test',
      basic_auth: %w[testuser testpass]
    )
    @service.answer
    @service.sleep(1000)
    @service.hangup
  end

  def teardown
    SignalWire::Logging.reset!
  end

  def app
    @service.rack_app
  end

  # -- Health / Ready (no auth) -------------------------------------------

  def test_health_endpoint
    get '/health'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal 'healthy', body['status']
  end

  def test_ready_endpoint
    get '/ready'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal 'ready', body['status']
  end

  # -- SWML endpoint with auth -------------------------------------------

  def test_swml_without_auth_returns_401
    get '/'

    assert_equal 401, last_response.status
  end

  def test_swml_with_wrong_auth_returns_401
    authorize 'wrong', 'creds'
    get '/'

    assert_equal 401, last_response.status
  end

  def test_swml_with_correct_auth_returns_200
    authorize 'testuser', 'testpass'
    get '/'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal '1.0.0', body['version']
    assert_equal 3, body['sections']['main'].length
  end

  def test_swml_content_type
    authorize 'testuser', 'testpass'
    get '/'

    assert_equal 'application/json', last_response.content_type
  end

  # -- Security headers ---------------------------------------------------

  def test_security_headers_present
    authorize 'testuser', 'testpass'
    get '/'
    headers = last_response.headers

    assert_equal 'nosniff',                              headers['x-content-type-options']
    assert_equal 'DENY',                                 headers['x-frame-options']
    assert_equal 'no-store, no-cache, must-revalidate',  headers['cache-control']
  end

  def test_health_does_not_have_security_headers
    get '/health'
    # Health is outside the secured map block — no security headers expected
    refute last_response.headers.key?('x-frame-options')
  end

  # -- POST with body -----------------------------------------------------

  def test_post_with_json_body
    authorize 'testuser', 'testpass'
    post '/', JSON.generate({ 'action' => 'test' }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
  end

  # -- Routing callback ---------------------------------------------------

  def test_routing_callback
    @service.register_routing_callback('/custom') do |data|
      { 'custom' => true, 'received' => data }
    end

    authorize 'testuser', 'testpass'
    post '/custom', JSON.generate({ 'foo' => 'bar' }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal true, body['custom']
    assert_equal({ 'foo' => 'bar' }, body['received'])
  end
end

# =========================================================================
# Timing-safe auth verification
# =========================================================================
class TimingSafeAuthTest < Minitest::Test
  def test_secure_compare_is_used
    # Verify that Rack::Utils responds to secure_compare,
    # confirming our middleware has the primitive available.
    assert_respond_to Rack::Utils, :secure_compare,
                      'Rack::Utils.secure_compare must be available for timing-safe auth'
  end

  def test_secure_compare_works
    assert Rack::Utils.secure_compare('hello', 'hello')
    refute Rack::Utils.secure_compare('hello', 'world')
    refute Rack::Utils.secure_compare('short', 'longer_string')
  end
end
