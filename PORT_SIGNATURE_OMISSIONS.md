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

# PORT_SIGNATURE_OMISSIONS.md

Documented signature divergences between this Ruby port and the Python
reference. Each line:

    <fully.qualified.symbol>: <one-line rationale>

Lines starting with `#` are ignored by `diff_port_signatures.py`. Surface-
level (missing/extra symbol) divergences live in PORT_OMISSIONS.md /
PORT_ADDITIONS.md and are inherited automatically by the signature diff.

## Categories of excused divergence

1. **Ruby keyword-argument idiom** — Python uses positional parameters
   with defaults (`required=False`); Ruby uses keyword arguments
   (`required: false`). Both express the same call shape; Method#parameters
   reports them as `keyword`/`keyreq` while Python's reflection reports
   `positional`. Functional parity is preserved; the call site reads
   `data_map.parameter(name, type, desc, required: true)` in Ruby and
   `data_map.parameter(name, type, desc, required=True)` in Python.

2. **`from_payload` classmethod (Ruby static)** — Python defines
   `from_payload` as `@classmethod` (signature `(cls, payload)`); Ruby
   defines it as a class-level `def self.from_payload(payload)`. Same
   factory contract; Ruby's static method has no explicit `cls` receiver
   in its parameter list.

3. **Ruby `**kwargs` / hash collapse** — Several `Call#X` methods accept a
   single hash (`**kwargs`) and forward to RELAY rather than enumerate every
   field. Functionally equivalent — every Python keyword arg maps to a
   matching hash key — but the projected signature shows `(self, **kwargs)`
   instead of the full Python parameter list. Tracked here as Ruby idiom
   matching the TypeScript port's BACKLOG entries.

4. **Ruby `**base` event spread** — Subclassed event `__init__` methods
   take their subclass-specific keyword args plus `**base` to forward to
   `super(**base)`. Python flattens the constructor inheritance into a
   single explicit signature; Ruby keeps base-class params under `**base`.

# Ruby keyword-argument idiom (Python positional with default ≡ Ruby keyword arg)

signalwire.core.contexts.Step.add_gather_question: kwargs-idiom — Ruby keyword args (`key:`, `question:`, `type:`, `confirm:`, `prompt:`, `functions:`) ≡ Python positional with default
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_to_section: kwargs-idiom — Ruby `(title, body_arg=nil, body:, bullet:, bullets:)` ≡ Python positional with default
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_to_section: kwargs-idiom — Ruby `(title, body_arg=nil, body:, bullet:, bullets:)` ≡ Python positional with default
signalwire.core.mixins.tool_mixin.ToolMixin.define_tool: kwargs-idiom — Ruby keyword args (`name:`, `description:`, `parameters:`, ..., `swaig_fields:`) ≡ Python positional + `**swaig_fields`
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_language: kwargs-idiom — Ruby positional `(name, code, voice, ...)` plus `speech_fillers:`, `function_fillers:`, `engine:`, `model:` keyword args ≡ Python positional with default
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_pattern_hint: kwargs-idiom — Ruby splats positional args plus optional keyword `ignore_case:`; ≡ Python `(hint, pattern, replace, ignore_case=False)`
signalwire.core.mixins.web_mixin.WebMixin.on_swml_request: kwargs-idiom — Ruby third positional optional + `request:` keyword ≡ Python `on_swml_request(request_data, callback_path, request)`
signalwire.core.agent_base.AgentBase.on_debug_event: kwargs-idiom — Ruby `handler:` keyword ≡ Python positional with default
signalwire.core.contexts.GatherInfo.__init__: kwargs-idiom — Ruby `(output_key:, completion_action:, prompt:)` ≡ Python positional with default
signalwire.core.contexts.GatherQuestion.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.core.contexts.Step.set_gather_info: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.data_map.DataMap.parameter: kwargs-idiom — Ruby `(required:, enum:)` keyword ≡ Python positional with default
signalwire.core.swml_service.SWMLService.register_routing_callback: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.client.RelayClient.on_call: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.client.RelayClient.on_message: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.client.RestClient.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default

# from_payload classmethod — Ruby static method has no explicit cls receiver


# Ruby **kwargs collapse — Call methods forward a hash to RELAY (matches TS port BACKLOG)

