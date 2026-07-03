#!/usr/bin/env python3
"""Generate the full-mock REST wire-test suite for signalwire-ruby.

This is the Ruby realisation of porting-sdk/REST_TEST_GENERATOR_RULES.md (the
portable REST *test* generator; reference:
generate_python_rest_types.py::generate_rest_tests, mirrors:
signalwire-php/scripts/generate_rest_tests.py + signalwire-go/cmd/
generate-rest-tests + signalwire-typescript/scripts/generate-rest-tests.ts). For
every REST route the SDK actually implements it emits, into
tests/rest/generated/<spec>_generated_test.rb:

  - a SUCCESS test: call the real SDK method against the shared mock_signalwire
    harness (MockTest.client), assert the mock journaled the expected
    (method, matched_route);
  - an ERROR test: arm a 500 for that route, assert the SDK raises
    SignalWire::REST::SignalWireRestError with .status_code == 500.

The assertion oracle is INDEPENDENT of the resource generator (RULES §1):
  - the (method, path) to call + the via method come from the route registry
    (scripts/route_registry.rb — captured from the REAL client) and the per-via
    call plan (scripts/rest_test_plan.rb — reflected from the real client), NOT
    re-walked here;
  - the matched_route to assert comes from the OpenAPI operationId
    (<spec_dir>.<operationId>) — the same value the mock derives its route table
    from. A generated test therefore catches SDK-vs-contract drift, not a
    generator self-snapshot.

Inputs joined by (METHOD, normalized-path) (RULES §2): the registry's deduped
routes (path params already {id}) × the spec operationIds (spec path normalized
the SAME way before the join). Routing collisions are resolved
longest-template-wins (RULES §7) so the asserted route is the one the mock
ACTUALLY journals (e.g. GET /rooms/{id} vs GET /rooms/{name}).

Call args are sentinel-faithful BY CONSTRUCTION (RULES §4): rest_test_plan.rb
reflects each via method's REQUIRED parameters off the live client and emits a
Ruby literal token per required param (a required positional path id → 'x'; a
required keyword closed-param body field → `name: 'x'`). Ruby is dynamically
typed and every closed required field the SDK exposes is string-shaped at the
wire, so a single 'x' sentinel is faithful — proven by route_registry.rb
invoking every route with the same string sentinel and reporting zero errors.

GEN-FRESH: `--check` reproduces the committed *_generated_test.rb and exits
non-zero if any file differs. Resolves porting-sdk via $PORTING_SDK or sibling.

Usage:
    python3 scripts/generate_rest_tests.py           # (re)write the test files
    python3 scripts/generate_rest_tests.py --check   # GEN-FRESH: fail if stale
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.stderr.write("generate_rest_tests.py requires PyYAML (pip install pyyaml)\n")
    raise


# ---------------------------------------------------------------------------
# Resolution.
# ---------------------------------------------------------------------------

def resolve_porting_sdk() -> Path:
    env = os.environ.get("PORTING_SDK")
    if env and (Path(env) / "rest-apis").is_dir():
        return Path(env).resolve()
    here = Path(__file__).resolve()
    for parent in here.parents:
        cand = parent.parent / "porting-sdk"
        if (cand / "rest-apis").is_dir():
            return cand.resolve()
    raise SystemExit(
        "generate_rest_tests.py: porting-sdk not found (set $PORTING_SDK or clone adjacent)"
    )


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# ---------------------------------------------------------------------------
# 1. Capture from the real client (RULES §3) — shell the committed Ruby helpers.
#    route_registry.rb: the SDK's deduped routes (via-merged, {id}-normalized).
#    rest_test_plan.rb: per-via call plan (chain, member, sentinel args).
# ---------------------------------------------------------------------------

def _run_ruby(script: Path) -> dict:
    proc = subprocess.run(
        ["ruby", "-Ilib", str(script)],
        cwd=str(repo_root()),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit(f"{script.name} exited {proc.returncode} — capture incomplete")
    out = proc.stdout
    # A stray log line may precede the JSON; slice from the first '{'.
    i = out.find("{")
    if i > 0:
        out = out[i:]
    return json.loads(out)


def load_routes() -> list[dict]:
    reg = _run_ruby(repo_root() / "scripts" / "route_registry.rb")
    if reg.get("errors"):
        raise SystemExit(
            f"route_registry.rb reported {len(reg['errors'])} capture error(s) — Set B incomplete"
        )
    return reg["routes"]


def load_plan() -> dict[str, dict]:
    plan = _run_ruby(repo_root() / "scripts" / "rest_test_plan.rb")
    if plan.get("errors"):
        raise SystemExit(
            f"rest_test_plan.rb reported {len(plan['errors'])} capture error(s) — plan incomplete"
        )
    # Index by via (unique per plan entry).
    return {e["via"]: e for e in plan["plan"]}


# ---------------------------------------------------------------------------
# 2. The join — registry routes × spec operationIds by (method, normalized-path).
# ---------------------------------------------------------------------------

_BRACE = re.compile(r"\{[^}]+\}")


def norm_params(p: str) -> str:
    """Every {param} → {id} (registry already does this; do it to the spec path
    so renamed params — {token_id}, {name} — line up)."""
    return _BRACE.sub("{id}", p)


def wire_key(p: str) -> str:
    """Every {param} → X: the wire-identical key used for collision ranking."""
    return _BRACE.sub("X", p)


def spec_prefix(doc: dict) -> str:
    url = ((doc.get("servers") or [{}])[0]).get("url", "")
    i = url.find("signalwire.com")
    return url[i + len("signalwire.com"):] if i >= 0 else ""


def spec_dirs_with_openapi(psdk: Path) -> list[str]:
    root = psdk / "rest-apis"
    out = [
        d.name
        for d in root.iterdir()
        if d.is_dir() and (d / "openapi.yaml").is_file()
    ]
    return sorted(out)


def build_join(routes: list[dict], psdk: Path, spec_dirs: list[str]) -> list[dict]:
    """Return one joined row per registry route that has a spec op AND a via.

    Row: {method, path, op_id (<spec>.<operationId>), via, spec}. The via is the
    registry's via[0] — the same accessor go/ts/php pick — and the op_id is the
    longest-template collision winner the mock actually journals (RULES §7).
    """
    op_by: dict[str, str] = {}  # "METHOD normPath" -> <spec>.<operationId>
    wire_winner: dict[str, tuple[int, str]] = {}  # "METHOD wireKey" -> (len, route)
    verbs = ("get", "post", "put", "patch", "delete")

    for spec in spec_dirs:
        doc = yaml.safe_load((psdk / "rest-apis" / spec / "openapi.yaml").read_text())
        prefix = spec_prefix(doc)
        for path_key, body in (doc.get("paths") or {}).items():
            orig = prefix + path_key
            full = _BRACE.sub("{id}", orig)
            wk = _BRACE.sub("X", orig)
            for verb in verbs:
                op = body.get(verb)
                if not isinstance(op, dict):
                    continue
                op_id = op.get("operationId")
                if not op_id:
                    continue
                route = f"{spec}.{op_id}"
                op_by[f"{verb.upper()} {full}"] = route
                wkey = f"{verb.upper()} {wk}"
                cur = wire_winner.get(wkey)
                if cur is None or len(orig) > cur[0]:
                    wire_winner[wkey] = (len(orig), route)

    rows: list[dict] = []
    for r in routes:
        via_list = r.get("via") or []
        if not via_list:
            continue  # helper route with no via — skip
        method = r["method"]
        np = norm_params(r["path_template"])
        if f"{method} {np}" not in op_by:
            continue  # no spec op for this route — coverage finding, not a bug
        winner = wire_winner.get(f"{method} {wire_key(r['path_template'])}")
        if winner is None:
            continue
        op_id = winner[1]
        spec = op_id[: op_id.index(".")]
        rows.append({
            "method": method,
            "path": np,
            "op_id": op_id,
            "via": via_list[0],
            "spec": spec,
        })
    return rows


# ---------------------------------------------------------------------------
# 3. Emit — one tests/rest/generated/<spec>_generated_test.rb per spec namespace.
# ---------------------------------------------------------------------------

def camel_spec(spec: str) -> str:
    """spec dir name → CamelCase class-name fragment (relay-rest → RelayRest)."""
    return "".join(part[:1].upper() + part[1:] for part in re.split(r"[-_]", spec) if part)


def slug(via: str) -> str:
    """The resource.method tail of the via, slugified — stable for GEN-FRESH.

    e.g. video.rooms.list_streams → rooms_list_streams; calling.calling.dial →
    calling_dial. Non-alnum → '_', trailing '_' trimmed. Used to build the
    test-method name, which minitest discovers by the `test_` prefix.
    """
    tail = via[via.index(".") + 1:] if "." in via else via
    return re.sub(r"_+$", "", re.sub(r"[^A-Za-z0-9]+", "_", tail))


def call_expr(plan_entry: dict) -> str:
    """The literal Ruby call `@client.ns.res.member(args)`."""
    chain = ".".join(plan_entry["chain"])
    args = ", ".join(plan_entry["args"])
    call = f"@client.{chain}.{plan_entry['member']}"
    return f"{call}({args})" if args else call


HEADER_TMPL = """# frozen_string_literal: true

