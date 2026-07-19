# frozen_string_literal: true

# 2.8 hand-runner drift guard: the DOC-WIRE hand runner
# (scripts/doc_wire_runner.rb) replays the REST calls the examples/docs teach.
# If the runner and the examples drift apart on a WIRE KEY — the runner replaying
# a corrected key while an example still ships the wrong one, or vice versa — the
# gate silently stops proving the doc. This test diffs the wire keys the runner
# replays against the keys the example/doc fixtures actually send, so any such
# drift reds here (it was live once: the runner replayed `areacode` while three
# examples shipped `area_code`).

require 'minitest/autorun'

class DocWireRunnerDriftTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  RUNNER = File.join(ROOT, 'scripts', 'doc_wire_runner.rb')

  # Doc/example sources that put REST calls on the wire (what the runner mirrors).
  FIXTURE_GLOBS = [
    'examples/**/*.rb', 'rest/examples/**/*.rb',
    'README.md', 'rest/README.md', 'rest/docs/**/*.md', 'docs/**/*.md'
  ].freeze

  # Wire keys that carry a KNOWN wrong-spelling footgun. Each maps the correct
  # spec key -> the wrong key that must appear NOWHERE (runner or fixtures).
  WIRE_KEY_CANON = { 'areacode' => 'area_code' }.freeze

  def fixture_files
    FIXTURE_GLOBS.flat_map { |g| Dir.glob(File.join(ROOT, g)) }
                 .reject { |p| p.include?('/.sw-tmp/') }
                 .select { |p| File.file?(p) }
  end

  def all_sources
    [RUNNER] + fixture_files
  end

  # No source (hand runner OR any example/doc) may ship a known wrong wire key.
  # This is the drift the runner can't be allowed to diverge on.
  def test_no_source_ships_a_wrong_wire_key
    WIRE_KEY_CANON.each do |correct, wrong|
      offenders = all_sources.select { |f| ships_wrong_key?(f, wrong) }

      assert_empty offenders,
                   "these sources ship the wrong wire key `#{wrong}` (spec key is " \
                   "`#{correct}`): #{offenders.map { |o| o.sub("#{ROOT}/", '') }}"
    end
  end

  # A source ships the wrong key if a NON-comment line uses it as a kwarg
  # (`wrong:` or `wrong=`). Ruby `#` / markdown-prose comment lines that merely
  # MENTION the footgun (as this runner's own docstring does) are not offenders.
  def ships_wrong_key?(file, wrong)
    File.readlines(file).any? do |line|
      code = line.sub(/#.*$/, '') # drop trailing Ruby comment
      code.match?(/\b#{Regexp.escape(wrong)}:/) || code.match?(/\b#{Regexp.escape(wrong)}\s*=[^=]/)
    end
  end

  # The runner must actually replay the phone-number search the examples teach —
  # if an example searches phone numbers, the runner must too (same wire key), so
  # the runner can't quietly stop mirroring a documented call.
  def test_runner_mirrors_the_phone_number_search_key
    example_uses_search = fixture_files.any? { |f| File.read(f).include?('phone_numbers.search(') }
    skip unless example_uses_search

    runner = File.read(RUNNER)

    assert_match(/phone_numbers\.search\(areacode:/, runner,
                 'examples teach phone_numbers.search but the runner does not replay it with the spec key `areacode`')
  end
end
