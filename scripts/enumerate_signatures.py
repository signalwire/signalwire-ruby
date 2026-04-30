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

    "SignalWire::AgentServer": "signalwire.agent_server",
    "SignalWire::Security::SessionManager": "signalwire.core.security.session_manager",
    "SignalWire::Prefabs::Concierge": "signalwire.prefabs.concierge",
    "SignalWire::Prefabs::FaqBot": "signalwire.prefabs.faq_bot",
    "SignalWire::Prefabs::InfoGatherer": "signalwire.prefabs.info_gatherer",
    "SignalWire::Prefabs::Receptionist": "signalwire.prefabs.receptionist",
    "SignalWire::Prefabs::Survey": "signalwire.prefabs.survey",
    "SignalWire::Skills::Builtin::SwmlTransferSkill": "signalwire.skills.swml_transfer.skill",
    "SignalWire::Skills::Builtin::McpGatewaySkill": "signalwire.skills.mcp_gateway.skill",
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
    "SignalWire::Relay::Action": "signalwire.relay.action",
    # Relay events: Python groups them under signalwire.relay.event
    "SignalWire::Relay::CallReceiveEvent": "signalwire.relay.event",
    "SignalWire::Relay::CallStateEvent": "signalwire.relay.event",
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
    "SignalWire::REST::HttpClient": "signalwire.rest.http_client",
    "SignalWire::REST::BaseResource": "signalwire.rest._base",
    "SignalWire::REST::CrudResource": "signalwire.rest._base",
    "SignalWire::REST::Namespaces::CallingNamespace": "signalwire.rest.namespaces.calling",
    "SignalWire::REST::Namespaces::ChatResource": "signalwire.rest.namespaces.chat",
    "SignalWire::REST::Namespaces::AddressesResource": "signalwire.rest.namespaces.addresses",
    "SignalWire::REST::Namespaces::CompatAccounts": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatApplications": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatCalls": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatConferences": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatFaxes": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatLamlBins": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatMessages": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatNamespace": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatPhoneNumbers": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatQueues": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatRecordings": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatTokens": "signalwire.rest.namespaces.compat",
    "SignalWire::REST::Namespaces::CompatTranscriptions": "signalwire.rest.namespaces.compat",
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
    "SignalWire::REST::Namespaces::ConferenceLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::FaxLogs": "signalwire.rest.namespaces.logs",
    "SignalWire::REST::Namespaces::LogsNamespace": "signalwire.rest.namespaces.logs",
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
    "SignalWire::Skills::Builtin::McpGatewaySkill": "MCPGatewaySkill",
    "SignalWire::Skills::Builtin::DatasphereSkill": "DataSphereSkill",
    "SignalWire::Skills::Builtin::DatasphereServerlessSkill": "DataSphereServerlessSkill",
    "SignalWire::Relay::Client": "RelayClient",
    "SignalWire::SWML::Service": "SWMLService",
}

MIXIN_PROJECTIONS = {
    ("signalwire.core.mixins.ai_config_mixin", "AIConfigMixin"): [
        "add_function_include", "add_hint", "add_hints", "add_internal_filler",
        "add_language", "add_pattern_hint", "add_pronunciation",
        "enable_debug_events",
        "set_function_includes", "set_global_data", "set_internal_fillers",
        "set_languages", "set_native_functions", "set_param", "set_params",
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
        "enable_debug_routes", "manual_set_proxy_url", "run", "serve",
        "set_dynamic_config_callback", "on_request", "on_swml_request",
    ],
    ("signalwire.core.mixins.mcp_server_mixin", "MCPServerMixin"): [
        "add_mcp_server",
    ],
    ("signalwire.core.mixins.state_mixin", "StateMixin"): [
        "validate_tool_token",
    ],
}

EXCLUDED_RUBY_CLASSES = {
    "SignalWire::AgentBase::AgentBodyLimitMiddleware",
    "SignalWire::AgentBase::AgentSecurityHeadersMiddleware",
    "SignalWire::AgentBase::AgentTimingSafeBasicAuth",
    "SignalWire::SWML::Service::SecurityHeadersMiddleware",
    "SignalWire::SWML::Service::TimingSafeBasicAuth",
    "SignalWire::Logging::Logger",
    "SignalWire::REST::Namespaces",
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
        if kind == "module":
            # Module-level functions emitted under their Python module.
            mod_path = ruby_module_to_py(full.split("::"))
            functions: dict = {}
            for m in type_entry.get("methods", []):
                if not m.get("is_static"):
                    continue
                native = m.get("name", "")
                if native.startswith("__") or native == "<init>":
                    continue
                if native.endswith("=") or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*[?!]?$", native):
                    continue  # skip Ruby setters / operator methods
                clean = native.rstrip("?!")
                snake = snake_case(clean)
                sig = build_signature(m, instance_method=False)
                sig["params"] = [p for p in sig["params"] if p.get("name")]
                functions[snake] = sig
            if functions:
                out_modules.setdefault(mod_path, {})
                out_modules[mod_path].setdefault("functions", {})
                out_modules[mod_path]["functions"].update(functions)
            continue

        resolved = resolve_class(full)
        if resolved is None:
            continue
        mod, canonical_class = resolved

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
                method_canonical = snake_case(clean)
            if method_canonical in methods_out:
                continue
            sig = build_signature(
                m, instance_method=not m.get("is_static") and native != "<init>",
            )
            # Filter out parameters with empty names (anonymous block / rest)
            sig["params"] = [p for p in sig["params"] if p.get("name")]
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
        if ruby_kind in ("opt", "key", "block"):
            param["required"] = False
            param["default"] = None
        else:
            param["required"] = True
        params_out.append(param)
    return {
        "params": params_out,
        "returns": "any" if method.get("name") != "<init>" else "void",
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