# Code generated by scripts/generate_rest_tests.py; DO NOT EDIT.
#
# AUTO-GENERATED full-mock REST wire tests for the '{spec}' namespace — regenerate:
#   ruby -Ilib scripts/generate_rest_tests.py  (via python3 scripts/generate_rest_tests.py)
#
# Each route the SDK implements (captured from the real client by
# scripts/route_registry.rb + scripts/rest_test_plan.rb, joined to the spec
# operationId) gets a SUCCESS test (call it, assert method + matched_route on the
# mock journal) and an ERROR test (arm a 500, assert SignalWireRestError with
# .status_code == 500). The assertion oracle is the spec operationId —
# independent of the resource generator — so these catch SDK-vs-contract drift,
# not a generator self-snapshot. Full-mock harness fixtures (MockTest).

require 'minitest/autorun'
require_relative '../mock_test'

# Generated full-mock wire tests for the '{spec}' REST namespace.
class {cls} < Minitest::Test
  # Each test's client uses a unique project + auth-scoped harness, so the shared
  # mock is concurrency-safe; parallelism stress-proves that isolation.
  parallelize_me!

  def setup
    h = MockTest.client
    @client = h[:client]
    @mock = h[:mock]
  end
"""


def emit_spec_file(spec: str, rows: list[dict]) -> str:
    cls = camel_spec(spec) + "GeneratedTest"
    body = HEADER_TMPL.format(spec=spec, cls=cls)
    for r in rows:
        name = r["_name"]
        call = r["_call"]
        method = r["method"]
        op_id = r["op_id"]
        body += f"""
  def test_{name}_success
    {call}
    last = @mock.last

    assert_equal '{method}', last.method
    assert_equal '{op_id}', last.matched_route
  end

  def test_{name}_error
    @mock.push_scenario('{op_id}', status: 500, response: {{ 'error' => 'x' }})
    err = assert_raises(SignalWire::REST::SignalWireRestError) {{ {call} }}

    assert_equal 500, err.status_code
    assert_equal 500, @mock.last.response_status
    assert_equal '{op_id}', @mock.last.matched_route
  end
