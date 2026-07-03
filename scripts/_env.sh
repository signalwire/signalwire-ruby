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
# Bootstraps on first call. Path scope (which dirs are linted, and the generated /
# examples excludes) lives in .rubocop.yml, so callers pass MODE flags only
# (nothing, or -a) and let the config decide the tree.
sw_rubocop() {
    _sw_bootstrap_rubocop || return 1
    (cd "$REPO_ROOT" && bundle exec rubocop "$@")
}
