# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/spider'

class SpiderSkillDetailedTest < Minitest::Test
  def test_register_tools_returns_three_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})

    assert skill.setup
    tools = skill.register_tools

    assert_equal 3, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'scrape_url'
    assert_includes names, 'crawl_site'
    assert_includes names, 'extract_structured_data'
  end

  def test_custom_tool_prefix
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({ 'tool_name' => 'myspider' })
    skill.setup
    tools = skill.register_tools
    names = tools.map { |t| t[:name] }

    assert_includes names, 'myspider_scrape_url'
  end

  def test_supports_multiple_instances
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})

    assert_predicate skill, :supports_multiple_instances?
  end

  def test_get_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'scrape'
    assert_includes hints, 'crawl'
  end

  def test_remove_xpaths_is_prefilled
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})

    assert_equal ['//script', '//style', '//nav', '//header', '//footer', '//aside', '//noscript'],
                 skill.remove_xpaths
  end

  def test_strip_html_drops_every_remove_xpath_element_with_its_content
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})
    html = '<nav>MENU</nav><header>HEAD</header><script>CODE</script>' \
           '<style>CSS</style><aside>SIDE</aside><noscript>NOJS</noscript>' \
           '<p>keep me</p><footer>FOOT</footer>'
    text = skill.send(:strip_html, html)

    assert_equal 'keep me', text
  end

  def test_strip_html_honours_a_mutated_remove_xpaths
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})
    skill.remove_xpaths.delete('//nav')
    text = skill.send(:strip_html, '<nav>MENU</nav><p>body</p>')

    assert_equal 'MENU body', text
  end

  def test_strip_html_skips_non_simple_xpath_expressions
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})
    skill.remove_xpaths.replace(['//div[@class="ad"]'])
    text = skill.send(:strip_html, '<div class="ad">AD</div><p>body</p>')

    assert_equal 'AD body', text
  end

  def test_scrape_empty_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('spider')
    skill = factory.call({})
    skill.setup
    tools = skill.register_tools
    handler = tools.find { |t| t[:name] == 'scrape_url' }[:handler]
    result = handler.call({ 'url' => '' }, {})

    assert_includes result.response, 'provide a URL'
  end
end
