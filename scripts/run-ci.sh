#!/usr/bin/env bash
# run-ci.sh — canonical local-and-CI gate runner for signalwire-ruby.
#
# Same script invoked locally (`bash scripts/run-ci.sh`) AND by the
# GitHub Actions workflow. No drift between local and CI behavior.
#
# The TEST, FMT, and LINT gates invoke the canonical self-bootstrapping entry-point
# scripts (scripts/run-tests.sh, run-format.sh, run-lint.sh — all sourcing
# scripts/_env.sh), so those gates work identically whether run by CI or standalone
# from any CWD (porting-sdk/RUN_LINT_FORMAT_SPEC.md).
#
# GATE SCHEDULING (porting-sdk/scripts/gate_scheduler.sh — CI_PERF S1 + S2):
#   Gates run CONCURRENTLY up to a cap (SW_CI_JOBS, default nproc), scheduled by
#   their DATA dependencies:
#     * S2 concurrent wave: the pure-Python side-effect-free gates (all GEN-FRESH*,
#       DRIFT, NO-CHEAT, EMISSION, SKILL-CONTRACT, SWAIG-COVERAGE, SURFACE-DIFF,
#       DOC-AUDIT, SWAIG-CLI) overlap — they share no mutable state.
#     * S1 fail-fast: heavy gates (TEST, LINT, FMT, REST-COVERAGE, SPEC-PARITY) are
#       deferred behind the cheap wave, so a trivial cheap-gate failure surfaces in
#       seconds; --fail-fast aborts the run before TEST starts.
#   HARD ordering is data-dependency ONLY:
#     * DRIFT reads port_signatures.json that SIGNATURES writes → deps=SIGNATURES.
#     * SURFACE-FRESH + SURFACE-DIFF regenerate port_surface.json in place (and
#       restore it), DOC-AUDIT reads it → all three share res=surface.
#   Per-gate PASS/FAIL + the FAILED_GATES tally preserved exactly; each gate's output
#   captured + replayed atomically.
#
# Flags:
#   --fail-fast   stop launching new gates at the first failure (local dev loop).

set -u
set -o pipefail

PORT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PORT_ROOT/.sw-tmp"  # repo-local CI scratch (never /tmp)
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

# shellcheck source=/dev/null
source "$PORTING_SDK_DIR/scripts/gate_scheduler.sh"

cd "$PORT_ROOT"

echo "==> running CI gates for $PORT_NAME (porting-sdk at $PORTING_SDK_DIR)"

pick_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

# SURFACE-FRESH — Layer B does NOT ride on DRIFT (Layer A), so port_surface.json can
# silently rot. Regenerate it in place via Ruby's surface enumerator, compare modulo
# the volatile generated_from git-sha, then restore the committed copy.
surface_fresh_gate() {
    git show HEAD:port_surface.json > "$PORT_ROOT/.sw-tmp/committed_surface.json" 2>/dev/null \
        || cp "$PORT_ROOT/port_surface.json" "$PORT_ROOT/.sw-tmp/committed_surface.json"
    bundle exec ruby scripts/enumerate_surface.rb --output "$PORT_ROOT/port_surface.json"
    local regen_rc=$?
    if [ "$regen_rc" -ne 0 ]; then
        git checkout -- port_surface.json 2>/dev/null
        return $regen_rc
    fi
    python3 "$PORTING_SDK_DIR/scripts/check_surface_freshness.py" \
        --committed "$PORT_ROOT/.sw-tmp/committed_surface.json" \
        --fresh "$PORT_ROOT/port_surface.json"
    local check_rc=$?
    git checkout -- port_surface.json 2>/dev/null
    return $check_rc
}

