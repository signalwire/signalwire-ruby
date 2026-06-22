#!/usr/bin/env bash
# run-ci.sh — canonical local-and-CI gate runner for signalwire-ruby.
#
# Same script invoked locally (`bash scripts/run-ci.sh`) AND by the
# GitHub Actions workflow. No drift between local and CI behavior.
#
# Gates (in order, fail-fast):
#   1. bundle exec rake test              — language test runner
#   2. signature regen                    — python adapter + signature_dump.rb
#   3. drift gate                         — porting-sdk diff_port_signatures.py
#   4. surface-fresh gate                 — porting-sdk check_surface_freshness.py
#   5. no-cheat gate                      — porting-sdk audit_no_cheat_tests.py
#   6. emission gate                      — porting-sdk diff_port_emission.py
#   7. fmt gate                           — rubocop (local: --autocorrect; CI: check)
#   8. lint gate                          — rubocop, zero offenses (the burndown floor)
#   9. doc-audit gate                     — porting-sdk audit_docs.py
#  10. surface-diff gate                  — porting-sdk diff_port_surface.py
#  11. skill-contract gate                — porting-sdk diff_skill_contracts.py

set -u
set -o pipefail

PORT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT_NAME="signalwire-ruby"

resolve_porting_sdk() {
    if [ -n "${PORTING_SDK:-}" ] && [ -d "$PORTING_SDK/scripts" ]; then
        echo "$PORTING_SDK"
        return 0
    fi
    if [ -d "$PORT_ROOT/../porting-sdk/scripts" ]; then
        (cd "$PORT_ROOT/../porting-sdk" && pwd)
        return 0
    fi
    return 1
}

PORTING_SDK_DIR="$(resolve_porting_sdk)" || {
    echo "FATAL: porting-sdk not found, clone it adjacent to this repo" >&2
    echo "       (expected $PORT_ROOT/../porting-sdk or \$PORTING_SDK env var)" >&2
    exit 2
}

FAILED_GATES=""

run_gate() {
    local name="$1"; shift
    local description="$1"; shift
    local logfile
    logfile="$(mktemp)"
    "$@" >"$logfile" 2>&1
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "[$name] $description ... PASS"
        rm -f "$logfile"
        return 0
    fi
    echo "[$name] $description ... FAIL: exit $rc"
    sed 's/^/    /' "$logfile" | tail -40
    rm -f "$logfile"
    FAILED_GATES="$FAILED_GATES $name"
    return $rc
}

cd "$PORT_ROOT"

echo "==> running CI gates for $PORT_NAME (porting-sdk at $PORTING_SDK_DIR)"

# Gate 1: rake test
run_gate "TEST" "bundle exec rake test" \
    bundle exec rake test

# Gate 2: signature regen
run_gate "SIGNATURES" "regenerate port_signatures.json" \
    python3 scripts/enumerate_signatures.py

# Gate 3: drift gate
run_gate "DRIFT" "diff_port_signatures vs python reference" \
    python3 "$PORTING_SDK_DIR/scripts/diff_port_signatures.py" \
        --reference "$PORTING_SDK_DIR/python_signatures.json" \
        --port-signatures "$PORT_ROOT/port_signatures.json" \
        --surface-omissions "$PORT_ROOT/PORT_OMISSIONS.md" \
        --surface-additions "$PORT_ROOT/PORT_ADDITIONS.md" \
        --omissions "$PORT_ROOT/PORT_SIGNATURE_OMISSIONS.md"

# Gate 4: surface-fresh gate — Layer B does NOT ride on the signature drift gate
# (Layer A) above, so port_surface.json can silently rot when a public symbol is
# added but only the signatures are regenerated. Save the committed surface,
# regenerate it in place via Ruby's surface enumerator, compare modulo the
# volatile generated_from git-sha, then restore the committed copy unconditionally.
surface_fresh_gate() {
    git show HEAD:port_surface.json > /tmp/committed_surface.json 2>/dev/null \
        || cp "$PORT_ROOT/port_surface.json" /tmp/committed_surface.json
    # `bundle exec` so the regen loads gems from the Gemfile (it `require`s
    # signalwire → rack); bare `ruby` failed in CI with `cannot load -- rack`.
    bundle exec ruby scripts/enumerate_surface.rb --output "$PORT_ROOT/port_surface.json"
    local regen_rc=$?
    if [ "$regen_rc" -ne 0 ]; then
        git checkout -- port_surface.json 2>/dev/null
        return $regen_rc
    fi
    python3 "$PORTING_SDK_DIR/scripts/check_surface_freshness.py" \
        --committed /tmp/committed_surface.json \
        --fresh "$PORT_ROOT/port_surface.json"
    local check_rc=$?
    git checkout -- port_surface.json 2>/dev/null
    return $check_rc
}
run_gate "SURFACE-FRESH" "check_surface_freshness vs committed surface" \
    surface_fresh_gate

# Gate 5: no-cheat
run_gate "NO-CHEAT" "audit_no_cheat_tests" \
    python3 "$PORTING_SDK_DIR/scripts/audit_no_cheat_tests.py" --root "$PORT_ROOT"

