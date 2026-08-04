#!/usr/bin/env bash
# _env.sh — shared tool-environment bootstrap for signalwire-ruby's FMT + LINT
# scripts (and run-ci.sh). Sourced, never executed. Holds the RuboCop/bundler
# bootstrap in ONE place so scripts/run-format.sh, scripts/run-lint.sh, and
# scripts/run-ci.sh all resolve the toolchain identically no matter the caller's
# CWD or shell setup (see porting-sdk/RUN_LINT_FORMAT_SPEC.md).
#
# Contract: after sourcing this file,
#   * $REPO_ROOT   — absolute path to the repo root (resolved from THIS file's
#                    own location, so it is correct from any CWD).
#   * `sw_rubocop …` — runs RuboCop through bundler with the pinned gem versions,
#                    from $REPO_ROOT, having ensured the rubocop gem resolves
#                    (bundle install on first miss). Fails loud with an install
#                    hint if it truly can't be bootstrapped.
#
# The FMT tool for ruby is rubocop (`-a` = apply / bare = read-only check) and the
# LINT tool is also rubocop (zero offenses) — one tool, two faces.

# Resolve the repo root from this script's OWN path (CWD-independent). This file
# lives at <repo>/scripts/_env.sh, so the repo root is its parent's parent.
_SW_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$_SW_ENV_DIR")"
export REPO_ROOT

# Ensure bundler + the rubocop gem resolve. `bundle exec rubocop` is the canonical
# invocation (pinned Gemfile.lock versions, never a stray global gem). If the
# rubocop gem isn't installed for this bundle yet, run `bundle install` once; if
# that still can't produce a working rubocop, fail loud with an install hint.
_sw_bootstrap_rubocop() {
    if ! command -v bundle >/dev/null 2>&1; then
        echo "FATAL: 'bundle' (bundler) not found on PATH." >&2
        echo "       Install Ruby + bundler, then run: gem install bundler" >&2
        return 1
    fi
    # Already resolvable? cheap check via `bundle show`.
    if (cd "$REPO_ROOT" && bundle show rubocop >/dev/null 2>&1); then
        return 0
    fi
    echo "==> rubocop gem not resolved for this bundle; running 'bundle install' ..." >&2
    if ! (cd "$REPO_ROOT" && bundle install >&2); then
        echo "FATAL: 'bundle install' failed — cannot bootstrap rubocop." >&2
        echo "       From $REPO_ROOT run: bundle install" >&2
        return 1
    fi
    if ! (cd "$REPO_ROOT" && bundle show rubocop >/dev/null 2>&1); then
        echo "FATAL: rubocop still unavailable after 'bundle install'." >&2
        echo "       Ensure the Gemfile declares rubocop, then run: bundle install" >&2
        return 1
    fi
    return 0
}

# sw_rubocop <rubocop-args…> — run rubocop via bundler from the repo root.
# Bootstraps on first call. Path scope lives in .rubocop.yml — which as of
# 2026-07-30 excludes ONLY vendor/, so this covers lib/, tests/, examples/,
# relay/examples/, rest/examples/, bin/, scripts/ and the generated trees at one
# bar. Callers pass MODE flags only (nothing, or -a) and let the config decide.
sw_rubocop() {
    _sw_bootstrap_rubocop || return 1
    (cd "$REPO_ROOT" && bundle exec rubocop "$@")
}

# The hand-written PYTHON in scripts/ (the 5 code generators, the surface
# enumerator, _gen_format.py) is linted + format-checked by ruff, configured in
# eng/ruff.toml. rubocop cannot see a .py file, so this is a SEPARATE tool with
# its own gates (PY-LINT / PY-FMT in run-ci.sh); it is not a second, looser bar
# -- eng/ruff.toml mirrors the reference implementation's rule selection exactly.
SW_PY_DIRS=("scripts")

