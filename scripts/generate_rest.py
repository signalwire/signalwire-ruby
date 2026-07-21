#!/usr/bin/env python3
"""Generate the SignalWire REST namespace resource layer for signalwire-ruby.

This is the RUBY realization of porting-sdk/REST_GENERATOR_RULES.md — the
language-neutral contract of the REST resource generator (bases,
x-sdk-resource markup, path composition, command-dispatch, set_methods,
cross-spec client-tree placement, fail-loud invariants).

Convention: like php (scripts/generate_rest.py) and go (cmd/generate-rest),
this is a Python script emitting the TARGET language — Ruby. Ruby's other
audit tooling is already Python (scripts/enumerate_signatures.py), so a Python
emitter matches the port's existing generator/tooling convention. It reads
porting-sdk/rest-apis/<ns>/openapi.yaml + x-sdk-* markup and emits .rb files.

Inputs (resolved from $PORTING_SDK or the adjacent ../porting-sdk):
    rest-apis/<ns>/openapi.yaml       (+ x-sdk-* markup)
    rest-apis/x-sdk-bases.yaml        (shared base method-sets)
    rest-apis/fabric/x-sdk-bases.yaml (FabricResource)

Outputs: Ruby files under lib/signalwire/rest/namespaces/generated/ — one file
per generated resource class, one client-tree container file per namespace
group, and resource_tree.rb (a module the hand RestClient composes). The hand
BASES stay hand-written (lib/signalwire/rest/http_client.rb: BaseResource /
CrudResource / CrudWithAddresses); the generator emits ONLY the per-resource
classes that inherit those bases, their typed create/update + declared/command/
set methods, and the container tree — mirroring the php/go generators.

Idiom (PORT_PHILOSOPHY_RUBY.md, SESSION_CHANGESET_FOR_PORTS.md §B): Ruby is a
KWARGS language (like python). Object-body operation params are emitted as
KEYWORD ARGUMENTS (required first, then optional `name: nil`), plus an explicit
`extras: {}` escape door AND a trailing `**kwargs` keyword-splat tail (the two
kwargs-lang doors — §B). Command-dispatch params flatten the union and emit the
same way. Class names are the x-sdk-resource.name VERBATIM (the Python oracle
canonical names — AiAgents, CxmlApplications, SipEndpoints, Calling, …) so the
Ruby adapter (enumerate_surface.rb) projects each generated class onto the same
signalwire.rest.namespaces.<ns>_resources_generated.<Name> module the oracle
produces.

The Ruby surface enumerator records `public_instance_methods(false)` (OWN
methods only, not inherited), so — unlike php whose reflection unfolds
inherited base methods — a full-CRUD resource must EMIT its typed create/update
into the subclass body (they override the base's generic create/update; the
oracle records exactly `create`/`update` on such a subclass, with
list/get/delete/list_addresses inherited from the base and NOT recorded on the
subclass). This matches REST_GENERATOR_RULES §2 ("the typed create/update
override per resource; list/get/delete stay in the base").

Usage:
    python3 scripts/generate_rest.py                 # write into the repo tree
    python3 scripts/generate_rest.py --check         # GEN-FRESH: fail if stale
    python3 scripts/generate_rest.py --out DIR       # scratch: emit flat into DIR
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _gen_format import rubocop_format, wrap_spec_derived_disables  # noqa: E402

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.stderr.write("generate_rest.py requires PyYAML (pip install pyyaml)\n")
    raise


# ---------------------------------------------------------------------------
# SDK-surface policy overlay (rest-apis/x-sdk-overlay.yaml) — the SINGLE
# authoritative source for which spec fields the SDKs hide or deprecate. It is a
# policy overlay, NOT wire truth / markup in the (often vendored) specs, so the
# same field is governed once and applied wherever it surfaces (schema.json
# $defs/AIParams for swml-verbs + the calling/fabric REST projections). Each rule
# matches by (field name, containing SPEC schema name): `scope` is compared to the
# schema's name AS IT APPEARS IN THE SPEC (the $defs / components.schemas key) — NOT
# the Ruby class name this generator later emits — so one scope value works cross-port.
#   - hidden:     DROP the field from the SDK surface entirely (still on the wire).
#   - deprecated: EMIT the field but flag it deprecated (a `# deprecated:` comment).
# _overlay_cache holds {"hidden": set, "deprecated": set} of (field, scope-or-None).
_overlay_cache: "dict[str, set[tuple[str, str | None]]] | None" = None


def _load_overlay(psdk: Path) -> "dict[str, set[tuple[str, str | None]]]":
    global _overlay_cache
    if _overlay_cache is None:
        def rules(key: str, data: dict) -> "set[tuple[str, str | None]]":
            out: set[tuple[str, str | None]] = set()
            for entry in data.get(key) or []:
                if isinstance(entry, dict) and entry.get("field"):
                    out.add((entry["field"], entry.get("scope")))
            return out
        path = psdk / "rest-apis" / "x-sdk-overlay.yaml"
        data = yaml.safe_load(path.read_text()) if path.is_file() else {}
        data = data or {}
        _overlay_cache = {"hidden": rules("hidden", data),
                          "deprecated": rules("deprecated", data)}
    return _overlay_cache


def _overlay_match(rules: "set[tuple[str, str | None]]", field: str,
                   schema_name: "str | None") -> bool:
    # A rule matches when its field equals `field` AND (it is unscoped OR its scope
    # equals the containing SPEC schema name — the $defs / components.schemas key,
    # NOT the emitted Ruby class name).
    for rf, scope in rules:
        if rf == field and (scope is None or scope == schema_name):
            return True
    return False


def overlay_hidden(field: str, schema_name: "str | None", psdk: Path) -> bool:
    return _overlay_match(_load_overlay(psdk)["hidden"], field, schema_name)


def overlay_deprecated(field: str, schema_name: "str | None", psdk: Path) -> bool:
    return _overlay_match(_load_overlay(psdk)["deprecated"], field, schema_name)


# Namespace discovery (was: two hardcoded lists SPEC_DIRS + TYPE_NS). The set of
# REST namespaces is DERIVED by scanning porting-sdk/rest-apis/*/openapi.yaml —
# the same spec-driven discovery the Python reference generator uses — so a new
# spec is picked up automatically instead of requiring a hand-edit of a list (the
# old lists carried no information not already in the specs). TWO discovery rules:
#
#   * RESOURCE namespace  — a spec whose openapi.yaml carries x-sdk-resource
#     markup on at least one path (or a top-level x-sdk-namespace). These are the
#     namespaces that get a generated resource layer + client tree. (14 specs;
#     `swml-webhooks` has no such markup and is excluded. `projects` — the new
#     `/api/projects` full-CRUD project-management surface, DISTINCT from the
#     singular `project` token namespace — now carries x-sdk-resource markup and
#     IS a resource namespace: `client.projects`. `messages` — the new
#     `/api/messaging/messages` send/redact surface, DISTINCT from the `message`
#     log namespace — carries x-sdk-resource markup: `client.messages`.)
#   * TYPE namespace      — a spec with a components/schemas section that is
#     EITHER a resource namespace OR a types-only payload spec (one with NO
#     `servers` block, i.e. not an addressable REST surface — this admits
#     `swml-webhooks`, a pure webhook-payload schema doc). (15 specs.)
#
# Ordering is load-bearing for byte-identical output (container/tree accessor
# order follows spec iteration order), and the historical hand-order is not
# alphabetical, so _NS_ORDER pins the canonical position of each known spec; a
# newly-discovered spec not in _NS_ORDER sorts to the end (deterministic) — it is
# never silently dropped. registry has no own dir (its resources live inside
# relay-rest via namespace: registry).
_NS_ORDER = [
    "relay-rest", "fabric", "calling", "video", "datasphere",
    "logs", "message", "messages", "voice", "fax", "project", "projects",
    "chat", "pubsub", "swml-webhooks",
]

# Module-segment casing overrides — where mechanical PascalCase of the dir name
# does not match the canonical Ruby module constant. `pubsub` -> `PubSub` (the
# canonical camel spelling; a bare PascalCase would give `Pubsub`). Everything
# else derives mechanically (dash-split PascalCase: `relay-rest` -> `RelayRest`).
_NS_MOD_OVERRIDE = {"pubsub": "PubSub"}


def _ns_order_key(dir_name: str) -> tuple[int, str]:
    """Sort key that reproduces the historical hand-order for known specs and
    puts any newly-discovered spec deterministically at the end (alphabetically)."""
    try:
        return (_NS_ORDER.index(dir_name), "")
    except ValueError:
        return (len(_NS_ORDER), dir_name)


def _ns_module(dir_name: str) -> str:
    """PascalCase Ruby module segment for a spec dir (`relay-rest` -> `RelayRest`),
    with the _NS_MOD_OVERRIDE casing exceptions applied (`pubsub` -> `PubSub`)."""
    if dir_name in _NS_MOD_OVERRIDE:
        return _NS_MOD_OVERRIDE[dir_name]
    return "".join(p[:1].upper() + p[1:] for p in dir_name.split("-"))


def _scan_namespaces(psdk: Path) -> tuple[list[str], list[tuple[str, str, str]]]:
    """Scan rest-apis/*/openapi.yaml and return (resource_dirs, type_ns) applying
    the two discovery rules documented above.

      * resource_dirs — spec dirs with x-sdk-resource / x-sdk-namespace markup,
        in canonical order (replaces the old SPEC_DIRS list).
      * type_ns       — [(spec_dir, ModuleSegment, ns_key)] for every spec with a
        components/schemas section that is a resource namespace OR a servers-less
        types-only spec, in canonical order (replaces the old TYPE_NS list).
        ns_key = dir with `-` folded to `_` (`relay-rest` -> `relay_rest`).
    """
    rest_apis = psdk / "rest-apis"
    dirs = sorted(
        (d.name for d in rest_apis.iterdir() if (d / "openapi.yaml").is_file()),
        key=_ns_order_key,
    )
    resource_dirs: list[str] = []
    type_ns: list[tuple[str, str, str]] = []
    for name in dirs:
        doc = yaml.safe_load((rest_apis / name / "openapi.yaml").read_text()) or {}
        has_resource = bool(doc.get("x-sdk-namespace")) or any(
            isinstance(item, dict) and item.get("x-sdk-resource")
            for item in (doc.get("paths") or {}).values()
        )
        has_schemas = bool(((doc.get("components") or {}).get("schemas")))
        has_servers = bool(doc.get("servers"))
        if has_resource:
            resource_dirs.append(name)
        # Type namespace: schema-bearing AND (a resource ns OR a servers-less
        # types-only payload spec). Excludes a staged REST surface (servers +
        # schemas but no x-sdk-resource, e.g. `projects`).
        if has_schemas and (has_resource or not has_servers):
            type_ns.append((name, _ns_module(name), name.replace("-", "_")))
    return resource_dirs, type_ns


# Ruby reserved words. A wire field colliding with one becomes a safe param
# (`end` -> `end_`) mapped back to the wire key in the body (§5). Method / class
# names collide only via the calling command-dispatch (handled by the command
# name derivation, e.g. `calling.end` -> `end`, which IS a keyword — see below).
RUBY_KEYWORDS = {
    "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def",
    "defined?", "do", "else", "elsif", "end", "ensure", "false", "for", "if",
    "in", "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
    "return", "self", "super", "then", "true", "undef", "unless", "until",
    "when", "while", "yield", "__FILE__", "__LINE__", "__ENCODING__",
}


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
    raise SystemExit("generate_rest.py: porting-sdk not found (set $PORTING_SDK or clone adjacent)")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# ---------------------------------------------------------------------------
# Base loading (x-sdk-bases; §2) — validate cyclic/undefined extends (fail loud).
# ---------------------------------------------------------------------------

def load_bases(psdk: Path) -> dict[str, list[str]]:
    raw = yaml.safe_load((psdk / "rest-apis" / "x-sdk-bases.yaml").read_text())
    bases = dict(raw.get("x-sdk-bases") or {})
    fab = psdk / "rest-apis" / "fabric" / "x-sdk-bases.yaml"
    if fab.is_file():
        bases.update((yaml.safe_load(fab.read_text()).get("x-sdk-bases") or {}))

    def resolve(name: str, seen: set[str]) -> list[str]:
        if name in seen:
            raise SystemExit(f"x-sdk-bases: cyclic extends at {name}")
        if name not in bases:
            raise SystemExit(f"x-sdk-bases: undefined base {name!r}")
        seen = seen | {name}
        methods: list[str] = []
        ext = bases[name].get("extends")
        if ext:
            methods.extend(resolve(ext, seen))
        methods.extend(list((bases[name].get("methods") or {}).keys()))
        return methods

    return {name: resolve(name, set()) for name in bases}


# ---------------------------------------------------------------------------
# Spec model.
# ---------------------------------------------------------------------------

class Spec:
    def __init__(self, name: str, doc: dict):
        self.name = name
        self.doc = doc
        self.server_path = _url_path(doc["servers"][0]["url"])
        if self.server_path != "/" and self.server_path.endswith("/"):
            raise SystemExit(f"{name}: servers[0].url path {self.server_path!r} has a trailing slash")
        self.namespace_attr = (doc.get("x-sdk-namespace") or {}).get("attr") or ""
        self.ops: dict[str, tuple[str, str, bool]] = {}
        self.op_body: dict[str, dict] = {}  # operationId -> requestBody JSON schema (or {})
        for path, item in (doc.get("paths") or {}).items():
            for verb in ("get", "post", "put", "patch", "delete"):
                o = item.get(verb)
                if o and o.get("operationId"):
                    self.ops[o["operationId"]] = (verb, path, bool(o.get("requestBody")))
                    body = o.get("requestBody") or {}
                    content = body.get("content") or {}
                    media = content.get("application/json") or (next(iter(content.values())) if content else {})
                    self.op_body[o["operationId"]] = (media or {}).get("schema") or {}
        self.schemas = ((doc.get("components") or {}).get("schemas")) or {}

    def resources(self) -> list[tuple[str, dict]]:
        out = []
        for path, item in (self.doc.get("paths") or {}).items():
            r = item.get("x-sdk-resource")
            if r and not r.get("exclude") and r.get("name"):
                out.append((path, r))
        return out


def _url_path(url: str) -> str:
    if "://" in url:
        url = url.split("://", 1)[1]
    i = url.find("/")
    return url[i:] if i >= 0 else "/"


def load_spec(psdk: Path, ns: str) -> Spec:
    return Spec(ns, yaml.safe_load((psdk / "rest-apis" / ns / "openapi.yaml").read_text()))


# ---------------------------------------------------------------------------
# Path composition (§4).
# ---------------------------------------------------------------------------

def join_path(a: str, b: str) -> str:
    if not b:
        return a
    return a.rstrip("/") + "/" + b.lstrip("/")


def collection_segment(anchor: str, markup: dict) -> str:
    if "collection" in markup:
        return markup["collection"]
    p = anchor
    i = p.find("/{")
    if i >= 0:
        p = p[:i]
    return p


def base_path(spec: Spec, anchor: str, markup: dict) -> str:
    return join_path(spec.server_path, collection_segment(anchor, markup))


def relative_tail(spec: Spec, anchor: str, markup: dict, op_path: str):
    coll = collection_segment(anchor, markup)
    full = join_path(spec.server_path, coll)
    absp = join_path(spec.server_path, op_path)
    if coll and absp.startswith(full + "/"):
        return ([s for s in absp[len(full) + 1:].split("/") if s], False)
    if coll and absp == full:
        return ([], False)
    return ([s for s in absp.lstrip("/").split("/") if s], True)


# ---------------------------------------------------------------------------
# Naming.
# ---------------------------------------------------------------------------

def escape_param(field: str) -> str:
    """A wire field name → a safe Ruby keyword-arg identifier. Ruby keyword-arg
    names are snake_case (already the wire convention); the aliased identifier is
    mapped back to the wire key in the body build (only the param NAME changes,
    never the wire key). Two escapes:
      * a reserved word gets a trailing underscore (`end` -> `end_`);
      * a name whose first character is UPPERCASE is a Ruby CONSTANT, not a valid
        param identifier, so it is lower-cased (`SWAIG` -> `swaig`). This is the
        Ruby analog of Python's `from`->`from_` reserved-word field rename — the
        oracle records `SWAIG` (Python allows uppercase params), so this is a
        documented port param rename (an adapter rename entry at adoption, like
        `from`->`from_`), NOT an omission."""
    ident = field
    if ident and ident[0].isupper():
        ident = ident[0].lower() + ident[1:]
    if ident in RUBY_KEYWORDS:
        return ident + "_"
    return ident


PARAM_ARG_NAME = {
    "id": "id", "queue_id": "queue_id", "NumberGroupId": "group_id",
    "documentId": "document_id", "chunkId": "chunk_id",
    "mfa_request_id": "request_id", "e164_number": "e164",
    "fabric_subscriber_id": "subscriber_id", "ai_agent_id": "id",
    "cxml_webhook_id": "id", "swml_webhook_id": "id", "token_id": "token_id",
    "room_id": "room_id", "resource_id": "resource_id",
    "sip_endpoint_id": "sip_endpoint_id",
}


def snake(s: str) -> str:
    out = []
    for ch in s.replace("-", "_").replace(".", "_"):
        if ch.isupper():
            if out and out[-1] != "_":
                out.append("_")
            out.append(ch.lower())
        else:
            out.append(ch)
    return "".join(out)


def arg_for(brace: str) -> str:
    return PARAM_ARG_NAME.get(brace, snake(brace) or "id")


def rb_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


# ---------------------------------------------------------------------------
# Base mapping (§2). Ruby hand bases live in http_client.rb:
#   BaseResource(http, base_path)          — floor; _path helper
#   CrudResource < BaseResource            — list/create/get/update/delete
#   CrudWithAddresses < CrudResource       — + list_addresses
# FabricResource / FabricResourcePUT are generated (they only pick the update
# verb) — a plain subclass of CrudWithAddresses.
# ---------------------------------------------------------------------------

BASE_PROVIDES = {
    "CrudResource": {"list", "create", "get", "update", "delete"},
    "FabricResource": {"list", "create", "get", "update", "delete", "list_addresses"},
    "ReadResource": {"list", "paginate", "get"},
    "BaseResource": set(),
}

# The Ruby parent class each markup base inherits (the hand base in http_client.rb,
# except FabricResource/PUT which are generated below and extend CrudWithAddresses).
RUBY_PARENT = {
    "CrudResource": "SignalWire::REST::CrudResource",
    # ReadResource is a list+get SUBSET — it must NOT inherit CrudResource (that
    # would expose create/update/delete the oracle doesn't have). It inherits the
    # BaseResource floor and EMITS its own list/get (which the Ruby enumerator —
    # own-methods-only — then records; the oracle records exactly list+get on a
    # ReadResource subclass). Composition-first, never subtract-down (§2).
    "ReadResource": "SignalWire::REST::BaseResource",
    "FabricResource": None,  # -> FabricResource / FabricResourcePUT (generated below)
    "BaseResource": "SignalWire::REST::BaseResource",
}


# ---------------------------------------------------------------------------
# Command-dispatch (§6).
# ---------------------------------------------------------------------------

def command_method_name(cmd: str) -> str:
    """Command string -> ruby snake_case method name (strip a leading `calling.`
    domain prefix, dots -> underscores). `calling.play.pause` -> `play_pause`,
    `dial` -> `dial`, `calling.end` -> `end` (a keyword, but a valid METHOD name
    in ruby — only PARAM/local-var identifiers need escaping)."""
    s = cmd[len("calling."):] if cmd.startswith("calling.") else cmd
    return s.replace(".", "_")


def discriminator_mapping(spec: Spec, schema_name: str) -> dict:
    sch = spec.schemas.get(schema_name)
    if sch is None:
        raise SystemExit(f"command-dispatch request {schema_name!r} not in components.schemas")
    mapping = (sch.get("discriminator") or {}).get("mapping")
    if not mapping:
        raise SystemExit(f"command-dispatch request {schema_name!r} has no discriminator.mapping")
    return mapping


# ---------------------------------------------------------------------------
# Typed inputs (§5).
# ---------------------------------------------------------------------------

def resolve_schema(spec: Spec, schema: dict | None, seen=None) -> dict:
    if not schema:
        return {}
    if seen is None:
        seen = set()
    ref = schema.get("$ref")
    if ref:
        if not ref.startswith("#/"):
            return {}
        leaf = ref.rsplit("/", 1)[-1]
        if leaf in seen:
            return {}
        seen.add(leaf)
        return resolve_schema(spec, spec.schemas.get(leaf), seen)
    allof = schema.get("allOf")
    if allof and len(allof) == 1 and not schema.get("properties") and not schema.get("type"):
        return resolve_schema(spec, allof[0], seen)
    return schema


def object_body_fields(spec: Spec, body_schema: dict) -> list[tuple[str, dict, bool]]:
    """[(wire_name, field_schema, required)] for an object request body,
    flattening allOf and following $refs. Spec declaration order preserved."""
    resolved = resolve_schema(spec, body_schema)
    props: dict[str, dict] = {}
    required: set[str] = set(resolved.get("required") or [])
    for name, psc in (resolved.get("properties") or {}).items():
        props.setdefault(name, psc)
    for br in resolved.get("allOf") or []:
        rb = resolve_schema(spec, br)
        required |= set(rb.get("required") or [])
        for name, psc in (rb.get("properties") or {}).items():
            props.setdefault(name, psc)
    return [(name, psc, name in required) for name, psc in props.items()]


def command_param_fields(spec: Spec, command_schema: dict) -> tuple[list[tuple[str, dict, bool]], bool]:
    """§6 union-flatten: ([(wire_name, schema, required)], has_id). The command
    schema's `params` sub-schema may itself be anyOf/oneOf of variant param
    schemas; expose the UNION of variants' fields, a field required only if
    EVERY variant requires it. `has_id` = the command schema has an `id`."""
    cs = resolve_schema(spec, command_schema)
    has_id = "id" in (cs.get("properties") or {})
    params_schema = (cs.get("properties") or {}).get("params")
    if params_schema is None:
        return [], has_id
    ps = resolve_schema(spec, params_schema)
    variants: list[dict] = []
    for comb in ("anyOf", "oneOf"):
        if comb in ps:
            variants = [resolve_schema(spec, v) for v in ps[comb]]
            break
    if not variants:
        variants = [ps]
    all_props: dict[str, dict] = {}
    req_sets: list[set[str]] = []
    for v in variants:
        req_sets.append(set(v.get("required") or []))
        for name, psc in (v.get("properties") or {}).items():
            all_props.setdefault(name, psc)
    req_all = set.intersection(*req_sets) if req_sets else set()
    return [(name, psc, name in req_all) for name, psc in all_props.items()], has_id


def is_object_body(spec: Spec, body_schema: dict) -> bool:
    """True when the request body is a typed OBJECT (properties / $ref to an
    object) → closed typed params. False for a top-level union body (anyOf/oneOf
    with no single object) → a single positional `body` param (§5.2)."""
    if not body_schema:
        return False
    if "anyOf" in body_schema or "oneOf" in body_schema:
        return False
    resolved = resolve_schema(spec, body_schema)
    if "anyOf" in resolved or "oneOf" in resolved:
        return False
    if resolved.get("properties") or resolved.get("allOf"):
        return True
    return (resolved.get("type") == "object")


def ordered_fields(fields):
    """Required-first, then optional; stable within each group (spec order)."""
    req = [f for f in fields if f[2]]
    opt = [f for f in fields if not f[2]]
    return req + opt


# ---------------------------------------------------------------------------
# Canonical audit types for the typed-input sidecar (§B / L10).
#
# Ruby is dynamically typed, so the source keyword params carry no static type;
# the ENUMERATOR can't recover one either. The generator therefore writes a
# machine-readable sidecar (`rest_signatures.json`) recording, for every
# generated operation/command/set/CRUD method, the canonical audit TYPE of each
# body field — the type the reference oracle records, expressed in an OPEN form
# that folds onto the concrete reference type via the drift gate's
# `types_compatible`:
#   * optional field           -> ``optional<any>``  (compatible with EVERY
#                                  concrete ``optional<X>`` the oracle records)
#   * required NAMED-$ref field -> ``dict<string,any>`` (folds onto the oracle's
#                                  ``gen:<Name>`` — the diff treats gen:X ==
#                                  open-object dict in either direction)
#   * required inline scalar    -> its concrete scalar (string/int/float/bool)
#   * required array            -> ``list<any>``
#   * required inline object    -> ``dict<string,any>``
# This is idiom-safe: the field's Ruby runtime value is untyped, but the AUDIT
# type recorded is the real (open) shape — never a bare ``any`` (which the drift
# gate correctly fails for a param the oracle types concretely; L14).
# ---------------------------------------------------------------------------

_SCALAR_CANON = {"string": "string", "integer": "int", "number": "float", "boolean": "bool"}


def _is_named_ref(schema: dict) -> bool:
    """True when the field is a $ref to a named object schema (directly or via a
    single-member allOf) — the oracle records these as a generated ``gen:<Name>``
    type, which the drift gate folds onto ``dict<string,any>``."""
    if not schema:
        return False
    if schema.get("$ref"):
        return True
    allof = schema.get("allOf")
    if allof and len(allof) == 1 and not schema.get("properties") and not schema.get("type"):
        return _is_named_ref(allof[0])
    return False


def _json_type(schema: dict) -> str | None:
    t = schema.get("type")
    if isinstance(t, list):
        non_null = [x for x in t if x != "null"]
        return non_null[0] if non_null else None
    return t


def canonical_type(spec: Spec, schema: dict, required: bool) -> str:
    """The canonical audit type the sidecar records for a body field (see the
    module comment above)."""
    if not required:
        return "optional<any>"
    if _is_named_ref(schema):
        return "dict<string,any>"
    resolved = resolve_schema(spec, schema)
    jt = _json_type(resolved)
    if jt in _SCALAR_CANON:
        return _SCALAR_CANON[jt]
    if jt == "array":
        return "list<any>"
    # inline object / oneOf / anyOf / unknown → an open JSON object.
    return "dict<string,any>"


# Sidecar accumulator: (RubyClassName, ruby_method_name) -> [param records
# without self]. Each record: {"name", "kind", "type", "required", ["default"]}.
# The enumerator UNFOLDS these onto the reflected generated methods (§B / L10),
# replacing the reflected ``any`` types with the recorded open-but-typed ones.
_SIDECAR: dict[tuple[str, str], list[dict]] = {}


def _register_sidecar(cls: str, ruby_method: str, records: list[dict]) -> None:
    _SIDECAR[(cls, ruby_method)] = records


# §PY-7 request_options: every generated REST verb accepts a trailing keyword-only
# ``request_options:`` (per-call timeout / connect_timeout / headers), forwarded to
# the HttpClient verb and NEVER folded into the wire body. Mirrors the Python
# reference, which types it ``RequestOptions | None`` on all resource verbs. The
# sidecar records it as a typed keyword so DRIFT matches the reference's concretely-
# typed param (the diff withdraws the bare-``any`` tolerance for input params).
REQUEST_OPTIONS_TYPE = "optional<class:RequestOptions>"
REQUEST_OPTIONS_SIG = "request_options: nil"
REQUEST_OPTIONS_FWD = "request_options: request_options"


def _request_options_record() -> dict:
    return {"name": "request_options", "kind": "keyword",
            "type": REQUEST_OPTIONS_TYPE, "required": False, "default": None}


def schema_fields(spec: Spec, schema: dict, seen=None) -> set[str]:
    if schema is None:
        return set()
    if seen is None:
        seen = set()
    ref = schema.get("$ref")
    if ref:
        if not ref.startswith("#/"):
            return set()
        leaf = ref.rsplit("/", 1)[-1]
        if leaf in seen:
            return set()
        seen.add(leaf)
        return schema_fields(spec, spec.schemas.get(leaf), seen)
    out = set(((schema.get("properties")) or {}).keys())
    for comb in ("allOf", "anyOf", "oneOf"):
        for br in schema.get(comb) or []:
            out |= schema_fields(spec, br, seen)
    return out


# ---------------------------------------------------------------------------
# Body-param emission (Ruby kwargs + extras + **kwargs — §B).
# ---------------------------------------------------------------------------

def kwarg_params_and_body(spec, fields, indent="        ", body_var="body"):
    """Build (kwarg_param_list, body_build_lines, sidecar_records, body_var) for a set of
    object-body / command-params fields, in the Ruby kwargs idiom + the two doors
    (§B):
      * required field  -> `name:`         (required keyword arg)
      * optional field  -> `name: nil`     (optional keyword arg)
      * `extras: {}`     -> the explicit forward-compat escape door
      * `**kwargs`       -> the keyword-splat tail (kwargs-lang, rides ONLY
                            alongside the explicit extras door)
    The wire body is the non-nil named fields merged with extras and kwargs.
    A reserved-word wire field is aliased (`end` -> `end_`) and mapped back to
    the wire key in the body build.

    ``sidecar_records`` are the canonical typed-param records the audit sidecar
    records for these fields (name=wire key, kind=keyword, type=open-but-typed),
    followed by the ``extras`` (keyword optional dict) + ``kwargs`` (var_keyword)
    forward-compat doors — the enumerator unfolds them onto the reflected method
    (§B / L10)."""
    # Collision-free accumulator name: if a wire field's param ident equals the
    # requested body_var (the messages spec has a field literally named `body`),
    # the `body = {}` accumulator would shadow the `body:` keyword arg, silently
    # breaking `body['body'] = body`. Prefix `req_` (and keep prefixing) until the
    # name no field ident can collide with — a plain identifier rubocop accepts
    # (an underscore prefix trips Lint/UnderscorePrefixedVariableName since the
    # accumulator IS used).
    idents = {escape_param(wire_name) for wire_name, _s, _r in fields}
    while body_var in idents:
        body_var = "req_" + body_var
    params: list[str] = []
    build: list[str] = [f"{indent}{body_var} = {{}}"]
    records: list[dict] = []
    for wire_name, schema, required in ordered_fields(fields):
        ident = escape_param(wire_name)
        ct = canonical_type(spec, schema, required)
        rec: dict = {"name": wire_name, "kind": "keyword", "type": ct, "required": required}
        if required:
            params.append(f"{ident}:")
            build.append(f"{indent}{body_var}[{rb_str(wire_name)}] = {ident}")
        else:
            params.append(f"{ident}: nil")
            rec["default"] = None
            build.append(f"{indent}{body_var}[{rb_str(wire_name)}] = {ident} unless {ident}.nil?")
        records.append(rec)
    params.append("extras: {}")
    params.append(REQUEST_OPTIONS_SIG)
    params.append("**kwargs")
    build.append(f"{indent}{body_var} = {body_var}.merge(extras).merge(kwargs)")
    records.append({
        "name": "extras", "kind": "keyword",
        "type": "optional<dict<string,any>>", "required": False, "default": None,
    })
    # §PY-7: the trailing sidecar slot is the keyword-only ``request_options`` (the
    # reference records it at the var_keyword position; the ``**kwargs`` forward-
    # compat splat stays in the physical signature but is not surfaced in the
    # sidecar). Callers that consume ``records`` therefore already carry it.
    records.append(_request_options_record())
    return params, build, records, body_var


def method_call_path(spec: Spec, anchor: str, markup: dict, op_path: str):
    """Return (id_args, ruby_path_expr) for a declared method op."""
    segs, sibling = relative_tail(spec, anchor, markup, op_path)
    id_args: list[str] = []
    pieces: list[str] = []
    for s in segs:
        if s.startswith("{") and s.endswith("}"):
            arg = arg_for(s[1:-1])
            while arg in id_args:
                arg += "2"
            id_args.append(arg)
            pieces.append(arg)
        else:
            pieces.append(rb_str(s))
    if sibling:
        full = join_path(spec.server_path, op_path.lstrip("/"))
        expr = abs_ruby_path(full, id_args)
    elif not pieces:
        expr = "@base_path"
    else:
        expr = "_path(" + ", ".join(pieces) + ")"
    return id_args, expr


def abs_ruby_path(full: str, id_args: list[str]) -> str:
    """A Ruby double-quoted interpolated string for a sibling absolute path,
    substituting {brace} with the positional id_args in order."""
    out = []
    ai = 0
    i = 0
    while i < len(full):
        if full[i] == "{":
            j = full.find("}", i)
            if ai < len(id_args):
                out.append("#{" + id_args[ai] + "}")
                ai += 1
            i = j + 1
            continue
        out.append(full[i])
        i += 1
    return '"' + "".join(out) + '"'


# ---------------------------------------------------------------------------
# Emitters.
# ---------------------------------------------------------------------------

GEN_HEADER = """# frozen_string_literal: true

# Code generated by scripts/generate_rest.py; DO NOT EDIT.
#
# AUTO-GENERATED from the SignalWire REST API specifications — regenerate with:
#   python3 scripts/generate_rest.py
#
# {desc}
"""


def emit_method(spec: Spec, anchor: str, markup: dict, base: str,
                method_snake: str, op_id: str, indent: str) -> list[str]:
    if op_id not in spec.ops:
        raise SystemExit(f"{markup['name']}.{method_snake}: op {op_id!r} not in spec")
    verb, op_path, has_body = spec.ops[op_id]
    id_args, path_expr = method_call_path(spec, anchor, markup, op_path)
    name = method_snake
    write_verb = verb in ("post", "put", "patch")
    lines: list[str] = []
    verb_fn = {"post": "post", "put": "put", "patch": "patch"}.get(verb, verb)

    cls = markup["name"]
    # Leading path-id params: the reference types every path/collection id
    # positional as ``string`` (a URL path segment). Record them so.
    id_records = [{"name": a, "kind": "positional", "type": "string", "required": True} for a in id_args]

    ro_rec = _request_options_record()
    if write_verb and has_body:
        body_schema = spec.op_body.get(op_id) or {}
        if is_object_body(spec, body_schema):
            fields = object_body_fields(spec, body_schema)
            # kwarg_params_and_body already emits ``request_options: nil`` into the
            # signature (kw) and the request_options record into ``records``.
            kw, build, records, bvar = kwarg_params_and_body(spec, fields, indent=indent + "  ")
            sig = ", ".join(id_args + kw)
            lines.append(f"{indent}def {name}({sig})")
            lines.extend(build)
            lines.append(f"{indent}  @http.{verb_fn}({path_expr}, {bvar}, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")
            _register_sidecar(cls, name, id_records + records)
        else:
            # §5.2 union body → a single positional `body` param. The reference
            # records the whole variant body as ONE param — do NOT explode it
            # (L10 watch-out); record it as a single positional ``body``, typed
            # by the body schema. A named-$ref union body (e.g. a oneOf named
            # ``CallFlowVersionDeployRequest``) the oracle records as
            # ``gen:<Name>`` — ``canonical_type`` returns the folding
            # ``dict<string,any>`` for it; a bare inline union stays ``any``.
            body_type = canonical_type(spec, body_schema, True)
            sig = ", ".join(id_args + ["body", REQUEST_OPTIONS_SIG])
            lines.append(f"{indent}def {name}({sig})")
            lines.append(f"{indent}  @http.{verb_fn}({path_expr}, body, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")
            _register_sidecar(cls, name, id_records + [
                {"name": "body", "kind": "positional", "type": body_type, "required": True},
                ro_rec,
            ])
    elif write_verb:
        sig = ", ".join(id_args + [REQUEST_OPTIONS_SIG])
        lines.append(f"{indent}def {name}({sig})")
        lines.append(f"{indent}  @http.{verb_fn}({path_expr}, {{}}, {REQUEST_OPTIONS_FWD})")
        lines.append(f"{indent}end")
        _register_sidecar(cls, name, id_records + [ro_rec])
    elif verb == "get":
        # §5.3 GET query door — a trailing keyword-splat `**params` map, plus the
        # keyword-only ``request_options:`` (extracted before the splat). The
        # reference enumerator records ONLY the path-ids + ``request_options`` for
        # a GET (the ``**params`` var_keyword is not surfaced), so the sidecar
        # mirrors that shape (drop ``params``, record ``request_options``).
        sig = ", ".join(id_args + [REQUEST_OPTIONS_SIG, "**params"])
        lines.append(f"{indent}def {name}({sig})")
        lines.append(f"{indent}  @http.get({path_expr}, params.empty? ? nil : params, {REQUEST_OPTIONS_FWD})")
        lines.append(f"{indent}end")
        _register_sidecar(cls, name, id_records + [ro_rec])
    else:  # delete
        sig = ", ".join(id_args + [REQUEST_OPTIONS_SIG])
        lines.append(f"{indent}def {name}({sig})")
        lines.append(f"{indent}  @http.delete({path_expr}, {REQUEST_OPTIONS_FWD})")
        lines.append(f"{indent}end")
        _register_sidecar(cls, name, id_records + [ro_rec])
    return lines


def emit_crud_create_update(spec: Spec, anchor: str, markup: dict, base: str, indent: str) -> list[str]:
    """Emit the OWN methods the oracle records for a full-CRUD resource, matching
    the Python enumerator's rule (`_emit_generic_inherited`): it walks the DIRECT
    generic base the resource subscripts and records that base's OWN members onto
    the subclass, with locally-overridden ones winning.

      * CrudResource's OWN members are {create, update, delete} (list/get live one
        level up on ReadResource → NOT recorded on the subclass). So a plain
        CrudResource resource records create + update (typed overrides) + DELETE.
      * FabricResource has NO own members (it only extends CrudWithAddresses), so a
        FabricResource resource records ONLY create + update — delete/list_addresses
        stay inherited (from CrudResource/CrudWithAddresses, two levels up) and are
        NOT recorded on the subclass.

    The Ruby surface enumerator records own-methods-only, so we EMIT exactly this
    own-set into the subclass body (delete for CrudResource, not for
    FabricResource) to reproduce the oracle."""
    lines: list[str] = []
    coll = collection_segment(anchor, markup)
    # create: the collection-level POST (create_* operation).
    create_op = _find_op(spec, anchor, markup, verbs=("post",), item_level=False)
    update_verb = "put" if markup.get("update_method") == "PUT" else "patch"
    update_op = _find_op(spec, anchor, markup, verbs=(update_verb, "put", "patch"), item_level=True)

    # NOTE: the plain-CRUD create/update/delete are NOT sidecar-registered. The
    # reference publishes them structurally (a CrudResource base), so the drift
    # gate's ``crud_satisfied`` already tolerates the port's per-method idiom
    # (a single ``body`` param) — registering a sidecar here would only risk
    # perturbing an already-satisfied method. Only DECLARED operation/command/set
    # methods (emit_method / emit_command_dispatch / emit_set_method) need the
    # typed-input unfold.
    if create_op:
        _, _, cbody = create_op
        fields = object_body_fields(spec, cbody) if is_object_body(spec, cbody) else None
        if fields is not None:
            kw, build, _records, bvar = kwarg_params_and_body(spec, fields, indent=indent + "  ")
            lines.append(f"{indent}def create({', '.join(kw)})")
            lines.extend(build)
            lines.append(f"{indent}  @http.post(@base_path, {bvar}, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")
        else:
            lines.append(f"{indent}def create(body, {REQUEST_OPTIONS_SIG})")
            lines.append(f"{indent}  @http.post(@base_path, body, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")

    if update_op:
        uverb, _, ubody = update_op
        fields = object_body_fields(spec, ubody) if is_object_body(spec, ubody) else None
        verb_fn = uverb
        if fields is not None:
            kw, build, _records, bvar = kwarg_params_and_body(spec, fields, indent=indent + "  ")
            lines.append("")
            lines.append(f"{indent}def update(resource_id, {', '.join(kw)})")
            lines.extend(build)
            lines.append(f"{indent}  @http.{verb_fn}(_path(resource_id), {bvar}, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")
        else:
            lines.append("")
            lines.append(f"{indent}def update(resource_id, body, {REQUEST_OPTIONS_SIG})")
            lines.append(f"{indent}  @http.{verb_fn}(_path(resource_id), body, {REQUEST_OPTIONS_FWD})")
            lines.append(f"{indent}end")

    # delete: a CrudResource OWN member → recorded on a plain CrudResource
    # subclass. FabricResource has no own delete, so its subclasses inherit it
    # (not recorded on the subclass) — do NOT emit for FabricResource.
    if base == "CrudResource":
        lines.append("")
        lines.append(f"{indent}def delete(resource_id, {REQUEST_OPTIONS_SIG})")
        lines.append(f"{indent}  @http.delete(_path(resource_id), {REQUEST_OPTIONS_FWD})")
        lines.append(f"{indent}end")
    return lines


def _find_op(spec: Spec, anchor: str, markup: dict, verbs, item_level: bool):
    """Locate the create (collection-level POST) or update (item-level put/patch)
    operation for a CRUD resource. Returns (verb, op_path, body_schema) or None.
    item_level=True → <collection>/{id}; False → the collection path itself."""
    coll = collection_segment(anchor, markup)
    for path, item in (spec.doc.get("paths") or {}).items():
        full = join_path(spec.server_path, coll)
        this = join_path(spec.server_path, path)
        if item_level:
            if not (path.startswith(coll + "/{") and path.count("/{") == 1 and path.endswith("}")):
                continue
        else:
            # collection-level: the anchor collection path exactly
            if this != full:
                continue
        for verb in verbs:
            o = item.get(verb)
            if o and o.get("operationId"):
                body = o.get("requestBody") or {}
                content = body.get("content") or {}
                media = content.get("application/json") or (next(iter(content.values())) if content else {})
                return (verb, path, (media or {}).get("schema") or {})
    return None


def emit_read_list_get(spec: Spec, anchor: str, markup: dict, indent: str) -> list[str]:
    """Emit the ReadResource base method-set (list + get) into the subclass body.
    Mirrors the CrudResource base surface the oracle records for a ReadResource
    subclass: `list(**params)` (collection GET, query tail) and
    `get(resource_id)` (item GET, NO query tail — the base-inherited shape, per
    L4: only DECLARED GET methods carry a query tail, not the base list/get)."""
    lines: list[str] = []
    lines.append(f"{indent}def list({REQUEST_OPTIONS_SIG}, **params)")
    lines.append(f"{indent}  @http.get(@base_path, params.empty? ? nil : params, {REQUEST_OPTIONS_FWD})")
    lines.append(f"{indent}end")
    lines.append("")
    # paginate: the ReadResource base's page-walking iterator (oracle records
    # `paginate` on every ReadResource subclass). Returns an Enumerable
    # PaginatedIterator wired to this resource's collection path — the Ruby
    # idiom for Python's returned iterator; follows resp["links"]["next"].
    lines.append(f"{indent}def paginate({REQUEST_OPTIONS_SIG}, **params)")
    lines.append(
        f"{indent}  SignalWire::REST::PaginatedIterator.new("
        "@http, @base_path, params.empty? ? nil : params, 'data', request_options)"
    )
    lines.append(f"{indent}end")
    lines.append("")
    lines.append(f"{indent}def get(resource_id, {REQUEST_OPTIONS_SIG})")
    lines.append(f"{indent}  @http.get(_path(resource_id), {REQUEST_OPTIONS_FWD})")
    lines.append(f"{indent}end")
    return lines


def emit_set_method(spec: Spec, markup: dict, sm_name: str, sm: dict,
                    update_schema_fields: set[str],
                    update_field_schemas: dict[str, dict], indent: str) -> list[str]:
    handler = sm.get("handler")
    if not handler:
        raise SystemExit(f"{markup['name']}.{sm_name}: set_method missing handler")
    args = sm.get("args") or {}
    params = ["resource_id"]
    required_lines: list[str] = []
    optional_lines: list[tuple[str, str]] = []
    # Sidecar records mirror the reference's set_method shape (§7 / L10): a leading
    # ``resource_id`` (positional string), each arg as a POSITIONAL param typed
    # from its bound update field (optionals carry a default), then the trailing
    # ``extra`` forward-compat splat as a var_keyword. The Ruby method physically
    # takes keyword args + an ``extra: {}`` / ``**kwargs`` pair; the sidecar unfold
    # projects the reference's positional/var_keyword kinds — wire-identical.
    records: list[dict] = [
        {"name": "resource_id", "kind": "positional", "type": "string", "required": True},
    ]
    for arg_name, arg in args.items():
        field = arg.get("field")
        if not field:
            raise SystemExit(f"{markup['name']}.{sm_name}: arg {arg_name!r} missing field")
        if field not in update_schema_fields:
            raise SystemExit(
                f"{markup['name']}.{sm_name}: arg field {field!r} not in update request schema"
            )
        ident = escape_param(arg_name)
        required = bool(arg.get("required"))
        ct = canonical_type(spec, update_field_schemas.get(field, {}), required)
        rec: dict = {"name": arg_name, "kind": "positional", "type": ct, "required": required}
        if required:
            params.append(f"{ident}:")
            required_lines.append(f"{indent}  body[{rb_str(field)}] = {ident}")
        else:
            params.append(f"{ident}: nil")
            rec["default"] = None
            optional_lines.append((ident, field))
        records.append(rec)
    params.append("extra: {}")
    params.append(REQUEST_OPTIONS_SIG)
    params.append("**kwargs")
    # Reference records the trailing keyword-only ``request_options`` at the
    # var_keyword slot (the ``extra``/``**kwargs`` forward-compat splat is not
    # surfaced) — mirror that: append request_options, not an ``extra`` record.
    records.append(_request_options_record())
    _register_sidecar(markup["name"], sm_name, records)
    sig = ", ".join(params)
    lines: list[str] = []
    lines.append(f"{indent}def {sm_name}({sig})")
    lines.append(f"{indent}  body = {{ 'call_handler' => {rb_str(handler)} }}")
    lines.extend(required_lines)
    for ident, field in optional_lines:
        lines.append(f"{indent}  body[{rb_str(field)}] = {ident} unless {ident}.nil?")
    lines.append(f"{indent}  update(resource_id, {REQUEST_OPTIONS_FWD}, **body.transform_keys(&:to_sym), **extra, **kwargs)")
    lines.append(f"{indent}end")
    return lines


def update_request_fields(spec: Spec, anchor: str, markup: dict) -> set[str]:
    op = _find_op(spec, anchor, markup,
                  verbs=("put" if markup.get("update_method") == "PUT" else "patch", "put", "patch"),
                  item_level=True)
    if not op:
        return set()
    return schema_fields(spec, op[2])


def update_request_field_schemas(spec: Spec, anchor: str, markup: dict) -> dict[str, dict]:
    """{ wire_field -> field_schema } for the update request body — used to type
    a set_method's args from their bound update field (§7 sidecar typing)."""
    op = _find_op(spec, anchor, markup,
                  verbs=("put" if markup.get("update_method") == "PUT" else "patch", "put", "patch"),
                  item_level=True)
    if not op:
        return {}
    return {name: sch for name, sch, _req in object_body_fields(spec, op[2])}


def emit_command_dispatch(spec: Spec, anchor: str, markup: dict) -> str:
    name = markup["name"]
    request = markup.get("request")
    if not request:
        raise SystemExit(f"{name}: command-dispatch requires request")
    mapping = discriminator_mapping(spec, request)
    commands = list(mapping.keys())
    op = spec.ops.get("call-commands")
    if op:
        base = join_path(spec.server_path, op[1].lstrip("/"))
    else:
        base = join_path(spec.server_path, anchor.lstrip("/"))

    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append(f"        # {name} — command-dispatch resource ({spec.name} spec).")
    lines.append(f"        #")
    lines.append(f"        # Each method POSTs {{command, params, id?}} to {base}.")
    lines.append(f"        class {name} < SignalWire::REST::BaseResource")
    lines.append("          def initialize(http)")
    lines.append(f"            super(http, {rb_str(base)})")
    lines.append("          end")
    for cmd in commands:
        mname = command_method_name(cmd)
        cmd_ref = mapping.get(cmd) or ""
        cmd_leaf = cmd_ref.rsplit("/", 1)[-1] if cmd_ref else ""
        cmd_schema = spec.schemas.get(cmd_leaf, {})
        fields, with_id = command_param_fields(spec, cmd_schema)
        kw, build, records, bvar = kwarg_params_and_body(spec, fields, indent="            ", body_var="params")
        id_params = ["call_id"] if with_id else []
        sig = ", ".join(id_params + kw)
        id_records = ([{"name": "call_id", "kind": "positional", "type": "string",
                        "required": True}] if with_id else [])
        _register_sidecar(name, mname, id_records + records)
        lines.append("")
        lines.append(f"          def {mname}({sig})")
        lines.extend(build)
        lines.append(f"            body = {{ 'command' => {rb_str(cmd)}, 'params' => {bvar} }}")
        if with_id:
            lines.append("            body['id'] = call_id if call_id")
        lines.append(f"            @http.post(@base_path, body, {REQUEST_OPTIONS_FWD})")
        lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    return GEN_HEADER.format(desc=f"Generated command-dispatch resource for the {spec.name!r} namespace.") + "\n" + "\n".join(lines) + "\n"


# The generated Fabric base classes (they only select the update verb). Emitted
# once into a shared file; every FabricResource resource subclasses one of them.
FABRIC_BASES = """# frozen_string_literal: true

# Code generated by scripts/generate_rest.py; DO NOT EDIT.
#
# AUTO-GENERATED from the SignalWire REST API specifications — regenerate with:
#   python3 scripts/generate_rest.py
#
# Generated Fabric base classes: CRUD + list_addresses (the FabricResource
# method-set, §2), differing only by the update HTTP verb (PATCH vs PUT).

module SignalWire
  module REST
    module Namespaces
      module Generated
        # Fabric CRUD-with-addresses base (PATCH updates).
        class FabricResource < SignalWire::REST::CrudWithAddresses
        end

        # Fabric CRUD-with-addresses base whose updates use PUT.
        class FabricResourcePUT < FabricResource
          self.update_method = 'PUT'
        end
      end
    end
  end
end
"""


def emit_resource(spec: Spec, anchor: str, markup: dict) -> str:
    name = markup["name"]
    base = markup["base"]
    if markup.get("kind") == "command-dispatch":
        return emit_command_dispatch(spec, anchor, markup)
    if base not in BASE_PROVIDES:
        raise SystemExit(f"{name}: unknown base {base!r}")

    # §9: write-capable bases require update_method matching the spec verb.
    if base in ("CrudResource", "FabricResource"):
        upd = markup.get("update_method")
        if not upd:
            raise SystemExit(f"{name}: {base} requires update_method")
        item = spec.doc["paths"][anchor]
        # anchor is the collection path; the update op is item-level. Validate
        # the declared verb against the actual item-level update op.
        up = _find_op(spec, anchor, markup, verbs=("put", "patch"), item_level=True)
        if up:
            spec_verb = up[0].upper()
            if upd != spec_verb:
                raise SystemExit(f"{name}: update_method {upd} != spec update verb {spec_verb}")

    # Resolve the Ruby parent class.
    if base == "FabricResource":
        parent = "FabricResourcePUT" if markup.get("update_method") == "PUT" else "FabricResource"
    else:
        parent = RUBY_PARENT[base]

    bp = base_path(spec, anchor, markup)
    indent = "          "  # class body: 4 module levels (8) + class (2) = 10 spaces

    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append(f"        # {name} — REST resource for the {spec.name} API (base {base}).")
    lines.append(f"        class {name} < {parent}")
    # Constructor bakes the base path (§4).
    lines.append("          def initialize(http)")
    lines.append(f"            super(http, {rb_str(bp)})")
    lines.append("          end")

    provided = BASE_PROVIDES[base]
    declared = markup.get("methods") or {}

    # Full-CRUD bases: emit the typed create/update overrides (the Ruby
    # enumerator records only own methods, so these must be in the subclass).
    if base in ("CrudResource", "FabricResource"):
        cu = emit_crud_create_update(spec, anchor, markup, base, indent)
        if cu:
            lines.append("")
            lines.extend(cu)

    # ReadResource: emit the base list/get into the subclass body (own-methods-
    # only enumerator; the oracle records list+get on a ReadResource subclass).
    if base == "ReadResource":
        lines.append("")
        lines.extend(emit_read_list_get(spec, anchor, markup, indent))

    for method_snake, spec_ref in declared.items():
        op_id = spec_ref.get("op")
        if not op_id:
            raise SystemExit(f"{name}.{method_snake}: method markup missing op")
        # A declared method the base already provides is inherited — EXCEPT
        # list_addresses re-declared with a sibling/override path (fabric
        # singular resources), which must shadow the base; AND declared
        # list/get/create/update/delete on a BaseResource resource (the base
        # does NOT provide them, so they are emitted).
        if method_snake in provided:
            if method_snake == "list_addresses":
                _, op_path, _ = spec.ops[op_id]
                _, sibling = relative_tail(spec, anchor, markup, op_path)
                if not sibling:
                    continue
            else:
                continue
        lines.append("")
        lines.extend(emit_method(spec, anchor, markup, base, method_snake, op_id, indent))

    # set_methods (§7): require a CRUD base.
    set_methods = markup.get("set_methods") or {}
    if set_methods:
        if base not in ("CrudResource", "FabricResource"):
            raise SystemExit(f"{name}: set_methods require a CRUD base, got {base}")
        upd_fields = update_request_fields(spec, anchor, markup)
        upd_schemas = update_request_field_schemas(spec, anchor, markup)
        for sm_name, sm in set_methods.items():
            lines.append("")
            lines.extend(emit_set_method(spec, markup, sm_name, sm, upd_fields, upd_schemas, indent))

    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    return GEN_HEADER.format(desc=f"Generated REST resource for the {spec.name!r} namespace.") + "\n" + "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Client tree (§8).
# ---------------------------------------------------------------------------

# Container attr -> (Ruby container class, RestClient accessor). Reproduces the
# hand FabricNamespace/VideoNamespace surface via the oracle _client_tree names.
CONTAINERS = {
    "fabric": ("FabricNamespace", "fabric"),
    "video": ("VideoNamespace", "video"),
    "logs": ("LogsNamespace", "logs"),
    "registry": ("RegistryNamespace", "registry"),
    "project": ("ProjectNamespace", "project"),
    "datasphere": ("DatasphereNamespace", "datasphere"),
}

# Accessor-name overrides — mirrors the reference generator's _ATTR_OVERRIDE
# table. Where the mechanical "snake_case, strip container prefix" derivation
# doesn't match the canonical accessor the reference client tree exposes, the
# override pins it. Reference FACTS (the accessor callers use).
ATTR_OVERRIDE = {
    "GenericResources": "resources", "FabricAddresses": "addresses",
    "FabricTokens": "tokens", "DatasphereDocuments": "documents",
    "ProjectTokens": "tokens", "PubSub": "pubsub",
    "MessageLogs": "messages", "VoiceLogs": "voice", "FaxLogs": "fax",
    "ConferenceLogs": "conferences",
}


def container_accessor(markup: dict, name: str, container: str) -> str:
    if markup.get("attr"):
        return snake(markup["attr"])
    if name in ATTR_OVERRIDE:
        return snake(ATTR_OVERRIDE[name])
    lead = container[:1].upper() + container[1:]
    stem = name[len(lead):] if name.startswith(lead) else name
    return snake(stem) if stem else snake(name)


def flat_accessor(name: str) -> str:
    if name in ATTR_OVERRIDE:
        return snake(ATTR_OVERRIDE[name])
    return snake(name)


def resolve_placement(specs: list[Spec]):
    placed = []
    for spec in specs:
        for anchor, markup in spec.resources():
            container = markup.get("namespace") or spec.namespace_attr or ""
            placed.append((spec, anchor, markup, container))
    return placed


def emit_container(container: str, members: list[tuple[str, str]]) -> str:
    """members: list of (accessor, class_name)."""
    cls, _ = CONTAINERS[container]
    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append(f"        # {cls} — generated container grouping the {container} namespace resources (§8).")
    lines.append(f"        class {cls}")
    accs = [a for a, _ in members]
    lines.append(f"          attr_reader {', '.join(':' + a for a in accs)}")
    lines.append("")
    lines.append("          def initialize(http)")
    for accessor, class_name in members:
        lines.append(f"            @{accessor} = {class_name}.new(http)")
    lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    return GEN_HEADER.format(desc=f"Generated REST client container for the {container} namespace (§8).") + "\n" + "\n".join(lines) + "\n"


def emit_resource_tree(placed) -> str:
    """Emit ResourceTree: a module the hand RestClient includes, wiring a lazy
    accessor per FLAT resource + per CONTAINER (§8)."""
    flats: list[tuple[str, str]] = []
    containers_seen: list[str] = []
    seen_c: set[str] = set()
    for spec, anchor, markup, container in placed:
        name = markup["name"]
        if not container:
            flats.append((flat_accessor(name), name))
        else:
            if container not in seen_c:
                seen_c.add(container)
                containers_seen.append(container)

    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append("        # ResourceTree — lazy accessors for every flat REST resource plus the")
    lines.append("        # namespace containers. The RestClient includes this module and provides")
    lines.append("        # `generated_http_client`; each accessor memoizes its resource on the")
    lines.append("        # shared HTTP client.")
    lines.append("        module ResourceTree")
    for accessor, cls in flats:
        lines.append("")
        lines.append(f"          def {accessor}")
        lines.append(f"            @{accessor} ||= {cls}.new(generated_http_client)")
        lines.append("          end")
    for c in containers_seen:
        clsname, acc = CONTAINERS[c]
        lines.append("")
        lines.append(f"          def {acc}")
        lines.append(f"            @{acc} ||= {clsname}.new(generated_http_client)")
        lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    return GEN_HEADER.format(desc="Generated REST resource tree module the hand RestClient includes (§8).") + "\n" + "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Wire-type emitter (item A/H — REAL types, not loose Hash).
#
# For each REST namespace, emit one Ruby data class per components/schemas entry
# whose schema is an OBJECT: a METHOD-LESS class carrying a frozen ``FIELDS``
# constant that maps each snake wire key to its JSON type symbol. The class has
# NO reader/writer methods and NO ``initialize`` — the Python reference records
# these as method-less type definitions, so the surface enumerator surfaces the
# bare class name with an empty method set. (A constant does not surface as a
# method in the Ruby enumerator, which walks only public instance/singleton
# methods.) This is idiomatic Ruby for a schema/DTO shape holder that documents
# the wire contract without polluting the method surface.
#
# A named public enum (x-sdk-enum — only PhoneCallHandler in relay-rest) becomes
# a method-less Ruby class carrying frozen string constants (value == wire
# string) grouped into a frozen ``ALL`` list — the port's closed-set idiom
# (PORT_PHILOSOPHY_RUBY: frozen string constants, not a static enum type). Also
# method-less, so it records ``[]`` like the reference.
#
# Every OTHER schema kind — a closed/open scalar or array alias, a oneOf/anyOf
# union, a bare inline string enum — is NOT surfaced by the Python reference (its
# enumerator drops module-level scalar TypeAlias / inline Literal), so this
# emitter emits nothing for it (matching the reference surface exactly —
# verified per namespace, emit-set == oracle-set, 0 missing / 0 extra).
#
# Files land one-class-per-file under
#   lib/signalwire/rest/namespaces/generated/types/<ns>/<snake_name>.rb
# in namespace SignalWire::REST::Namespaces::Generated::Types::<NsMod>. The
# <ns> subdir maps 1:1 to the oracle's <ns>_types_generated module: the surface
# and signature enumerators route by the FQN namespace prefix
# (SignalWire::REST::Namespaces::Generated::Types::<NsMod>::) to
# signalwire.rest.namespaces.<ns>_types_generated, WINNING over the name-keyed
# class->module map — required because type names recur across namespaces AND
# collide with SDK class names (DataMap/Document/Section).
#
# The reference emits the SAME schema name into multiple <ns>_types_generated
# modules (shared SWML-schema types + shared error types Types_StatusCodes_*);
# Ruby mirrors that per-namespace duplication faithfully (each spec's
# components/schemas carries its own copy). The SURFACE-DIFF tool's gen-type
# leaf-name fold collapses a type declared in >1 module to a single
# gen-type.<Leaf> symbol on BOTH sides, so the duplicates compare equal.
# ---------------------------------------------------------------------------

TYPES_HEADER = """# frozen_string_literal: true

# Code generated by scripts/generate_rest.py; DO NOT EDIT.
#
# AUTO-GENERATED from the SignalWire REST API specifications (schemas) — regenerate with:
#   python3 scripts/generate_rest.py
#
# {desc}
"""


def type_name(raw: str) -> str:
    """Sanitise a components/schemas key to a valid Ruby CONSTANT (class) name,
    folding every non-identifier rune to ``_`` — matching the Go/TS/PHP/python
    ref_name so the LEAF the surface diff compares is the identical token across
    ports (``Types.StatusCodes.StatusCode400`` -> ``Types_StatusCodes_StatusCode400``).
    Ruby class names are constants: they must begin with an uppercase letter, and
    every wire schema name already does, so no reserved-word rename is needed (a
    Ruby constant may be any word incl. keywords; scoped under the Types module a
    name like ``Set`` merely shadows the stdlib constant inside that namespace,
    which is harmless for a method-less data holder)."""
    s = re.sub(r"[^A-Za-z0-9_]", "_", raw).lstrip("_")
    if not s:
        return "Schema"
    if s[0].isdigit():
        return "Schema_" + s
    if not s[0].isupper():
        s = s[0].upper() + s[1:]
    return s


def _type_schema_type(node: dict):
    t = node.get("type")
    if isinstance(t, list):
        return next((x for x in t if x != "null"), None)
    return t


def is_object_schema(node: dict) -> bool:
    """Mirror the reference is_object test: type:object (or no type but non-empty
    properties) AND not a oneOf/anyOf/allOf combinator AND properties non-empty."""
    if any(k in node for k in ("oneOf", "anyOf", "allOf")):
        return False
    props = node.get("properties")
    t = _type_schema_type(node)
    return (t == "object" or (t is None and props)) and isinstance(props, dict) and len(props) > 0


def _wire_field_type_symbol(psc: dict) -> str:
    """A short JSON-type symbol (``:string``/``:integer``/``:number``/``:boolean``/
    ``:array``/``:object``/``:any``) documenting the wire type of a field, for the
    frozen FIELDS map. Purely documentary — the surface records only the class
    name; this keeps the DTO self-describing without any reader method."""
    if not isinstance(psc, dict):
        return ":any"
    if any(k in psc for k in ("$ref", "allOf", "oneOf", "anyOf")):
        # A $ref/combinator resolves to a nested object/union on the wire.
        return ":object"
    t = _type_schema_type(psc)
    if t in ("string", "integer", "number", "boolean", "array", "object"):
        return f":{t}"
    return ":any"


def emit_type_class(ns_mod: str, raw_name: str, node: dict, ns_key: str,
                    psdk: "Path | None" = None) -> str:
    """Emit one method-less Ruby data class for an object schema.

    ``raw_name`` is the SPEC schema name (the components/schemas key) — that, not the
    emitted Ruby class name, is what the x-sdk-overlay policy is scoped by."""
    rb_name = type_name(raw_name)
    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append("        module Types")
    lines.append(f"          module {ns_mod}")
    lines.append(f"            # {rb_name} — generated wire type from the {ns_key!r} spec"
                 f" (components/schemas {raw_name!r}).")
    lines.append("            #")
    lines.append("            # Method-less data DTO: the frozen FIELDS constant maps each snake wire")
    lines.append("            # key to its JSON type symbol. No reader/writer methods and no")
    lines.append("            # initialize — the reference records this as a method-less type")
    lines.append("            # definition, so the surface enumerator surfaces the bare class name.")
    lines.append(f"            class {rb_name}")
    # SDK-surface policy from the single overlay (rest-apis/x-sdk-overlay.yaml), keyed by
    # the SPEC schema name (raw_name, the components/schemas key — NOT the emitted Ruby
    # class name): hidden fields dropped entirely, deprecated fields flagged.
    props = {
        k: v for k, v in (node.get("properties") or {}).items()
        if not (psdk and overlay_hidden(k, raw_name, psdk))
    }
    if props:
        lines.append("              FIELDS = {")
        for wire_key, psc in props.items():
            sym = _wire_field_type_symbol(psc if isinstance(psc, dict) else {})
            if psdk and overlay_deprecated(wire_key, raw_name, psdk):
                lines.append(f"                # deprecated: {wire_key}")
            lines.append(f"                {rb_str(wire_key)} => {sym},")
        lines.append("              }.freeze")
    else:
        lines.append("              FIELDS = {}.freeze")
    lines.append("            end")
    lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    desc = f"Generated REST wire type for the {ns_key!r} namespace (object schema)."
    return TYPES_HEADER.format(desc=desc) + "\n" + "\n".join(lines) + "\n"


def _enum_const_name(value: str) -> str:
    """UPPER_SNAKE constant name for a closed-set wire value."""
    s = re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_").upper()
    if not s:
        s = "VALUE"
    if s[0].isdigit():
        s = "V_" + s
    return s


def emit_type_enum(ns_mod: str, enum_name: str, values: list, ns_key: str, raw_name: str) -> str:
    """Emit a method-less Ruby class carrying frozen string constants (value ==
    wire string) grouped into a frozen ALL list — the port's closed-set idiom for
    an x-sdk-enum public enum (PORT_PHILOSOPHY_RUBY). Surfaced as a method-less
    class by the reference."""
    lines: list[str] = []
    lines.append("module SignalWire")
    lines.append("  module REST")
    lines.append("    module Namespaces")
    lines.append("      module Generated")
    lines.append("        module Types")
    lines.append(f"          module {ns_mod}")
    lines.append(f"            # {enum_name} — public closed-set for {raw_name!r}")
    lines.append(f"            # ({ns_key!r} API). Frozen string constants whose value IS the wire")
    lines.append("            # string (the idiomatic Ruby closed set — not a static enum type),")
    lines.append("            # grouped into a frozen ALL. Method-less, records [] like the reference.")
    lines.append(f"            class {enum_name}")
    used: set[str] = set()
    consts: list[str] = []
    for v in values:
        if v == "" or not isinstance(v, str):
            continue
        cname = _enum_const_name(v)
        while cname in used:
            cname += "_"
        used.add(cname)
        consts.append(cname)
        lines.append(f"              {cname} = {rb_str(v)}")
    if consts:
        lines.append("")
        lines.append("              ALL = [" + ", ".join(consts) + "].freeze")
    else:
        lines.append("              ALL = [].freeze")
    lines.append("            end")
    lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    desc = f"Generated REST public closed-set for the {ns_key!r} namespace."
    return TYPES_HEADER.format(desc=desc) + "\n" + "\n".join(lines) + "\n"


GENERIC_TYPES_HEADER = """# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# {desc}
"""


def _reader_name(wire_key: str) -> str:
    """Ruby attr_reader identifier for a wire key. Fold non-identifier runes to
    ``_``; a leading digit / uppercase-initial is legal for a method name (Ruby
    method names may start uppercase). The reader name is the wire key VERBATIM
    where it is already a valid identifier, so the reference's recorded accessor
    name (== the wire field) matches (SWAIG stays SWAIG, not sWAIG — a reader is
    a method, not a keyword arg, so no reserved-word lowercasing is needed)."""
    s = re.sub(r"[^A-Za-z0-9_]", "_", wire_key)
    if not s:
        s = "field"
    if s[0].isdigit():
        s = "_" + s
    return s


def emit_methodless_class(module_segments: list, rb_name: str, properties: dict,
                          source_desc: str, emit_readers: bool = False,
                          spec_schema_name: "str | None" = None,
                          psdk: "Path | None" = None) -> str:
    """Emit one generated Ruby data class under an ARBITRARY nested module path,
    carrying a frozen FIELDS constant that maps each snake wire key to its JSON
    type symbol. Shared by the REST wire-type emitter and the SWML-verbs /
    relay-protocol / SWAIG payload generators so they never diverge.

    ``emit_readers=False`` (REST wire types, relay-protocol, swaig-actions): NO
    reader/writer methods and no initialize — a truly method-less class. The
    reference's SURFACE oracle records these method-less, and its SIGNATURE oracle
    does NOT record them at all (griffe drops a class with no class-typed field),
    so a method-less port class matches BOTH gates (the port's signature_dump also
    drops a method-less class).

    ``emit_readers=True`` (SWML-verbs, post-prompt, swaig-request): ALSO emit one
    zero-arg ``attr_reader`` per wire field. The reference's SIGNATURE oracle
    records these classes WITH a zero-arg accessor per class-typed field (folded to
    ``gen-payload.<Class>.<field>``); the port must present the same accessors to
    match. The SURFACE enumerator DROPS these readers for the generated-payload
    files (they surface method-less, matching the reference surface) — the
    signature/surface split the reference itself has (griffe: fields are
    attributes on the surface, zero-arg accessors in signatures). Extra port
    readers (a field the reference's class-typed filter dropped) are excused as
    port-side state accessors (zero-arg, ``any`` return)."""
    indent = ""
    lines: list[str] = []
    for seg in module_segments:
        lines.append(f"{indent}module {seg}")
        indent += "  "
    kind = "data type" if not emit_readers else "read-side payload"
    lines.append(f"{indent}# {rb_name} — generated {kind} ({source_desc}).")
    lines.append(f"{indent}#")
    lines.append(f"{indent}# Frozen FIELDS maps each snake wire key to its JSON type symbol.")
    if emit_readers:
        lines.append(f"{indent}# A zero-arg reader per field mirrors the reference's recorded")
        lines.append(f"{indent}# accessors (dropped on the SURFACE by the enumerator — method-less there).")
    else:
        lines.append(f"{indent}# No reader/writer methods and no initialize — a method-less type the")
        lines.append(f"{indent}# reference records method-less on both surface and signatures.")
    lines.append(f"{indent}class {rb_name}")
    inner = indent + "  "
    # SDK-surface policy from the single overlay (rest-apis/x-sdk-overlay.yaml), keyed
    # by the SPEC schema name (spec_schema_name) — hidden fields are dropped entirely
    # (FIELDS + reader), deprecated fields are emitted with a `# deprecated:` marker.
    # Only applied when the caller passes the spec name + psdk (swml-verbs does; the
    # relay-protocol / swaig-payload callers don't and are unaffected).
    def _hidden(k: str) -> bool:
        return bool(spec_schema_name and psdk and overlay_hidden(k, spec_schema_name, psdk))

    def _deprecated(k: str) -> bool:
        return bool(spec_schema_name and psdk and overlay_deprecated(k, spec_schema_name, psdk))

    props_kept = {k: v for k, v in (properties or {}).items() if not _hidden(k)}
    if props_kept:
        lines.append(f"{inner}FIELDS = {{")
        for wire_key, psc in props_kept.items():
            sym = _wire_field_type_symbol(psc if isinstance(psc, dict) else {})
            if _deprecated(wire_key):
                lines.append(f"{inner}  # deprecated: {wire_key}")
            lines.append(f"{inner}  {rb_str(wire_key)} => {sym},")
        lines.append(f"{inner}}}.freeze")
        if emit_readers:
            readers: list[str] = []
            used: set = set()
            for wire_key in props_kept:
                r = _reader_name(wire_key)
                while r in used:
                    r += "_"
                used.add(r)
                readers.append(r)
            lines.append("")
            for r in readers:
                lines.append(f"{inner}attr_reader :{r}")
    else:
        lines.append(f"{inner}FIELDS = {{}}.freeze")
    lines.append(f"{indent}end")
    for _ in module_segments:
        indent = indent[:-2]
        lines.append(f"{indent}end")
    return GENERIC_TYPES_HEADER.format(desc=source_desc) + "\n" + "\n".join(lines) + "\n"


def _load_types_schemas(psdk: Path, spec_dir: str) -> dict:
    """Load a spec's components/schemas WITHOUT the full Spec model (swml-webhooks
    has no servers block, so Spec() would reject it). Ordered by yaml declaration."""
    doc = yaml.safe_load((psdk / "rest-apis" / spec_dir / "openapi.yaml").read_text())
    return ((doc.get("components") or {}).get("schemas")) or {}


def emit_types(psdk: Path, outs: dict, type_ns: list[tuple[str, str, str]]) -> None:
    """Emit every <ns>_types_generated Ruby data class / closed-set into
    ``types/<ns>/<snake_name>.rb`` keys of ``outs`` (relative to the Generated
    dir). ``type_ns`` is the scanned [(spec_dir, ModuleSegment, ns_key)] list."""
    for spec_dir, ns_mod, ns_key in type_ns:
        schemas = _load_types_schemas(psdk, spec_dir)
        for raw_name, node in schemas.items():
            if not isinstance(node, dict):
                continue
            # x-sdk-enum public enum → a frozen-string closed-set class.
            xe = node.get("x-sdk-enum")
            if xe:
                enum_name = type_name(xe)
                fn = f"types/{ns_key}/{snake(enum_name)}.rb"
                if fn not in outs:
                    outs[fn] = emit_type_enum(
                        ns_mod, enum_name, list(node.get("enum") or []), ns_key, raw_name)
                continue
            # Object schema → a method-less data class. (Non-object, non-x-sdk-enum
            # schemas — scalar/array/union aliases and plain inline enums — are NOT
            # surfaced by the reference, so emit nothing for them.)
            if is_object_schema(node):
                rb_name = type_name(raw_name)
                fn = f"types/{ns_key}/{snake(rb_name)}.rb"
                # First-seen wins within a namespace (names don't collide inside one
                # spec's components.schemas — verified; guard is belt-and-braces).
                if fn not in outs:
                    outs[fn] = emit_type_class(ns_mod, raw_name, node, ns_key, psdk)


# ---------------------------------------------------------------------------
# Driver.
# ---------------------------------------------------------------------------

def generated_module(spec_name: str) -> str:
    """The oracle module a namespace's resource classes land in — the Python
    reference emits every generated resource of spec ``<ns>`` into
    ``signalwire.rest.namespaces.<ns>_resources_generated`` (spec-dir dashes
    folded to underscores: relay-rest -> relay_rest). Containers live in the
    shared ``_client_tree_generated`` module. The Ruby adapters project each
    generated ``SignalWire::REST::Namespaces::Generated::<Name>`` class onto the
    module this returns so the idiom-blind surface/signature diffs line up 1:1
    with the reference."""
    return "signalwire.rest.namespaces." + spec_name.replace("-", "_") + "_resources_generated"


CLIENT_TREE_MODULE = "signalwire.rest.namespaces._client_tree_generated"


def build_surface_map(psdk: Path) -> dict[str, str]:
    """{ generated class NAME -> reference module } for every emitted resource +
    container. The single source of truth the two Ruby adapters
    (enumerate_signatures.py / enumerate_surface.rb) read via the committed
    ``generated_surface_map.json`` sidecar, so the class->module projection is
    generated once here and never hand-maintained (SESSION_CHANGESET §B)."""
    resource_dirs, _type_ns = _scan_namespaces(psdk)
    specs = [load_spec(psdk, ns) for ns in resource_dirs]
    mapping: dict[str, str] = {}
    for spec in specs:
        for _anchor, markup in spec.resources():
            mapping[markup["name"]] = generated_module(spec.name)
    for cls, _acc in CONTAINERS.values():
        mapping[cls] = CLIENT_TREE_MODULE
    return dict(sorted(mapping.items()))


def build_rest_signatures_sidecar() -> dict:
    """Serialize the typed-input sidecar (_SIDECAR, populated during
    build_outputs) into the committed ``rest_signatures.json`` — the canonical
    typed-param records the enumerator UNFOLDS onto the reflected generated
    operation/command/set methods (§B / L10). Keyed ``ClassName::method``.

    Ruby is dynamically typed and the enumerator cannot recover keyword-only
    kinds / open-`extras` / element types from ``Method#parameters``; the source
    keyword params and this sidecar are BOTH derived from the same computed param
    lists in the generator, so they never diverge (GEN-FRESH covers the sidecar)."""
    methods = {
        f"{cls}::{meth}": records
        for (cls, meth), records in sorted(_SIDECAR.items())
    }
    return {
        "_comment": (
            "Generated by scripts/generate_rest.py; DO NOT EDIT. Canonical typed-param "
            "records for every generated REST operation/command/set method. The "
            "enumerator unfolds these onto the reflected methods (typed-input §B / L10)."
        ),
        "methods": methods,
    }


def build_outputs(psdk: Path) -> dict[str, str]:
    load_bases(psdk)  # validate x-sdk-bases (fail loud)
    resource_dirs, type_ns = _scan_namespaces(psdk)
    specs = [load_spec(psdk, ns) for ns in resource_dirs]
    outs: dict[str, str] = {}

    # Generated Fabric bases (once).
    outs["_fabric_bases.rb"] = FABRIC_BASES

    for spec in specs:
        for anchor, markup in spec.resources():
            src = emit_resource(spec, anchor, markup)
            outs[snake(markup["name"]) + ".rb"] = src

    placed = resolve_placement(specs)
    by_container: dict[str, list[tuple[str, str]]] = {}
    order: list[str] = []
    for spec, anchor, markup, container in placed:
        if not container:
            continue
        if container not in by_container:
            by_container[container] = []
            order.append(container)
        acc = container_accessor(markup, markup["name"], container)
        by_container[container].append((acc, markup["name"]))
    for container in order:
        if container not in CONTAINERS:
            raise SystemExit(f"container attr {container!r} has no Ruby container class (add to CONTAINERS)")
        cls, _ = CONTAINERS[container]
        outs[snake(cls) + ".rb"] = emit_container(container, by_container[container])
    outs["resource_tree.rb"] = emit_resource_tree(placed)

    # Wire types (item A/H): one method-less Ruby data class / closed-set per
    # components/schemas object across all 13 REST namespaces, under types/<ns>/.
    emit_types(psdk, outs, type_ns)
    return outs


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="GEN-FRESH: exit non-zero if stale")
    ap.add_argument("--out", default="", help="scratch: emit flat into this dir")
    args = ap.parse_args(argv)

    psdk = resolve_porting_sdk()
    outs = build_outputs(psdk)

    scratch = bool(args.out)
    if scratch:
        out_dir = Path(args.out)
    else:
        out_dir = repo_root() / "lib" / "signalwire" / "rest" / "namespaces" / "generated"

    # Format-on-emit: run the raw emit through the repo's rubocop safe-autocorrect so the
    # committed tree is both GEN-FRESH clean (regen reproduces it) and FMT/LINT clean
    # (needs no generated-tree Exclude in .rubocop.yml). Skipped for a --out scratch dump.
    if not scratch:
        rel_base = out_dir.relative_to(repo_root()).as_posix()
        wrapped = {f"{rel_base}/{fn}": wrap_spec_derived_disables(src) for fn, src in outs.items()}
        formatted = rubocop_format(wrapped)
        outs = {fn: formatted[f"{rel_base}/{fn}"] for fn in outs}

    # The class->reference-module sidecar the two Ruby adapters read. Committed
    # at the repo root next to port_signatures.json; only emitted/checked for the
    # real source-tree run (a --out scratch run is a flat dump for A-agent diffing
    # and has no adapters to feed).
    sidecar_path = repo_root() / "generated_surface_map.json"
    sidecar_src = json.dumps(build_surface_map(psdk), indent=2, sort_keys=True) + "\n"

    # The typed-input sidecar the enumerator UNFOLDS onto the generated methods
    # (§B / L10). Populated during build_outputs(psdk) above. Committed at the
    # repo root next to port_signatures.json.
    rest_sig_path = repo_root() / "rest_signatures.json"
    rest_sig_src = json.dumps(build_rest_signatures_sidecar(), indent=2, sort_keys=True) + "\n"

    if args.check:
        stale = []
        for fn, src in outs.items():
            p = out_dir / fn
            if not p.is_file() or p.read_text() != src:
                stale.append(str(p))
        expected = set(outs.keys())
        for p in sorted(out_dir.rglob("*.rb")):
            rel = p.relative_to(out_dir).as_posix()
            if rel not in expected:
                stale.append(f"{p} (leftover — not in generator output)")
        if not scratch and (not sidecar_path.is_file() or sidecar_path.read_text() != sidecar_src):
            stale.append(f"{sidecar_path} (surface-map sidecar stale)")
        if not scratch and (not rest_sig_path.is_file() or rest_sig_path.read_text() != rest_sig_src):
            stale.append(f"{rest_sig_path} (typed-input sidecar stale)")
        if stale:
            sys.stderr.write("GEN-FRESH FAIL: %d generated REST file(s) stale:\n" % len(stale))
            for s in stale:
                sys.stderr.write("  - %s\n" % s)
            return 1
        print("GEN-FRESH: generated REST files match the canonical specs.")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    for fn, src in outs.items():
        p = out_dir / fn
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(src)
    if not scratch:
        sidecar_path.write_text(sidecar_src)
        rest_sig_path.write_text(rest_sig_src)
    print(f"generated {len(outs)} REST file(s) into {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
