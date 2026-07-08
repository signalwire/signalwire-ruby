#!/usr/bin/env bash
# run-format.sh — the FMT entry point for signalwire-ruby (tool: rubocop).
#
# The SINGLE entry point for formatting, callable from ANY directory by run-ci, an
# agent, or a human — the tool environment is self-bootstrapped (scripts/_env.sh)
# so it never depends on the caller's shell setup. See
# porting-sdk/RUN_LINT_FORMAT_SPEC.md.
#
# Modes:
#   bash scripts/run-format.sh            # DEFAULT: APPLY — reformat the tree in
#                                         #   place (rubocop -a). Exit 0 on success
#                                         #   even if it changed files.
#   bash scripts/run-format.sh --check    # VERIFY-ONLY (CI) — do not modify; exit
#                                         #   non-zero if anything is unformatted.
#
# Scope (lib/ + tests/ + scripts/ + the generated trees, with examples/vendor
# excluded) is defined once in .rubocop.yml, so this script passes MODE flags
# only. Only SAFE autocorrect (-a / --autocorrect) is applied — --autocorrect-all
# (unsafe) is deliberately NOT used here (it has rewritten real logic in this
# codebase); unsafe corrections are made by hand.
#
# Idempotent: a second run right after the first produces no diff.

set -euo pipefail

# shellcheck source=scripts/_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

MODE="apply"
if [ "${1:-}" = "--check" ]; then
    MODE="check"
elif [ -n "${1:-}" ]; then
    echo "usage: $0 [--check]" >&2
    exit 2
fi

if [ "$MODE" = "check" ]; then
    echo "==> FMT check (rubocop, read-only) — repo: $REPO_ROOT"
    # Bare rubocop is read-only; any offense (including formatting) → non-zero.
    sw_rubocop
else
    echo "==> FMT apply (rubocop --autocorrect, safe) — repo: $REPO_ROOT"
    # -a = safe autocorrect. Reformat in place; report if it changed files, but
    # still succeed (a formatting APPLY that changed files is a success).
    sw_rubocop --autocorrect >/dev/null || true
    if ! (cd "$REPO_ROOT" && git diff --quiet 2>/dev/null); then
        echo "    (FMT applied formatting to your working tree — review & stage)"
    fi
    # A residual offense rubocop can't autocorrect must still fail the gate.
    sw_rubocop
fi
