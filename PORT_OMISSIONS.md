<!-- ══════════════════════════════════════════════════════════════════════════
BEFORE YOU ADD AN ENTRY TO THIS FILE — READ THIS.

Every entry here is a place the parity checker STOPS comparing. That is a real cost:
a divergence you list is a divergence no gate will ever catch again. So entries must
be RARE, and each one must earn its place. Default to skepticism: assume the entry is
NOT needed and make the case that it is.

The order of preference, always:
  1. FIX THE PORT so it matches the reference (add the missing member; make the
     signature match).
  2. FIX THE EMISSION so idiom folds onto the reference shape — the enumerator/emitter
     canonicalizes your language's spelling onto the oracle's (builder → __init__,
     getters → attributes, Result<T,E> → the plain return, CamelCase → the reference
     name, options-object/kwargs → the expanded param list, RAII/dispose → close).
     MOST divergences are idiom and belong here, not in this file.
  3. FIX THE REFERENCE if the oracle itself is wrong or stale (a Python-only symbol
     that leaked into the contract, a param the reference added and the oracle never
     re-enumerated). Fix Python / the oracle, then re-drift — do not paper over a
     broken reference with a per-port entry.
  4. Only when 1–3 genuinely cannot apply does an entry here become justified.

An entry is JUSTIFIED ONLY IF it is irreducible after correct emission — i.e. the
divergence survives because the two languages genuinely cannot express the same thing,
not because the emitter hasn't folded the idiom yet. If emission COULD fold it, the
entry is a bug in this file; go fix the emitter.

Each entry MUST state WHY, concretely, in one of these forms:
  • ADDITION — this symbol exists in the port but not the reference. Answer: is it
    genuine port-only surface with NO reference twin (say what it is and why the
    reference has no equivalent), or is it IDIOM the emitter should have folded (then
    it does not belong here — fold it)? A convenience/alias/back-compat wrapper is NOT
    a justification.
  • OMISSION — this reference symbol has no port member. Answer: WHY can it not exist
    here — what specific language feature is absent (e.g. no async-context-manager
    protocol, no __init__ method protocol)? "impossible:" means the construct cannot
    be expressed at all; if it merely LOOKS different, that's idiom → fold it, don't
    omit it. Cite a precedent when one exists (e.g. RelayClient omits the same dunder).
  • SIGNATURE — the symbol matches by name but its parameters differ. Answer: is the
    difference a foldable idiom collapse (options-object, leading context/self,
    builder) — then EXPAND it in the signature emitter so names+count match, don't list
    it — or a genuine reference-only parameter with no cross-language analogue?

If you cannot write a crisp, specific WHY that survives the "could emission fold this?"
test, the entry is not ready. Prove it's needed before you add it.
═══════════════════════════════════════════════════════════════════════════════ -->

# PORT_OMISSIONS.md

Symbols present in `python_surface.json` (the Python SDK reference at
`../porting-sdk/python_surface.json`) that this Ruby port
deliberately does **not** implement. Each line has the form:

    <fully.qualified.symbol>: <one-sentence rationale>

Lines starting with `#` are ignored by `diff_port_surface.py`. Blank lines
are ignored too. Don't rename or remove entries without also updating the
port surface; the diff tool will fail the build on unexcused drift.

## Category summary

- **CLI subsystem** (~120 symbols under `signalwire.cli.*`): Ruby SDK does
  not ship a standalone CLI tool. Python's `signalwire-agents` CLI is a
  separate project.
- **Search subsystem** (~60 symbols under `signalwire.search.*`,
  `signalwire.skills.native_vector_search.*`,
  `signalwire.skills.web_search.skill_improved.*`,
  `signalwire.skills.web_search.skill_original.*`): vector search /
  indexing omitted per porting-sdk Phase 7 "What to Skip".
- **LiveKit shim** (~65 symbols under `signalwire.livewire.*`): deferred
  per PORTING_GUIDE.md "LiveKit Compatibility Shim" — added once core
  port stabilises.