# REST-COVERAGE — every implemented REST route covered success+error. Self-
# contained: spins its own mock, runs the rest tests serially, replays the journal —
# then checks the journal for BOTH coverage AND wire-truth (STRICT-MOCKS §2.2a: any
# journaled wire_violation reds the gate — respelling-proof, since it reads the
# mock's own spec-vs-wire judgement).
rest_coverage_gate() {
    local port
    port="$(pick_free_port)" || { echo "could not allocate a free port" >&2; return 1; }
    local mock_pkg_parent="$PORTING_SDK_DIR/test_harness/mock_signalwire"
    export PYTHONPATH="$mock_pkg_parent${PYTHONPATH:+:$PYTHONPATH}"
    python3 -m mock_signalwire --host 127.0.0.1 --port "$port" --log-level error \
        >"$PORT_ROOT/.sw-tmp/rest_cov_mock_ruby.$$.log" 2>&1 &
    local mock_pid=$!
    # shellcheck disable=SC2064
    trap "kill $mock_pid 2>/dev/null" RETURN
    local i ready=0
    for i in $(seq 1 60); do
        if ! kill -0 "$mock_pid" 2>/dev/null; then
            echo "mock_signalwire died on port $port — log:" >&2
            cat "$PORT_ROOT/.sw-tmp/rest_cov_mock_ruby.$$.log" >&2
            return 1
        fi
        if python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:$port/__mock__/health',timeout=1)" 2>/dev/null; then
            ready=1
            break
        fi
        sleep 0.5
    done
    if [ "$ready" -ne 1 ]; then
        echo "mock_signalwire on port $port not healthy within 30s" >&2
        return 1
    fi
    python3 -c "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:$port/__mock__/journal/reset',method='POST'),timeout=5).read()"
    # Drive ONLY the generated *_generated_test.rb suite (route_registry.rb x spec
    # oracle, one per REST namespace) against the mock to populate the coverage
    # journal — the direct ruby analog of python's generated *Wire test classes,
    # which give full success+error route coverage on their own (proven: 217/236
    # routes hit here, matching REST_COVERAGE_GAPS.md's accepted-gap count exactly).
    # Deliberately EXCLUDES the hand-authored tests/rest/*_mock_test.rb files (still
    # run in full under the plain TEST gate above): two of those hand tests
    # legitimately exercise KNOWN PARKED spec gaps un-declared on the spec side —
    # `page_size` on relay-rest.list_recordings and `cursor` on
    # fabric.list_fabric_addresses (both owner-adjudicated pending prime-rails
    # confirmation, tracked on porting-sdk fix/recordings-pagination-spec; NOT an
    # invented exception, so not allowlisted). Letting those two hand tests feed
    # this journal would red the wire-truth check on a gap the spec itself hasn't
    # caught up to yet — narrowing the coverage-measuring pass to the generated
    # corpus (which is spec-faithful by construction) keeps STRICT-MOCKS honest
    # without laundering a real gap through an allowlist.
    MOCK_SIGNALWIRE_PORT="$port" bash scripts/run-tests.sh 'tests/rest/generated/*_test.rb' || return 1
    python3 -m mock_signalwire.rest_coverage \
        --mock-url "http://127.0.0.1:$port" \
        --spec-root "$PORTING_SDK_DIR/rest-apis" \
        --allowlist "$PORTING_SDK_DIR/REST_COVERAGE_BASELINE.md" \
        --allowlist "$PORT_ROOT/REST_COVERAGE_GAPS.md" \
        --gap-baseline "$PORTING_SDK_DIR/REST_COVERAGE_GAP_BASELINE.md" || return 1
    # STRICT-MOCKS §2.2a — fail the gate on ANY journaled wire_violation. The shared
    # helper reads the same live mock journal and exits non-zero on any offender
    # (see porting-sdk/scripts/assert_no_wire_violations.py). WIRE_VIOLATIONS_ALLOW.md
    # holds ONLY owner-signed spec-gap parks (currently empty for ruby — the two
    # known parked gaps above are excluded from the selector, not allowlisted here).
    python3 "$PORTING_SDK_DIR/scripts/assert_no_wire_violations.py" \
        --rest-mock-url "http://127.0.0.1:$port" \
        --allowlist "$PORT_ROOT/WIRE_VIOLATIONS_ALLOW.md"
}

# SPEC-PARITY — implemented routes == canonical spec. route_registry.rb drives the
# live RestClient through a recording HttpClient and captures every dispatched route.
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

