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

# Gate-enforcement plan (Part D): ruby's red list is burned, so its widened
# (wave-A) gate findings BLOCK rather than report-only. Default OFF here; a
# caller may still set SW_WAVE_A_REPORT_ONLY=1 to inspect the report-only view.
export SW_WAVE_A_REPORT_ONLY="${SW_WAVE_A_REPORT_ONLY:-0}"

# STRICT-MOCKS D3 (400-default, fleet-wide): the REST mock returns a 400 on any
# wire-truth violation (unknown/wrong key) instead of only journaling it, so a
# test that puts a bad shape on the REST wire FAILS here rather than passing
# vacuously. Exported (not per-gate) so it reaches the mock subprocess the TEST
# harness spawns. Declared in WIRED_MODES.md; the WIRED-MODES gate guards it
# against a merge silently dropping the line.
export MOCK_SIGNALWIRE_STRICT=1

echo "==> running CI gates for $PORT_NAME (porting-sdk at $PORTING_SDK_DIR)"
echo "==> wave-A gate findings are ${SW_WAVE_A_REPORT_ONLY:+BLOCKING (SW_WAVE_A_REPORT_ONLY=$SW_WAVE_A_REPORT_ONLY)}"

# NOTE: the former per-gate `--fn` helpers (surface_fresh_gate, surface_diff_gate,
# rest_coverage_gate, spec_parity_gate, dayone_artifact_deny) and pick_free_port are
# DEAD here — their bodies are reproduced INSIDE the Part-5 suites (SURFACE / BEHAVIORAL
# / PACKAGE), which schedule those rules now. Kept out of this file to avoid drift.

# ---- register gates ----------------------------------------------------------
sched_init "$@"

# HEAVY (deferred behind the cheap wave for S1 fail-fast).
sched_gate TEST defer=1 desc="run-tests.sh (bundle exec rake test)" \
    -- bash scripts/run-tests.sh

# ---- Part 5 gate SUITES ------------------------------------------------------
# The former per-gate SIGNATURES/DRIFT/SURFACE-*/GEN-FRESH*/BEHAVIORAL-*/EMISSION/
# ERROR-ENVELOPE/PAGINATION-WIRED/WAIT-LIVENESS/DOC-WIRE/REST-COVERAGE/SPEC-PARITY/
# SKILL-CONTRACT/SWAIG-*/DOC-*/COUNT-CLAIM/ACCESSOR-TRUTH/STATUS-CLAIM/README-INCLUDE/
# SEMVER-DIFF/GEN-TYPE-DEGENERACY/GEN-IDIOM/PACKAGE-*/META-CONSISTENT/ARTIFACT-DENY/
# RELEASE-FRESH/*-LEDGER gates now run under 6 SUITE engines. Each suite emits every
# original gate NAME as a `[SUITE:RULE] ... PASS/FAIL` rule ID (failure identity is
# preserved; allowlists + finding output unchanged). A suite exits nonzero iff any of
# its rules fails. Byte-identity vs the old per-gate path is proven by
# porting-sdk/tests/test_suite_parity*.py. See porting-sdk PART5 plan.
#
# The `--fn` helpers the old gates used (surface_fresh_gate, surface_diff_gate,
# rest_coverage_gate, spec_parity_gate, dayone_artifact_deny) are reproduced INSIDE
# the suites, so they are no longer defined here.
#
# The former single-gate scheduler features are preserved by the suites internally:
#   * SIGNATURES→DRIFT ordering + the SURFACE-FRESH/SURFACE-DIFF surface mutex live
#     inside the SURFACE suite (it regenerates + git-restores in order). ruby's
#     SURFACE-DIFF is itself a `--fn` that RE-ENUMERATES the surface — reproduced.
#   * mixed tiers are split with --rules: PACKAGE + BEHAVIORAL each schedule a per-PR
#     line and a nightly line (their nightly members are broken out below).

