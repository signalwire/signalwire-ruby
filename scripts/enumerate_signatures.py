#!/usr/bin/env python3
"""enumerate_signatures.py — emit port_signatures.json for the Ruby SDK.

Phase 4-Ruby of the cross-language signature audit. Pipeline:

    1. ``bundle exec ruby scripts/signature_dump.rb`` — Ruby
       reflection over every loaded class, dumps method parameters
       (name + kind from Method#parameters) as JSON.
    2. This wrapper applies Ruby→Python module/class mappings extracted
       from scripts/enumerate_surface.rb, translates Ruby parameter
       kinds to canonical, and emits port_signatures.json conforming to
       surface_schema_v2.json.

Ruby is dynamically typed; v1 emits ``any`` for every parameter type.
Structural drift (param name, count, kind, presence) is what's caught;
typed drift requires .rbs annotations or YARD metadata, deferred to a
follow-up.

Usage:
    python3 scripts/enumerate_signatures.py
    python3 scripts/enumerate_signatures.py --raw raw.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PORT_ROOT = HERE.parent


def _resolve_porting_sdk() -> Path:
    """Locate the porting-sdk checkout, or FAIL LOUD.

    Order (first existing wins), matching ``enumerate_surface.rb``:
      1. ``$PORTING_SDK``   — the canonical var every workflow here exports
      2. ``../porting-sdk`` — local layout (sibling of this repo)
      3. ``./porting-sdk``  — CI layout (checked out under the repo root)

    The env var goes FIRST on purpose. It used to be checked only as a fallback
    *after* the sibling probe, so on any machine with a sibling checkout an
    explicit override was silently ignored and could not redirect the enumerator
    at all — the opposite of what an override is for. ``./porting-sdk`` was not
    probed at all, which is the layout CI actually uses.

    Never returns a degraded result: an unresolvable oracle raises. A resolver
    that quietly yields "no oracle" is the trap that cost dotnet ~300 lost
    symbols behind a phantom CI red and go ~200 chased through six wrong
    hypotheses, because the enumerator still exited 0 with a plausible snapshot.
    """
    env_psdk = os.environ.get("PORTING_SDK")
    if env_psdk and Path(env_psdk).is_dir():
        return Path(env_psdk).resolve()
    for cand in (PORT_ROOT.parent / "porting-sdk", PORT_ROOT / "porting-sdk"):
        if cand.is_dir():
            return cand.resolve()
    raise SystemExit(
        "porting-sdk not found: set $PORTING_SDK, or clone it as a sibling of "
        f"this repo ({PORT_ROOT.parent / 'porting-sdk'}) or under it "
        f"({PORT_ROOT / 'porting-sdk'}). Refusing to emit a degraded snapshot."
    )


PSDK = _resolve_porting_sdk()

# The generated REST resource layer (scripts/generate_rest.py) emits every
# class into SignalWire::REST::Namespaces::Generated::<Name>; the idiom-blind
# projection back onto the reference's <ns>_resources_generated / _client_tree_
# generated modules is driven by the committed sidecar the generator writes
# (single source of truth — never hand-maintained here). Class name is the
# reference name VERBATIM (L1/L2).
GENERATED_PREFIX = "SignalWire::REST::Namespaces::Generated::"

# Generated wire-type / read-side-payload FQN prefixes -> reference module,
# routed by PATH (wins over name-keyed lookup — these class names recur across
# modules and collide with SDK class names). Mirrors enumerate_surface.rb's
# GENERATED_TYPES_PREFIX / GENERATED_PAYLOAD_PREFIXES. The REST wire-type +
# relay-protocol + swaig-actions classes are METHOD-LESS (dropped by
# signature_dump.rb, so they never reach here); the SWML-verbs / post-prompt /
# swaig-request classes carry zero-arg field readers and DO land here — routed to
# the flat <...>_generated module the reference records (folded to gen-payload by
# the diff tool).
GENERATED_TYPES_PREFIX = GENERATED_PREFIX + "Types::"
GENERATED_TYPES_NS = {
    "RelayRest": "relay_rest", "Fabric": "fabric", "Calling": "calling",
    "Video": "video", "Datasphere": "datasphere", "Logs": "logs",
    "Message": "message", "Voice": "voice", "Fax": "fax", "Project": "project",
    "Chat": "chat", "PubSub": "pubsub", "SwmlWebhooks": "swml_webhooks",
}
GENERATED_PAYLOAD_PREFIXES = {
    "SignalWire::Core::SwmlVerbsGenerated::": "signalwire.core.swml_verbs_generated",
    "SignalWire::Relay::ProtocolTypesGenerated::": "signalwire.relay.protocol_types_generated",
    "SignalWire::Core::PostPromptGenerated::": "signalwire.core.post_prompt_generated",
    "SignalWire::Core::SwaigRequestGenerated::": "signalwire.core.swaig_request_generated",
    "SignalWire::Core::SwaigActionsGenerated::": "signalwire.core.swaig_actions_generated",
}
_GEN_MAP_PATH = PORT_ROOT / "generated_surface_map.json"
GENERATED_SURFACE_MAP: dict[str, str] = (
    json.loads(_GEN_MAP_PATH.read_text()) if _GEN_MAP_PATH.is_file() else {}
)

# Typed-input sidecar (§B / L10): the generator (scripts/generate_rest.py)
# records, per generated operation/command/set method, the canonical param
# records (name/kind/type/required) the reference oracle carries. Ruby is
# dynamically typed and ``Method#parameters`` can't recover keyword-only kinds,
# open-``extras`` dicts, or field element types, so the enumerator UNFOLDS the
# reflected params — replacing them with the sidecar's canonical set — for every
# generated method it lists. Keyed ``ClassName::method``. GEN-FRESH keeps this in
# lock-step with the emitted source (both derive from the same computed params).
_REST_SIG_PATH = PORT_ROOT / "rest_signatures.json"
_REST_SIG_RAW = (
    json.loads(_REST_SIG_PATH.read_text()) if _REST_SIG_PATH.is_file() else {}
)
REST_SIGNATURES: dict[str, list[dict]] = _REST_SIG_RAW.get("methods", {})

# ---------------------------------------------------------------------------
# Reference-type projection for hand-written params (typed-surface strictness).
#
# Ruby's ``Method#parameters`` recovers a param's NAME and KIND but NOT its
# TYPE — the language erases it at the reflection boundary (there is no RBS/sig
# tree to read). So build_signature() below records ``type: any`` for every
# hand-written param. That is NOT genuine "Ruby can't express this type" — Ruby
# CAN (the same way PHP does via its PHPDoc/declaration remap, and the generated
# REST layer does via the rest_signatures.json sidecar): the concrete type the
# port param accepts IS the contract it implements, recorded in the Python
# oracle. This pass projects that concrete type onto a hand-written port param
# ONLY when the port method is present in the reference AND carries a param of
# the SAME NAME that the reference types concretely — i.e. it re-attaches the
# type reflection erased, exactly like PHP's (class, method) param-type remap.
#
# Discipline (this is a rename/remap, NOT an omission — real future drift stays
# visible):
#   * Keyed by same NAME on the same (module, class, method) — never invents a
#     param, never changes a kind, never touches count. If the port drops or
#     renames a param, or the reference changes the type, it re-surfaces as
#     drift.
#   * Only rewrites a port param that is currently bare ``any`` (never overrides
#     a type the port already carries — e.g. the REST sidecar's typed records).
#   * Ruby-idiom params with no same-name reference param (a Ruby ``block``, a
#     reserved-word/renamed kwarg like ``from``/``sWAIG``, a hash-collapse
#     ``**kwargs``) have no projection source and stay ``any`` — those remain
#     governed by PORT_SIGNATURE_OMISSIONS.md as before.
_REF_SIG_PATH = PSDK / "python_signatures.json"
# FAIL LOUD on an unresolvable oracle. This used to be
# ``… if _REF_SIG_PATH.is_file() else {}``, which DEGRADED SILENTLY: an empty
# oracle empties REF_PARAM_TYPES (every param type falls back to ``any``) and
# empties every oracle-gated fold below, while the enumerator still exits 0 with
# a plausible-looking snapshot. That exact failure mode cost dotnet ~300 lost
# symbols behind a phantom CI red and go ~200 chased through six wrong
# hypotheses. A gate that cannot resolve its oracle must say so, not quietly
# emit less.
if not _REF_SIG_PATH.is_file():
    raise SystemExit(
        f"porting-sdk oracle not found: {_REF_SIG_PATH}\n"
        "  Set $PORTING_SDK to the porting-sdk checkout, or clone it as a "
        "sibling of this repo. Refusing to emit a degraded snapshot."
    )
_REF_SIG_RAW = json.loads(_REF_SIG_PATH.read_text())


def _build_ref_param_type_index() -> dict:
    """(module, class_or_None, method) -> {param_name: type} for every
    reference param the oracle types concretely (non-``any``)."""
    idx: dict = {}
    for mod, me in _REF_SIG_RAW.get("modules", {}).items():
        for cls, ce in me.get("classes", {}).items():
            for meth, sig in ce.get("methods", {}).items():
                pt = {
                    p["name"]: p["type"]
                    for p in sig.get("params", [])
                    if p.get("name")
                    and p.get("kind") not in ("self", "cls")
                    and p.get("type", "any") != "any"
                }
                if pt:
                    idx[(mod, cls, meth)] = pt
        for fn, sig in me.get("functions", {}).items():
            pt = {
                p["name"]: p["type"]
                for p in sig.get("params", [])
                if p.get("name")
                and p.get("kind") not in ("self", "cls")
                and p.get("type", "any") != "any"
            }
            if pt:
                idx[(mod, None, fn)] = pt
    return idx


REF_PARAM_TYPES = _build_ref_param_type_index()


def _build_ref_method_index() -> dict:
    """``(module, class) -> {method_name, ...}`` for every method the reference
    signature oracle records. The gate for the idiom method-strip tables below:
    a strip entry's premise is "the reference records no such member", so the
    oracle is the authority on whether that premise still holds. Class B2
    (ALLOWLIST_DISCIPLINE §15) made several such premises false by recording
    caller-supplied ``__init__`` attributes, which turned those entries into
    hand-maintained capability removals. Gating on the oracle makes them
    self-retire as it grows, instead of needing a hand edit per oracle change.
    """
    idx: dict = {}
    for mod, me in _REF_SIG_RAW.get("modules", {}).items():
        for cls, ce in me.get("classes", {}).items():
            idx[(mod, cls)] = set(ce.get("methods", {}))
    return idx


REF_METHODS = _build_ref_method_index()

# Hand-written param RENAMES (renames, NOT omissions — same param slot, same wire
# role; only the Ruby-side identifier differs from the reference-recorded name).
# The Ruby port idiomatically abbreviates (``desc``↔``description``,
# ``lang_code``↔``language_code``), uses a generic setter arg (``val``↔the
# semantic name), snake-cases a camelCase reference name
# (``numbered_bullets``↔``numberedBullets``), or renames to avoid an awkward
# identifier (``loop_count``↔``loop``). Renaming keeps the two comparing EQUAL
# AND lets the reference-type projection attach the concrete type — a real future
# param drift (drop/added/retyped) still surfaces (unlike an omission, which
# would blind the slot). Keyed (py_module, py_class_or_None, method) ->
# {ruby_param_name: reference_param_name}. Applied BEFORE the type projection.
HAND_PARAM_RENAMES: dict[tuple, dict[str, str]] = {
    ("signalwire.core.agent_base", "AgentBase", "register_sip_username"): {"username": "sip_username"},
    ("signalwire.core.auth_handler", "AuthHandler", "flask_decorator"): {"app": "f"},
    ("signalwire.core.contexts", "Context", "add_enter_filler"): {"lang_code": "language_code"},
    ("signalwire.core.contexts", "Context", "add_exit_filler"): {"lang_code": "language_code"},
    ("signalwire.core.contexts", "Context", "set_consolidate"): {"val": "consolidate"},
    ("signalwire.core.contexts", "Context", "set_enter_fillers"): {"fillers": "enter_fillers"},
    ("signalwire.core.contexts", "Context", "set_exit_fillers"): {"fillers": "exit_fillers"},
    ("signalwire.core.contexts", "Context", "set_full_reset"): {"val": "full_reset"},
    ("signalwire.core.contexts", "Context", "set_isolated"): {"val": "isolated"},
    ("signalwire.core.contexts", "Context", "set_post_prompt"): {"prompt": "post_prompt"},
    ("signalwire.core.contexts", "Context", "set_system_prompt"): {"prompt": "system_prompt"},
    ("signalwire.core.contexts", "Context", "set_user_prompt"): {"prompt": "user_prompt"},
    ("signalwire.core.contexts", "Step", "set_end"): {"is_end": "end"},
    ("signalwire.core.contexts", "Step", "set_reset_consolidate"): {"val": "consolidate"},
    ("signalwire.core.contexts", "Step", "set_reset_full_reset"): {"val": "full_reset"},
    ("signalwire.core.contexts", "Step", "set_reset_system_prompt"): {"prompt": "system_prompt"},
    ("signalwire.core.contexts", "Step", "set_reset_user_prompt"): {"prompt": "user_prompt"},
    ("signalwire.core.data_map", "DataMap", "description"): {"desc": "description"},
    ("signalwire.core.data_map", "DataMap", "purpose"): {"desc": "description"},
    ("signalwire.core.function_result", "FunctionResult", "set_post_process"): {"val": "post_process"},
    ("signalwire.core.function_result", "FunctionResult", "set_response"): {"text": "response"},
    ("signalwire.core.function_result", "FunctionResult", "toggle_functions"): {"toggles": "function_toggles"},
    ("signalwire.core.mixins.ai_config_mixin", "AIConfigMixin", "add_internal_filler"): {"func_name": "function_name", "lang_code": "language_code"},
    ("signalwire.core.mixins.ai_config_mixin", "AIConfigMixin", "set_internal_fillers"): {"fillers": "internal_fillers"},
    ("signalwire.core.mixins.ai_config_mixin", "AIConfigMixin", "set_native_functions"): {"names": "function_names"},
    ("signalwire.core.mixins.web_mixin", "WebMixin", "manual_set_proxy_url"): {"url": "proxy_url"},
    ("signalwire.core.mixins.web_mixin", "WebMixin", "set_dynamic_config_callback"): {"callable": "callback"},
    ("signalwire.core.security.session_manager", "SessionManager", "activate_session"): {"_call_id": "call_id"},
    ("signalwire.pom.pom", "PromptObjectModel", "add_section"): {"numbered_bullets": "numberedBullets"},
    ("signalwire.pom.pom", "Section", "__init__"): {"numbered_bullets": "numberedBullets"},
    ("signalwire.pom.pom", "Section", "add_subsection"): {"numbered_bullets": "numberedBullets"},
    ("signalwire.relay.call", "Call", "play"): {"loop_count": "loop"},
    # DialEvent's ctor kwarg: the reference dataclass field is ``call``, Ruby
    # spells the same slot ``call_data`` (``call`` collides with nothing but
    # reads as a verb on an event object). Same wire key — both sides read
    # ``params['call']`` (relay_event.rb:508, event.py:308) — so this is a
    # RENAME, not a missing configurable.
    ("signalwire.relay.event", "DialEvent", "__init__"): {"call_data": "call"},
    ("signalwire.rest._base", "HttpClient", "__init__"): {"project_id": "project", "space": "host"},
    ("signalwire.rest._base", "SignalWireRestError", "__init__"): {"method_name": "method"},
    ("signalwire.rest._base", "SignalWireRestTransportError", "__init__"): {"method_name": "method"},
    ("signalwire.skills.registry", "SkillRegistry", "register_skill"): {"skill_class_or_name": "skill_class"},
    # SkillManager get/unload take a Ruby ``key`` positional == the reference's
    # ``skill_identifier`` (method names reconciled via SIG_METHOD_ALIASES above).
    ("signalwire.core.skill_manager", "SkillManager", "get_skill"): {"key": "skill_identifier"},
    ("signalwire.core.skill_manager", "SkillManager", "unload_skill"): {"key": "skill_identifier"},
    ("signalwire.core.skill_manager", "SkillManager", "has_skill"): {"key": "skill_identifier"},
    # SWMLService add_* are donated from SWML::Document (SIG_METHOD_DONORS); the
    # Document param names (``name``/``section``) reconcile to the reference's
    # ``section_name``.
    ("signalwire.core.swml_service", "SWMLService", "add_section"): {"name": "section_name"},
    ("signalwire.core.swml_service", "SWMLService", "add_verb_to_section"): {"section": "section_name"},
}


# Hand-written METHOD-NAME aliases: the Ruby-idiom method name -> the reference
# method name, so the two compare EQUAL (Rule 2 — reconcile idiom in the
# enumerator, not via an omission). MIRRORS enumerate_surface.rb's
# SURFACE_METHOD_ALIASES so the signature audit reconciles the SAME renames the
# surface audit already does (otherwise a reconciled method drifts twice at
# signature level: missing-port for the reference name + missing-reference for
# the Ruby name). Keyed (py_module, py_class) -> {ruby_method: reference_method}.
# A rename (not an omission): a real future method drift still surfaces.
SIG_METHOD_ALIASES: dict[tuple, dict[str, str]] = {
    ("signalwire.core.contexts", "Context"): {"to_h": "to_dict"},
    # NB: alias keys are the CLEANED method name (collect() strips a trailing
    # ``?``/``!`` before this runs — so ``validate!`` is keyed ``validate``,
    # ``loaded?`` is keyed ``loaded``).
    ("signalwire.core.contexts", "ContextBuilder"): {"to_h": "to_dict"},
    ("signalwire.core.contexts", "Step"): {"to_h": "to_dict"},
    ("signalwire.core.contexts", "GatherInfo"): {"to_h": "to_dict"},
    ("signalwire.core.contexts", "GatherQuestion"): {"to_h": "to_dict"},
    ("signalwire.pom.pom", "PromptObjectModel"): {"to_h": "to_dict"},
    # ``numberedBullets`` is recorded camelCase VERBATIM because it IS the POM
    # wire key (pom.py:345,361,371 round-trip it unchanged); Ruby spells the
    # reader snake_case per its own idiom.
    ("signalwire.pom.pom", "Section"): {
        "to_h": "to_dict", "numbered_bullets": "numberedBullets"},
    ("signalwire.core.function_result", "FunctionResult"): {"to_h": "to_dict"},
    ("signalwire.relay.event", "DialEvent"): {"call_data": "call"},
    ("signalwire.relay.call", "Call"): {"pass_call": "pass_", "tap_audio": "tap"},
    ("signalwire.relay.message", "Message"): {"on_event": "on"},
    ("signalwire.relay.client", "RelayClient"): {
        "stop": "disconnect", "project_id": "project"},
    # Ruby cannot name these readers ``message``: ``Exception#message`` is
    # stdlib-defined and overriding it changes what raise/rescue and every logger
    # print. Likewise ``method`` is ``Object#method``, core reflection on every
    # object. Renamed here, wire/reference identity preserved.
    ("signalwire.relay.client", "RelayError"): {"error_message": "message"},
    ("signalwire.ai_chat.client", "AIChatError"): {"server_message": "message"},
    ("signalwire.rest._base", "SignalWireRestError"): {"method_name": "method"},
    ("signalwire.prefabs.faq_bot", "FAQBotAgent"): {"handle_search": "search_faqs"},
    ("signalwire.prefabs.info_gatherer", "InfoGathererAgent"): {
        "handle_start": "start_questions", "handle_submit": "submit_answer"},
    ("signalwire.core.skill_base", "SkillBase"): {"instance_key": "get_instance_key"},
    ("signalwire.core.skill_manager", "SkillManager"): {
        "load": "load_skill", "unload": "unload_skill", "get": "get_skill",
        "loaded": "has_skill", "loaded_keys": "list_loaded_skills"},
}


def apply_sig_method_aliases(out_modules: dict) -> None:
    """Rename Ruby-idiom methods to their reference name (see SIG_METHOD_ALIASES).
    Only fires when the port has the Ruby-named method and does NOT already carry
    the reference name (so it never clobbers a real reference-named method). In
    place."""
    for (mod, cls), aliases in SIG_METHOD_ALIASES.items():
        ce = out_modules.get(mod, {}).get("classes", {}).get(cls)
        if not ce:
            continue
        methods = ce.get("methods", {})
        for ruby_name, ref_name in aliases.items():
            if ruby_name in methods and ref_name not in methods:
                methods[ref_name] = methods.pop(ruby_name)


# Method DONORS: the reference declares these methods on a class, but the Ruby
# port implements them on a DIFFERENT class (design split). MIRRORS
# enumerate_surface.rb's SURFACE_METHOD_DONORS. (ref_module, ref_class) ->
# [(donor_module, donor_class, [methods])]. The donor signature is COPIED onto
# the reference target class (already reference-named) so the signature audit
# sees the method where the reference declares it.
SIG_METHOD_DONORS: dict[tuple, list] = {
    ("signalwire.core.swml_service", "SWMLService"): [
        ("signalwire.swml.document", "Document",
         ["add_section", "add_verb", "add_verb_to_section", "reset"]),
    ],
}

# Class-method -> module-level FREE FUNCTION projections: a Ruby ``def self.X``
# (or module_function) that the reference exposes as a MODULE-level function.
# MIRRORS enumerate_surface.rb's FREE_FUNCTION_PROJECTIONS / the
# SignalWire::Contexts module-function mapping. (src_module, src_class) ->
# (ref_module, [methods]). The method is MOVED from the class to the reference
# module's functions[].
SIG_FREE_FUNCTION_PROJECTIONS: dict[tuple, tuple] = {
    ("signalwire.core.data_map", "DataMap"): (
        "signalwire.core.data_map", ["create_expression_tool", "create_simple_api_tool"]),
    ("signalwire.contexts", "Contexts"): (
        "signalwire.core.contexts", ["create_simple_context"]),
    # The decomposed framework-free webhook-validation core. Ruby ships it as a
    # ``def self.validate`` singleton method on the WebhookMiddleware class (the
    # natural home — the Rack #call wrapper delegates to it); the reference
    # records it as the module-level function
    # signalwire.core.security.webhook_middleware.validate. Project it to the
    # module's functions[] so the two compare EQUAL. Param types
    # (method/url/headers/body/signing_key) are re-attached from the oracle by
    # project_reference_param_types (runs after this).
    ("signalwire.core.security.webhook_middleware", "WebhookMiddleware"): (
        "signalwire.core.security.webhook_middleware", ["validate"]),
    # RequestOptions envelope: the reference exposes resolve + status_is_retryable
    # as MODULE-level functions; Ruby ships them as `def self.` methods on
    # RequestOptions. Project both to the module functions[] (mirrors
    # FREE_FUNCTION_PROJECTIONS in enumerate_surface.rb).
    ("signalwire.rest._request_options", "RequestOptions"): (
        "signalwire.rest._request_options", ["resolve", "status_is_retryable"]),
}


def apply_sig_method_donors(out_modules: dict) -> None:
    """Copy donor-class method signatures onto the reference target class (see
    SIG_METHOD_DONORS). In place."""
    for (ref_mod, ref_cls), donors in SIG_METHOD_DONORS.items():
        for donor_mod, donor_cls, methods in donors:
            dce = out_modules.get(donor_mod, {}).get("classes", {}).get(donor_cls)
            if not dce:
                continue
            dmethods = dce.get("methods", {})
            tce = (
                out_modules.setdefault(ref_mod, {})
                .setdefault("classes", {})
                .setdefault(ref_cls, {"methods": {}})
            )
            tce.setdefault("methods", {})
            for m in methods:
                if m in dmethods and m not in tce["methods"]:
                    tce["methods"][m] = dmethods[m]


def apply_sig_free_function_projections(out_modules: dict) -> None:
    """Move a Ruby class factory method to the reference module's functions[]
    (see SIG_FREE_FUNCTION_PROJECTIONS). In place."""
    for (src_mod, src_cls), (ref_mod, methods) in SIG_FREE_FUNCTION_PROJECTIONS.items():
        sce = out_modules.get(src_mod, {}).get("classes", {}).get(src_cls)
        if not sce:
            continue
        smethods = sce.get("methods", {})
        target = out_modules.setdefault(ref_mod, {}).setdefault("functions", {})
        for m in methods:
            if m in smethods:
                sig = smethods.pop(m)
                # A module free function has no receiver — drop the self param.
                sig = dict(sig)
                sig["params"] = [p for p in sig.get("params", []) if p.get("kind") not in ("self", "cls")]
                target.setdefault(m, sig)


# The AI-Chat response models are Ruby ``Struct.new(..., keyword_init: true)``
# value types — the idiomatic analog of the reference's ``@dataclass``
# ConversationInfo / ChatResponse / ChatLog. A Struct's constructor params are
# invisible to Method#parameters reflection (the fields surface only as zero-arg
# READERS), and it auto-generates machinery (``new`` / ``members`` /
# ``keyword_init`` / ``inspect``) the reference dataclass doesn't have. Rebuild
# each class's signature to the ONE method the reference records — a keyword
# ``__init__`` whose params ARE the Struct fields — sourced from the reflected
# field readers (so a real field drop/rename still surfaces as drift), and drop
# the machinery. The reference-param-type projection (run next) attaches the
# concrete field types by name. Keyed by (module, class) -> ordered field names
# (Struct field order = the reference __init__ positional order).
AI_CHAT_STRUCT_FIELDS: dict[tuple, list[str]] = {
    ("signalwire.ai_chat.client", "ConversationInfo"): ["id", "status", "initial_message"],
    ("signalwire.ai_chat.client", "ChatResponse"): ["text", "conversation_id", "user_event"],
    ("signalwire.ai_chat.client", "ChatLog"): ["messages", "call_timeline"],
}

# Ruby-idiom accessors/methods on the AI-Chat client family the reference records
# as plain instance ATTRIBUTES or a PRIVATE method — no reference surface member
# to compare against, so drop them (mirrors enumerate_surface.rb's
# SURFACE_MEMBER_DROPS). Keyed (module, class) -> method names to remove.
# ORACLE-GATED (see the loop in synth_ai_chat_struct_inits): an entry applies
# only while REF_METHODS does NOT record that name on that class. Names here are
# the POST-ALIAS spelling — apply_sig_method_aliases runs first, so ``message``
# not ``server_message``. Keying a member table by the SOURCE name while the
# consumer sees the EMITTED one is how typescript silently dropped every field of
# an aliased class; key it by what the emitter emits.
AI_CHAT_METHOD_DROPS: dict[tuple, set[str]] = {
    # resolve_url mirrors the reference's PRIVATE ``_resolve_url`` @staticmethod
    # (dropped from the reference surface by its leading ``_``); Ruby exposes the
    # same helper public for testability. Still live — the oracle records no
    # ``resolve_url``.
    ("signalwire.ai_chat.client", "AIChatClient"): {"resolve_url"},
    # Written for the pre-B2 oracle, which recorded ``code``/``message`` only as
    # ``__init__`` params. The oracle NOW records both as members, so the gate
    # retires this entry and the Ruby readers are emitted.
    ("signalwire.ai_chat.client", "AIChatError"): {"code", "message"},
}


def synth_ai_chat_struct_inits(out_modules: dict) -> None:
    """Rebuild the AI-Chat Struct value models to a single keyword ``__init__``
    (params = the reflected Struct field readers) and drop the Struct machinery;
    also drop the client-family Ruby-idiom accessors the reference records as
    attributes/private. In place."""
    for (mod, cls), fields in AI_CHAT_STRUCT_FIELDS.items():
        entry = out_modules.get(mod, {}).get("classes", {}).get(cls)
        if not entry:
            continue
        methods = entry.get("methods", {})
        # Verify each declared field is present as a reflected zero-arg reader —
        # a real Struct field drop/rename then re-surfaces as drift here.
        readers = [
            f for f in fields
            if f in methods and not _has_value_params(methods[f])
        ]
        # DEFAULT VALUES ARE GENUINELY UNRECOVERABLE HERE, and not for the usual
        # reflection reason. These models are ``Struct.new(..., keyword_init:
        # true)``: a Struct declares FIELD NAMES only, so there is no per-field
        # default EXPRESSION anywhere in the source for a parser to read. Every
        # omitted field is nil by the Struct protocol itself. So unlike a ``def``
        # parameter — whose default the Ripper pass in signature_dump.rb
        # recovers from source — there is nothing here to recover, in any
        # language-level sense.
        #
        # ``default: None`` is therefore the accurate record for a Struct field,
        # not a placeholder. Note the reference oracle types some of these fields
        # ``required: true`` with no default (the dataclass declares them without
        # one); Ruby's Struct cannot express a required field, and that
        # divergence is pre-existing and governed as before — it is NOT changed
        # here, since this pass is additive to ``default`` only.
        params = [{"name": "self", "kind": "self"}] + [
            {"name": f, "type": "any", "kind": "keyword", "required": False, "default": None}
            for f in readers
        ]
        # The oracle records each dataclass field BOTH as an ``__init__`` param
        # AND as a zero-arg accessor member (griffe surfaces the field). Keep the
        # Struct's field readers (their `self`-only zero-arg shape) alongside the
        # synthesized keyword ``__init__``; drop the rest of the Struct machinery
        # (`new`/`members`/`keyword_init?`/`inspect`/`[]`/…). The field types come
        # from the reference-param-type projection run next.
        new_methods = {"__init__": {"params": params, "returns": "void"}}
        for f in readers:
            new_methods[f] = methods[f]
        entry["methods"] = new_methods

    for (mod, cls), drops in AI_CHAT_METHOD_DROPS.items():
        entry = out_modules.get(mod, {}).get("classes", {}).get(cls)
        if not entry:
            continue
        recorded = REF_METHODS.get((mod, cls), set())
        for m in drops:
            # Oracle gate: never strip a member the reference records — that
            # would remove a capability the reference publishes.
            if m in recorded:
                continue
            entry.get("methods", {}).pop(m, None)


def _has_value_params(sig: dict) -> bool:
    """True if the method takes any non-receiver param (i.e. it is not a plain
    zero-arg reader)."""
    return any(p.get("kind") not in ("self", "cls") for p in sig.get("params", []))


def apply_hand_param_renames(out_modules: dict) -> None:
    """Rewrite Ruby-idiom hand-written param identifiers to the reference name so
    the projection + diff compare EQUAL (see HAND_PARAM_RENAMES). In place."""
    def apply(key: tuple, sig: dict) -> None:
        rn = HAND_PARAM_RENAMES.get(key)
        if not rn:
            return
        for p in sig.get("params", []):
            new = rn.get(p.get("name"))
            if new is not None:
                p["name"] = new

    for mod, me in out_modules.items():
        for cls, ce in me.get("classes", {}).items():
            for meth, sig in ce.get("methods", {}).items():
                apply((mod, cls, meth), sig)
        for fn, sig in me.get("functions", {}).items():
            apply((mod, None, fn), sig)


# RequestOptions-envelope param-KIND reconciliation (Rule 2 — reconcile pure
# idiom in the enumerator, not via an omission). The reference exposes the
# request-options envelope through positional-or-keyword params (a Python
# dataclass / ``request_options=None`` argument, recorded with no explicit kind
# => canonical "positional"). Ruby's idiom for a same-typed optional argument is
# a keyword arg (``request_options:`` on the verbs; the 5 named optional fields
# on ``RequestOptions.new``) — Method#parameters reports these as ``:key`` =>
# canonical "keyword". Functionally identical (the caller supplies the same
# argument in the same slot); the kind label is the only difference. Normalize
# the named params on exactly these compared methods from "keyword" to
# positional so the two compare EQUAL. Narrowly scoped by (module, class,
# method) -> {param names}; an unrelated keyword param is never touched.
REQUEST_OPTIONS_KEYWORD_AS_POSITIONAL = {
    ("signalwire.rest._base", "HttpClient", "__init__"): {"request_options"},
    ("signalwire.rest._base", "HttpClient", "get"): {"request_options"},
    ("signalwire.rest._base", "HttpClient", "post"): {"request_options"},
    ("signalwire.rest._base", "HttpClient", "put"): {"request_options"},
    ("signalwire.rest._base", "HttpClient", "patch"): {"request_options"},
    ("signalwire.rest._base", "HttpClient", "delete"): {"request_options"},
    ("signalwire.rest.client", "RestClient", "__init__"): {"request_options"},
    ("signalwire.rest._request_options", "RequestOptions", "__init__"): {
        "timeout", "retries", "retry_on_status", "retry_backoff", "abort_signal",
    },
    # 6.6 error-observability: the reference's trailing optional ``headers=None``
    # ctor param (positional-or-keyword => canonical positional). Ruby spells a
    # trailing optional map as a keyword arg (``headers: nil``) — same slot, same
    # argument; kind label is the only difference.
    ("signalwire.rest._base", "SignalWireRestError", "__init__"): {"headers"},
}


def normalize_request_options_param_kind(out_modules: dict) -> None:
    """Relabel the request-options envelope's keyword params as positional so the
    Ruby keyword idiom compares EQUAL to the reference's positional-or-keyword
    params (see REQUEST_OPTIONS_KEYWORD_AS_POSITIONAL). In place."""
    for (mod, cls, meth), names in REQUEST_OPTIONS_KEYWORD_AS_POSITIONAL.items():
        sig = out_modules.get(mod, {}).get("classes", {}).get(cls, {}).get("methods", {}).get(meth)
        if not sig:
            continue
        for prm in sig.get("params", []):
            if prm.get("name") in names and prm.get("kind") == "keyword":
                # positional is the implicit default: drop the explicit kind key
                # (mirrors build_signature, which omits kind for positional).
                del prm["kind"]


def project_reference_param_types(out_modules: dict) -> None:
    """Re-attach the reference-documented concrete type onto each hand-written
    port param that reflection recorded as bare ``any`` (see the block comment
    above). Mutates ``out_modules`` in place."""
    def apply(key: tuple, sig: dict) -> None:
        ref_types = REF_PARAM_TYPES.get(key)
        if not ref_types:
            return
        for p in sig.get("params", []):
            if p.get("kind") in ("self", "cls"):
                continue
            if p.get("type") != "any":
                continue  # never override a type the port already carries
            rt = ref_types.get(p.get("name"))
            if rt is not None:
                p["type"] = rt

    for mod, me in out_modules.items():
        for cls, ce in me.get("classes", {}).items():
            for meth, sig in ce.get("methods", {}).items():
                apply((mod, cls, meth), sig)
        for fn, sig in me.get("functions", {}).items():
            apply((mod, None, fn), sig)

# ADAPTER PARAM-RENAMES (renames, NOT omissions — the wire field is unchanged;
# only the Ruby-side kwarg identifier differs from the reference-recorded name).
#   * The generator lower-cases an uppercase-initial wire field so it is a valid
#     Ruby keyword-arg identifier (SWAIG -> sWAIG). The Python oracle allows the
#     uppercase param and records ``SWAIG`` — rename ``sWAIG`` back to ``SWAIG``.
#   * Ruby uses a plain ``from`` kwarg (``from`` is not a Ruby keyword); the
#     Python oracle renames the reserved word to ``from_`` and records that —
#     rename ``from`` -> ``from_`` so the two compare EQUAL.
# Scoped to the generated REST classes so an unrelated ``from``/``sWAIG`` param
# elsewhere is never silently rewritten.
GENERATED_PARAM_RENAMES = {
    "sWAIG": "SWAIG",
    "from": "from_",
}


# ---------------------------------------------------------------------------
# Mappings extracted from scripts/enumerate_surface.rb
# (Single source of truth would be a shared YAML; for v1 these are duplicated
# verbatim and must stay in sync if the .rb table changes.)
# ---------------------------------------------------------------------------

RUBY_TO_PYTHON_MODULE_OVERRIDES = {
    # Core: Ruby has no Core:: namespace; Python puts these under
    # signalwire.core.<file>.
    "SignalWire::AgentBase": "signalwire.core.agent_base",
    "SignalWire::SWML::Service": "signalwire.core.swml_service",
    "SignalWire::SWML::Schema": "signalwire.core.swml_schema",
    # SchemaUtils + SchemaValidationError both live under
    # signalwire.utils.schema_utils per the canonical Python module layout.
    "SignalWire::Utils::SchemaUtils": "signalwire.utils.schema_utils",
    "SignalWire::Utils::SchemaValidationError": "signalwire.utils.schema_utils",
    "SignalWire::SWAIG::FunctionResult": "signalwire.core.function_result",
    "SignalWire::Swaig::FunctionResult": "signalwire.core.function_result",
    "SignalWire::DataMap": "signalwire.core.data_map",
    "SignalWire::Contexts::Context": "signalwire.core.contexts",
    "SignalWire::Contexts::ContextBuilder": "signalwire.core.contexts",
    "SignalWire::Contexts::Step": "signalwire.core.contexts",
    "SignalWire::Contexts::GatherInfo": "signalwire.core.contexts",
    "SignalWire::Contexts::GatherQuestion": "signalwire.core.contexts",
    "SignalWire::Skills::SkillBase": "signalwire.core.skill_base",
    "SignalWire::Skills::SkillManager": "signalwire.core.skill_manager",
    "SignalWire::Skills::SkillRegistry": "signalwire.skills.registry",
    # Item-I implemented subsystems — mirror enumerate_surface.rb so both
    # gates route these classes to the same reference module.
    "SignalWire::Swaig::SWAIGFunction": "signalwire.core.swaig_function",
    "SignalWire::Core::AuthHandler": "signalwire.core.auth_handler",
    "SignalWire::Core::ConfigLoader": "signalwire.core.config_loader",
    "SignalWire::Core::SecurityConfig": "signalwire.core.security_config",
    "SignalWire::Core::PomBuilder": "signalwire.core.pom_builder",
    "SignalWire::Web::WebService": "signalwire.web.web_service",
    "SignalWire::SWML::SwmlRenderer": "signalwire.core.swml_renderer",
    "SignalWire::SWML::SWMLBuilder": "signalwire.core.swml_builder",
    "SignalWire::SWML::AIVerbHandler": "signalwire.core.swml_handler",
    "SignalWire::SWML::SWMLVerbHandler": "signalwire.core.swml_handler",
    "SignalWire::SWML::VerbHandlerRegistry": "signalwire.core.swml_handler",
    "SignalWire::Agents::BedrockAgent": "signalwire.agents.bedrock",
    "SignalWire::Core::Agent::Prompt::PromptManager": "signalwire.core.agent.prompt.manager",
    "SignalWire::Core::Agent::Tools::ToolRegistry": "signalwire.core.agent.tools.registry",

    # Prompt Object Model: Ruby's SignalWire::POM::* classes mirror Python's
    # signalwire.pom.pom.* module exactly (PromptObjectModel + Section).
    "SignalWire::POM::PromptObjectModel": "signalwire.pom.pom",
    "SignalWire::POM::Section": "signalwire.pom.pom",

    "SignalWire::AgentServer": "signalwire.agent_server",
    "SignalWire::Security::SessionManager": "signalwire.core.security.session_manager",
    "SignalWire::Security::WebhookMiddleware": "signalwire.core.security.webhook_middleware",
    "SignalWire::Prefabs::Concierge": "signalwire.prefabs.concierge",
    "SignalWire::Prefabs::FaqBot": "signalwire.prefabs.faq_bot",
    "SignalWire::Prefabs::InfoGatherer": "signalwire.prefabs.info_gatherer",
    "SignalWire::Prefabs::Receptionist": "signalwire.prefabs.receptionist",
    "SignalWire::Prefabs::Survey": "signalwire.prefabs.survey",
    "SignalWire::Skills::Builtin::SwmlTransferSkill": "signalwire.skills.swml_transfer.skill",
    "SignalWire::Skills::Builtin::DatasphereSkill": "signalwire.skills.datasphere.skill",
    "SignalWire::Skills::Builtin::DatasphereServerlessSkill": "signalwire.skills.datasphere_serverless.skill",
    "SignalWire::Skills::Builtin::WebSearchSkill": "signalwire.skills.web_search.skill",
    "SignalWire::Skills::Builtin::ApiNinjasTriviaSkill": "signalwire.skills.api_ninjas_trivia.skill",
    "SignalWire::Skills::Builtin::ClaudeSkillsSkill": "signalwire.skills.claude_skills.skill",
    "SignalWire::Skills::Builtin::DateTimeSkill": "signalwire.skills.datetime.skill",
    "SignalWire::Skills::Builtin::GoogleMapsSkill": "signalwire.skills.google_maps.skill",
    "SignalWire::Skills::Builtin::InfoGathererSkill": "signalwire.skills.info_gatherer.skill",
    "SignalWire::Skills::Builtin::JokeSkill": "signalwire.skills.joke.skill",
    "SignalWire::Skills::Builtin::MathSkill": "signalwire.skills.math.skill",
    "SignalWire::Skills::Builtin::MCPGatewaySkill": "signalwire.skills.mcp_gateway.skill",
    "SignalWire::Skills::Builtin::NativeVectorSearchSkill": "signalwire.skills.native_vector_search.skill",
    "SignalWire::Skills::Builtin::PlayBackgroundFileSkill": "signalwire.skills.play_background_file.skill",
    "SignalWire::Skills::Builtin::SpiderSkill": "signalwire.skills.spider.skill",
    "SignalWire::Skills::Builtin::WeatherApiSkill": "signalwire.skills.weather_api.skill",
    "SignalWire::Skills::Builtin::WikipediaSearchSkill": "signalwire.skills.wikipedia_search.skill",
    "SignalWire::Relay::Client": "signalwire.relay.client",
    "SignalWire::Relay::ActionTimeoutError": "signalwire.relay.client",
    "SignalWire::Relay::RelayError": "signalwire.relay.client",
    # Relay actions: Python collapses every Action class under
    # signalwire/relay/call.py alongside Call itself.
    "SignalWire::Relay::Action": "signalwire.relay.call",
    "SignalWire::Relay::AIAction": "signalwire.relay.call",
    "SignalWire::Relay::CollectAction": "signalwire.relay.call",
    "SignalWire::Relay::DetectAction": "signalwire.relay.call",
    "SignalWire::Relay::FaxAction": "signalwire.relay.call",
    "SignalWire::Relay::PayAction": "signalwire.relay.call",
    "SignalWire::Relay::PlayAction": "signalwire.relay.call",
    "SignalWire::Relay::RecordAction": "signalwire.relay.call",
    "SignalWire::Relay::StandaloneCollectAction": "signalwire.relay.call",
    "SignalWire::Relay::StreamAction": "signalwire.relay.call",
    "SignalWire::Relay::TapAction": "signalwire.relay.call",
    "SignalWire::Relay::TranscribeAction": "signalwire.relay.call",
    # Relay events: Python groups them under signalwire.relay.event
    "SignalWire::Relay::CallReceiveEvent": "signalwire.relay.event",
    "SignalWire::Relay::CallStateEvent": "signalwire.relay.event",
    "SignalWire::Relay::CallingErrorEvent": "signalwire.relay.event",
    "SignalWire::Relay::ConferenceEvent": "signalwire.relay.event",
    "SignalWire::Relay::DenoiseEvent": "signalwire.relay.event",
    "SignalWire::Relay::EchoEvent": "signalwire.relay.event",
    "SignalWire::Relay::HoldEvent": "signalwire.relay.event",
    "SignalWire::Relay::QueueEvent": "signalwire.relay.event",
    "SignalWire::Relay::RecordEvent": "signalwire.relay.event",
    "SignalWire::Relay::TranscribeEvent": "signalwire.relay.event",
    "SignalWire::Relay::PlayEvent": "signalwire.relay.event",
    "SignalWire::Relay::DialEvent": "signalwire.relay.event",
    "SignalWire::Relay::DetectEvent": "signalwire.relay.event",
    "SignalWire::Relay::CollectEvent": "signalwire.relay.event",
    "SignalWire::Relay::FaxEvent": "signalwire.relay.event",
    "SignalWire::Relay::TapEvent": "signalwire.relay.event",
    "SignalWire::Relay::StreamEvent": "signalwire.relay.event",
    "SignalWire::Relay::ConnectEvent": "signalwire.relay.event",
    "SignalWire::Relay::ReferEvent": "signalwire.relay.event",
    "SignalWire::Relay::SendDigitsEvent": "signalwire.relay.event",
    "SignalWire::Relay::PayEvent": "signalwire.relay.event",
    "SignalWire::Relay::MessagingReceiveEvent": "signalwire.relay.event",
    "SignalWire::Relay::MessagingStateEvent": "signalwire.relay.event",
    "SignalWire::Relay::MessageReceiveEvent": "signalwire.relay.event",
    "SignalWire::Relay::MessageStateEvent": "signalwire.relay.event",
    "SignalWire::Relay::AIEvent": "signalwire.relay.event",
    "SignalWire::Relay::RelayEvent": "signalwire.relay.event",
    "SignalWire::Relay::Message": "signalwire.relay.message",
    # AI Chat: the reference collapses the client, its typed error family, and
    # the response models into one module signalwire.ai_chat.client. Ruby splits
    # the client (top-level SignalWire::AIChatClient) from the error/model family
    # (nested under SignalWire::AIChat::*); pin every one to the reference module
    # so the surface + signature gates route them identically (mirrors
    # enumerate_surface.rb's auto-resolve of these unique class names).
    "SignalWire::AIChatClient": "signalwire.ai_chat.client",
    "SignalWire::AIChat::AIChatError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::AuthenticationError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::ConversationNotFoundError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::RateLimitError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::ChatInProgressError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::SummaryError": "signalwire.ai_chat.client",
    "SignalWire::AIChat::ConversationInfo": "signalwire.ai_chat.client",
    "SignalWire::AIChat::ChatResponse": "signalwire.ai_chat.client",
    "SignalWire::AIChat::ChatLog": "signalwire.ai_chat.client",
    # RequestOptions envelope (plan 4.2): route the value type to the
    # reference module signalwire.rest._request_options. Its helper classes
    # (EffectiveOptions/AbortSignal) mirror that module's PRIVATE
    # _EffectiveOptions/_AbortSignal and are excluded (EXCLUDED_RUBY_CLASSES).
    "SignalWire::REST::RequestOptions": "signalwire.rest._request_options",
    # REST resource & namespace classes — Python groups them by domain.
    # Ruby's ``SignalWire::REST::RestClient`` -> Python's
    # ``signalwire.rest.client.RestClient``.
    "SignalWire::REST::RestClient": "signalwire.rest.client",
    # Python keeps HttpClient + SignalWireRestError in signalwire/rest/_base.py;
    # Ruby gives HttpClient its own file but that's a layout-only difference.
    "SignalWire::REST::HttpClient": "signalwire.rest._base",
    "SignalWire::REST::SignalWireRestError": "signalwire.rest._base",
    "SignalWire::REST::SignalWireRestTransportError": "signalwire.rest._base",
    "SignalWire::REST::BaseResource": "signalwire.rest._base",
    "SignalWire::REST::ReadResource": "signalwire.rest._base",
    "SignalWire::REST::CrudResource": "signalwire.rest._base",
    "SignalWire::REST::CrudWithAddresses": "signalwire.rest._base",
    "SignalWire::REST::PaginatedIterator": "signalwire.rest._pagination",
    "SignalWire::REST::Namespaces::CallingNamespace": "signalwire.rest.namespaces.calling",
    "SignalWire::REST::Namespaces::ChatResource": "signalwire.rest.namespaces.chat",
    "SignalWire::REST::Namespaces::AddressesResource": "signalwire.rest.namespaces.addresses",
    "SignalWire::REST::Namespaces::DatasphereDocuments": "signalwire.rest.namespaces.datasphere",
    "SignalWire::REST::Namespaces::DatasphereNamespace": "signalwire.rest.namespaces.datasphere",
    "SignalWire::REST::Namespaces::FabricAddresses": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::FabricNamespace": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::FabricResource": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::FabricTokens": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::AutoMaterializedWebhook": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::CallFlowsResource": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::ConferenceRoomsResource": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::CxmlApplicationsResource": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::GenericResources": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::SubscribersResource": "signalwire.rest.namespaces.fabric",
    "SignalWire::REST::Namespaces::ConferenceLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::FaxLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::LogsNamespace": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::MessageLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::VoiceLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::ImportedNumbersResource": "signalwire.rest.namespaces.imported_numbers",
    "SignalWire::REST::Namespaces::LookupResource": "signalwire.rest.namespaces.lookup",
    "SignalWire::REST::Namespaces::MfaResource": "signalwire.rest.namespaces.mfa",
    "SignalWire::REST::Namespaces::NumberGroupsResource": "signalwire.rest.namespaces.number_groups",
    "SignalWire::REST::Namespaces::PhoneNumbersResource": "signalwire.rest.namespaces.phone_numbers",
    "SignalWire::REST::Namespaces::ProjectNamespace": "signalwire.rest.namespaces.project",
    "SignalWire::REST::Namespaces::ProjectTokens": "signalwire.rest.namespaces.project",
    "SignalWire::REST::Namespaces::PubSubResource": "signalwire.rest.namespaces.pubsub",
    "SignalWire::REST::Namespaces::QueuesResource": "signalwire.rest.namespaces.queues",
    "SignalWire::REST::Namespaces::RecordingsResource": "signalwire.rest.namespaces.recordings",
    "SignalWire::REST::Namespaces::RegistryBrands": "signalwire.rest.namespaces.registry",
    "SignalWire::REST::Namespaces::RegistryCampaigns": "signalwire.rest.namespaces.registry",
    "SignalWire::REST::Namespaces::RegistryNamespace": "signalwire.rest.namespaces.registry",
    "SignalWire::REST::Namespaces::RegistryNumbers": "signalwire.rest.namespaces.registry",
    "SignalWire::REST::Namespaces::RegistryOrders": "signalwire.rest.namespaces.registry",
    "SignalWire::REST::Namespaces::ShortCodesResource": "signalwire.rest.namespaces.short_codes",
    "SignalWire::REST::Namespaces::SipProfileResource": "signalwire.rest.namespaces.sip_profile",
    "SignalWire::REST::Namespaces::VerifiedCallersResource": "signalwire.rest.namespaces.verified_callers",
    # Video namespace classes
    "SignalWire::REST::Namespaces::VideoNamespace": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoRooms": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoRoomTokens": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoRoomSessions": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoRoomRecordings": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoConferences": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoConferenceTokens": "signalwire.rest.namespaces.video",
    "SignalWire::REST::Namespaces::VideoStreams": "signalwire.rest.namespaces.video",
    # Chat namespace
    "SignalWire::REST::Namespaces::ChatResource": "signalwire.rest.namespaces.chat",
    # Datasphere namespace
    "SignalWire::REST::Namespaces::DatasphereDocuments": "signalwire.rest.namespaces.datasphere",
    "SignalWire::REST::Namespaces::DatasphereNamespace": "signalwire.rest.namespaces.datasphere",
}

RUBY_TO_PYTHON_CLASS_ALIASES = {
    "SignalWire::Prefabs::Concierge": "ConciergeAgent",
    "SignalWire::Prefabs::FaqBot": "FAQBotAgent",
    "SignalWire::Prefabs::InfoGatherer": "InfoGathererAgent",
    "SignalWire::Prefabs::Receptionist": "ReceptionistAgent",
    "SignalWire::Prefabs::Survey": "SurveyAgent",
    "SignalWire::Skills::Builtin::SwmlTransferSkill": "SWMLTransferSkill",
    "SignalWire::Skills::Builtin::DatasphereSkill": "DataSphereSkill",
    "SignalWire::Skills::Builtin::DatasphereServerlessSkill": "DataSphereServerlessSkill",
    "SignalWire::Relay::Client": "RelayClient",
    "SignalWire::SWML::Service": "SWMLService",
}

MIXIN_PROJECTIONS = {
    ("signalwire.core.mixins.ai_config_mixin", "AIConfigMixin"): [
        "add_function_include", "add_hint", "add_hints", "add_internal_filler",
        "add_language", "add_mcp_server", "add_pattern_hint", "add_pronunciation",
        "enable_debug_events", "enable_mcp_server",
        "get_language_params",
        "set_function_includes", "set_global_data", "set_internal_fillers",
        "set_language_params",
        "set_languages", "set_multilingual", "set_native_functions",
        "set_param", "set_params",
        "set_post_prompt_llm_params", "set_prompt_llm_params",
        "set_pronunciations", "update_global_data",
    ],
    ("signalwire.core.mixins.prompt_mixin", "PromptMixin"): [
        "define_contexts", "get_post_prompt", "get_prompt",
        "prompt_add_section",
        "prompt_add_subsection", "prompt_add_to_section",
        "prompt_has_section", "reset_contexts", "set_post_prompt",
        "set_prompt_text",
    ],
    # Python additionally extracted a ``PromptManager`` class that
    # PromptMixin delegates to. The user-facing surface is identical
    # (``agent.prompt_manager.X`` ≡ ``agent.X``). Project the same set of
    # AgentBase methods to PromptManager so the cross-language audit
    # treats both paths as covered.
    ("signalwire.core.agent.prompt.manager", "PromptManager"): [
        "define_contexts", "get_contexts", "get_post_prompt", "get_prompt",
        "get_raw_prompt",
        "prompt_add_section", "prompt_add_subsection", "prompt_add_to_section",
        "prompt_has_section", "set_post_prompt", "set_prompt_pom",
        "set_prompt_text",
    ],
    ("signalwire.core.mixins.skill_mixin", "SkillMixin"): [
        "add_skill", "has_skill", "list_skills", "remove_skill",
    ],
    ("signalwire.core.mixins.tool_mixin", "ToolMixin"): [
        "define_tool", "on_function_call", "register_swaig_function",
    ],
    ("signalwire.core.agent.tools.registry", "ToolRegistry"): [
        "define_tool", "register_swaig_function",
        "has_function", "get_function", "get_all_functions",
        "remove_function",
    ],
    ("signalwire.core.mixins.auth_mixin", "AuthMixin"): [
        "validate_basic_auth", "get_basic_auth_credentials",
    ],
    ("signalwire.core.mixins.web_mixin", "WebMixin"): [
        "as_router", "enable_debug_routes", "get_app", "manual_set_proxy_url",
        "on_request", "on_swml_request", "register_routing_callback", "run",
        "serve", "set_dynamic_config_callback", "setup_graceful_shutdown",
    ],
    ("signalwire.core.mixins.mcp_server_mixin", "MCPServerMixin"): [
        "add_mcp_server",
    ],
    ("signalwire.core.mixins.state_mixin", "StateMixin"): [
        "validate_tool_token",
    ],
    ("signalwire.core.mixins.serverless_mixin", "ServerlessMixin"): [
        "handle_serverless_request",
    ],
}

# Free-function name overrides — for cases where the Python canonical
# name doesn't follow snake_case. Python's top-level
# ``signalwire.RestClient`` is a factory function but uses PascalCase
# (it mirrors the class name). The Ruby source-side method is also named
# ``RestClient`` so the snake_case() helper would emit ``rest_client``;
# this table preserves the PascalCase canonical name.
FREE_FN_NAME_OVERRIDES = {
    "rest_client": "RestClient",
}

# Per-method canonical RETURN-type overrides. Ruby is dynamically typed, so the
# dump records ``any`` for every return by default (below). A few methods have a
# well-defined, named cross-port return type we want recorded explicitly so the
# signature diff reconciles on a NAMED type (not merely the ``any`` wildcard):
#   as_router — the "embed my routes in a host app" mountable unit. Ruby returns
#   its rack_app, a ``Rack::Builder`` app (an object responding to #call(env),
#   mountable via Rails/Sinatra `mount`/`map`) — Ruby's idiom for Python's
#   HostAppRouter. The native→canonical mapping (Rack::Builder → HostAppRouter)
#   is documented in porting-sdk/type_aliases.yaml (ruby section); this
#   enumerator applies it, emitting the canonical class-ref directly (the diff
#   is invoked without --aliases, so ports canonicalize at enumerate time —
#   Go's enumerator likewise stores `class:...HostAppRouter` for AsRouter).
RETURN_TYPE_OVERRIDES = {
    "as_router": "class:signalwire.core.web.HostAppRouter",
}

# Ruby-module-to-Python-module overrides for ``module`` kinds (vs the
# class-keyed RUBY_TO_PYTHON_MODULE_OVERRIDES above). When a Ruby module
# (e.g. ``SignalWire::Relay``) defines its own static methods, route them
# to the matching Python module (``signalwire.relay.event``) rather than
# the default name-derived path (``signalwire.relay``).
RUBY_MODULE_LEVEL_OVERRIDES = {
    "SignalWire::Relay": "signalwire.relay.event",
    # WebhookValidator is a Ruby module (with module_function entries) that
    # mirrors Python's module-level webhook_validator helpers under
    # signalwire/core/security/.
    "SignalWire::Security::WebhookValidator": "signalwire.core.security.webhook_validator",
    # SecurityUtils is a Ruby module whose self.* methods mirror Python's
    # module-level free functions in signalwire.core.security.security_utils
    # (filter_sensitive_headers, redact_url, is_valid_hostname).
    "SignalWire::Security::SecurityUtils": "signalwire.core.security.security_utils",
}

# Port-only Ruby modules that have no Python equivalent. Project their
# singleton methods as a synthetic class (mirroring enumerate_surface.rb)
# so the surface- and signature-level audits see the same shape.
RUBY_PORT_ONLY_MODULE_AS_CLASS = {
    # SignalWire::Runtime.execution_mode / .lambda? / etc. -> Runtime class
    "SignalWire::Runtime": ("signalwire.runtime", "Runtime"),
    # SignalWire::Contexts.create_simple_context -> Contexts class
    # (matches port_surface.json shape; Python's create_simple_context
    # lives at signalwire.core.contexts as a free function).
    "SignalWire::Contexts": ("signalwire.contexts", "Contexts"),
}

EXCLUDED_RUBY_CLASSES = {
    "SignalWire::AgentBase::AgentBodyLimitMiddleware",
    "SignalWire::AgentBase::AgentSecurityHeadersMiddleware",
    "SignalWire::AgentBase::AgentTimingSafeBasicAuth",
    "SignalWire::SWML::Service::SecurityHeadersMiddleware",
    "SignalWire::SWML::Service::TimingSafeBasicAuth",
    "SignalWire::Logging::Logger",
    # The PRIVATE backing implementation of the public reference-parity facade
    # SignalWire::Core::LoggingConfig, which already projects onto all five
    # signalwire.core.logging_config free functions (zero omissions).
    # lib/signalwire/core/logging_config.rb delegates explicitly:
    # get_logger -> Logging.logger, reset_logging_configuration ->
    # Logging.reset!, configure_logging -> Logging.configure; global_level /
    # suppressed? are the SIGNALWIRE_LOG_LEVEL / SIGNALWIRE_LOG_MODE=off
    # settings the reference's configure_logging reads from the environment.
    # No capability the reference cannot reach -> idiom, folded here rather
    # than recorded as ADDITIONs (ALLOWLIST_DISCIPLINE §0/§0b). Kept in
    # lockstep with RUBY_EXCLUDED_CLASSES in scripts/enumerate_surface.rb.
    "SignalWire::Logging",
    "SignalWire::REST::Namespaces",
    # Internal implementation classes extracted during the lint burndown purely
    # to satisfy Metrics cops — no Python counterpart, file-local, not public
    # surface. Excluded from both the signature and surface enumerators
    # (mirrors RUBY_EXCLUDED_CLASSES in scripts/enumerate_surface.rb).
    "SignalWire::Skills::Builtin::SafeEvaluator",
    "SignalWire::Skills::Builtin::MathTokenizer",
    "SignalWire::POM::SectionBuilder",
    "SignalWire::Skills::SkillIntrospection",
    "SignalWire::Relay::MessageSerialization",
    # Composition-only mixins whose members signature_dump.rb LIFTS onto the
    # classes that `include` them (COMPOSED_MODULES there), so the enumerator
    # records the surface a CALLER sees: RestClient's 22 resource accessors come
    # from ResourceTree, Relay::Message's serialization from MessageSerialization.
    # They must stay excluded HERE so a lifted module is not also recorded as its
    # own symbol, which would double-count every member it contributes.
    "SignalWire::REST::Namespaces::Generated::ResourceTree",
    # RequestOptions helpers mirroring the reference's PRIVATE
    # signalwire.rest._request_options._EffectiveOptions / _AbortSignal.
    "SignalWire::REST::EffectiveOptions",
    "SignalWire::REST::AbortSignal",
    # Internal REST retry-loop outcome value object (DONE/RETRY); no Python
    # counterpart (the reference inlines the loop in HttpClient._request).
    "SignalWire::REST::Attempt",
}


_CAMEL_RE_1 = re.compile(r"([A-Z]+)([A-Z][a-z])")
_CAMEL_RE_2 = re.compile(r"([a-z0-9])([A-Z])")


def snake_case(name: str) -> str:
    s = _CAMEL_RE_1.sub(r"\1_\2", name)
    s = _CAMEL_RE_2.sub(r"\1_\2", s).lower()
    return s


def ruby_module_to_py(ns_parts: list[str]) -> str:
    """SignalWire::REST::Phone -> signalwire.rest.phone"""
    if ns_parts and ns_parts[0] == "SignalWire":
        ns_parts = ns_parts[1:]
    return ".".join(["signalwire"] + [snake_case(p) for p in ns_parts])


def resolve_class(full_name: str) -> tuple[str, str] | None:
    if full_name in EXCLUDED_RUBY_CLASSES:
        return None
    parts = full_name.split("::")
    short = parts[-1]
    # Generated wire-type DTOs: route by the Types::<Ns>:: FQN prefix (PATH wins
    # over name-keyed lookup). Method-less, so they normally don't reach here; the
    # routing is kept for parity with the surface enumerator.
    if full_name.startswith(GENERATED_TYPES_PREFIX):
        ns_mod = full_name[len(GENERATED_TYPES_PREFIX):].split("::", 1)[0]
        ns_key = GENERATED_TYPES_NS.get(ns_mod)
        if ns_key is None:
            raise SystemExit(
                f"generated type class {full_name!r} has unknown Types namespace {ns_mod!r}"
            )
        return f"signalwire.rest.namespaces.{ns_key}_types_generated", short
    # Generated read-side payload DTOs (SWML-verbs / post-prompt / swaig-request /
    # relay-protocol / swaig-actions): route by FQN prefix to the flat reference
    # module (folded to gen-payload by the diff tool). Class name VERBATIM.
    for prefix, mod in GENERATED_PAYLOAD_PREFIXES.items():
        if full_name.startswith(prefix):
            return mod, short
    # Generated REST resource/container: project onto the reference's
    # <ns>_resources_generated / _client_tree_generated module via the sidecar,
    # class name VERBATIM.
    if full_name.startswith(GENERATED_PREFIX):
        mod = GENERATED_SURFACE_MAP.get(short)
        if mod is None:
            raise SystemExit(
                f"generated class {full_name!r} not in generated_surface_map.json — "
                f"regenerate with `python3 scripts/generate_rest.py`"
            )
        return mod, short
    canonical_class = RUBY_TO_PYTHON_CLASS_ALIASES.get(full_name, short)
    if full_name in RUBY_TO_PYTHON_MODULE_OVERRIDES:
        return RUBY_TO_PYTHON_MODULE_OVERRIDES[full_name], canonical_class
    # Default: derive Python module from Ruby namespace
    return ruby_module_to_py(parts[:-1] + [short]), canonical_class


# ---------------------------------------------------------------------------
# Parameter kind translation
# ---------------------------------------------------------------------------

# Ruby Method#parameters kinds:
#   :req           positional required
#   :opt           positional optional (has default)
#   :rest          *args
#   :keyreq        keyword required
#   :key           keyword optional (may have default)
#   :keyrest       **kwargs
#   :block         &blk

KIND_TO_CANONICAL = {
    "req": "positional",
    "opt": "positional",
    "rest": "var_positional",
    "keyreq": "keyword",
    "key": "keyword",
    "keyrest": "var_keyword",
    "block": "keyword",  # block is always callable; treated as keyword param
}


def collect(raw: dict) -> dict:
    out_modules: dict = {}
    # canonical ``module.Class`` -> canonical ``module.Class`` of its SDK
    # superclass. Populated below; consumed ONLY by build_construction to follow
    # a ``**opts``-to-``super`` forward (see that function's docstring). Kept as
    # a side index rather than a field on the emitted classes so port_signatures
    # keeps exactly the shape the differ and the other ports use.
    superclass_index: dict[str, str] = {}
    ruby_to_canonical: dict[str, str] = {}

    for type_entry in raw.get("types", []):
        full = type_entry.get("full_name", "")
        kind = type_entry.get("kind", "class")
        if full in EXCLUDED_RUBY_CLASSES:
            # Internal implementation modules/classes (e.g. helpers extracted
            # during the lint burndown) with no Python counterpart — drop them
            # entirely from the audited surface (applies to both module- and
            # class-kind entries).
            continue
        if kind == "module":
            # Module-level static methods emit either as functions in the
            # mapped Python module, or — for port-only Ruby modules with
            # no Python counterpart — as methods on a synthetic class so
            # the surface and signature audits agree on shape.
            as_class = RUBY_PORT_ONLY_MODULE_AS_CLASS.get(full)
            if as_class:
                mod_path, class_name = as_class
            else:
                mod_path = RUBY_MODULE_LEVEL_OVERRIDES.get(full) or \
                    ruby_module_to_py(full.split("::"))
            functions: dict = {}
            class_methods: dict = {}
            for m in type_entry.get("methods", []):
                if not m.get("is_static"):
                    continue
                native = m.get("name", "")
                if native.startswith("__") or native == "<init>":
                    continue
                if native.endswith("=") or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*[?!]?$", native):
                    continue  # skip Ruby setters / operator methods
                # Underscore-prefixed Ruby methods are private convention;
                # skip them from the public surface.
                if native.startswith("_"):
                    continue
                clean = native.rstrip("?!")
                snake = snake_case(clean)
                # Free-function name overrides — Python's top-level
                # ``signalwire.RestClient`` is a factory function but uses
                # PascalCase (it mirrors the class name). The Ruby
                # source-side method is also named ``RestClient`` (Ruby
                # allows uppercase method names). Preserve the PascalCase
                # for this canonical name.
                projected = FREE_FN_NAME_OVERRIDES.get(snake, snake)
                sig = build_signature(m, instance_method=False)
                sig["params"] = [p for p in sig["params"] if p.get("name")]
                if as_class:
                    class_methods[projected] = sig
                else:
                    functions[projected] = sig
            if functions:
                out_modules.setdefault(mod_path, {})
                out_modules[mod_path].setdefault("functions", {})
                out_modules[mod_path]["functions"].update(functions)
            if class_methods:
                out_modules.setdefault(mod_path, {})
                out_modules[mod_path].setdefault("classes", {})
                out_modules[mod_path]["classes"].setdefault(
                    class_name, {"methods": {}}
                )
                out_modules[mod_path]["classes"][class_name]["methods"].update(class_methods)
            continue

        resolved = resolve_class(full)
        if resolved is None:
            continue
        mod, canonical_class = resolved
        is_generated = full.startswith(GENERATED_PREFIX)
        # A generated read-side payload class (SWML-verbs / post-prompt /
        # swaig-request): its zero-arg field readers carry the wire field name
        # VERBATIM (the reference records the accessor as the field, e.g. ``SWAIG``,
        # not snake-cased). Skip the snake_case canonicalisation for these so the
        # accessor compares equal to the reference.
        is_payload = any(full.startswith(p) for p in GENERATED_PAYLOAD_PREFIXES)

        methods_out: dict = {}
        for m in type_entry.get("methods", []):
            native = m.get("name", "")
            if native == "<init>":
                method_canonical = "__init__"
            else:
                if native.startswith("_") and not native.startswith("__"):
                    continue
                # Skip Ruby setter methods (``foo=``); they're part of
                # @property machinery and Python lists the property name
                # only once. Operator methods (``[]``, ``==``, ``+``,
                # etc.) likewise aren't part of the canonical surface.
                if native.endswith("=") or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*[?!]?$", native):
                    continue
                # Strip Ruby ?/! suffixes for the canonical name; Python
                # signature inventory doesn't mark predicates / bangs.
                clean = native.rstrip("?!")
                # Payload readers carry the wire field verbatim (no snake_case).
                method_canonical = clean if is_payload else snake_case(clean)
            if method_canonical in methods_out:
                continue
            sig = build_signature(
                m, instance_method=not m.get("is_static") and native != "<init>",
            )
            # Filter out parameters with empty names (anonymous block / rest)
            sig["params"] = [p for p in sig["params"] if p.get("name")]
            if is_generated:
                # §B / L10 typed-input UNFOLD: a generated operation/command/set
                # method takes its wire fields as named kwargs, but Ruby
                # reflection recovers neither their concrete TYPES nor the
                # reference's keyword/positional/var_keyword KINDS (it sees
                # ``any`` for everything and a Ruby ``**kwargs`` for the doors).
                # REPLACE the reflected params with the generator's canonical
                # records (keyed ClassName::method) so the port compares on the
                # reference's real param count + kind + open-but-typed types.
                # This is legitimate adapter representation — wire-identical, the
                # same param SET the source method exposes — not an omission.
                sidecar = (
                    REST_SIGNATURES.get(f"{canonical_class}::{clean}")
                    if native != "<init>" else None
                )
                if sidecar is not None:
                    self_p = [p for p in sig["params"] if p.get("kind") == "self"]
                    sig["params"] = self_p + [dict(r) for r in sidecar]
                # Apply the documented adapter param-renames (sWAIG->SWAIG,
                # from->from_) so the Ruby kwarg identifiers compare EQUAL to the
                # reference-recorded names. Renames, not omissions. (Applies to
                # both the sidecar-unfolded records and any non-sidecar method.)
                for p in sig["params"]:
                    p["name"] = GENERATED_PARAM_RENAMES.get(p["name"], p["name"])
            methods_out[method_canonical] = sig

        if not methods_out:
            continue
        out_modules.setdefault(mod, {})
        out_modules[mod].setdefault("classes", {})
        out_modules[mod]["classes"][canonical_class] = {
            "methods": dict(sorted(methods_out.items())),
        }
        ruby_to_canonical[full] = f"{mod}.{canonical_class}"
        raw_super = type_entry.get("superclass")
        if raw_super:
            superclass_index[f"{mod}.{canonical_class}"] = raw_super

    # Mixin projection: Ruby mixes all AgentBase mixins via include/extend
    # so every method shows on AgentBase. Project canonical-Python mixin
    # methods onto their owning mixin module. Methods may also live on
    # SWMLService (parent class) — combine both for projection lookup.
    ab_entry = out_modules.get("signalwire.core.agent_base", {}).get("classes", {}).get("AgentBase")
    svc_entry = out_modules.get("signalwire.core.swml_service", {}).get("classes", {}).get("SWMLService")
    if ab_entry or svc_entry:
        ab_methods = ab_entry["methods"] if ab_entry else {}
        svc_methods = svc_entry["methods"] if svc_entry else {}
        combined = {**svc_methods, **ab_methods}
        projected: set[str] = set()
        for (target_mod, target_cls), expected in MIXIN_PROJECTIONS.items():
            present = {m: combined[m] for m in expected if m in combined}
            if not present:
                continue
            out_modules.setdefault(target_mod, {})
            out_modules[target_mod].setdefault("classes", {})
            out_modules[target_mod]["classes"].setdefault(target_cls, {"methods": {}})
            target_methods = out_modules[target_mod]["classes"][target_cls]["methods"]
            # A projection FILLS a method the target class does not declare; it
            # must never CLOBBER one the target really has. PromptManager is the
            # case that proved it: Ruby declares its own
            # ``PromptManager#define_contexts(contexts)`` — required, matching the
            # reference's PromptManager — but the projection overwrote it with
            # AgentBase's ``define_contexts(contexts = nil)``, whose reference
            # counterpart (PromptMixin) is deliberately OPTIONAL. The two
            # reference methods genuinely differ, so overwriting reported the
            # correct Ruby method as a required-flip against a signature it does
            # not have. Only project the names the target is actually missing.
            target_methods.update(
                {m: sig for m, sig in present.items() if m not in target_methods}
            )
            # The AgentBase donor copy is popped for EVERY name this projection
            # CLAIMS -- both the ones it filled in and the ones the target already
            # declared. Claiming is what says "this member's reference home is the
            # target class, not AgentBase"; whether Ruby happened to also declare
            # it on the target does not change where the reference records it.
            # (Popping only the filled ones stranded ``set_prompt_pom`` on
            # AgentBase, where the reference has no counterpart -> a bogus
            # missing-reference drift.)
            projected.update(present)
        for n in projected:
            ab_methods.pop(n, None)
        if ab_entry and not ab_methods:
            out_modules["signalwire.core.agent_base"]["classes"].pop("AgentBase", None)
            if not out_modules["signalwire.core.agent_base"].get("classes"):
                out_modules.pop("signalwire.core.agent_base", None)

    # Typed-surface strictness: rename Ruby-idiom hand-written params to the
    # reference identifier, THEN re-attach reference-documented concrete param
    # types onto hand-written params reflection recorded as bare ``any``.
    apply_sig_method_aliases(out_modules)
    apply_sig_method_donors(out_modules)
    apply_sig_free_function_projections(out_modules)
    synth_ai_chat_struct_inits(out_modules)
    apply_hand_param_renames(out_modules)
    project_reference_param_types(out_modules)
    normalize_request_options_param_kind(out_modules)

    sorted_modules = {}
    for k in sorted(out_modules):
        entry = out_modules[k]
        sorted_modules[k] = {}
        if "classes" in entry:
            sorted_modules[k]["classes"] = {
                c: entry["classes"][c] for c in sorted(entry["classes"])
            }
        if "functions" in entry:
            sorted_modules[k]["functions"] = dict(sorted(entry["functions"].items()))
    # Resolve each recorded Ruby superclass name to its canonical ``module.Class``.
    # A superclass outside the audited set (or dropped by EXCLUDED_RUBY_CLASSES)
    # simply has no entry — the chain stops there.
    canonical_supers = {
        cls: ruby_to_canonical[raw_super]
        for cls, raw_super in superclass_index.items()
        if raw_super in ruby_to_canonical
    }
    return {
        "version": "2",
        "generated_from": "signalwire-ruby via Method#parameters reflection",
        "modules": sorted_modules,
        "construction": build_construction(sorted_modules, canonical_supers),
    }


# ---------------------------------------------------------------------------
# Construction contract (porting-sdk ALLOWLIST_DISCIPLINE.md §10)
# ---------------------------------------------------------------------------

# Ruby expresses the reference's wide kwargs constructor DIRECTLY: Python's
# ``AgentBase.__init__(self, name=…, route=…, host=…, …)`` is Ruby's
# ``AgentBase#initialize(name:, route:, host:, …)``. Ruby keyword args are the
# closest analogue to Python kwargs in the fleet — same NAMED, unordered,
# any-subset call shape — so no builder binding and no name mapping are needed;
# the construction set is exactly the ctor's keyword parameters.
#
# This is what retires the 33 ``__init__`` signature-omissions whose rationale is
# literally "kwargs-idiom — Ruby keyword constructor ≡ Python positional with
# default": the positional-matching ``compare_param`` could never line a keyword
# ctor up against Python's positional-with-default signature, so the whole
# constructor was excused at once. Name-keyed construction compares them
# param-for-param instead.

# Params that are the ctor MECHANISM, not configurables. Ruby's ``**base`` spread
# (event subclasses forward the base-event fields to ``super``) and ``*args`` are
# splats, not named configurables; ``&block`` likewise. Kinds are already
# canonicalized by KIND_TO_CANONICAL, so this is a kind filter, not a name list.
_CONSTRUCTION_NON_PARAM_KINDS = frozenset(
    {"self", "cls", "var_keyword", "var_positional"}
)

# The reference's own construction sets, used to GATE the ``**opts``-to-``super``
# fold (see build_construction). This is the same oracle-driven discipline as
# enumerate_surface.rb's ORACLE_FIELD_ACCESSOR_MODULES: the adapter never decides
# on its own which inheritance to flatten — it asks the oracle what the reference
# actually records, per class.
REF_CONSTRUCTION: dict = _REF_SIG_RAW.get("construction", {})


def _oracle_flattens(cls: str, parent: str) -> bool:
    """Does the REFERENCE flatten ``parent``'s construction params into ``cls``?

    True when the reference's own construction set for ``cls`` already contains
    the parent's params (Python's ``@dataclass`` inheritance) — then Ruby's
    ``**base`` splat is folding the SAME set and must be unfolded to compare.
    False when the reference records only the subclass's own params (a
    ``**kwargs``-to-``super()`` forward, which the oracle does not enumerate) —
    folding there would invent extra params the reference never declares.

    FAILS LOUD rather than guessing: an oracle with no ``construction`` node at
    all means this enumerator is running against a pre-contract reference, and a
    silent False would emit a construction set that quietly under-reports every
    event class. Raising is the correct behaviour — regenerate/pull the oracle.
    """
    if not REF_CONSTRUCTION:
        raise RuntimeError(
            f"{_REF_SIG_PATH} has no `construction` node — cannot gate the "
            "**opts-to-super fold against the oracle. Pull porting-sdk (the "
            "construction contract landed in cf05021) and re-run."
        )
    ref_cls = (REF_CONSTRUCTION.get(cls) or {}).get("params")
    ref_parent = (REF_CONSTRUCTION.get(parent) or {}).get("params")
    if not ref_cls or not ref_parent:
        # The reference does not record a construction set for one side of this
        # edge; there is nothing to unfold TOWARD, so leave the port's own set.
        return False
    return set(ref_parent).issubset(set(ref_cls))


def build_construction(modules: dict, superclasses: dict) -> dict:
    """Return ``{"module.Class": {"params": {name: {type, required}}}}``.

    A NAME-KEYED set — order/arity/mechanism are idiom, the named set is the
    capability (porting-sdk ALLOWLIST_DISCIPLINE.md §10). The primary source for
    Ruby is the class's own ``__init__`` (``initialize``): Ruby's keyword
    constructor already IS the reference's named parameter set, unlike the
    factory/options-struct/builder ports which must bind a second construct.

    ``required`` mirrors the source signature — Ruby's ``:keyreq`` (``name:``
    with no default) is required, ``:key`` (``name: default``) is not. Per the
    owner ruling ``required`` is contract and must not vary between ports, so a
    Ruby ctor that defaults a reference-required param (or demands a
    reference-defaulted one) raises ``construction-required-flip`` rather than
    being smoothed over here.

    THE ``**opts``-TO-``super`` FOLD, ORACLE-GATED. Ruby's second construction
    idiom is the keyword splat: ``CallReceiveEvent#initialize(call_state: '', …,
    **base)`` ends in ``super(**base)``, so a caller may pass every one of the
    base class's keyword args — ``event_type:``, ``params:``, ``call_id:``,
    ``timestamp:`` — directly to the subclass (verified by construction, not by
    reading). ``Method#parameters`` reports only the ``:keyrest`` splat, so
    reflection alone under-reports the set by the whole inherited tail.

    But the reference has TWO subclass-construction shapes and they record
    DIFFERENTLY, so the fold cannot be applied unconditionally:

      * ``@dataclass`` events (``CallReceiveEvent(RelayEvent)``) — Python's
        dataclass machinery genuinely FLATTENS the base's fields into the
        generated ``__init__``, so the oracle records all 12 params. Ruby's
        ``**base`` splat is the same capability; without the fold each event
        reads as 4 missing configurables. FOLD.
      * ``**kwargs`` agents (``BedrockAgent(AgentBase)``) — the reference
        subclass ALSO forwards to ``super()``, and the oracle records only the
        subclass's OWN 7 params. Folding here would make Ruby declare 20
        ``construction-extra-param``s against a reference that simply does not
        enumerate them. DO NOT FOLD.

    The discriminator is not a property of Ruby at all — it is what the ORACLE
    records — so the gate reads the oracle: fold only into classes the reference
    itself flattens, i.e. where the reference's construction set already
    CONTAINS the parent's params. Same discipline as
    ``ORACLE_FIELD_ACCESSOR_MODULES`` in enumerate_surface.rb: oracle-driven,
    scoped, and it fails loud (see ``_oracle_flattens``) rather than guessing
    when the oracle is unavailable.

    Gating additionally on the splat keeps it honest from the Ruby side — a
    subclass that does NOT splat genuinely cannot accept the inherited keywords,
    and its missing params stay visible.
    """
    own: dict = {}
    splats: set = set()
    for mod, entry in modules.items():
        for cls, cinfo in (entry.get("classes") or {}).items():
            init = (cinfo.get("methods") or {}).get("__init__")
            if not isinstance(init, dict):
                continue
            key = f"{mod}.{cls}"
            params: dict = {}
            for p in init.get("params", []):
                if not isinstance(p, dict):
                    continue
                kind = p.get("kind") or "positional"
                if kind == "var_keyword":
                    splats.add(key)
                if kind in _CONSTRUCTION_NON_PARAM_KINDS:
                    continue
                name = p.get("name")
                if not name or name.startswith("_"):
                    continue
                params[name] = {
                    "type": p.get("type", "any"),
                    "required": bool(p.get("required", True)),
                }
            own[key] = params

    def resolved(key: str, seen: frozenset = frozenset()) -> dict:
        """Own params, plus the superclass's when this ctor splats to ``super``
        AND the reference flattens the same inheritance (see the docstring)."""
        params = dict(own.get(key, {}))
        parent = superclasses.get(key)
        if (key in splats and parent and parent not in seen
                and _oracle_flattens(key, parent)):
            inherited = resolved(parent, seen | {key})
            for name, spec in inherited.items():
                params.setdefault(name, spec)
        return params

    out: dict = {}
    for key in own:
        params = resolved(key)
        if params:
            out[key] = {"params": dict(sorted(params.items()))}
    return dict(sorted(out.items()))


def build_signature(method: dict, instance_method: bool) -> dict:
    params_out: list = []
    if instance_method or method.get("name") == "<init>":
        params_out.append({"name": "self", "kind": "self"})
    for p in method.get("parameters", []):
        ruby_kind = p.get("kind", "req")
        canonical_kind = KIND_TO_CANONICAL.get(ruby_kind, "positional")
        param: dict = {
            "name": p.get("name", "_"),
            "type": "any",  # Ruby is dynamically typed
        }
        if canonical_kind != "positional":
            param["kind"] = canonical_kind
        # A splat (*args / **kwargs) is inherently OPTIONAL — the method is
        # callable with zero extra positional/keyword args — as are default-
        # bearing opt/key params and the block. Only :req / :keyreq are
        # genuinely required. (Marking a splat required would wrongly fail the
        # signature diff's "extra port params must all be optional" tolerance
        # for the generated REST bodies' `**kwargs` forward-compat tail.)
        if ruby_kind in ("opt", "key", "block", "rest", "keyrest"):
            param["required"] = False
            # The DEFAULT VALUE comes from signature_dump.rb's Ripper source
            # parse (Method#parameters reports only that a default EXISTS, never
            # what it IS -- see that script's block comment). ``has_default``
            # marks a literal that was actually recovered, which is what lets a
            # recovered literal ``nil`` (``def f(x = nil)``) stay distinct from
            # "not statically recoverable" (``def f(x = SOME_CONST)``). Both
            # emit ``default: None``, but only the former is a real match --
            # they are recorded identically because the reference oracle has no
            # third state either, so an unrecovered default is reported below
            # rather than encoded here.
            #
            # A splat (*args/**kwargs) and a block have no default expression at
            # all; they are optional by nature and keep ``default: None``.
            param["default"] = p.get("default") if p.get("has_default") else None
        else:
            param["required"] = True
        params_out.append(param)
    name = method.get("name")
    if name == "<init>":
        returns = "void"
    else:
        returns = RETURN_TYPE_OVERRIDES.get(name, "any")
    return {
        "params": params_out,
        "returns": returns,
    }


def run_dump() -> dict:
    cp = subprocess.run(
        ["bundle", "exec", "ruby", str(HERE / "signature_dump.rb")],
        cwd=PORT_ROOT, capture_output=True, text=True, timeout=300,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"signature_dump.rb failed:\n{cp.stderr}\n{cp.stdout}")
    return json.loads(cp.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=PORT_ROOT / "port_signatures.json")
    args = parser.parse_args()

    if args.raw and args.raw.is_file():
        raw = json.loads(args.raw.read_text(encoding="utf-8"))
    else:
        raw = run_dump()

    canonical = collect(raw)

    args.out.write_text(json.dumps(canonical, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    n_mods = len(canonical["modules"])
    n_methods = sum(sum(len(c["methods"]) for c in m.get("classes", {}).values()) for m in canonical["modules"].values())
    n_funcs = sum(len(m.get("functions", {})) for m in canonical["modules"].values())
    print(f"enumerate_signatures: wrote {args.out} ({n_mods} modules, {n_methods} methods, {n_funcs} functions)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
