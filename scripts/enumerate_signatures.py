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
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PORT_ROOT = HERE.parent
PSDK = (PORT_ROOT.parent / "porting-sdk").resolve()
if not PSDK.is_dir():
    PSDK = Path("/usr/local/home/devuser/src/porting-sdk")

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
_REF_SIG_RAW = (
    json.loads(_REF_SIG_PATH.read_text()) if _REF_SIG_PATH.is_file() else {}
)


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
    ("signalwire.rest._base", "HttpClient", "__init__"): {"project_id": "project", "space": "host"},
    ("signalwire.rest._base", "SignalWireRestError", "__init__"): {"method_name": "method"},
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
    ("signalwire.pom.pom", "Section"): {"to_h": "to_dict"},
    ("signalwire.core.function_result", "FunctionResult"): {"to_h": "to_dict"},
    ("signalwire.relay.call", "Call"): {"pass_call": "pass_", "tap_audio": "tap"},
    ("signalwire.relay.message", "Message"): {"on_event": "on"},
    ("signalwire.relay.client", "RelayClient"): {"stop": "disconnect"},
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
    # REST resource & namespace classes — Python groups them by domain.
    # Ruby's ``SignalWire::REST::RestClient`` -> Python's
    # ``signalwire.rest.client.RestClient``.
    "SignalWire::REST::RestClient": "signalwire.rest.client",
    # Python keeps HttpClient + SignalWireRestError in signalwire/rest/_base.py;
    # Ruby gives HttpClient its own file but that's a layout-only difference.
    "SignalWire::REST::HttpClient": "signalwire.rest._base",
    "SignalWire::REST::SignalWireRestError": "signalwire.rest._base",
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
    # SignalWire::Logging.global_level / .logger / etc. -> Logging class
    "SignalWire::Logging": ("signalwire.logging", "Logging"),
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
            out_modules[target_mod]["classes"][target_cls]["methods"].update(present)
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
    apply_hand_param_renames(out_modules)
    project_reference_param_types(out_modules)

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
    return {
        "version": "2",
        "generated_from": "signalwire-ruby via Method#parameters reflection",
        "modules": sorted_modules,
    }


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
            param["default"] = None
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