# SURFACE (parity spine): SIGNATURES→DRIFT ordered, SURFACE-FRESH/DIFF (ruby re-
# enumerates both), SEMVER-DIFF, GEN-TYPE-DEGENERACY, GEN-IDIOM — all read the one
# enumeration. Not deferred: it writes port_signatures.json that nothing else depends
# on cross-suite, and it is the parity spine (run it in the cheap wave). No ROUTE-
# COLLISION (ruby does not wire it — see the ROUTE-COLLISION note below).
sched_gate SURFACE desc="surface parity suite (SIGNATURES/DRIFT/SURFACE-FRESH/SURFACE-DIFF/SEMVER-DIFF/GEN-TYPE-DEGENERACY/GEN-IDIOM)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/surface.py" --port ruby --repo "$PORT_ROOT"

# SIGNATURES-FRESH: the signatures analogue of SURFACE-FRESH. SURFACE-FRESH only
# guards port_surface.json; NOTHING guarded port_signatures.json — yet that file is
# DRIFT's INPUT, so a stale one makes the parity gate compare against a fiction and
# pass. Standalone sched_gate rather than a _surface_commands.py table entry: only 8
# of 10 run-ci scripts read that table, so a table entry is silently skipped where it
# is not read. res=surface shares the mutex with SURFACE, which regenerates
# port_signatures.json in place and git-restores it.
sched_gate SIGNATURES-FRESH res=surface desc="committed port_signatures.json matches a fresh regen" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/_signatures_fresh.py" \
        --port ruby --repo "$PORT_ROOT" --porting-sdk "$PORTING_SDK_DIR"

# TYPE-EROSION: a port may not erase a type the reference DECLARES. compare_param treats
# `any` on EITHER side as matching anything, so a port emitting `any` silently satisfies
# every reference declaration — an unlimited opt-out. ConciergeAgent.hours_of_operation is
# declared optional<dict<string,string>> and go still shipped a bare string, with no gate
# red. RATCHET, not a hard gate: dynamic languages cannot always express a type, so this
# banks the current count and fails only on REGRESSION. Drive the number DOWN; never up.
sched_gate TYPE-EROSION desc="port did not erase a reference-declared param type (ratchet 16)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_type_erosion.py" --port ruby --repo "$PORT_ROOT" --max 16

# GEN (regen-from-specs family): the 5 GEN-FRESH rules.
sched_gate GEN defer=1 desc="generated-code freshness suite (GEN-FRESH/-TESTS/-RELAY/-SWAIG/-SWML)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/gen.py" --port ruby --repo "$PORT_ROOT"

# BEHAVIORAL (one Layer-D pass per rule): the per-PR rules. WAIT-LIVENESS (nightly)
# is the separate line below.
sched_gate BEHAVIORAL defer=1 desc="behavioral suite (BEHAVIORAL-*/EMISSION/ERROR-ENVELOPE/PAGINATION-WIRED/PAGINATION-CORPUS/DOC-WIRE/REST-COVERAGE/SPEC-PARITY/SKILL-CONTRACT/SWAIG-COVERAGE/SWAIG-CLI/CA-VAR/SECURE-DEFAULT/SECRET-SCRUB/TLS-VERIFY)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/behavioral.py" --port ruby --repo "$PORT_ROOT" \
        --rules BEHAVIORAL-WIRE,BEHAVIORAL-SWML,BEHAVIORAL-STRICT-RENDER,BEHAVIORAL-STATE,BEHAVIORAL-HTTP,BEHAVIORAL-WIRE-RELAY,EMISSION,ERROR-ENVELOPE,PAGINATION-WIRED,PAGINATION-CORPUS,DOC-WIRE,REST-COVERAGE,SPEC-PARITY,SKILL-CONTRACT,SWAIG-COVERAGE,SWAIG-CLI,CA-VAR,SECURE-DEFAULT,SECRET-SCRUB,TLS-VERIFY

sched_gate BEHAVIORAL-NIGHTLY tier=nightly defer=1 desc="behavioral suite, nightly rules (WAIT-LIVENESS/RELAY-LIVENESS/SECRET-SCRUB-LIVE)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/behavioral.py" --port ruby --repo "$PORT_ROOT" \
        --rules WAIT-LIVENESS,RELAY-LIVENESS,SECRET-SCRUB-LIVE