# ruff is a NATIVE binary (not a gem), so it is declared here rather than in the
# Gemfile: `python3 -m ruff` when the module is importable, else the `ruff`
# binary on PATH, else fail loud with an install hint. Same shape as the rubocop
# bootstrap above -- never a silent skip, which would let the gate pass vacuously.
#
# PINNED, for the same reason the Gemfile bounds rubocop on the minor version.
# ruff adds rules and adjusts its format heuristics between releases, so an
# UNPINNED `pip install ruff` in the workflows made PY-LINT/PY-FMT's verdict a
# function of WHEN the runner was provisioned rather than of the source: CI
# installs the newest release at run time while a contributor runs whatever they
# installed months ago, and the CI red does not reproduce locally because the
# difference is not in the code. That exact shape already bit this repo through
# its OTHER linter -- `gem 'rubocop', '>= 1.80'` let CI resolve 1.89.0 against a
# local 1.88.0, and 1.89's tightened Layout/MultilineMethodCallIndentation failed
# CI with 3 offenses on a commit whose local run reported "1464 files inspected,
# no offenses detected".
#
# Keep this in LOCKSTEP with the `pip install ruff==` steps in
# .github/workflows/{test,nightly,publish}.yml. Bump deliberately, with any
# resulting fixes in the same commit.
#
# 0.15.21 is the fleet-wide version: signalwire-python/-perl/-php declare it and
# the rest of the matrix was pinned to it on 2026-08-04.
SW_RUFF_VERSION="0.15.21"
export SW_RUFF_VERSION

_sw_ruff_cmd() {
    if python3 -c 'import ruff' >/dev/null 2>&1; then
        echo "python3 -m ruff"
        return 0
    fi
    if command -v ruff >/dev/null 2>&1; then
        echo "ruff"
        return 0
    fi
    echo "FATAL: ruff not found (needed to lint/format the Python under scripts/)." >&2
    echo "       Install it with: python3 -m pip install ruff   (or: brew install ruff)" >&2
    return 1
}

# _sw_assert_ruff_version <resolved-ruff-command> — the ruff that decides
# PY-LINT/PY-FMT is the version this repo declares.
#
# Pinning the workflows is necessary but NOT sufficient. pip does not re-resolve
# an already-satisfied requirement, so an environment provisioned before the pin
# was tightened keeps its old ruff indefinitely: the pin is then correct in the
# workflow and violated in the interpreter that actually runs the gates, which is
# invisible without a check. This compares what the resolved command REPORTS
# against what SW_RUFF_VERSION declares, so a drifted local box is a loud failure
# rather than a silently different verdict.
#
# SW_ALLOW_TOOL_VERSION_DRIFT=1 downgrades the mismatch to a warning, for a
# deliberate bump-and-fix run only (then _env.sh and the three workflows move
# together and the resulting fixes land in the same commit).
_sw_assert_ruff_version() {
    local cmd have
    cmd="$1"
    # `ruff --version` prints "ruff 0.15.21"; take the x.y.z so both the
    # `python3 -m ruff` and bare-binary spellings compare identically.
    # shellcheck disable=SC2086 # $cmd is our own 1-or-3 word command, intentionally split
    have="$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    if [ "$have" = "$SW_RUFF_VERSION" ]; then
        return 0
    fi
    if [ "${SW_ALLOW_TOOL_VERSION_DRIFT:-0}" = "1" ]; then
        echo "    (ruff is '${have:-unknown}', not the pinned $SW_RUFF_VERSION — drift allowed)" >&2
        return 0
    fi
    echo "FATAL: ruff is '${have:-unknown}', not the pinned $SW_RUFF_VERSION." >&2
    if [ -n "${CI:-}" ]; then
        echo "       The workflow must install the pin: pip install ruff==$SW_RUFF_VERSION" >&2
    else
        echo "       Install the pin: python3 -m pip install ruff==$SW_RUFF_VERSION" >&2
    fi
    echo "       A ruff version that differs between local and CI makes PY-LINT/PY-FMT" >&2
    echo "       red on code that never changed, and no local run reproduces it." >&2
    echo "       Set SW_ALLOW_TOOL_VERSION_DRIFT=1 only for a deliberate bump run." >&2
    return 1
}

# sw_ruff <subcommand> <ruff-args…> — run ruff from the repo root with the repo
# config PINNED.
#
# --config is load-bearing, not decoration: ruff.toml lives at eng/ruff.toml (the
# ROOT-HYGIENE gate keeps tool config out of a public port's root), and ruff only
# auto-discovers a config from the TARGET's directory upward. Without the flag it
# would silently fall back to its BUILT-IN defaults. Measured on a probe file
# using shell=True plus an unnecessary .keys() iteration: the built-in defaults
# find 0, this config finds 4. A gate running the wrong ruleset passes vacuously,
# which is worse than no gate.
sw_ruff() {
    local cmd sub
    cmd="$(_sw_ruff_cmd)" || return 1
    _sw_assert_ruff_version "$cmd" || return 1
    sub="$1"
    shift
    # shellcheck disable=SC2086 # $cmd is our own 1-or-3 word command, intentionally split
    (cd "$REPO_ROOT" && $cmd "$sub" --config "$REPO_ROOT/eng/ruff.toml" "$@")
}
