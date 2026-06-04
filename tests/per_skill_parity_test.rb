# frozen_string_literal: true

# Per-skill hook-override parity tests.
#
# Closes the cross-port gap where six per-skill hook overrides existed in the
# Python reference but not (visibly) in the Ruby port:
#
#   DateTimeSkill#get_parameter_schema   (TS)
#   DateTimeSkill#setup                  (php)
#   MathSkill#get_parameter_schema       (TS)
#   MathSkill#setup                      (java, php, dotnet)
#   SpiderSkill#cleanup                  (TS)
#   WikipediaSearchSkill#search_wiki     (TS, perl)
#
# Each test drives the *real* method (no mocking the thing under test) and
# asserts on real content. The two network-backed methods (spider scrape and
# wikipedia search) are exercised end-to-end against a local WEBrick fixture
# reached via the skills' own SPIDER_BASE_URL / WIKIPEDIA_BASE_URL overrides —
# so the actual fetch/parse code path runs, not a stand-in.

require 'minitest/autorun'
require 'webrick'
require 'json'
require 'socket'

require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/skills/skill_base'
require_relative '../lib/signalwire/skills/skill_registry'
require_relative '../lib/signalwire/skills/builtin/datetime'
require_relative '../lib/signalwire/skills/builtin/math'
require_relative '../lib/signalwire/skills/builtin/spider'
require_relative '../lib/signalwire/skills/builtin/wikipedia_search'

# ---------------------------------------------------------------------------
# Tiny local HTTP fixture. A block decides each response based on the request;
# returns [content_type, body] (or nil for 404). Bound to an ephemeral port on
# loopback so tests never touch the network or the shared mock server.
# ---------------------------------------------------------------------------
class LocalHTTPFixture
  attr_reader :port

  def initialize(&handler)
    @handler = handler
    @port = pick_free_port
    @server = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1',
      Port: @port,
      Logger: WEBrick::Log.new(File.open(File::NULL, 'w'), WEBrick::Log::FATAL),
      AccessLog: []
    )
    @server.mount_proc('/') do |req, res|
      result = @handler.call(req)
      if result.nil?
        res.status = 404
        res.body = 'not found'
      else
        content_type, body = result
        res.status = 200
        res['Content-Type'] = content_type
        res.body = body
      end
    end
    @thread = Thread.new { @server.start }
    wait_until_ready
  end

  def base_url
    "http://127.0.0.1:#{@port}"
  end

  def shutdown
    @server&.shutdown
    @thread&.join(5)
  end

  private

  def pick_free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  def wait_until_ready
    20.times do
      TCPSocket.new('127.0.0.1', @port).close
      return
    rescue Errno::ECONNREFUSED
      sleep 0.05
    end
  end
end

# ---------------------------------------------------------------------------
# DateTimeSkill / MathSkill: setup + get_parameter_schema overrides
# ---------------------------------------------------------------------------
class DateTimeSkillHookParityTest < Minitest::Test
  def build
    SignalWire::Skills::SkillRegistry.get_factory('datetime').call({})
  end

  def test_setup_returns_true_and_loads_stdlib
    skill = build
    assert_equal true, skill.setup, 'datetime setup should report the skill is ready'
    # setup requires the stdlib it depends on; if it returned true those are loadable.
    assert defined?(Time), 'Time must be available after datetime setup'
    assert defined?(Date), 'Date must be available after datetime setup'
  end

  def test_get_parameter_schema_returns_base_schema
    skill = build
    schema = skill.get_parameter_schema
    assert_kind_of Hash, schema
    # Python: DateTimeSkill.get_parameter_schema returns only the base schema
    # (no custom params). The override delegates to super, so it must equal
    # what the base class produces.
    base = SignalWire::Skills::SkillBase.instance_method(:get_parameter_schema)
                                        .bind(skill).call
    assert_equal base, schema, 'datetime schema must be exactly the base-class schema'
  end

  def test_get_parameter_schema_is_own_public_method
    # The audit enumerator only sees public_instance_methods(false); the
    # override must be defined directly on DateTimeSkill, not just inherited.
    klass = SignalWire::Skills::Builtin::DateTimeSkill
    assert_includes klass.public_instance_methods(false), :get_parameter_schema
    assert_includes klass.public_instance_methods(false), :setup
  end
end

class MathSkillHookParityTest < Minitest::Test
  def build
    SignalWire::Skills::SkillRegistry.get_factory('math').call({})
  end

  def test_setup_returns_true
    assert_equal true, build.setup, 'math setup should report the skill is ready'
  end

  def test_get_parameter_schema_returns_base_schema
    skill = build
    schema = skill.get_parameter_schema
    assert_kind_of Hash, schema
    base = SignalWire::Skills::SkillBase.instance_method(:get_parameter_schema)
                                        .bind(skill).call
    assert_equal base, schema, 'math schema must be exactly the base-class schema'
  end

  def test_overrides_are_own_public_methods
    klass = SignalWire::Skills::Builtin::MathSkill
    assert_includes klass.public_instance_methods(false), :get_parameter_schema
    assert_includes klass.public_instance_methods(false), :setup
  end