# TOKEN-INTEROP — property 3 of the SWAIG tool-token contract: a token this port MINTS
# must validate under the REFERENCE's own decoder. SECURE-DEFAULT proves a token is
# minted and the fleet keying check proves the HMAC key; NEITHER sees the base64
# ENVELOPE, so a port can ship correct-key correct-HMAC tokens that no other
# implementation accepts — in production every secure tool call then fails auth. Six of
# the ten ports shipped exactly that (an unpadded envelope), invisible to their own tests
# because each port's DECODER tolerates missing padding while the reference's
# urlsafe_b64decode RAISES on it — so round-tripping against ourselves could never catch
# it. One mint + a pure-python validation → cheap, per-PR (a security property must not
# wait for nightly). Its OWN line rather than a member of the BEHAVIORAL suite line,
# which is defer=1 (heavy wave).
sched_gate TOKEN-INTEROP desc="a token this port mints validates under the reference's decoder (padded urlsafe base64, ':'-signed / '.'-enveloped, hex HMAC keyed by the secret_key string)" \
    -- python3 "$PORTING_SDK_DIR/scripts/diff_port_token_interop.py" --port ruby \
        --mint-cmd "bundle exec ruby $PORT_ROOT/bin/token-interop-mint"

# DOC-TRUTH (one markdown walk): DOC-AUDIT/DOC-LINKS/DOC-LANG-PURITY/DOC-ENV/COUNT-CLAIM/
# ACCESSOR-TRUTH/STATUS-CLAIM/README-INCLUDE. res=surface: DOC-AUDIT reads port_surface.json
# that the SURFACE suite regenerates+restores.
sched_gate DOC-TRUTH res=surface desc="doc-truth suite (DOC-AUDIT/DOC-LINKS/DOC-LANG-PURITY/DOC-ENV/COUNT-CLAIM/ACCESSOR-TRUTH/STATUS-CLAIM/README-INCLUDE)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/doc_truth.py" --port ruby --repo "$PORT_ROOT"

# LEDGER: SUPPRESSION-LEDGER + IGNORE-LEDGER-VERIFY.
sched_gate LEDGER res=dayone desc="ledger governance suite (SUPPRESSION-LEDGER/IGNORE-LEDGER-VERIFY)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/ledger.py" --port ruby --repo "$PORT_ROOT"

# PACKAGE: per-PR rules (ARTIFACT-DENY/RELEASE-FRESH); nightly rules (PACKAGE-SMOKE/
# META-CONSISTENT) on the separate line below.
sched_gate PACKAGE res=dayone desc="package suite, per-PR rules (ARTIFACT-DENY/RELEASE-FRESH)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/package.py" --port ruby --repo "$PORT_ROOT" \
        --rules ARTIFACT-DENY,RELEASE-FRESH

sched_gate PACKAGE-NIGHTLY tier=nightly defer=1 desc="package suite, nightly rules (PACKAGE-SMOKE/META-CONSISTENT)" \
    -- python3 "$PORTING_SDK_DIR/scripts/suites/package.py" --port ruby --repo "$PORT_ROOT" \
        --rules PACKAGE-SMOKE,META-CONSISTENT

# ---- gates that stay standalone (native toolchains + singletons) -------------
sched_gate NO-CHEAT desc="audit_no_cheat_tests" \
    -- python3 "$PORTING_SDK_DIR/scripts/audit_no_cheat_tests.py" --root "$PORT_ROOT"

sched_gate COORDINATED-PASS desc="a non-main porting-sdk pin must be declared on the PR (Coordinated-With: line or coordinated-pass label)" \
    -- python3 "$PORTING_SDK_DIR/scripts/coordinated_pass.py" --porting-sdk "$PORTING_SDK_DIR"

sched_gate COORDINATED-REFS desc="every coordinated-set checkout (porting-sdk + python oracle + matrix ports) uses PORTING_SDK_REF, not a literal ref" \
    -- python3 "$PORTING_SDK_DIR/scripts/check_coordinated_refs.py" --repo "$PORT_ROOT"

