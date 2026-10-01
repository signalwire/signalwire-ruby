# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative '../lib/signalwire/utils/url_validator'
require_relative '../lib/signalwire/skills/builtin/spider'

# The session user-supplied URLs are fetched through: every request (and every
# redirect hop) is checked, and a private/internal/invalid URL raises before any
# connection. Parity: signalwire-python utils/url_validator.py _PublicSession,
# skills/spider/skill.py SpiderSkill.session.
class UtilsPublicSessionTest < Minitest::Test
  UV = SignalWire::Utils::UrlValidator

  def setup
    @saved_env = ENV.fetch('SWML_ALLOW_PRIVATE_URLS', nil)
    ENV.delete('SWML_ALLOW_PRIVATE_URLS')
    # Hermetic DNS: a literal IP resolves to itself, internal.test to a private
    # address, any other name to a public one (never connected to here).
    UV._resolver = lambda do |host|
      next [host] if host.match?(/\A[\d.]+\z/)

      { 'internal.test' => ['10.0.0.7'] }.fetch(host, ['93.184.216.34'])
    end
  end

  def teardown
    UV._resolver = nil
    @saved_env.nil? ? ENV.delete('SWML_ALLOW_PRIVATE_URLS') : ENV['SWML_ALLOW_PRIVATE_URLS'] = @saved_env
  end

  def test_private_address_is_refused_before_connecting
    err = assert_raises(UV::BlockedURLError) { UV::PublicSession.new.get('http://internal.test/x') }
    assert_match(/private, internal or invalid/, err.message)
  end

  def test_loopback_and_bad_scheme_are_refused
    assert_raises(UV::BlockedURLError) { UV::PublicSession.new.get('http://127.0.0.1:9/') }
    assert_raises(UV::BlockedURLError) { UV::PublicSession.new.get('file:///etc/passwd') }
  end

  def test_spider_fetches_through_a_public_session_carrying_its_headers
    skill = SignalWire::Skills::Builtin::SpiderSkill.new(nil, { 'user_agent' => 'ua/1', 'headers' => { 'X-T' => '1' } })

    assert_kind_of UV::PublicSession, skill.session
    assert_equal({ 'X-T' => '1', 'User-Agent' => 'ua/1' }, skill.session.headers)
  end

  def test_spider_scrape_of_a_private_url_yields_no_content
    skill = SignalWire::Skills::Builtin::SpiderSkill.new(nil, {})

    assert_nil skill.send(:fetch_text, 'http://internal.test/admin')
  end
end