"""
    body += "end\n"
    return body


# ---------------------------------------------------------------------------
# Driver.
# ---------------------------------------------------------------------------

def build_outputs(psdk: Path) -> tuple[dict[str, str], list[str], int]:
    """Return ({filename: source}, uncovered_vias, n_routes_covered)."""
    routes = load_routes()
    plan = load_plan()
    spec_dirs = spec_dirs_with_openapi(psdk)
    rows = build_join(routes, psdk, spec_dirs)

    by_spec: dict[str, list[dict]] = {}
    uncovered: list[str] = []
    covered_vias: set[str] = set()

    for row in rows:
        via = row["via"]
        entry = plan.get(via)
        if entry is None:
            uncovered.append(f"{via} ({row['method']} {row['path']})")
            continue
        row = dict(row)
        row["_call"] = call_expr(entry)
        row["_slug"] = slug(via)
        by_spec.setdefault(row["spec"], []).append(row)
        covered_vias.add(via)

    outs: dict[str, str] = {}
    for spec in sorted(by_spec):
        srows = by_spec[spec]
        # Deterministic ordering: sort by (via + method).
        srows.sort(key=lambda r: r["via"] + r["method"])
        # Ensure unique test-method names within the file.
        used: set[str] = set()
        for r in srows:
            name = r["_slug"]
            base = name
            k = 2
            while name in used:
                name = f"{base}_{k}"
                k += 1
            used.add(name)
            r["_name"] = name
        fn = f"{spec.replace('-', '_')}_generated_test.rb"
        outs[fn] = emit_spec_file(spec, srows)

    return outs, uncovered, len(covered_vias)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="GEN-FRESH: exit non-zero if stale")
    ap.add_argument("--out", default="", help="scratch: emit into this dir")
    args = ap.parse_args(argv)

    psdk = resolve_porting_sdk()
    outs, uncovered, n_covered = build_outputs(psdk)

    out_dir = Path(args.out) if args.out else (repo_root() / "tests" / "rest" / "generated")

    if uncovered:
        sys.stderr.write(
            f"\nUNCOVERED ({len(uncovered)} joined route(s) with no reflectable via plan):\n"
        )
        for u in uncovered:
            sys.stderr.write(f"  - {u}\n")

    if args.check:
        stale = []
        for fn, src in outs.items():
            p = out_dir / fn
            if not p.is_file() or p.read_text() != src:
                stale.append(str(p))
        expected = set(outs.keys())
        if out_dir.is_dir():
            for p in sorted(out_dir.glob("*_generated_test.rb")):
                if p.name not in expected:
                    stale.append(f"{p} (leftover — not in generator output)")
        if stale:
            sys.stderr.write("GEN-FRESH FAIL: %d generated REST test file(s) stale:\n" % len(stale))
            for s in stale:
                sys.stderr.write(f"  - {s}\n")
            return 1
        total = sum(src.count("def test_") for src in outs.values())
        print(
            f"GEN-FRESH: {len(outs)} generated REST test file(s) up to date "
            f"({total} tests, {n_covered} routes)."
        )
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    # Remove any stale files no longer emitted.
    expected = set(outs.keys())
    for p in sorted(out_dir.glob("*_generated_test.rb")):
        if p.name not in expected:
            p.unlink()
    for fn, src in outs.items():
        (out_dir / fn).write_text(src)
    total = sum(src.count("def test_") for src in outs.values())
    print(
        f"generated {len(outs)} REST test file(s) into {out_dir} "
        f"({total} tests across {len(outs)} namespaces, {n_covered} routes covered)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