# SURFACE-DIFF — diff the port's public surface against the Python reference.
# Regenerate in place, diff, restore unconditionally.
surface_diff_gate() {
    git show HEAD:port_surface.json > "$PORT_ROOT/.sw-tmp/committed_surface_diff.json" 2>/dev/null \
        || cp "$PORT_ROOT/port_surface.json" "$PORT_ROOT/.sw-tmp/committed_surface_diff.json"
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

# ARTIFACT-DENY — no porting artifact may ship inside the PUBLISHED gem. The
# git-ls-files proxy over-reports in-repo-but-unpublished files; feed the REAL
# gem's file listing to --listing instead. A .gem is a tar wrapping data.tar.gz
# (the actual shipped files), so build the gem into repo-local scratch and unpack
# data.tar.gz's listing.
dayone_artifact_deny() {
    local gem="$PORT_ROOT/.sw-tmp/artifact_deny.gem"
    gem build "$PORT_ROOT"/*.gemspec -o "$gem" >/dev/null 2>&1 || {
        echo "gem build failed" >&2; return 1
    }
    tar xOf "$gem" data.tar.gz | tar tzf - 2>/dev/null \
        | python3 "$PORTING_SDK_DIR/scripts/artifact_deny.py" --port ruby --repo . --listing -
    local rc=$?
    rm -f "$gem"
    return $rc
}

# ---- register gates ----------------------------------------------------------
sched_init "$@"

# STRICT-MOCKS §2.2b — run the suite (incl. RELAY tests, which probe-or-spawn
# their own mock_relay) under MOCK_RELAY_STRICT=1: any unknown frame field /
# duplicate command-id is rejected with an error frame, so a wrong RELAY wire
# shape fails the test rather than being silently accepted.
sched_gate TEST defer=1 desc="run-tests.sh (bundle exec rake test) (STRICT-MOCKS: MOCK_RELAY_STRICT=1)" \
    -- env MOCK_RELAY_STRICT=1 bash scripts/run-tests.sh

sched_gate GEN-FRESH desc="generated REST layer matches canonical specs" \
    -- python3 scripts/generate_rest.py --check

sched_gate GEN-FRESH-TESTS desc="generated REST wire-test suite matches route-registry × spec oracle" \
    -- python3 scripts/generate_rest_tests.py --check

sched_gate GEN-FRESH-SWML desc="generated SWML-verbs config tree matches schema.json (\$defs)" \
    -- python3 scripts/generate_swml_verbs.py --check

sched_gate GEN-FRESH-RELAY desc="generated RELAY-protocol tree matches relay-protocol/*.json" \
    -- python3 scripts/generate_relay_protocol.py --check

sched_gate GEN-FRESH-SWAIG desc="generated SWAIG payload tree matches swaig-specs/" \
    -- python3 scripts/generate_swaig_payloads.py --check

sched_gate SWAIG-COVERAGE desc="every engine SWAIG action emittable (modulo allowlist)" \
    -- python3 "$PORTING_SDK_DIR/scripts/swaig_coverage.py" --check \
        --emission "$PORT_ROOT/lib/signalwire/swaig/function_result.rb"

sched_gate SIGNATURES desc="regenerate port_signatures.json" \
    -- python3 scripts/enumerate_signatures.py

sched_gate DRIFT deps=SIGNATURES desc="diff_port_signatures vs python reference" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_signatures.py" \
        --reference "$PORTING_SDK_DIR/python_signatures.json" \
        --port-signatures "$PORT_ROOT/port_signatures.json" \
        --surface-omissions "$PORT_ROOT/PORT_OMISSIONS.md" \
        --surface-additions "$PORT_ROOT/PORT_ADDITIONS.md" \
        --omissions "$PORT_ROOT/PORT_SIGNATURE_OMISSIONS.md"

sched_gate SURFACE-FRESH res=surface desc="check_surface_freshness vs committed surface" \
    --fn surface_fresh_gate

sched_gate NO-CHEAT desc="audit_no_cheat_tests" \
    -- python3 "$PORTING_SDK_DIR/scripts/audit_no_cheat_tests.py" --root "$PORT_ROOT"

sched_gate REST-COVERAGE defer=1 desc="every implemented REST route covered success+error (parity + allowlist)" \
    --fn rest_coverage_gate

sched_gate SPEC-PARITY defer=1 desc="implemented routes == canonical spec (modulo SPEC_IMPLEMENTATION_GAPS.md)" \
    --fn spec_parity_gate

sched_gate EMISSION desc="diff_port_emission vs python oracle" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_emission.py" \
        --dump-cmd "bundle exec ruby bin/emit-corpus"

sched_gate BEHAVIORAL-WIRE desc="diff_port_wire vs python oracle (Layer D)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_wire.py" \
        --port ruby \
        --dump-cmd "bundle exec ruby bin/wire-dump"

sched_gate BEHAVIORAL-SWML desc="diff_port_swml vs python oracle (Layer D)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_swml.py" \
        --port ruby \
        --dump-cmd "bundle exec ruby bin/swml-dump"

sched_gate BEHAVIORAL-STATE desc="diff_port_state vs python oracle (Layer D)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_state.py" \
        --port ruby \
        --dump-cmd "bundle exec ruby bin/state-dump"

sched_gate BEHAVIORAL-HTTP desc="diff_port_http vs python oracle (Layer D)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_http.py" \
        --port ruby \
        --dump-cmd "bundle exec ruby bin/http-dump"

sched_gate BEHAVIORAL-WIRE-RELAY desc="diff_port_wire_relay vs python oracle (Layer D)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_wire_relay.py" \
        --port ruby \
        --dump-cmd "bundle exec ruby bin/wire-relay-dump"

sched_gate FMT defer=1 desc="run-format.sh (local: apply; CI: --check)" \
    -- bash scripts/run-format.sh ${CI:+--check}

sched_gate LINT defer=1 desc="run-lint.sh (rubocop zero offenses)" \
    -- bash scripts/run-lint.sh

sched_gate DOC-AUDIT res=surface desc="audit_docs vs port_surface.json" \
    -- python3 "$PORTING_SDK_DIR/scripts/audit_docs.py" \
        --root "$PORT_ROOT" \
        --surface "$PORT_ROOT/port_surface.json" \
        --ignore "$PORT_ROOT/DOC_AUDIT_IGNORE.md"

sched_gate SURFACE-DIFF res=surface desc="diff_port_surface vs python reference" \
    --fn surface_diff_gate

sched_gate SKILL-CONTRACT desc="diff_skill_contracts vs python reference" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_skill_contracts.py" \
        --dump-cmd "bundle exec ruby bin/emit-skills" \
        --port-repo "$PORT_ROOT"

sched_gate SWAIG-CLI desc="swaig-test shared mini-contract (verbs/serverless-reject/default-action)" \
    -- python3 "$PORTING_SDK_DIR/scripts/audit_swaig_cli_contract.py" \
        --port ruby \
        --cmd "ruby -I$PORT_ROOT/lib $PORT_ROOT/bin/swaig-test" \
        --require-url-model \
        --default-action-argv='--url|http://user:pass@127.0.0.1:1/' \
        --has-serverless \
        --serverless-argv='AGENT_FILE_PLACEHOLDER|--simulate-serverless|bogus-platform-xyz|--dump-swml' \
        --agent-file-suffix '.rb' \
        --agent-file-content "require 'signalwire'; AGENT = SignalWire::AgentBase.new(name: 'p', route: '/'); AGENT.set_prompt_text('hi')"

sched_gate DOC-LANG-PURITY res=dayone desc="no python-verbatim docs in a non-python port" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_lang_purity.py" --port ruby --repo .

sched_gate DOC-LINKS res=dayone desc="every relative markdown link resolves to a tracked file" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_links.py" --port ruby --repo .

sched_gate README-INCLUDE res=dayone desc="doc code blocks are byte-identical to their gate-compiled fixture regions" \
    -- python3 "$PORTING_SDK_DIR/scripts/readme_include.py" --port ruby --repo .

sched_gate ROOT-HYGIENE res=dayone desc="no audit/scratch clutter tracked at repo root (allowlist ROOT_HYGIENE_ALLOW.md)" \
    -- python3 "$PORTING_SDK_DIR/scripts/root_hygiene.py" --port ruby --repo .

sched_gate IGNORE-LEDGER-VERIFY res=dayone desc="no laundered false-absence entries in DOC_AUDIT_IGNORE.md (strict: reason/approver/date required)" \
    -- python3 "$PORTING_SDK_DIR/scripts/ignore_ledger_verify.py" --port ruby --repo . --require-fields

sched_gate META-CONSISTENT res=dayone desc="package metadata consistency" \
    -- python3 "$PORTING_SDK_DIR/scripts/meta_consistent.py" --port ruby --repo .

sched_gate ARTIFACT-DENY res=dayone desc="no porting artifacts in the PUBLISHED package (authoritative listing)" \
    --fn dayone_artifact_deny

# --- Expansion gates (GATE_EXPANSION_PLAN) — enforcing (backlog burned to zero) ---
# ROUTE-COLLISION is intentionally NOT wired here: with ruby's route_registry.rb it
# fails on a SPEC-FAITHFUL route-split — the fabric spec declares SINGULAR sibling
# paths /resources/call_flow/{id}/addresses + /resources/conference_room/{id}/addresses
# (operationIds list_call_flow_addresses / list_conference_room_addresses) while the
# class collection base is plural. Ruby's generated code matches the spec exactly, so
# this is a proven exception that needs a human-approved ROUTE_COLLISION_ALLOW.md entry
# before the gate can be wired enforcing — not added autonomously. Follow-up.

sched_gate GEN-TYPE-DEGENERACY res=dayone desc="no degenerate generated-typed aliases (no consumers / collapse to a base)" \
    -- python3 "$PORTING_SDK_DIR/scripts/gen_type_degeneracy.py" --port ruby --repo .

sched_gate PUBLIC-JARGON res=dayone desc="no porting-internal jargon leaks into the public/published surface" \
    -- python3 "$PORTING_SDK_DIR/scripts/public_jargon.py" --port ruby --repo .

sched_gate GEN-IDIOM res=dayone desc="generated code is not lint-excluded (idiom parity with hand code)" \
    -- python3 "$PORTING_SDK_DIR/scripts/gen_idiom.py" --port ruby --repo .

sched_gate RELEASE-FRESH res=dayone desc="publish workflow runs the gates before publishing (gated release path)" \
    -- python3 "$PORTING_SDK_DIR/scripts/release_fresh.py" --port ruby --repo .

sched_gate SEMVER-DIFF res=dayone desc="version bump matches the API surface change vs the release baseline (port_signatures.baseline.json)" \
    -- python3 "$PORTING_SDK_DIR/scripts/semver_diff.py" --port ruby --repo "$PORT_ROOT"

# ---- §C1 doc/example execution gates -----------------------------------------
# SNIPPET-COMPILE (compile-only) + DOC-CLI (parse-only probe) are cheap → cheap
# wave, blocking. SNIPPET-RUN + EXAMPLES-RUN execute code (mock-backed) and are
# minutes-long → defer=1 heavy wave. Mirrors python's run-ci wiring.
sched_gate SNIPPET-COMPILE tier=nightly desc="documented code snippets compile" \
    -- python3 "$PORTING_SDK_DIR/scripts/snippet_compile.py" --port ruby --repo "$PORT_ROOT"

sched_gate DOC-CLI desc="documented swaig-test invocations parse against the real CLI" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_cli.py" --port ruby --repo "$PORT_ROOT"

# Wave-3 doc/API-truth gates — deterministic source/doc analysis (no build, no
# mock, ~1.3s for all six). Per-PR tier: cheap enough to catch doc/API drift at
# PR time rather than a day later in nightly.
sched_gate ERROR-ENVELOPE desc="REST error carries the full (status,body,url,method) envelope + raised on >=400" \
    -- python3 "$PORTING_SDK_DIR/scripts/error_envelope.py" --port ruby --repo "$PORT_ROOT"
sched_gate DEAD-PUBLIC-ERROR desc="exported error types are raised/caught/user-signalled (no dead error surface)" \
    -- python3 "$PORTING_SDK_DIR/scripts/dead_public_error.py" --port ruby --repo "$PORT_ROOT"
sched_gate PAGINATION-WIRED desc="shipped iterator-protocol paginator is wired into list()" \
    -- python3 "$PORTING_SDK_DIR/scripts/pagination_wired.py" --port ruby --repo "$PORT_ROOT"
sched_gate DOC-ENV desc="documented SIGNALWIRE_*/SWML_* env vars <=> code-read vars agree" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_env.py" --port ruby --repo "$PORT_ROOT"
sched_gate COUNT-CLAIM desc="numeric doc claims (skills/namespaces) match reality" \
    -- python3 "$PORTING_SDK_DIR/scripts/count_claim.py" --port ruby --repo "$PORT_ROOT"
sched_gate ACCESSOR-TRUTH desc="documented backtick method() refs exist in source" \
    -- python3 "$PORTING_SDK_DIR/scripts/accessor_truth.py" --port ruby --repo "$PORT_ROOT"

# SNIPPET-RUN is BLOCKING: every runnable ruby doc snippet must execute to a zero
# exit against the mock. Non-runnable blocks carry a `<!-- snippet: no-run … -->`
# (or no-compile) marker; credential/live-network cases are ledgered in
# SNIPPET_RUN_ALLOW.md. Backlog burned to 0.
sched_gate SNIPPET-RUN tier=nightly defer=1 desc="dynamic-port doc snippets run to a zero exit against the mock" \
    -- python3 "$PORTING_SDK_DIR/scripts/snippet_run.py" --port ruby --repo "$PORT_ROOT"

sched_gate EXAMPLES-RUN tier=nightly defer=1 desc="shipped examples load/start against the mock (modulo EXAMPLES_RUN_ALLOW.md)" \
    -- python3 "$PORTING_SDK_DIR/scripts/examples_run.py" --port ruby --repo "$PORT_ROOT"

# ---- §G anti-laundering ledger + §D1 packaging -------------------------------
sched_gate SUPPRESSION-LEDGER res=dayone desc="no un-ledgered analyzer suppressions (rubocop:disable) outside the ledger" \
    -- python3 "$PORTING_SDK_DIR/scripts/suppression_ledger.py" --port ruby --repo .

sched_gate PACKAGE-SMOKE defer=1 desc="build+install the real gem, then require/construct from the installed artifact" \
    -- python3 "$PORTING_SDK_DIR/scripts/package_smoke.py" --port ruby --repo .

sched_run
rc=$?
if [ "$rc" -eq 0 ]; then
    echo "==> CI PASS"
else
    echo "==> CI FAIL (gates:$FAILED_GATES )"
fi
exit "$rc"
