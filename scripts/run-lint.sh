#!/usr/bin/env bash
# run-lint.sh — the LINT entry point for signalwire-ruby (tool: rubocop).
#
# The SINGLE entry point for linting, callable from ANY directory by run-ci, an
# agent, or a human — the tool environment is self-bootstrapped (scripts/_env.sh)
# so it never depends on the caller's shell setup. See
# porting-sdk/RUN_LINT_FORMAT_SPEC.md.
#
# Runs rubocop as the blocking quality floor: zero offenses required. Reports
# findings and exits non-zero on any finding.
#
# Modes:
#   bash scripts/run-lint.sh          # report; exit non-zero on any offense.
#   bash scripts/run-lint.sh --fix    # apply SAFE autocorrect (rubocop -a) first,
#                                     #   then report the residual.
#
# Scope + the cop set (including the short, justified whole-cop DISABLE list) live
# in .rubocop.yml. Only SAFE autocorrect is applied by --fix; unsafe corrections
# are made by hand and reviewed individually.

set -euo pipefail

# shellcheck source=scripts/_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

if [ "${1:-}" = "--fix" ]; then
    echo "==> LINT autofix (rubocop --autocorrect, safe) — repo: $REPO_ROOT"
    sw_rubocop --autocorrect >/dev/null || true
elif [ -n "${1:-}" ]; then
    echo "usage: $0 [--fix]" >&2
    exit 2
fi

echo "==> LINT (rubocop, zero offenses) — repo: $REPO_ROOT"
sw_rubocop
