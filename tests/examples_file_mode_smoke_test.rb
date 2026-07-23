# frozen_string_literal: true

require 'minitest/autorun'
require 'timeout'
require 'open3'

# ruby_R5 N1: `swaig-test --file <example> --list-tools` used to HANG on the 51/56
# examples whose last line is a bare `agent.run` — loading the file booted a
# blocking WEBrick server. The SIGNALWIRE_SUPPRESS_RUN guard (scoped around the
# Kernel.load in the CLI's file loaders) makes the load introspect-only, so file
# mode terminates deterministically.
#
# This smoke test spawns the real CLI over every agent/service example under a
# hard per-example deadline and asserts it TERMINATES (a hang => the deadline
# fires and the test fails, catching a regression of the guard). It asserts
# termination + a non-crash exit, not tool contents (that's SWAIG-CLI's job).
class ExamplesFileModeSmokeTest < Minitest::Test
  REPO   = File.expand_path('..', __dir__)
  BIN    = File.join(REPO, 'bin', 'swaig-test')
  RUBY   = RbConfig.ruby
  DEADLINE = 30 # seconds per example — generous; a healthy run is < 2s.

  # Relay examples open a live WebSocket to the platform on load and are not
  # file-mode/introspection targets; exclude them from the file-mode smoke.
  RELAY_EXAMPLES = %w[quickstart_relay.rb relay_answer_and_welcome.rb relay_audit_harness.rb].freeze

  # Examples that legitimately exit non-zero in file mode for a reason UNRELATED
  # to the hang (missing credentials / live network / not a SWAIG-agent script) —
  # each with its reason. These are still asserted NOT to hang; only their
  # non-zero exit is tolerated. (They are covered elsewhere: EXAMPLES-RUN runs
  # them against the mock; N3 tracks the joke/web_search key-hint UX.)
  NON_ZERO_OK = {
    'datasphere_serverless_env.rb' => 'requires DATASPHERE_DOCUMENT_ID env',
    'datasphere_webhook_env_demo.rb' => 'requires DATASPHERE_DOCUMENT_ID env',
    'joke_agent.rb' => 'skill setup needs API_NINJAS_KEY (N3)',
    'joke_skill_demo.rb' => 'skill setup needs API_NINJAS_KEY (N3)',
    'skills_demo.rb' => 'joke skill needs API_NINJAS_KEY (N3)',
    'web_search_agent.rb' => 'web_search skill needs a Google CSE key',
    'quickstart_rest.rb' => 'REST script — makes a live authenticated call, not a SWAIG agent',
    'rest_demo.rb' => 'REST script — needs live credentials, not a SWAIG agent',
    'rest_audit_harness.rb' => 'REST audit harness — not a SWAIG-agent file',
    'skills_audit_harness.rb' => 'skills audit harness — not a SWAIG-agent file'
  }.freeze

  def agent_examples
    Dir[File.join(REPO, 'examples', '*.rb')]
      .reject { |p| RELAY_EXAMPLES.include?(File.basename(p)) }
      .sort
  end

  # The PRIMARY guarantee (ruby_R5 N1): NO agent/service example hangs the CLI in
  # file mode. Every example must terminate within the deadline. A non-zero exit
  # is tolerated only for the documented NON_ZERO_OK set (credentials / live
  # network / non-agent scripts) — everything else must exit clean.
  def test_no_agent_example_hangs_in_file_mode
    results = agent_examples.to_h { |ex| [File.basename(ex), run_file_mode(ex)] }
    hung = results.select { |_, s| s == :timeout }.keys
    unexpected = results.select { |b, s| s == :crash && !NON_ZERO_OK.key?(b) }.keys

    assert_empty hung, "swaig-test --file HUNG (suppress-run guard regression) on: #{hung.join(', ')}"
    assert_empty unexpected,
                 "swaig-test --file exited non-zero (not in the tolerated set) on: #{unexpected.join(', ')}"
  end

  private

  # Returns :ok / :crash / :timeout.
  def run_file_mode(example)
    Timeout.timeout(DEADLINE) do
      env = { 'SIGNALWIRE_LOG_MODE' => 'off' }
      _out, _err, status = Open3.capture3(
        env, RUBY, '-I', File.join(REPO, 'lib'), BIN, '--file', example, '--list-tools'
      )
      status.success? ? :ok : :crash
    end
  rescue Timeout::Error
    :timeout
  end
end
