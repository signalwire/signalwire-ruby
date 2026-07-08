#!/usr/bin/env bash
# run-tests.sh — the TEST entry point for signalwire-ruby (tool: rake test).
#
# The SINGLE entry point for the test suite, callable from ANY directory by
# run-ci, an agent, or a human — the tool environment is self-bootstrapped
# (scripts/_env.sh) so it never depends on the caller's shell setup. See
# porting-sdk/RUN_LINT_FORMAT_SPEC.md.
#
# Runs the full Minitest suite via `bundle exec rake test`; exits non-zero on any
# failure.
#
# Optional filter (run a subset):
#   bash scripts/run-tests.sh                         # whole suite
#   bash scripts/run-tests.sh tests/unit/core/test_agent_base.rb
#                                                     # a single test FILE (glob ok)
# The filter is passed to rake's Minitest task as TEST=<glob> (the standard
# minitest/rake file selector).
#
# Env passthrough: any exported vars (e.g. MOCK_SIGNALWIRE_PORT, set by run-ci's
# REST-COVERAGE gate; COVERAGE=1) flow through unchanged — this script does not
# clear the environment. Mock hygiene (mocks self-terminate on parent death) is
# the harness's, unchanged by this wrapper.

set -euo pipefail

# shellcheck source=scripts/_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

# Ensure the bundle (and its gems) resolve — reuse the shared rubocop bootstrap,
# which runs `bundle install` on a miss (rake + the test gems come from the same
# Gemfile/bundle).
_sw_bootstrap_rubocop

FILTER="${1:-}"

echo "==> TEST (bundle exec rake test) — repo: $REPO_ROOT${FILTER:+  filter=$FILTER}"
if [ -n "$FILTER" ]; then
    (cd "$REPO_ROOT" && TEST="$FILTER" bundle exec rake test)
else
    (cd "$REPO_ROOT" && bundle exec rake test)
fi