end

# ---------------------------------------------------------------------------
# SpiderSkill#cleanup: real teardown of the response cache.
# ---------------------------------------------------------------------------
class SpiderSkillCleanupParityTest < Minitest::Test
  HTML = '<html><head><title>T</title><script>x()</script></head>' \
         '<body><p>Hello spider world</p></body></html>'

  def setup
    @fixture = LocalHTTPFixture.new do |_req|
      ['text/html', HTML]
    end
    ENV['SPIDER_BASE_URL'] = @fixture.base_url
  end

  def teardown
    ENV.delete('SPIDER_BASE_URL')
    @fixture&.shutdown
  end

  def build
    skill = SignalWire::Skills::SkillRegistry.get_factory('spider').call({})
    assert skill.setup
    skill
  end

  def test_cleanup_clears_populated_cache_and_is_idempotent
    skill = build
    scrape = skill.register_tools[0][:handler]

    # Drive a real fetch so the cache gets populated by real behavior.
    result = scrape.call({ 'url' => 'http://example.test/page' }, {})
    body = result.respond_to?(:response) ? result.response.to_s : result.to_s
    assert_includes body, 'Hello spider world', 'scrape should return extracted text'

    cache = skill.instance_variable_get(:@cache)
    refute_nil cache, 'cache should be present while the skill is live'
    refute_empty cache, 'a successful scrape should populate the cache'

    # cleanup must tear the cache down...
    assert_nil skill.cleanup, 'cleanup returns nil (Python parity: returns None)'
    assert_nil skill.instance_variable_get(:@cache), 'cleanup must drop the cache'

    # ...and be safe to call again.
    assert_nil skill.cleanup
  end

  def test_cleanup_is_own_public_method
    klass = SignalWire::Skills::Builtin::SpiderSkill
    assert_includes klass.public_instance_methods(false), :cleanup
  end
end

# ---------------------------------------------------------------------------
# WikipediaSearchSkill#search_wiki: real two-step lookup against a fixture.
# ---------------------------------------------------------------------------
class WikipediaSearchWikiParityTest < Minitest::Test
  EXTRACT = 'Ruby is a dynamic, open source programming language.'

  def setup
    # Fixture serves the two Wikipedia API shapes search_wiki actually calls:
    # list=search (step 1) and prop=extracts (step 2).
    @fixture = LocalHTTPFixture.new do |req|
      q = req.query
      if q['list'] == 'search'
        body = {
          'query' => {
            'search' => [{ 'title' => 'Ruby (programming language)', 'snippet' => 'snip' }]
          }
        }
        ['application/json', JSON.generate(body)]
      elsif q['prop'] == 'extracts'
        body = {
          'query' => {
            'pages' => { '12345' => { 'title' => 'Ruby (programming language)', 'extract' => EXTRACT } }
          }
        }
        ['application/json', JSON.generate(body)]
      end
    end
    ENV['WIKIPEDIA_BASE_URL'] = @fixture.base_url
  end

  def teardown
    ENV.delete('WIKIPEDIA_BASE_URL')
    @fixture&.shutdown
  end

  def build
    skill = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search').call({})
    skill.setup
    skill
  end

  def test_search_wiki_returns_formatted_article_text
    result = build.search_wiki('ruby language')
    assert_kind_of String, result
    # Real formatted output: bold title header + the extract body.
    assert_includes result, '**Ruby (programming language)**'
    assert_includes result, EXTRACT
  end

  def test_search_wiki_returns_no_results_message_when_empty
    # Repoint the fixture at an empty search result to exercise that branch.
    empty = LocalHTTPFixture.new do |req|
      if req.query['list'] == 'search'
        ['application/json', JSON.generate({ 'query' => { 'search' => [] } })]
      end
    end
    ENV['WIKIPEDIA_BASE_URL'] = empty.base_url
    begin
      skill = build
      result = skill.search_wiki('nonexistent topic zzz')
      assert_kind_of String, result
      assert_includes result.downcase, "couldn't find"
      refute_includes result, '**', 'no-results message should not be a formatted article'
    ensure
      empty.shutdown
    end
  end

  def test_search_wiki_is_own_public_method
    klass = SignalWire::Skills::Builtin::WikipediaSearchSkill
    assert_includes klass.public_instance_methods(false), :search_wiki,
                    'search_wiki must be public so the surface enumerator picks it up'
  end
end
