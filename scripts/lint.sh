#!/usr/bin/env bash
# lint.sh — RuboCop FMT + LINT runner for signalwire-ruby.
#
# One stable entry point for the FMT and LINT gates so local runs, CI, and any
# tooling invoke RuboCop the same way (via `bundle exec`, so the pinned gem
# versions from the gemspec/Gemfile.lock are used — never a stray global gem).
#
# Scope: lib/ + tests/ + scripts/ (the real code). The examples trees are
# excluded by .rubocop.yml (demos, not audited surface).
#
# Modes:
#   bash scripts/lint.sh            # check only (no changes) — the gate form
#   bash scripts/lint.sh --fix      # apply SAFE autocorrect, then check
#
# Exit code 0 = clean (zero offenses). Non-zero = offenses remain / a fix failed.
#
# NOTE: only SAFE autocorrect (--autocorrect) is ever applied. --autocorrect-all
# (unsafe) is deliberately NOT used: it has rewritten real logic in this
# codebase (e.g. renaming a `build` test fixture to `test_build`, dropping
# branches). Unsafe corrections are made by hand, reviewed individually.

set -u
set -o pipefail

cd "$(dirname "$0")/.."

TARGETS=(lib tests scripts)

if [ "${1:-}" = "--fix" ]; then
    echo "==> rubocop --autocorrect (safe only) on ${TARGETS[*]}"
    bundle exec rubocop "${TARGETS[@]}" --autocorrect
fi

echo "==> rubocop (check) on ${TARGETS[*]}"
exec bundle exec rubocop "${TARGETS[@]}"
