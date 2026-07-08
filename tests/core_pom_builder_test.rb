# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Real-behavior tests for SignalWire::Core::PomBuilder (parity with Python's
# signalwire.core.pom_builder.PomBuilder).
class CorePomBuilderTest < Minitest::Test
  def setup
    @builder = SignalWire::Core::PomBuilder.new
  end

  def test_add_section_returns_self_for_chaining
    result = @builder.add_section('Identity', body: 'You are helpful')

    assert_same @builder, result
    assert @builder.has_section('Identity')
  end

  def test_render_markdown_contains_section
    @builder.add_section('Rules', body: 'Follow them', bullets: %w[one two])
    md = @builder.render_markdown

    assert_includes md, 'Rules'
    assert_includes md, 'Follow them'
    assert_includes md, 'one'
    assert_includes md, 'two'
  end

  def test_render_xml_is_well_formed
    @builder.add_section('Task', body: 'Do work')
    xml = @builder.render_xml

    assert_includes xml, '<?xml version="1.0" encoding="UTF-8"?>'
    assert_includes xml, '<prompt>'
    assert_includes xml, 'Task'
    assert_includes xml, '</prompt>'
  end

  def test_add_to_section_autovivifies_and_appends_body
    @builder.add_to_section('New', body: 'first')
    @builder.add_to_section('New', body: 'second')
    section = @builder.get_section('New')

    assert_equal "first\n\nsecond", section.body
  end

  def test_add_to_section_appends_bullets
    @builder.add_section('L', bullets: ['a'])
    @builder.add_to_section('L', bullet: 'b')
    @builder.add_to_section('L', bullets: %w[c d])

    assert_equal %w[a b c d], @builder.get_section('L').bullets
  end

  def test_add_subsection_autovivifies_parent
    @builder.add_subsection('Parent', 'Child', body: 'nested')
    parent = @builder.get_section('Parent')

    assert @builder.has_section('Parent')
    assert_equal 1, parent.subsections.length
    assert_equal 'Child', parent.subsections[0].title
    assert_equal 'nested', parent.subsections[0].body
  end

  def test_add_section_with_subsections_hash
    @builder.add_section('Top', body: 'b',
                                subsections: [{ 'title' => 'Sub', 'body' => 'sb', 'bullets' => ['x'] }])
    sub = @builder.get_section('Top').subsections[0]

    assert_equal 'Sub', sub.title
    assert_equal 'sb', sub.body
    assert_equal ['x'], sub.bullets
  end

  def test_has_section_false_when_absent
    refute @builder.has_section('Nope')
    assert_nil @builder.get_section('Nope')
  end

  def test_to_dict_returns_section_array
    @builder.add_section('One', body: 'body-one')
    dict = @builder.to_dict

    assert_instance_of Array, dict
    assert_equal 'One', dict[0]['title']
    assert_equal 'body-one', dict[0]['body']
  end

  def test_to_json_round_trips
    @builder.add_section('J', body: 'jb')
    parsed = JSON.parse(@builder.to_json)

    assert_equal 'J', parsed[0]['title']
    assert_equal 'jb', parsed[0]['body']
  end

  def test_from_sections_class_method
    builder = SignalWire::Core::PomBuilder.from_sections(
      [{ 'title' => 'A', 'body' => 'ba' }, { 'title' => 'B', 'body' => 'bb' }]
    )

    assert builder.has_section('A')
    assert builder.has_section('B')
    assert_equal 'ba', builder.get_section('A').body
  end
end