- **MCP gateway service** (~35 symbols under `signalwire.mcp_gateway.*`):
  separate daemon; Ruby agents consume MCP via
  `SignalWire::AgentBase#add_mcp_server`.
- **Python mixins** (~66 symbols under `signalwire.core.mixins.*`): Python
  multiple-inheritance pattern collapsed into `SignalWire::AgentBase` per
  Ruby's single-inheritance + modules model. Every mixin method is
  present on `AgentBase` (see PORT_ADDITIONS.md entries under
  `signalwire.core.agent_base.AgentBase.*`).
- **POM**: `SignalWire::POM::PromptObjectModel` and
  `SignalWire::POM::Section` ship as the typed equivalent of Python's
  `signalwire.pom.pom.PromptObjectModel` / `Section`, with byte-for-byte
  Markdown / XML / JSON / YAML rendering parity. `to_dict` uses Ruby's
  `to_h` idiom. The `PomBuilder` (Python helper) and `pom_tool` CLI
  remain omitted.
- **SWML internals** (~47 symbols under `signalwire.core.swml_service.*`,
  `signalwire.core.swml_builder.*`, `signalwire.core.swml_renderer.*`,
  `signalwire.core.swml_handler.*`, `signalwire.utils.schema_utils.*`):
  consolidated into `SignalWire::SWML::Service`, `::Document`, and
  `::Schema` (see PORT_ADDITIONS.md entries under `signalwire.swml.*`).
- **Auth/Config/Logging/Security config** (~34 symbols): Ruby uses
  `SignalWire::AgentBase` middleware, `ENV` directly, and
  `SignalWire::Logging` instead of standalone classes.
- **Web service** (6 symbols under `signalwire.web.web_service.*`):
  standalone WebService not ported; static files served from
  `SignalWire::Server::AgentServer`.
- **Python async-context-manager / dunder methods** on RelayClient and
  Message (`__aenter__`, `__aexit__`, `__del__`, `__repr__`): Ruby uses
  block-style constructors and `inspect`/`to_s` idioms.

> **Renames are NOT omissions — they live in the adapter, not here.**
> Ruby-keyword collisions and idiomatic shortenings
> (`pass_call`↔`pass_`, `tap_audio`↔`tap`, `on_event`↔`on`, `done?`↔`is_done`
> on `Call`/`Message`; the shortened `SessionManager`/`SkillManager`/
> `SkillRegistry`/`RelayClient` names) are reconciled by the enumerator's
> `MEMBER_RENAMES` / rename tables in `scripts/enumerate_surface.rb`
> (`:410-441`) so the canonical Python symbol stays PRESENT and keeps being
> compared. They are therefore recorded in `PORT_ADDITIONS.md` (the Ruby
> spelling) and mapped in the adapter — never listed as omitted symbols
> below. Per `RULES.md`, an omission excuses a symbol from comparison (a
> permanent blind spot); a rename re-establishes identity and keeps
> comparing, so a future shape change still surfaces as drift.

# Omitted symbols

