# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/claude_skills'

# Discovery/registration parity with the Python reference
# (`skills/claude_skills/skill.py`): each skill is a SUBDIRECTORY containing a
# `SKILL.md`; YAML frontmatter supplies name/description; one SWAIG tool is
# registered per discovered skill; the skills_path load-path is validated.
class ClaudeSkillDetailedTest < Minitest::Test
  def setup
    @tmpdir = File.join(Dir.tmpdir, "claude_skill_test_#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    write_skill('greeting', name: 'greeting', description: 'Greet the user',
                            body: 'Say hello to the user.')
    write_skill('farewell', name: 'farewell', description: 'Bid farewell',
                            body: 'Say goodbye to the user.')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  # Create a skill directory <dir>/SKILL.md with YAML frontmatter + body.
  def write_skill(dir, name:, description:, body:)
    skill_dir = File.join(@tmpdir, dir)
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'),
               "---\nname: #{name}\ndescription: #{description}\n---\n\n#{body}\n")
  end

  def factory_for(params)
    SignalWire::Skills::SkillRegistry.get_factory('claude_skills').call(params)
  end

  def test_setup_requires_skills_path
    refute factory_for({}).setup
  end

  def test_setup_with_valid_path
    assert factory_for({ 'skills_path' => @tmpdir }).setup
  end

  def test_setup_rejects_nonexistent_path
    refute factory_for({ 'skills_path' => File.join(@tmpdir, 'does_not_exist') }).setup
  end

  def test_register_tools_discovers_skill_md_directories
    skill = factory_for({ 'skills_path' => @tmpdir })
    skill.setup
    tools = skill.register_tools

    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }

    assert(names.any? { |n| n.include?('greeting') })
    assert(names.any? { |n| n.include?('farewell') })
  end

  # A loose .md file that is NOT a SKILL.md inside a skill directory is ignored
  # (mirrors Python's directory-with-SKILL.md contract).
  def test_loose_md_files_are_not_discovered
    File.write(File.join(@tmpdir, 'stray.md'), '# Not a skill')
    FileUtils.mkdir_p(File.join(@tmpdir, 'no_manifest'))
    File.write(File.join(@tmpdir, 'no_manifest', 'notes.md'), '# Also not a skill')

    skill = factory_for({ 'skills_path' => @tmpdir })
    skill.setup

    assert_equal 2, skill.register_tools.size,
                 'only directories containing a SKILL.md should be discovered'
  end

  # Frontmatter name/description feed the registered tool.
  def test_frontmatter_description_used_for_tool
    skill = factory_for({ 'skills_path' => @tmpdir })
    skill.setup
    greeting = skill.register_tools.find { |t| t[:name].include?('greeting') }

    assert_equal 'Greet the user', greeting[:description]
  end

  # Directory name is the fallback when frontmatter omits `name`.
  def test_missing_frontmatter_name_falls_back_to_dir
    FileUtils.mkdir_p(File.join(@tmpdir, 'bare'))
    File.write(File.join(@tmpdir, 'bare', 'SKILL.md'), "Just body, no frontmatter.\n")

    skill = factory_for({ 'skills_path' => @tmpdir })
    skill.setup
    names = skill.register_tools.map { |t| t[:name] }

    assert(names.any? { |n| n.include?('bare') }, 'dir name is the name fallback')
  end

  def test_include_exclude_patterns
    skill = factory_for({ 'skills_path' => @tmpdir, 'exclude' => ['farewell'] })
    skill.setup
    names = skill.register_tools.map { |t| t[:name] }

    assert(names.any? { |n| n.include?('greeting') })
    refute(names.any? { |n| n.include?('farewell') }, 'excluded skill dir must be dropped')
  end

  def test_custom_tool_prefix
    skill = factory_for({ 'skills_path' => @tmpdir, 'tool_prefix' => 'sk_' })
    skill.setup

    assert(skill.register_tools.all? { |t| t[:name].start_with?('sk_') })
  end

  def test_supports_multiple_instances
    assert_predicate factory_for({}), :supports_multiple_instances?
  end
end
