# frozen_string_literal: true

require 'minitest/autorun'
require 'tzinfo'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/datetime'

class DateTimeSkillDetailedTest < Minitest::Test
  def setup
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    @skill = factory.call({})
    @skill.setup
  end

  def test_name_and_description
    assert_equal 'datetime', @skill.name
    assert_equal 'Get current date, time, and timezone information', @skill.description
  end

  def test_version
    assert_equal '1.0.0', @skill.version
  end

  def test_register_tools_returns_two_tools
    tools = @skill.register_tools

    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'get_current_time'
    assert_includes names, 'get_current_date'
  end

  def test_get_current_time_handler
    tools = @skill.register_tools
    time_tool = tools.find { |t| t[:name] == 'get_current_time' }
    result = time_tool[:handler].call({ 'timezone' => 'UTC' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/current time is/i, result.response)
  end

  def test_get_current_date_handler
    tools = @skill.register_tools
    date_tool = tools.find { |t| t[:name] == 'get_current_date' }
    result = date_tool[:handler].call({ 'timezone' => 'UTC' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/date is/i, result.response)
  end

  def test_prompt_sections
    sections = @skill.get_prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Date and Time Information', sections[0]['title']
  end

  def test_tool_parameters_include_timezone
    tools = @skill.register_tools

    tools.each do |t|
      assert t[:parameters].key?('timezone'), "#{t[:name]} should have timezone parameter"
    end
  end

  def test_setup_always_succeeds
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})

    assert skill.setup
  end

  # --- #32 regression: thread-safe, ENV-clean timezone resolution ---------
  # (Correct wall-clock per zone is asserted under load by the concurrent test.)

  # An unknown timezone must return the "unknown timezone" error result, not
  # silently fall back to UTC (the old ENV['TZ'] path did on some platforms).
  def test_unknown_timezone_returns_error_result
    assert_match(/unknown timezone/i, call_time('Not/AZone'))
  end

  # Would have caught the bug: resolving a zone must NEVER mutate the
  # process-global ENV['TZ'] (the old code set ENV['TZ'] = tz_name to compute it).
  def test_env_tz_is_never_mutated
    ENV.delete('TZ')
    call_time('Asia/Tokyo')

    assert_nil ENV.fetch('TZ', nil), "resolving a timezone must not set ENV['TZ']"

    ENV['TZ'] = 'America/Chicago'
    call_time('Europe/Paris')

    assert_equal 'America/Chicago', ENV.fetch('TZ', nil),
                 "resolving a timezone must not clobber a pre-existing ENV['TZ']"
  ensure
    ENV.delete('TZ')
  end

  # Would have caught the bug: concurrent calls with different zones must not
  # corrupt each other (the old ENV['TZ'] mutation let one thread leak into
  # another's Time.now). Each thread checks its own zone vs tzinfo under load.
  def test_concurrent_different_timezones_do_not_corrupt_each_other
    zones = %w[America/New_York Asia/Tokyo Europe/London Australia/Sydney Pacific/Honolulu]
    mismatches = []
    threads = zones.map { |zone| Thread.new { 50.times { verify_zone(zone, mismatches) } } }
    threads.each(&:join)

    assert_empty mismatches,
                 "concurrent zone resolution corrupted results: #{mismatches.first(3).inspect}"
  end

  private

  # Call get_current_time for a zone and return its FunctionResult response text.
  def call_time(zone)
    tool = @skill.register_tools.find { |t| t[:name] == 'get_current_time' }
    tool[:handler].call({ 'timezone' => zone }, {}).response
  end

  # Record a mismatch if the skill's wall-clock for +zone+ disagrees with tzinfo.
  def verify_zone(zone, mismatches)
    expected = TZInfo::Timezone.get(zone).now.strftime('%I:%M %p')
    got = call_time(zone)[/\d{1,2}:\d{2}:\d{2} [AP]M/]&.sub(/:\d{2} /, ' ')
    mismatches << [zone, expected, got] unless got && near_minute?(expected, got)
  end

  # True when two "HH:MM AM/PM" strings are within one minute of each other
  # (tolerates the clock ticking over between the handler call and the assert).
  def near_minute?(expected, got)
    e = minutes_of(expected)
    g = minutes_of(got)
    return false unless e && g

    diff = (e - g).abs
    diff <= 1 || diff >= ((12 * 60) - 1)
  end

  def minutes_of(str)
    m = str.match(/(\d{1,2}):(\d{2}) ([AP])M/)
    return nil unless m

    (((m[1].to_i % 12) + (m[3] == 'P' ? 12 : 0)) * 60) + m[2].to_i
  end
end