signalwire.relay.call.Call.ai: kwargs-collapse — Ruby `def ai(control_id:, on_completed:, **kwargs)` forwards every remaining Python keyword to RELAY as a hash key (category 3)
signalwire.relay.call.Call.ai_hold: kwargs-collapse — Ruby `def ai_hold(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.ai_message: kwargs-collapse — Ruby `def ai_message(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.ai_unhold: kwargs-collapse — Ruby `def ai_unhold(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.amazon_bedrock: kwargs-collapse — Ruby `def amazon_bedrock(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.bind_digit: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.clear_digit_bindings: kwargs-collapse — Ruby `def clear_digit_bindings(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.collect: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.connect: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.echo: kwargs-collapse — Ruby `def echo(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.join_conference: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.join_room: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.leave_conference: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.leave_room: kwargs-collapse — Ruby `def leave_room(**kwargs)` forwards hash to RELAY
signalwire.relay.call.Call.live_translate: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.pay: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.queue_enter: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.queue_leave: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.refer: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.send_digits: kwargs-collapse — Ruby includes optional **kwargs even though Python signature is fixed-arity
signalwire.relay.call.Call.send_fax: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.stream: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.relay.call.Call.transcribe: kwargs-collapse — Ruby keeps required args explicit, optionals collapse into **kwargs
signalwire.prefabs.receptionist.ReceptionistAgent.__init__: kwargs-collapse — Ruby `**_opts` forwards extra kwargs to AgentBase super
signalwire.prefabs.survey.SurveyAgent.__init__: kwargs-collapse — Ruby `**_opts` forwards extra kwargs to AgentBase super

# Ruby **base spread — event subclass __init__ takes its own keyword args plus **base for super

signalwire.relay.event.CallReceiveEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super; Python flattens inheritance
signalwire.relay.event.CallStateEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.CallingErrorEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.CollectEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.ConferenceEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.ConnectEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.DenoiseEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.DetectEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.DialEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.EchoEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.FaxEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.HoldEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.MessageReceiveEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.MessageStateEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.PayEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.PlayEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.QueueEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.RecordEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.ReferEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.SendDigitsEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.StreamEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.TapEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super
signalwire.relay.event.TranscribeEvent.__init__: base-spread — Ruby keyword args + `**base` forwarded to super

# Single-case: kind 'keyword' vs 'var_keyword' (RelayClient.dial)

signalwire.relay.client.RelayClient.dial: kwargs-spread — Ruby `dial_timeout:` keyword arg projects as keyword while Python collects late args via var_keyword

# Prompt Object Model — Ruby keyword-arg idiom

signalwire.pom.pom.PromptObjectModel.__init__: Ruby keyword-arg idiom — `debug:` defaults are keyword in Ruby, positional with default in Python
signalwire.pom.pom.PromptObjectModel.to_json: Ruby JSON convention — `to_json(*_args)` accepts the optional state argument that Ruby's JSON.generate forwards
signalwire.pom.pom.Section.render_markdown: Ruby keyword-arg idiom — `level:` and `section_number:` are keyword in Ruby, positional with default in Python
signalwire.pom.pom.Section.render_xml: Ruby keyword-arg idiom — `indent:` and `section_number:` are keyword in Ruby, positional with default in Python

# Cross-port parity methods — Ruby keyword-arg idiom (positional-with-default in Python)

signalwire.prefabs.info_gatherer.InfoGathererAgent.on_swml_request: kwargs-idiom — Ruby third param `request:` is keyword ≡ Python positional (matches WebMixin.on_swml_request)



# ---------------------------------------------------------------------------
# Typed-surface strictness pass (2026-07): the signature audit now compares
# PARAM TYPES + method presence at signature granularity. Concrete param
# types are re-attached by the enumerator's reference-type projection;
# method/param renames + donors + free-fn projections mirror
# enumerate_surface.rb. The residual below is GENUINE Ruby idiom the
# enumerator cannot reconcile, a reference SIGNATURE-ORACLE gap (surface has
# the symbol, the sig oracle doesn't — proven by SURFACE-DIFF PASS), or a
# true Ruby-only addition. Each carries its signature-level reason.

# --- Ruby keyword-arg / **kwargs / block / classmethod idiom (kind & count) ---
signalwire.relay.call.PlayAction.volume: untyped-idiom — Ruby is dynamically typed; the `volume` param carries no static type (untyped `any`) where Python types it `float`. Same value on the wire (`play.volume` with `volume` key); the type divergence is Ruby's runtime-typed idiom, not a wire difference.
signalwire.relay.call.CollectAction.volume: untyped-idiom — Ruby is dynamically typed; the `volume` param carries no static type (untyped `any`) where Python types it `float`. Same value on the wire (`play_and_collect.volume` with `volume` key); the type divergence is Ruby's runtime-typed idiom, not a wire difference.
signalwire.core.logging_config.strip_control_chars: Ruby structlog processor closure takes only `event_dict`; Python's (logger, method_name, event_dict) processor signature — same processor contract
signalwire.core.pom_builder.PomBuilder.from_sections: classmethod idiom — Ruby `def self.` factory has no explicit `cls` receiver
signalwire.core.skill_base.SkillBase.define_tool: Ruby explicit keyword args (`name:`, `description:`, `parameters:`, &handler) ≡ Python `**kwargs` — same define_tool contract as named Ruby kwargs
signalwire.core.skill_manager.SkillManager.load_skill: Ruby SkillManager idiom — `load(key, skill)` takes a pre-built skill + instance key; Python `load_skill(skill_name, skill_class, params)` constructs it — same load contract, different split
signalwire.core.mixins.web_mixin.WebMixin.register_routing_callback: Ruby block idiom — the routing callback is an `&block`; `path:` is a Ruby keyword ≡ Python positional (donated from SWML::Service, matches surface donor)

# --- Reference accessors/properties hosted under a different Ruby idiom ---
signalwire.agent_server.AgentServer.agents: Ruby AgentServer holds registered agents in an internal ivar (no public `agents` reader); Python exposes an `agents` property — surface-reconciled
signalwire.core.mixins.prompt_mixin.PromptMixin.contexts: Ruby exposes contexts via `define_contexts`/internal state, not a bare `contexts` accessor; Python property — surface-reconciled (PORT_ADDITIONS)
signalwire.core.mixins.prompt_mixin.PromptMixin.set_prompt_pom: Ruby PromptMixin sets the POM via `prompt_add_section`/POM builder, not a `set_prompt_pom(pom)` setter — surface-reconciled (PORT_ADDITIONS)
signalwire.core.mixins.tool_mixin.ToolMixin.define_tools: Ruby ToolMixin defines tools one at a time via `define_tool`; Python's plural `define_tools` batch helper folds into the singular — surface-reconciled
signalwire.core.skill_manager.SkillManager.loaded_skills: Ruby exposes a single `list_loaded_skills` accessor (aliased from `loaded_keys`); Python has both `loaded_skills` (property) and `list_loaded_skills` — same list, one Ruby accessor
signalwire.core.swml_service.SWMLService.security: Ruby SWMLService keeps security in internal state / SecurityConfig, not a public `security` accessor; Python property — surface-reconciled
signalwire.web.web_service.WebService.app: Ruby WebService wraps a Rack app via `rack_app`; Python exposes a Flask `.app` attribute — no direct equivalent (matches AgentServer.app / PORT_OMISSIONS)

# --- Reference signature-oracle gaps (reference surface HAS the symbol) ---
signalwire.agents.bedrock.BedrockAgent.__init__: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_inference_params: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_llm_model: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_llm_temperature: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_post_prompt_llm_params: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_prompt_llm_params: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.agents.bedrock.BedrockAgent.set_voice: reference-oracle gap — the signature oracle omits `signalwire.agents.bedrock`, but the reference SURFACE records the full BedrockAgent surface and the port implements it (SURFACE-DIFF PASS)
signalwire.core.agent_base.AgentBase.handle_request: reference-oracle gap — the reference SURFACE records AgentBase.handle_request (the AgentBase override of the decomposed dispatch core) and the port implements it, but the signature oracle enumerates handle_request only on SWMLService, not the AgentBase override (SURFACE-DIFF PASS). Same signature as SWMLService.handle_request(method, url, headers, body) -> [status, headers, body_string], rendering agent SWML.
signalwire.core.swml_handler.AIVerbHandler.validate_config: reference-oracle gap — the reference surface records AIVerbHandler.validate_config but the signature oracle omits it (SURFACE-DIFF PASS)
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.__init__: reference-oracle gap — the reference surface records this skill class but the signature oracle omits its `__init__` (SURFACE-DIFF PASS)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.__init__: reference-oracle gap — the reference surface records this skill class but the signature oracle omits its `__init__` (SURFACE-DIFF PASS)
signalwire.skills.weather_api.skill.WeatherApiSkill.__init__: reference-oracle gap — the reference surface records this skill class but the signature oracle omits its `__init__` (SURFACE-DIFF PASS)

# --- True Ruby-only additions (absent from reference surface too) ---
signalwire.core.auth_handler.basic_credentials.BasicCredentials.inspect: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.basic_credentials.BasicCredentials.keyword_init: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.basic_credentials.BasicCredentials.members: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.basic_credentials.BasicCredentials.new: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.bearer_credentials.BearerCredentials.inspect: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.bearer_credentials.BearerCredentials.keyword_init: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.bearer_credentials.BearerCredentials.members: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.auth_handler.bearer_credentials.BearerCredentials.new: port-only: Ruby Struct/Data auto-generated method on a credentials value object; no Python counterpart (reference surface omits it too)
signalwire.core.swaig_function.SWAIGFunction.call: reference-oracle gap — port `call` is Ruby's callable primitive (surface reconciles it to `__call__`, which the reference surface records but the signature oracle omits) (SURFACE-DIFF PASS)
signalwire.core.swml_builder.SWMLBuilder.method_missing: reference-oracle gap — port `method_missing` is Ruby's dynamic-dispatch primitive (surface reconciles it to `__getattr__`, which the reference surface records but the signature oracle omits) (SURFACE-DIFF PASS)
signalwire.core.swml_service.SWMLService.function: port-only: Ruby SWMLService `function` DSL helper; absent from the reference surface + signature oracle
signalwire.core.swml_service.SWMLService.method_missing: reference-oracle gap — port `method_missing` is Ruby's dynamic-dispatch primitive (surface reconciles it to `__getattr__`, which the reference surface records but the signature oracle omits) (SURFACE-DIFF PASS)
signalwire.web.web_service.WebService.file_allowed: port-only: Ruby WebService `file_allowed` internal predicate; absent from the reference surface + signature oracle