sched_gate ENV-VAR-CONSISTENCY desc="REST base-url override present + custom-CA env names canonical (SIGNALWIRE_{REST,RELAY}_CA_FILE)" \
    -- python3 "$PORTING_SDK_DIR/scripts/env_var_consistency.py" --port ruby --repo "$PORT_ROOT"

# NOTE: ACTIONLINT is intentionally NOT wired into ruby's run-ci. The gate fails
# LOUD (exit 2) when the actionlint native binary is absent, and ruby's CI runners
# don't install it — wiring it would red the test job (as it did for another port).
# porting-sdk's cross-port ACTIONLINT run already covers workflow-validity detection
# for every port. This port's workflows are verified valid (live-smoke.yml gates on a
# JOB-level env, not a step-level secrets.* in if:); actionlint is clean here.

sched_gate FMT defer=1 desc="run-format.sh (local: apply; CI: --check)" \
    -- bash scripts/run-format.sh ${CI:+--check}

sched_gate LINT defer=1 desc="run-lint.sh (rubocop zero offenses)" \
    -- bash scripts/run-lint.sh

# ROUTE-COLLISION is intentionally NOT wired (kept out of the SURFACE suite for ruby):
# with ruby's route_registry.rb it fails on a SPEC-FAITHFUL route-split — the fabric
# spec declares SINGULAR sibling paths /resources/call_flow/{id}/addresses +
# /resources/conference_room/{id}/addresses (operationIds list_call_flow_addresses /
# list_conference_room_addresses) while the class collection base is plural. Ruby's
# generated code matches the spec exactly, so this is a proven exception that needs a
# human-approved ROUTE_COLLISION_ALLOW.md entry before it can be wired enforcing — not
# added autonomously. Follow-up.

sched_gate PUBLIC-JARGON res=dayone desc="no porting-internal jargon leaks into the public/published surface" \
    -- python3 "$PORTING_SDK_DIR/scripts/public_jargon.py" --port ruby --repo .

sched_gate ROOT-HYGIENE res=dayone desc="no audit/scratch clutter tracked at repo root (allowlist ROOT_HYGIENE_ALLOW.md)" \
    -- python3 "$PORTING_SDK_DIR/scripts/root_hygiene.py" --port ruby --repo .

# ---- §C1 doc/example execution gates -----------------------------------------
# SNIPPET-COMPILE (compile-only) + DOC-CLI (parse-only probe) mirror python's wiring;
# DEAD-PUBLIC-ERROR is source analysis of exported error types (not a doc-truth/
# behavioral rule) → stays standalone. SNIPPET-RUN + EXAMPLES-RUN execute code
# (mock-backed) and are minutes-long → defer=1 heavy nightly wave.
sched_gate SNIPPET-COMPILE tier=nightly desc="documented code snippets compile" \
    -- python3 "$PORTING_SDK_DIR/scripts/snippet_compile.py" --port ruby --repo "$PORT_ROOT"

sched_gate DOC-CLI desc="documented swaig-test invocations parse against the real CLI" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_cli.py" --port ruby --repo "$PORT_ROOT"

sched_gate DEAD-PUBLIC-ERROR desc="exported error types are raised/caught/user-signalled (no dead error surface)" \
    -- python3 "$PORTING_SDK_DIR/scripts/dead_public_error.py" --port ruby --repo "$PORT_ROOT"

# SNIPPET-RUN is BLOCKING: every runnable ruby doc snippet must execute to a zero
# exit against the mock. Non-runnable blocks carry a `<!-- snippet: no-run … -->`
# (or no-compile) marker; credential/live-network cases are ledgered in
# SNIPPET_RUN_ALLOW.md. Backlog burned to 0. STRICT-MOCKS (§2.x): MOCK_RELAY_STRICT=1
# makes the mock reject unknown wire keys/frames so a snippet that puts a bad shape
# on the wire fails here (nightly, where the heavy mock-backed execution runs).
sched_gate SNIPPET-RUN tier=nightly defer=1 desc="dynamic-port doc snippets run to a zero exit against the mock (STRICT-MOCKS: MOCK_RELAY_STRICT=1)" \
    -- env MOCK_RELAY_STRICT=1 python3 "$PORTING_SDK_DIR/scripts/snippet_run.py" --port ruby --repo "$PORT_ROOT"

