# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../../lib/signalwire/pom/prompt_object_model'

# Cross-port parity tests for SignalWire::POM::PromptObjectModel and Section.
#
# These tests assert the **exact** rendered shape (not just substrings) of
# Markdown, XML, JSON, and YAML output for the canonical scenarios that
# Python's ``signalwire.pom.pom`` emits. The Ruby port must reproduce the
# same byte-for-byte output so cross-language POM documents interoperate.
#
# The Python source-of-truth lives at:
#   /home/devuser/src/signalwire-python/tests/unit/pom/test_pom_render_parity.py
#   /home/devuser/src/signalwire-python/tests/unit/pom/test_pom_object_model.py
#
# When you change rendering behaviour in either port, update the parity
# fixtures in BOTH languages.
class PromptObjectModelTest < Minitest::Test
  POM = SignalWire::POM::PromptObjectModel
  Section = SignalWire::POM::Section

  # ---------------------------------------------------------------------------
  # Empty POM
  # ---------------------------------------------------------------------------

  def test_empty_pom_has_no_sections
    pom = POM.new

    assert_equal [], pom.sections
  end

  def test_empty_render_markdown_is_empty_string
    assert_equal '', POM.new.render_markdown
  end

  def test_empty_render_xml_is_just_prompt_tags
    expected = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<prompt>\n</prompt>"

    assert_equal expected, POM.new.render_xml
  end

  def test_empty_to_json_is_empty_array
    assert_equal '[]', POM.new.to_json
  end

  def test_empty_to_yaml
    assert_equal "[]\n", POM.new.to_yaml
  end

  # ---------------------------------------------------------------------------
  # Single-section basics
  # ---------------------------------------------------------------------------

  def test_add_section_returns_section_instance
    pom = POM.new
    section = pom.add_section('Greeting')

    assert_kind_of Section, section
    assert_equal 'Greeting', section.title
  end

  def test_add_section_appears_in_sections
    pom = POM.new
    pom.add_section('A')
    pom.add_section('B')

    assert_equal %w[A B], pom.sections.map(&:title)
  end

  def test_add_section_with_string_bullets_wraps
    # Python parity: when bullets is a string, wrap it into a single-element list.
    pom = POM.new
    s = pom.add_section('S', body: 'b', bullets: 'one')

    assert_equal ['one'], s.bullets
  end

  def test_only_first_section_can_have_no_title
    pom = POM.new
    pom.add_section(nil, body: 'first')
    err = assert_raises(ArgumentError) { pom.add_section(nil, body: 'second') }
    assert_match(/Only the first section can have no title/, err.message)
  end

  # ---------------------------------------------------------------------------
  # find_section
  # ---------------------------------------------------------------------------

  def test_find_section_returns_match
    pom = POM.new
    pom.add_section('Greeting', body: 'Hello')
    section = pom.find_section('Greeting')

    refute_nil section
    assert_equal 'Greeting', section.title
  end

  def test_find_section_returns_nil_when_absent
    assert_nil POM.new.find_section('Nope')
  end

  def test_find_section_recurses_into_subsections
    pom = POM.new
    s = pom.add_section('Outer', body: 'ob')
    s.add_subsection('Inner', body: 'ib')
    found = pom.find_section('Inner')

    refute_nil found
    assert_equal 'ib', found.body
  end

  # ---------------------------------------------------------------------------
  # Section basics
  # ---------------------------------------------------------------------------

  def test_section_with_title_only
    s = Section.new('Hello', body: 'b')

    assert_equal 'Hello', s.title
  end

  def test_section_add_body_replaces
    # Python parity: ``add_body`` replaces, not appends.
    s = Section.new('X', body: 'initial')
    s.add_body('replacement')

    assert_equal 'replacement', s.body
    md = s.render_markdown

    assert_includes md, 'replacement'
    refute_includes md, 'initial'
  end

  def test_section_add_bullets_appends
    s = Section.new('X', bullets: ['existing'])
    s.add_bullets(%w[one two])

    assert_equal %w[existing one two], s.bullets
  end

  def test_section_add_subsection_returns_section
    parent = Section.new('P', body: 'pb')
    child = parent.add_subsection('C', body: 'cb')

    assert_kind_of Section, child
    assert_equal 'C', child.title
    assert_includes parent.subsections, child
  end

  def test_section_add_subsection_nil_title_raises
    parent = Section.new('P', body: 'pb')
    err = assert_raises(ArgumentError) { parent.add_subsection(nil, body: 'b') }
    assert_match(/Subsections must have a title/, err.message)
  end

  def test_section_body_must_be_string
    err = assert_raises(TypeError) { Section.new('X', body: 123) }
    assert_match(/body must be a string/, err.message)
  end

  def test_section_bullets_must_be_array
    err = assert_raises(TypeError) { Section.new('X', body: 'b', bullets: 'oops') }
    assert_match(/bullets must be an Array/, err.message)
  end

  # ---------------------------------------------------------------------------
  # Exact-string rendering parity (mirrors test_pom_render_parity.py)
  # ---------------------------------------------------------------------------

  def test_render_markdown_simple_section_exact
    pom = POM.new
    pom.add_section('Greeting', body: 'Hello world')

    assert_equal "## Greeting\n\nHello world\n", pom.render_markdown
  end

  def test_render_xml_simple_section_exact
    pom = POM.new
    pom.add_section('Greeting', body: 'Hello world')
    expected =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
      "<prompt>\n  " \
      "<section>\n    " \
      "<title>Greeting</title>\n    " \
      "<body>Hello world</body>\n  " \
      "</section>\n" \
      '</prompt>'

    assert_equal expected, pom.render_xml
  end

  def test_render_markdown_with_bullets
    pom = POM.new
    pom.add_section('Goals', body: 'Be helpful', bullets: ['Be concise', 'Be clear'])
    expected = "## Goals\n\nBe helpful\n\n- Be concise\n- Be clear\n"

    assert_equal expected, pom.render_markdown
  end

  def test_render_xml_with_bullets
    pom = POM.new
    pom.add_section('Goals', body: 'Be helpful', bullets: ['Be concise', 'Be clear'])
    expected =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
      "<prompt>\n  " \
      "<section>\n    " \
      "<title>Goals</title>\n    " \
      "<body>Be helpful</body>\n    " \
      "<bullets>\n      " \
      "<bullet>Be concise</bullet>\n      " \
      "<bullet>Be clear</bullet>\n    " \
      "</bullets>\n  " \
      "</section>\n" \
      '</prompt>'

    assert_equal expected, pom.render_xml
  end

  def test_render_markdown_with_subsection
    pom = POM.new
    s = pom.add_section('Top', body: 'Top body')
    s.add_subsection('Sub1', body: 'Sub1 body', bullets: %w[a b])
    expected = "## Top\n\nTop body\n\n### Sub1\n\nSub1 body\n\n- a\n- b\n"

    assert_equal expected, pom.render_markdown
  end

  def test_render_xml_with_subsection
    pom = POM.new
    s = pom.add_section('Top', body: 'Top body')
    s.add_subsection('Sub1', body: 'Sub1 body', bullets: %w[a b])
    expected =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
      "<prompt>\n  " \
      "<section>\n    " \
      "<title>Top</title>\n    " \
      "<body>Top body</body>\n    " \
      "<subsections>\n      " \
      "<section>\n        " \
      "<title>Sub1</title>\n        " \
      "<body>Sub1 body</body>\n        " \
      "<bullets>\n          " \
      "<bullet>a</bullet>\n          " \
      "<bullet>b</bullet>\n        " \
      "</bullets>\n      " \
      "</section>\n    " \
      "</subsections>\n  " \
      "</section>\n" \
      '</prompt>'

    assert_equal expected, pom.render_xml
  end

  def test_render_markdown_numbered_propagates_to_siblings
    pom = POM.new
    pom.add_section('S1', body: 'b1', numbered: true)
    pom.add_section('S2', body: 'b2')
    expected = "## 1. S1\n\nb1\n\n## 2. S2\n\nb2\n"

    assert_equal expected, pom.render_markdown
  end

  def test_render_xml_numbered_propagates
    pom = POM.new
    pom.add_section('S1', body: 'b1', numbered: true)
    pom.add_section('S2', body: 'b2')
    expected =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
      "<prompt>\n  " \
      "<section>\n    " \
      "<title>1. S1</title>\n    " \
      "<body>b1</body>\n  " \
      "</section>\n  " \
      "<section>\n    " \
      "<title>2. S2</title>\n    " \
      "<body>b2</body>\n  " \
      "</section>\n" \
      '</prompt>'

    assert_equal expected, pom.render_xml
  end

  def test_render_markdown_numbered_bullets
    pom = POM.new
    pom.add_section('X', bullets: %w[one two], numbered_bullets: true)
    expected = "## X\n\n1. one\n2. two\n"

    assert_equal expected, pom.render_markdown
  end

  def test_render_xml_numbered_bullets_use_id_attr
    pom = POM.new
    pom.add_section('X', bullets: %w[one two], numbered_bullets: true)
    expected =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
      "<prompt>\n  " \
      "<section>\n    " \
      "<title>X</title>\n    " \
      "<bullets>\n      " \
      "<bullet id=\"1\">one</bullet>\n      " \
      "<bullet id=\"2\">two</bullet>\n    " \
      "</bullets>\n  " \
      "</section>\n" \
      '</prompt>'

    assert_equal expected, pom.render_xml
  end

  # ---------------------------------------------------------------------------
  # JSON / YAML round-trip with exact key order
  # ---------------------------------------------------------------------------

  def test_to_json_exact_shape
    pom = POM.new
    s = pom.add_section('A', body: 'ab')
    s.add_subsection('A1', body: 'a1b', bullets: ['x'])
    expected = <<~JSON.chomp
      [
        {
          "title": "A",
          "body": "ab",
          "subsections": [
            {
              "title": "A1",
              "body": "a1b",
              "bullets": [
                "x"
              ]
            }
          ]
        }
      ]
    JSON
    assert_equal expected, pom.to_json
  end

  def test_to_yaml_exact_shape
    pom = POM.new
    s = pom.add_section('A', body: 'ab')
    s.add_subsection('A1', body: 'a1b', bullets: ['x'])
    expected =
      "- title: A\n  " \
      "body: ab\n  " \
      "subsections:\n  " \
      "- title: A1\n    " \
      "body: a1b\n    " \
      "bullets:\n    " \
      "- x\n"

    assert_equal expected, pom.to_yaml
  end

  def test_from_json_round_trip_preserves_structure
    pom = POM.new
    s = pom.add_section('A', body: 'ab')
    s.add_subsection('A1', body: 'a1b', bullets: %w[x y])
    json_str = pom.to_json
    restored = POM.from_json(json_str)

    assert_equal json_str, restored.to_json
  end

  def test_from_yaml_round_trip_preserves_structure
    pom = POM.new
    s = pom.add_section('A', body: 'ab')
    s.add_subsection('A1', body: 'a1b', bullets: %w[x y])
    yaml_str = pom.to_yaml
    restored = POM.from_yaml(yaml_str)

    assert_equal yaml_str, restored.to_yaml
  end

  def test_from_yaml_accepts_array_input
    # Python parity: from_yaml accepts either a YAML string OR a parsed
    # Array of Hash section descriptors.
    data = [{ 'title' => 'B', 'body' => 'y' }]
    pom = POM.from_yaml(data)

    refute_nil pom.find_section('B')
  end

  def test_from_json_validates_required_content
    bad = '[{"title":"Only title"}]'
    err = assert_raises(ArgumentError) { POM.from_json(bad) }
    assert_match(/non-empty body, non-empty bullets, or subsections/, err.message)
  end

  def test_from_json_validates_subsection_title
    bad = '[{"title":"P","subsections":[{"body":"x"}]}]'
    err = assert_raises(ArgumentError) { POM.from_json(bad) }
    assert_match(/subsections must have a title/i, err.message)
  end

  # ---------------------------------------------------------------------------
  # add_pom_as_subsection
  # ---------------------------------------------------------------------------

  def test_add_pom_to_existing_section_by_title
    host = POM.new
    host.add_section('Host', body: 'hb')
    guest = POM.new
    guest.add_section('Guest', body: 'gb')

    host.add_pom_as_subsection('Host', guest)
    host_section = host.find_section('Host')

    refute_nil host_section
    assert_equal 1, host_section.subsections.length
    assert_equal 'Guest', host_section.subsections[0].title
    assert_equal 'gb', host_section.subsections[0].body
  end

  def test_add_pom_to_section_object_directly
    host = POM.new
    target = host.add_section('Host', body: 'hb')
    guest = POM.new
    guest.add_section('GuestA', body: 'ab')
    guest.add_section('GuestB', body: 'bb')

    host.add_pom_as_subsection(target, guest)

    assert_equal %w[GuestA GuestB], target.subsections.map(&:title)
  end

  def test_add_pom_to_missing_title_raises
    host = POM.new
    host.add_section('Other', body: 'b')
    guest = POM.new
    guest.add_section('G', body: 'b')

    err = assert_raises(ArgumentError) { host.add_pom_as_subsection('Missing', guest) }
    assert_match(/No section with title 'Missing' found/, err.message)
  end
end
