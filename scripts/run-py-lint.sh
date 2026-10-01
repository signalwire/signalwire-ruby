#!/usr/bin/env bash
# run-py-lint.sh — the PY-LINT entry point for signalwire-ruby (tool: ruff).
#
# The repo is a Ruby SDK, but scripts/ holds seven hand-written PYTHON programs:
# the five code generators, the cross-port surface enumerator, and
# _gen_format.py, which is part of the format toolchain itself. rubocop cannot
# see a .py file, so until 2026-07-30 none of that load-bearing tooling was
# linted by anything.
#
# This is NOT a second, looser tier: ruff.toml mirrors the reference
# implementation's rule selection (signalwire-python/pyproject.toml [tool.ruff])
# exactly, so the Python here is held to the same bar the reference holds its own.
#
# Callable from ANY directory; the tool environment is self-bootstrapped via
# scripts/_env.sh (see porting-sdk/RUN_LINT_FORMAT_SPEC.md).
#
# Modes:
#   bash scripts/run-py-lint.sh          # report; exit non-zero on any finding.
#   bash scripts/run-py-lint.sh --fix    # apply SAFE fixes first, then report.

set -euo pipefail

# shellcheck source=scripts/_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

if [ "${1:-}" = "--fix" ]; then
    echo "==> PY-LINT autofix (ruff check --fix, safe only) — repo: $REPO_ROOT"
    sw_ruff check --fix "${SW_PY_DIRS[@]}" >/dev/null || true
elif [ -n "${1:-}" ]; then
    echo "usage: $0 [--fix]" >&2
    exit 2
fi

echo "==> PY-LINT (ruff check, zero findings) — repo: $REPO_ROOT"
sw_ruff check "${SW_PY_DIRS[@]}"