signalwire.ai_chat.client.AIChatClient.__aenter__: impossible: Python async-context-manager protocol dunder; Ruby's AIChatClient is stateless per-request (Net::HTTP, no persistent aiohttp session to enter) — no __aenter__ equivalent (mirrors RelayClient.__aenter__; TS/PHP omit identically)
signalwire.ai_chat.client.AIChatClient.__aexit__: impossible: Python async-context-manager protocol dunder; Ruby's AIChatClient holds no persistent session to exit/close (Net::HTTP is per-request) — no __aexit__ equivalent (mirrors RelayClient.__aexit__; TS/PHP omit identically)
signalwire.core.agent.tools.decorator.ToolDecorator: impossible: Python @tool class/instance decorator API relies on the decorator protocol; Ruby registers tools via define_tool(name:, description:, parameters:, &handler) directly (TS + PHP both omit this as impossible)
signalwire.core.agent.tools.decorator.ToolDecorator.create_class_decorator: impossible: Python @tool decorator-protocol method; Ruby registers tools via define_tool directly (TS + PHP both omit as impossible)
signalwire.core.agent.tools.decorator.ToolDecorator.create_instance_decorator: impossible: Python @tool decorator-protocol method; Ruby registers tools via define_tool directly (TS + PHP both omit as impossible)
signalwire.core.agent.tools.registry.ToolRegistry.register_class_decorated_tools: impossible: discovers @tool-decorated class methods via the Python decorator protocol; Ruby has no method-decorator feature to discover, so there is nothing to register (TS + PHP both omit as impossible)
signalwire.core.mixins.mcp_server_mixin.MCPServerMixin: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.core.security.webhook_middleware.make_webhook_validation_dependency: impossible: framework-bound factory returning a FastAPI dependency; Ruby ships the equivalent as the SignalWire::Security::WebhookMiddleware Rack middleware (a PORT_ADDITION) — the FastAPI-dependency FORM has no Rack analog (TS/PHP ship native middleware likewise)
signalwire.relay.client.RelayClient.__aenter__: impossible: Python async-context-manager protocol dunder; Ruby uses block form / explicit connect+disconnect — no __aenter__ equivalent (TS/PHP omit identically)
signalwire.relay.client.RelayClient.__aexit__: impossible: Python async-context-manager protocol dunder; Ruby uses block form / explicit connect+disconnect (TS/PHP omit identically)
signalwire.relay.client.RelayClient.__del__: impossible: Python finalizer dunder; Ruby has no deterministic __del__ finalizer protocol (TS/PHP omit identically)
signalwire.relay.client.RelayClient.relay_protocol: impossible: Python property exposing the internal relay-protocol object; Ruby keeps the protocol object private (no public accessor) — internal plumbing, not public surface (TS/PHP omit identically)
signalwire.relay.message.Message.__repr__: impossible: Python object-repr dunder; Ruby provides the equivalent via the shared MessageSerialization module's inspect/to_s, but the __repr__ NAME itself has no standalone Ruby form (mirrors Call.__repr__; TS/PHP omit identically)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.cleanup: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_global_data: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_prompt_sections: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.registry.SkillRegistry.get_skill_class: Ruby SignalWire::Skills::SkillRegistry#get_factory returns class-or-factory - different name

<!-- B1 composition-attribute enrichment (porting-sdk) surfaced Python composition
attributes (SWMLService.security, AgentServer.agents, SkillManager.loaded_skills) that
Ruby exposes under an accessor idiom (get_agents/list_loaded_skills) or keeps as internal
state — recorded here as idiom omissions. The generated read-side model FIELD accessors
(swml_verbs_generated / post_prompt_generated / swaig_request_generated) are now EMITTED by
enumerate_surface.rb (oracle-gated field readers), matching go/rust/cpp/ts/php/dotnet — no
longer omitted. -->
agentbase-family.tool: impossible: Python @tool decorator relies on the decorator protocol; Ruby has no method-decorator feature — tools register via define_tool(name:, description:, parameters:, &handler) (TS + PHP also omit this as impossible). Folded key for the SURFACE diff; raw ToolMixin.tool twin excused for the SIGNATURE diff.
signalwire.agent_server.AgentServer.agents: impossible: Python surfaces `agents` as a dict-of-AgentBase composition attribute (B1 enrichment); Ruby exposes the same registry through `AgentServer#get_agents` (accessor idiom) — no bare `agents` attr member, wire-neutral (TS/PHP hit the same accessor idiom).
signalwire.core.skill_manager.SkillManager.loaded_skills: impossible: Python surfaces `loaded_skills` as a dict-of-SkillBase composition attribute (B1); Ruby exposes it through `SkillManager#list_loaded_skills` (accessor idiom) — no bare `loaded_skills` attr member, wire-neutral.
signalwire.core.swml_service.SWMLService.security: impossible: Python surfaces `security` as a SecurityConfig composition attribute (B1); Ruby keeps security config as internal state with no public model-accessor member (wire-neutral).