# Gate 5b: REST-COVERAGE — every implemented canonical REST route exercised with
# BOTH a success (2xx) AND an error (4xx/5xx) response on the correct path
# (parity). Self-contained: spins its own mock, runs the rest tests serially
# against it (one shared journal), then runs porting-sdk's rest_coverage checker
# with the shared baseline + this port's REST_COVERAGE_GAPS.md. A stale allowlist
# entry (route now covered) fails the gate. Same shape as python/java/ts/go.
rest_coverage_gate() {
    local port=8769
    local mock_pkg_parent="$PORTING_SDK_DIR/test_harness/mock_signalwire"
    export PYTHONPATH="$mock_pkg_parent${PYTHONPATH:+:$PYTHONPATH}"
    python3 -m mock_signalwire --host 127.0.0.1 --port "$port" --log-level error \
        >/tmp/rest_cov_mock_ruby.$$.log 2>&1 &
    local mock_pid=$!
    # shellcheck disable=SC2064
    trap "kill $mock_pid 2>/dev/null" RETURN
    local i
    for i in $(seq 1 60); do
        if python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:$port/__mock__/health',timeout=1)" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done
    python3 -c "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:$port/__mock__/journal/reset',method='POST'),timeout=5).read()"
    MOCK_SIGNALWIRE_PORT="$port" bundle exec rake test || return 1
    python3 -m mock_signalwire.rest_coverage \
        --mock-url "http://127.0.0.1:$port" \
        --spec-root "$PORTING_SDK_DIR/rest-apis" \
        --allowlist "$PORTING_SDK_DIR/REST_COVERAGE_BASELINE.md" \
        --allowlist "$PORT_ROOT/REST_COVERAGE_GAPS.md" \
        --gap-baseline "$PORTING_SDK_DIR/REST_COVERAGE_GAP_BASELINE.md"
}
run_gate "REST-COVERAGE" "every implemented REST route covered success+error (parity + allowlist)" \
    rest_coverage_gate

# Gate 5c: SPEC-PARITY — the routes the SDK actually IMPLEMENTS must equal the
# canonical spec route set, modulo porting-sdk/SPEC_IMPLEMENTATION_GAPS.md. This
# is the spec-first guard REST-COVERAGE can't give: REST-COVERAGE only proves
# *tested* routes match the spec, so a route the SDK implements that the spec
# doesn't define (or vice versa) would slip past it. Set B is built by
# scripts/route_registry.rb — it drives the live RestClient through a recording
# HttpClient and captures every dispatched (method, path), so it sees every
# implemented route whether or not it's tested (not an AST scrape, not the
# journal). The shared porting-sdk diff consumes that JSON via --registry-json
# (porting-sdk#45). Deprecation warnings from the SDK go to stderr; we discard
# stderr so stdout stays pure JSON.
spec_parity_gate() {
    local mock_pkg_parent="$PORTING_SDK_DIR/test_harness/mock_signalwire"
    export PYTHONPATH="$mock_pkg_parent${PYTHONPATH:+:$PYTHONPATH}"
    local registry
    registry="$(mktemp)"
    ruby -Ilib scripts/route_registry.rb >"$registry" 2>/dev/null || {
        rm -f "$registry"; return 1
    }
    python3 "$PORTING_SDK_DIR/scripts/diff_spec_implementation.py" \
        --registry-json "$registry" \
        --gaps "$PORTING_SDK_DIR/SPEC_IMPLEMENTATION_GAPS.md"
    local rc=$?
    rm -f "$registry"
    return $rc
}
run_gate "SPEC-PARITY" "implemented routes == canonical spec (modulo SPEC_IMPLEMENTATION_GAPS.md)" \
    spec_parity_gate

# Gate 6: emission gate — byte-compare native FunctionResult to_h against the
# Python to_dict() oracle over the shared 81-entry corpus. Closes the behavioral
# (action shape/keys/values) gap the surface drift gate cannot see. Run with
# cwd=$PORT_ROOT (set above), so the relative dump command resolves.
run_gate "EMISSION" "diff_port_emission vs python oracle" \
    python3 "$PORTING_SDK_DIR/scripts/diff_port_emission.py" \
        --dump-cmd "ruby bin/emit-corpus"

# Gate 7: FMT — the language format gate (ruby: rubocop). RuboCop is both
# formatter and linter; here it wears the "format" face. Source-style only and
# proven surface/emission-neutral (a reformat leaves port_signatures.json +
# port_surface.json byte-identical, and EMISSION 81/81 — verified during the
# burndown). Mirrors the go/ts FMT shape:
#   * LOCAL ($CI unset)  → `rubocop --autocorrect`: reformats your working tree
#     in place so you never hand-run it; notes if it changed files.
#   * CI ($CI=true)      → `rubocop` (read-only): FAILS if any offense reached CI.
# lib/ + tests/ were burned to zero earlier; the bin/ tooling + Gemfile/gemspec
# were brought to zero in the FMT/LINT rollout.
fmt_gate() {
    if [ -n "${CI:-}" ]; then
        bundle exec rubocop
    else
        bundle exec rubocop --autocorrect >/dev/null
        if ! git diff --quiet 2>/dev/null; then
            echo "    (FMT auto-applied formatting to your working tree — review & stage)"
        fi
        # A residual offense rubocop can't autocorrect must still fail the gate.
        bundle exec rubocop
    fi
}
run_gate "FMT" "rubocop (local: --autocorrect; CI: check)" fmt_gate