sched_gate EXAMPLES-RUN tier=nightly defer=1 desc="shipped examples load/start against the mock (modulo EXAMPLES_RUN_ALLOW.md; STRICT-MOCKS: MOCK_RELAY_STRICT=1)" \
    -- env MOCK_RELAY_STRICT=1 python3 "$PORTING_SDK_DIR/scripts/examples_run.py" --port ruby --repo "$PORT_ROOT"

# DOC-SURFACE (§6.3): public doc-comment (YARD `#`) coverage floor.
# BLOCKING. ruby is at 100.0% (2162/2162) as of the 2026-07-29 burn and .doc_surface_floor
# is pinned there, so the next undocumented public method is a real regression with a
# pinned number to prove it — it must red the run rather than print a line and pass.
sched_gate DOC-SURFACE desc="public YARD doc-comment coverage holds the .doc_surface_floor ratchet (100% — blocking)" \
    -- python3 "$PORTING_SDK_DIR/scripts/doc_surface.py" --port ruby --repo "$PORT_ROOT"

# WIRED-MODES (Part 1.6 / D7): guard that this run-ci still exports the
# load-bearing strict-mode lines declared in WIRED_MODES.md (MOCK_RELAY_STRICT +
# MOCK_SIGNALWIRE_STRICT). The strict-mocks × Part-5 merge race silently dropped
# such lines from several ports, shipping green-and-vacuous gates; this fails
# loud if a future merge drops one here.
sched_gate WIRED-MODES desc="run-ci exports every load-bearing strict-mode line declared in WIRED_MODES.md" \
    -- python3 "$PORTING_SDK_DIR/scripts/check_wired_modes.py" --port ruby --repo "$PORT_ROOT"

# AI-CHAT (task #22, COORDINATED pass ruby:ai-chat-client <-> porting-sdk:ai-chat-client):
# wire-behavioral gate for the AIChatClient. Drives bin/ai-chat-dump through the shared
# ai_chat_corpus against porting-sdk's in-process mock_ai_chat and asserts the client
# speaks the AI Chat JSON-RPC protocol per the vendored spec (ai-chat-specs/ai-chat.yaml).
# The gate script (diff_port_ai_chat.py) + mock live on the porting-sdk `ai-chat-client`
# branch, so during the coordinated pass PORTING_SDK_REF pins that branch and the gate
# runs; on plain main it skip-passes until the branch merges.
sched_gate AI-CHAT desc="AIChatClient speaks the AI Chat protocol per the vendored spec (mock_ai_chat wire-behavioral)" \
    -- bash -c 'if [ -f "$1/scripts/diff_port_ai_chat.py" ]; then python3 "$1/scripts/diff_port_ai_chat.py" --port ruby --dump-cmd "ruby $2/bin/ai-chat-dump"; else echo "[ai-chat] diff_port_ai_chat.py not on porting-sdk main yet — skip-pass (coordinated-branch dep: porting-sdk ai-chat-client)"; fi' _ "$PORTING_SDK_DIR" "$PORT_ROOT"

# GATE-INVENTORY NOTE (§2.16): §1.11b (GATE-INVENTORY freshness) is intentionally
# NOT wired here. gen_gate_inventory.py resolves its reference port as a SIBLING
# checkout (DEFAULT_REFERENCE=signalwire-typescript), which does not exist in a
# port's CI layout (porting-sdk is a subdir of the port workspace, so
# ../signalwire-typescript is absent → exit 2). The check is inherently
# porting-sdk-side and already runs in porting-sdk's own CI
# (.github/workflows/test.yml). Wiring it per-port would require each port to also
# check out the TS reference — not worth it.

sched_run
rc=$?
if [ "$rc" -eq 0 ]; then
    echo "==> CI PASS"
else
    echo "==> CI FAIL (gates:$FAILED_GATES )"
fi
exit "$rc"