# Gate 8: LINT — the language lint gate (ruby: rubocop, zero offenses). This is
# the blocking quality floor: the full cop set in .rubocop.yml burned to zero by
# hand (the whole-cop DISABLE list there is short + justified — a cop is off ONLY
# when obeying it would change the SWAIG wire bytes / rename a wire token, or
# fights faithful Python-reference parity; type/shape + naming idiom is NEVER
# suppressed — idiom wins and the cross-port DRIFT checker is taught the
# equivalence). Mirrors the go golangci / rust clippy blocking-lint gate.
#
# Inline `# rubocop:disable Cop` directives ARE allowed when site-scoped (a
# disable/enable pair, or a same-line disable) and carry a rationale — that's the
# preferred form over turning a whole cop off. The honesty guard against a
# disable that hides a real offense is rubocop's OWN Lint/RedundantCopDisable
# Directive cop (enabled): it fails the run if any disable suppresses a non-
# offense, so a gratuitous/over-broad disable can't pass this gate. No hand-rolled
# grep guard — it can't tell a justified site-disable from a blanket one, and a
# naive one wrongly fails wire-critical paired disables in lib/.
run_gate "LINT" "rubocop zero offenses (lint gate)" \
    bundle exec rubocop

# Gate 9: DOC-AUDIT — every method/class referenced in docs/ + examples/ fenced
# code blocks must resolve to a real symbol in the port surface (catches
# phantom-API doc promises). Uses the committed port_surface.json (the
# SURFACE-FRESH gate above already proved it is fresh) + DOC_AUDIT_IGNORE.md for
# intentional non-symbol references.
run_gate "DOC-AUDIT" "audit_docs vs port_surface.json" \
    python3 "$PORTING_SDK_DIR/scripts/audit_docs.py" \
        --root "$PORT_ROOT" \
        --surface "$PORT_ROOT/port_surface.json" \
        --ignore "$PORT_ROOT/DOC_AUDIT_IGNORE.md"

# Gate 10: surface-diff — diff the port's public surface against the Python
# reference (omissions + additions). The signature DRIFT gate (Layer A) checks
# method *signatures*; this checks surface *membership* — it catches public
# symbols the port has that Python doesn't (e.g. helpers leaked onto the surface
# by a refactor) and vice-versa. Mirrors the CI "Verify symbol-level parity"
# job so local == CI. Regenerate the surface in place, diff, then restore the
# committed copy unconditionally.
surface_diff_gate() {
    git show HEAD:port_surface.json > /tmp/committed_surface_diff.json 2>/dev/null \
        || cp "$PORT_ROOT/port_surface.json" /tmp/committed_surface_diff.json
    bundle exec ruby scripts/enumerate_surface.rb --output "$PORT_ROOT/port_surface.json"
    local regen_rc=$?
    if [ "$regen_rc" -ne 0 ]; then
        git checkout -- port_surface.json 2>/dev/null
        return $regen_rc
    fi
    python3 "$PORTING_SDK_DIR/scripts/diff_port_surface.py" \
        --reference "$PORTING_SDK_DIR/python_surface.json" \
        --port-surface "$PORT_ROOT/port_surface.json" \
        --omissions "$PORT_ROOT/PORT_OMISSIONS.md" \
        --additions "$PORT_ROOT/PORT_ADDITIONS.md"
    local check_rc=$?
    git checkout -- port_surface.json 2>/dev/null
    return $check_rc
}
run_gate "SURFACE-DIFF" "diff_port_surface vs python reference" \
    surface_diff_gate

# Gate 11: SKILL-CONTRACT — the surface/drift/emission gates see signatures +
# symbol names + FunctionResult.to_dict(); NONE sees a built-in skill's SWAIG
# tool contract ({name, parameters, required, enum} each skill registers). This
# differ closes that gap: it builds the Python oracle by instantiating each
# covered reference skill, runs the Ruby skill-dump program (bin/emit-skills,
# which reads the SAME shared corpus), and structurally compares the two.
# DESCRIPTIONS + implementation (handler vs DataMap) are not compared — only
# name/param-name/param-type/enum/required. Mirrors the go/dotnet SKILL-CONTRACT
# gate. Same prereqs as EMISSION (signalwire-python adjacent; no network).
run_gate "SKILL-CONTRACT" "diff_skill_contracts vs python reference" \
    python3 "$PORTING_SDK_DIR/scripts/diff_skill_contracts.py" \
        --dump-cmd "bundle exec ruby bin/emit-skills" \
        --port-repo "$PORT_ROOT"

if [ -z "$FAILED_GATES" ]; then
    echo "==> CI PASS"
    exit 0
else
    echo "==> CI FAIL (gates:$FAILED_GATES )"
    exit 1
fi
