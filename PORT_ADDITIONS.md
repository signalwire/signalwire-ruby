# PORT_ADDITIONS.md

Symbols present in this Ruby port's `port_surface.json` but **not** in
`python_surface.json`. Each line has the form:

    <fully.qualified.symbol>: <one-sentence rationale>

Lines starting with `#` are ignored by `diff_port_surface.py`. Blank lines
are ignored too. Every addition needs a justification so reviewers can
spot drift from the Python reference.

## Category summary

- **Runtime support**: `signalwire.runtime.Runtime` (added in
  `feat/lambda-support`) with `execution_mode`, `lambda?`, `serverless?`,
  and `lambda_base_url` — Ruby SDK needs to detect the serverless
  environment at startup. Python has an equivalent buried inside
  `signalwire.core.logging_config.get_execution_mode` (also omitted).
- **Lambda runtime**: `signalwire.serverless.lambda_handler.LambdaHandler`
  (added in `feat/lambda-support`) — Rack-compatible handler for AWS
  Lambda. Python has no equivalent in its module structure.
- **Mixin hoisting** (~56 methods under
  `signalwire.core.agent_base.AgentBase.*`): Python distributes these
  across `signalwire.core.mixins.*`; Ruby's single-inheritance + modules
  model consolidates them on `AgentBase`. The corresponding mixin classes
  are omitted in PORT_OMISSIONS.md.
- **Ruby-idiomatic method naming**: `to_h` (vs `to_dict`), `to_json`,
  `to_s`, `inspect`, `?`-suffixed predicates, `!`-suffixed bang methods.
  Idiomatic Ruby equivalents of Python methods omitted in
  PORT_OMISSIONS.md.
- **attr_reader accessors**: Ruby exposes constructor state via
  `attr_reader` methods (e.g. `AgentBase#name`, `Call#project_id`,
  `ConciergeAgent#amenities`). Python exposes the same data as dataclass
  fields or `@property` getters.
- **REST namespace accessors** (`RestClient.addresses`, `RestClient.video`,
  `FabricNamespace.swml_webhooks`, etc.): Ruby `attr_reader` methods on
  namespace resources. Python uses `@property` for the same access.
- **SWML consolidated classes**: `signalwire.swml.document.Document`,
  `signalwire.swml.schema.Schema`, `signalwire.swml.service.Service` —
  Ruby collapses the Python `SWMLBuilder`/`SwmlRenderer`/`SchemaUtils`/
  `SWMLService` split into three cohesive classes under
  `SignalWire::SWML::*`. The Python counterparts are omitted.
- **Ruby-keyword workarounds**: `Call.pass_call` (Python `Call.pass_`),
  `Call.tap_audio` (Python `Call.tap`), `CallingNamespace.end_call`
  (Python `CallingNamespace.end`), `Message.on_event`/`on_completed`
  (Python `Message.on`), `Action.is_done?`/`done?` (Python `is_done`).
- **Module-level helpers**: `SignalWire::Logging`, `SignalWire::SWML`,
  `SignalWire::Contexts`, `SignalWire::Runtime` module functions. These
  mirror behaviour Python keeps inside classes or separate files.
- **Relay event attr_readers** (~118 symbols under
  `signalwire.relay.event.*Event.*`): Ruby exposes Python `@dataclass`
  fields as explicit attr_readers. Every event class mirrors the Python
  contract but with Ruby-style accessors.
- **Relay value-object idiom layer** (Tier-2 idiom pass; 6 symbols on
  `RelayEvent`, 6 on `Message`): `deconstruct_keys`/`deconstruct` for
  Ruby 3.0 pattern matching (`case event in { call_state: }`), `to_h`/
  `to_json` for a typed projection, and value `==`/`eql?`/`hash` so equal
  events/messages dedupe in Sets and resolve as Hash keys. Defined once on
  the `RelayEvent` base and inherited by all 23 typed event subclasses
  (subclasses contribute fields via a private `_event_fields` hook, off the
  public surface), so the audit only counts them on the base. Python's
  `@dataclass(frozen=...)` events get structural equality + `__match_args__`
  for free; this is the Ruby-idiomatic equivalent.
- **Relay Tier-3 typed objects** (Tier-3 idiom pass; SELECTIVE, highest-traffic
  relay blobs) — three additive value objects + three frozen state-enum
  modules, all idiomatic Ruby (not another language's enum), all yielding the
  *identical* wire shape so the raw-Hash path stays canonical:
  - `signalwire.relay.device.Device` — types the `{ type, params }` descriptor
    handed to `connect`/`refer`/`dial`/`tap`. Types the *shape*; `type` stays a
    String (the discriminant is **not** schema-enumerated — `calling.{connect,
    refer,dial,tap}.params.json` declare `type` as a bare `"string"`). `#to_h`
    is byte identical to the hand-written literal. Carries the Wave-A relay
    idioms (`deconstruct`/`deconstruct_keys`, `==`/`eql?`/`hash`, `to_h`/
    `to_json`, `to_s`/`inspect`) plus `phone`/`sip` factory constructors.
    Python passes raw `dict`s; this is the Ruby-idiomatic typed equivalent.
  - `signalwire.relay.collect_config.CollectConfig` — types the known-shape
    collect config the input wrappers (`collect`/`play_and_collect`/`prompt_*`)
    already enumerate, grounded in `calling.collect.params.json` (`digits`/
    `speech` sub-shapes + top-level toggles). `#to_h` yields only the set
    fields (omit-when-nil), byte identical to the wrapper's wire shape. **No
    Tier-1 enum is folded in** — the collect shape carries no schema-enumerated
    sets (`terminators` is a free DTMF string; `language`/`model` are open
    vocabularies). Same value-object idioms (minus array `deconstruct`).
  - `signalwire.relay.{call_state,dial_state,message_state}` modules
    (`CallState`/`DialState`/`MessageState`) — frozen named constants wrapping
    the existing flat `*_STATE_*` literals (single source) with `ALL` +
    `TERMINAL` + a `terminal?`/`valid?` predicate; the wire value stays a bare
    String everywhere. `DialState` is new vocabulary (the reference exposes no
    flat dial-state constants; grounded in `relay/client.py`'s
    `_handle_dial_event` docstring `dialing | answered | failed`). The three
    vocabularies never conflate (`answered` ∈ Call+Dial but ∉ Message;
    `delivered` ∈ Message only; terminal sets differ). Plus typed predicate
    accessors **alongside the bare string** on the events that already carry
    the state: `CallStateEvent#terminal?`, `DialEvent#terminal?`/`answered?`/
    `failed?`, `MessageStateEvent#terminal?`, `Message#terminal?` — each agrees
    with the `*State.terminal?(string)` module call. Python keys off bare
    string compares (`== "ended"`, `MESSAGE_TERMINAL_STATES`); these are the
    Ruby-idiomatic named-constant equivalent. (Layer A drops the `?` suffix, so
    `terminal`/`valid` appear there; Layer B keeps the suffixed spelling.)

# Added symbols

signalwire.agent_server.AgentServer.app: port-only: Ruby accessor exposing the cached Rack app (Python parity: `server.app` FastAPI instance)
signalwire.agent_server.AgentServer.host: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.agent_server.AgentServer.log_level: port-only: Ruby attr_reader for the constructor `log_level:` argument (Python keeps it as `self.log_level`)
signalwire.agent_server.AgentServer.logger: port-only: Ruby attr_reader for the AgentServer's logger (Python parity: `server.logger`)
signalwire.agent_server.AgentServer.port: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.agent_server.AgentServer.rack_app: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.contexts.Contexts: port-only: SignalWire::Contexts module with create_simple_context helper
signalwire.contexts.Contexts.create_simple_context: port-only: Ruby counterpart of Python signalwire.core.contexts.create_simple_context (omitted)
signalwire.core.agent_base.AgentBase.add_function_include: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.agent_id: port-only: Ruby attr_reader for the auto-generated/explicit agent UUID (Python keeps it as `self.agent_id` instance attribute)
signalwire.core.agent_base.AgentBase.default_webhook_url: port-only: Ruby attr_reader for the constructor `default_webhook_url:` arg (Python: `self._default_webhook_url`)
signalwire.core.agent_base.AgentBase.add_hint: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_hints: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_internal_filler: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_language: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_mcp_server: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_pattern_hint: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_pronunciation: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.add_skill: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.as_rack_app: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.contexts: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.create_tool_token: port-only: Ruby instance helper that delegates to SessionManager#create_token (Python keeps token creation only in SessionManager)
signalwire.core.agent_base.AgentBase.define_contexts: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.define_tool: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.define_tools: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_debug_events: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_debug_routes: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_mcp_server: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.extract_sip_username: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.extract_sip_username_from_request: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.get_basic_auth_credentials: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.get_contexts: port-only: Ruby getter for the contexts dictionary (Python parity: PromptManager#get_contexts via PromptMixin projection)
signalwire.core.agent_base.AgentBase.get_post_prompt: port-only: Ruby getter for the post-prompt text (Python parity: PromptManager#get_post_prompt via PromptMixin projection)
signalwire.core.agent_base.AgentBase.get_prompt: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.get_raw_prompt: port-only: Ruby getter for the raw prompt text (Python parity: PromptManager#get_raw_prompt via PromptMixin projection)
signalwire.core.agent_base.AgentBase.has_skill?: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.host: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.list_skills: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.list_tool_names: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.logger: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.manual_set_proxy_url: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.name: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.native_functions: port-only: Ruby attr_reader for the constructor `native_functions:` arg (Python: `self.native_functions` list)
signalwire.core.agent_base.AgentBase.on_function_call: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.pom: port-only: Ruby read-only snapshot accessor for the POM section list (Python: `agent.pom` returns the live PromptObjectModel instance)
signalwire.core.agent_base.AgentBase.port: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.prompt_add_section: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.prompt_add_subsection: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.prompt_add_to_section: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.prompt_has_section?: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.rack_app: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.register_swaig_function: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.remove_skill: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.render_swml: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.reset_contexts: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.route: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.run: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.serve: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_dynamic_config_callback: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_function_includes: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_global_data: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_internal_fillers: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_languages: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_native_functions: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_param: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_params: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_post_prompt: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_post_prompt_llm_params: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_prompt_llm_params: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_prompt_pom: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_prompt_text: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.set_pronunciations: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.skill_manager: port-only: Ruby attr_reader for the owning SkillManager instance (Python parity: `self.skill_manager`)
signalwire.core.agent_base.AgentBase.update_global_data: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.use_pom: port-only: Ruby attr_reader for the constructor `use_pom:` flag (Python: `self._use_pom` private attribute)
signalwire.core.agent_base.AgentBase.validate_tool_token: port-only: token-validation helper hoisted from Python's StateMixin onto AgentBase (Ruby single-inheritance + modules model)
signalwire.core.contexts.Context.name: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.Context.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.core.contexts.ContextBuilder.attach_agent: port-only: Ruby ContextBuilder attaches to an agent for method chaining
signalwire.core.contexts.ContextBuilder.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.core.contexts.ContextBuilder.validate!: port-only: Ruby bang-convention validate! matching Python validate (omitted)
signalwire.core.contexts.GatherInfo.completion_action: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherInfo.output_key: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherInfo.prompt: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherInfo.questions: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherInfo.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.core.contexts.GatherQuestion.confirm: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherQuestion.functions: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherQuestion.key: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherQuestion.prompt: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherQuestion.question: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.GatherQuestion.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.core.contexts.GatherQuestion.type: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.Step.name: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.core.contexts.Step.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.core.data_map.DataMap.create_expression_tool: port-only class method: moved from module-level function in Python
signalwire.core.data_map.DataMap.create_simple_api_tool: port-only class method: moved from module-level function in Python
signalwire.core.data_map.DataMap.function_name: port-only: attr_reader for function_name
signalwire.core.function_result.FunctionResult.action: port-only: attr_reader for function-result action array
signalwire.core.function_result.FunctionResult.post_process: port-only: attr_reader for post_process flag
signalwire.core.function_result.FunctionResult.response: port-only: attr_reader for response text
signalwire.core.function_result.FunctionResult.to_h: port-only: Ruby convention - to_h replaces to_dict
signalwire.core.function_result.FunctionResult.to_json: port-only: Ruby convention - to_json serializer
signalwire.core.security.session_manager.SessionManager.create_token: port-only: Ruby create_token name matches the Python generate_token/create_tool_token surface (both omitted)
signalwire.core.security.webhook_middleware.WebhookMiddleware: rack-middleware idiom — Python ships a FastAPI dependency factory; Ruby ships a Rack middleware class (canonical HTTP adapter shape)
signalwire.core.security.webhook_middleware.WebhookMiddleware.__init__: rack-middleware idiom — Python ships a FastAPI dependency factory; Ruby ships a Rack middleware class (canonical HTTP adapter shape)
signalwire.core.security.webhook_middleware.WebhookMiddleware.call: rack-middleware idiom — Rack call(env) entry point; Python equivalent is the FastAPI async dependency callable
signalwire.core.skill_base.SkillBase.agent: port-only: Ruby attr_reader for the owning AgentBase (Python parity: `self.agent` instance attribute)
signalwire.core.skill_base.SkillBase.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.logger: port-only: Ruby attr_reader for the namespaced logger (Python parity: `self.logger`)
signalwire.core.skill_base.SkillBase.get_param: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.params: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.required_env_vars: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.core.skill_base.SkillBase.swaig_fields: port-only: Ruby attr_reader for the swaig_fields override extracted from params (Python parity: `self.swaig_fields`)
signalwire.core.skill_base.SkillBase.version: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_manager.SkillManager.agent: port-only: Ruby attr_reader for the owning AgentBase (Python parity: `self.agent`)
signalwire.core.skill_manager.SkillManager.clear: port-only: SkillManager#clear - no direct Python equivalent (Python unloads individually)
signalwire.core.skill_manager.SkillManager.logger: port-only: Ruby attr_reader for the manager's namespaced logger (Python parity: `self.logger`)
signalwire.core.skill_manager.SkillManager.get: port-only: SkillManager#get - Ruby shortened name; see PORT_OMISSIONS for get_skill
signalwire.core.skill_manager.SkillManager.load: port-only: SkillManager#load - Ruby shortened name; see PORT_OMISSIONS for load_skill
signalwire.core.skill_manager.SkillManager.loaded: port-only: same as SkillManager#loaded? - signature audit strips Ruby ?/! suffixes
signalwire.core.skill_manager.SkillManager.loaded?: port-only: SkillManager#loaded? predicate - Ruby shortened name; see PORT_OMISSIONS for has_skill
signalwire.core.skill_manager.SkillManager.loaded_keys: port-only: SkillManager#loaded_keys - Ruby shortened name; see PORT_OMISSIONS for list_loaded_skills
signalwire.core.skill_manager.SkillManager.size: port-only: SkillManager#size - count of loaded skills
signalwire.core.skill_manager.SkillManager.unload: port-only: SkillManager#unload - Ruby shortened name; see PORT_OMISSIONS for unload_skill
signalwire.logging.Logging: port-only: Ruby SignalWire::Logging module (Python splits this between core.logging_config and standard logging)
signalwire.logging.Logging.global_level: port-only: module accessor for the current log level
signalwire.logging.Logging.logger: port-only: module accessor for a named logger
signalwire.logging.Logging.reset!: port-only: Ruby bang-convention - reset logging configuration (used in tests)
signalwire.logging.Logging.suppressed?: port-only: Ruby predicate - check if logging is suppressed
signalwire.prefabs.concierge.ConciergeAgent.amenities: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.handle_amenity_info: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.concierge.ConciergeAgent.handle_service_info: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.concierge.ConciergeAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.services: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.concierge.ConciergeAgent.venue_name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.faqs: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.questions: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.tools: port-only: Ruby convenience reader listing the prefab's tool names
signalwire.prefabs.receptionist.ReceptionistAgent.departments: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.greeting: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.handle_transfer: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.receptionist.ReceptionistAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.receptionist.ReceptionistAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.handle_start: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.survey.SurveyAgent.handle_submit: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.survey.SurveyAgent.handle_summary: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.survey.SurveyAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.questions: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.survey_name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.survey.SurveyAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.relay.call.Action.call: port-only: attr_reader for parent call
signalwire.relay.call.Action.completed: port-only: attr_reader for action completed state
signalwire.relay.call.Action.control_id: port-only: attr_reader for control_id
signalwire.relay.call.Action.done?: port-only: Ruby predicate for done state
signalwire.relay.call.Action.is_done?: port-only: Ruby predicate for done state (see PORT_OMISSIONS for Python is_done)
signalwire.relay.call.Action.on_completed: port-only: block-style event handler (idiomatic Ruby)
signalwire.relay.call.Action.result: port-only: attr_reader for action result
signalwire.relay.call.Call.call_id: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.context: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.device: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.direction: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.ended?: port-only: Ruby predicate for ended state
signalwire.relay.call.Call.inspect: port-only: Ruby Object#inspect override
signalwire.relay.call.Call.node_id: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.pass_call: port-only: Ruby Call#pass_call - see PORT_OMISSIONS for Python pass_ (Ruby keyword conflict)
signalwire.relay.call.Call.project_id: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.segment_id: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.state: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.tag: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.call.Call.tap_audio: port-only: Ruby Call#tap_audio - see PORT_OMISSIONS for Python tap (Ruby core method conflict)
signalwire.relay.call.Call.to_s: port-only: Ruby Object#to_s override
signalwire.relay.client.ActionTimeoutError: port-only: Ruby error class for action timeouts (Python uses asyncio.TimeoutError)
signalwire.relay.client.RelayClient.host: port-only: Ruby attr_reader for the resolved RELAY host URL (Python parity: `self.host` instance attribute)
signalwire.relay.client.RelayClient.max_active_calls: port-only: Ruby attr_reader for the constructor `max_active_calls:` arg (Python: `self._max_active_calls`)
signalwire.relay.client.RelayClient.project_id: port-only: attr_reader for project_id on Client
signalwire.relay.client.RelayClient.protocol: port-only: Ruby Client#protocol - see PORT_OMISSIONS for Python relay_protocol equivalent
signalwire.relay.client.RelayClient.stop: port-only: Ruby Client#stop - see PORT_OMISSIONS for Python disconnect equivalent
signalwire.relay.client.RelayError.code: port-only: attr_reader for error code
signalwire.relay.client.RelayError.error_message: port-only: attr_reader for error message
signalwire.relay.event.CallReceiveEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.call_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.context: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.device: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.direction: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.node_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.project_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.segment_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallReceiveEvent.tag: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallStateEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallStateEvent.call_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallStateEvent.device: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallStateEvent.direction: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallStateEvent.end_reason: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallingErrorEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallingErrorEvent.code: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CallingErrorEvent.message: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CollectEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CollectEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CollectEvent.final: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CollectEvent.result: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.CollectEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConferenceEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConferenceEvent.conference_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConferenceEvent.name: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConferenceEvent.status: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConnectEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConnectEvent.connect_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ConnectEvent.peer: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DenoiseEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DenoiseEvent.denoised: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DetectEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DetectEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DetectEvent.detect: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DialEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DialEvent.call_data: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DialEvent.dial_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.DialEvent.tag: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.EchoEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.EchoEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.FaxEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.FaxEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.FaxEvent.fax: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.HoldEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.HoldEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.body: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.context: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.direction: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.from_number: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.media: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.message_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.message_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.segments: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.tags: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageReceiveEvent.to_number: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.body: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.context: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.direction: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.from_number: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.media: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.message_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.message_state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.reason: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.segments: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.tags: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.MessageStateEvent.to_number: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PayEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PayEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PayEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PlayEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PlayEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.PlayEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.position: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.queue_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.queue_name: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.size: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.QueueEvent.status: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.duration: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.record: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.size: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RecordEvent.url: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ReferEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ReferEvent.sip_notify_response_code: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ReferEvent.sip_refer_response_code: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ReferEvent.sip_refer_to: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.ReferEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.call_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.event_type: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.params: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.timestamp: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.RelayEvent.deconstruct: port-only: Ruby 3.0 array pattern-matching hook (`in [type, call_id, ts]`); defined once on the base, inherited by every typed event subclass
signalwire.relay.event.RelayEvent.deconstruct_keys: port-only: Ruby 3.0 hash pattern-matching hook (`case event in { call_state: }`); defined once on the base, inherited by every typed event subclass
signalwire.relay.event.RelayEvent.eql: port-only: Ruby value-equality (`eql?`) so same-data events are interchangeable Hash keys; inherited by every typed event subclass
signalwire.relay.event.RelayEvent.eql?: port-only: Ruby value-equality `eql?` (Layer B keeps the `?` suffix; same method as the suffix-stripped `eql` Layer A spelling above)
signalwire.relay.event.RelayEvent.hash: port-only: Ruby `Object#hash` override paired with `==`/`eql?` so equal events share a Set/Hash bucket; inherited by every typed event subclass
signalwire.relay.event.RelayEvent.to_h: port-only: Ruby convention - typed Hash projection (envelope + typed fields, not raw params); inherited by every typed event subclass
signalwire.relay.event.RelayEvent.to_json: port-only: Ruby convention - JSON serializer over `to_h`; inherited by every typed event subclass
signalwire.relay.event.SendDigitsEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.SendDigitsEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.SendDigitsEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.StreamEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.StreamEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.StreamEvent.name: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.StreamEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.StreamEvent.url: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TapEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TapEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TapEvent.device: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TapEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TapEvent.tap: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.__init__: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.control_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.duration: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.recording_id: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.size: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.state: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.event.TranscribeEvent.url: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
signalwire.relay.message.Message.body: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.context: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.direction: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.done?: port-only: Ruby predicate for done state
signalwire.relay.message.Message.from_number: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.inspect: port-only: Ruby Object#inspect override
signalwire.relay.message.Message.is_done?: port-only: Ruby predicate (see PORT_OMISSIONS for Python is_done)
signalwire.relay.message.Message.media: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.message_id: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.on_completed: port-only: block-style completion handler
signalwire.relay.message.Message.on_event: port-only: block-style event handler - Ruby name (see PORT_OMISSIONS for Python on)
signalwire.relay.message.Message.reason: port-only: attr_reader for message failure reason
signalwire.relay.message.Message.segments: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.state: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.tags: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.to_number: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.relay.message.Message.to_s: port-only: Ruby Object#to_s override
signalwire.relay.message.Message.deconstruct: port-only: Ruby 3.0 array pattern-matching hook (`in [id, direction, state]`)
signalwire.relay.message.Message.deconstruct_keys: port-only: Ruby 3.0 hash pattern-matching hook (`case msg in { direction:, body: }`)
signalwire.relay.message.Message.eql: port-only: Ruby value-equality (`eql?`) over the message's value fields, ignoring completion machinery
signalwire.relay.message.Message.eql?: port-only: Ruby value-equality `eql?` (Layer B keeps the `?` suffix; same method as the suffix-stripped `eql` Layer A spelling above)
signalwire.relay.message.Message.hash: port-only: Ruby `Object#hash` override paired with `==`/`eql?` so equal messages share a Set/Hash bucket
signalwire.relay.message.Message.to_h: port-only: Ruby convention - Hash projection of the message's value fields (excludes mutex/condition/callbacks)
signalwire.relay.message.Message.to_json: port-only: Ruby convention - JSON serializer over `to_h`

# --- Tier-3 typed objects (relay) ---
# Device: typed { type, params } descriptor for connect/refer/dial/tap; type stays a String (discriminant not schema-enumerated); to_h is byte-identical to the raw Hash; raw-Hash path stays canonical.
signalwire.relay.device.Device: port-only: typed RELAY device value object ({ type, params }) for connect/refer/dial/tap; Python passes a raw dict
signalwire.relay.device.Device.__init__: port-only: Ruby `Device.new(type, params={})` constructor (type stringified, params default {})
signalwire.relay.device.Device.type: port-only: attr_reader for the device discriminant (a free String, not a closed enum — `calling.*.params.json` declares `type` as bare "string")
signalwire.relay.device.Device.params: port-only: attr_reader for the device-specific params Hash
signalwire.relay.device.Device.phone: port-only: `Device.phone(to:, from:, timeout:)` factory building the canonical phone device (omit-when-nil optionals)
signalwire.relay.device.Device.sip: port-only: `Device.sip(to:, from:, headers:)` factory building the canonical sip device
signalwire.relay.device.Device.to_h: port-only: wire Hash `{ "type"=>, "params"=> }` (string keys), byte-identical to the hand-written device literal
signalwire.relay.device.Device.to_json: port-only: Ruby convention - JSON serializer over `to_h`
signalwire.relay.device.Device.deconstruct: port-only: Ruby 3.0 array pattern-matching hook (`in [type, params]`)
signalwire.relay.device.Device.deconstruct_keys: port-only: Ruby 3.0 hash pattern-matching hook (`in { type: "phone", params: }`)
signalwire.relay.device.Device.eql: port-only: Ruby value-equality (`eql?`) — same type + params (Layer A suffix-stripped spelling)
signalwire.relay.device.Device.eql?: port-only: Ruby value-equality `eql?` (Layer B keeps the `?` suffix; same method as the suffix-stripped `eql` above)
signalwire.relay.device.Device.hash: port-only: Ruby `Object#hash` override paired with `==`/`eql?` so equal devices share a Set/Hash bucket
signalwire.relay.device.Device.to_s: port-only: Ruby Object#to_s override
signalwire.relay.device.Device.inspect: port-only: Ruby Object#inspect override (aliases to_s)
# CollectConfig: typed known-shape collect config the input wrappers enumerate; grounded in calling.collect.params.json; to_h yields the identical wire shape (omit-when-nil); no Tier-1 enum (the shape has no closed sets).
signalwire.relay.collect_config.CollectConfig: port-only: typed RELAY collect-config value object for collect/play_and_collect/prompt_*; Python passes a raw dict
signalwire.relay.collect_config.CollectConfig.__init__: port-only: keyword constructor for the collect shape (digits/speech sub-Hashes + top-level toggles)
signalwire.relay.collect_config.CollectConfig.digits: port-only: attr_reader for the digits sub-config
signalwire.relay.collect_config.CollectConfig.speech: port-only: attr_reader for the speech sub-config
signalwire.relay.collect_config.CollectConfig.initial_timeout: port-only: attr_reader for the initial_timeout toggle
signalwire.relay.collect_config.CollectConfig.partial_results: port-only: attr_reader for the partial_results toggle
signalwire.relay.collect_config.CollectConfig.continuous: port-only: attr_reader for the continuous toggle
signalwire.relay.collect_config.CollectConfig.send_start_of_input: port-only: attr_reader for the send_start_of_input toggle
signalwire.relay.collect_config.CollectConfig.start_input_timers: port-only: attr_reader for the start_input_timers toggle
signalwire.relay.collect_config.CollectConfig.to_h: port-only: wire Hash with only the set fields (omit-when-nil), byte-identical to the wrapper's collect literal
signalwire.relay.collect_config.CollectConfig.to_json: port-only: Ruby convention - JSON serializer over `to_h`
signalwire.relay.collect_config.CollectConfig.deconstruct_keys: port-only: Ruby 3.0 hash pattern-matching hook (`in { initial_timeout: }`)
signalwire.relay.collect_config.CollectConfig.eql: port-only: Ruby value-equality (`eql?`) over the projected wire shape (Layer A suffix-stripped spelling)
signalwire.relay.collect_config.CollectConfig.eql?: port-only: Ruby value-equality `eql?` (Layer B keeps the `?` suffix; same method as the suffix-stripped `eql` above)
signalwire.relay.collect_config.CollectConfig.hash: port-only: Ruby `Object#hash` override paired with `==`/`eql?`
signalwire.relay.collect_config.CollectConfig.to_s: port-only: Ruby Object#to_s override
signalwire.relay.collect_config.CollectConfig.inspect: port-only: Ruby Object#inspect override (aliases to_s)
# RELAY state enums: frozen named-constant modules wrapping the flat *_STATE_* literals (single source) with ALL/TERMINAL/terminal?/valid?; wire value stays a bare String. Python keys off bare-string compares.
signalwire.relay.call_state.CallState: port-only: frozen named view over the call-state vocabulary (ALL/TERMINAL + predicates); wraps the flat CALL_STATE_* literals
signalwire.relay.call_state.CallState.terminal?: port-only: `CallState.terminal?(state)` predicate (true for `ended`); Python compares `== "ended"`
signalwire.relay.call_state.terminal: port-only: Layer A suffix-stripped spelling of `CallState.terminal?`
signalwire.relay.call_state.CallState.valid?: port-only: `CallState.valid?(state)` membership predicate over ALL
signalwire.relay.call_state.valid: port-only: Layer A suffix-stripped spelling of `CallState.valid?`
signalwire.relay.dial_state.DialState: port-only: frozen named view over the outbound-dial vocabulary (dialing/answered/failed) — new vocabulary the reference exposes no flat constants for (grounded in client.py `_handle_dial_event` docstring)
signalwire.relay.dial_state.DialState.terminal?: port-only: `DialState.terminal?(state)` predicate (true for answered/failed — the dial resolves/rejects)
signalwire.relay.dial_state.terminal: port-only: Layer A suffix-stripped spelling of `DialState.terminal?`
signalwire.relay.dial_state.DialState.valid?: port-only: `DialState.valid?(state)` membership predicate over ALL
signalwire.relay.dial_state.valid: port-only: Layer A suffix-stripped spelling of `DialState.valid?`
signalwire.relay.message_state.MessageState: port-only: frozen named view over the messaging-state vocabulary (ALL/TERMINAL + predicates); wraps the flat MESSAGE_STATE_* literals, TERMINAL is the same object as MESSAGE_TERMINAL_STATES
signalwire.relay.message_state.MessageState.terminal?: port-only: `MessageState.terminal?(state)` predicate (delivered/undelivered/failed); Python uses `MESSAGE_TERMINAL_STATES`
signalwire.relay.message_state.terminal: port-only: Layer A suffix-stripped spelling of `MessageState.terminal?`
signalwire.relay.message_state.MessageState.valid?: port-only: `MessageState.valid?(state)` membership predicate over ALL
signalwire.relay.message_state.valid: port-only: Layer A suffix-stripped spelling of `MessageState.valid?`
# Typed state-predicate accessors ALONGSIDE the bare string on the events/Message that already carry the state.
signalwire.relay.event.CallStateEvent.terminal?: port-only: typed predicate over `call_state` (agrees with `CallState.terminal?`), alongside the bare string
signalwire.relay.event.DialEvent.terminal?: port-only: typed predicate over `dial_state` (agrees with `DialState.terminal?`), alongside the bare string
signalwire.relay.event.DialEvent.answered?: port-only: typed predicate — dial succeeded (`dial_state == "answered"`)
signalwire.relay.event.DialEvent.failed?: port-only: typed predicate — dial failed (`dial_state == "failed"`)
signalwire.relay.event.MessageStateEvent.terminal?: port-only: typed predicate over `message_state` (agrees with `MessageState.terminal?`), alongside the bare string
signalwire.relay.message.Message.terminal?: port-only: typed predicate over `Message#state` (agrees with `MessageState.terminal?`), alongside the bare string
# --- end Tier-3 typed objects ---

signalwire.rest._base.CrudResource.update_method: port-only: per-resource override hook for PATCH vs PUT (default update verb)
signalwire.rest._base.HttpClient.base_url: port-only: attr_reader for base_url
signalwire.rest._base.SignalWireRestError.body: port-only: attr_reader for error body
signalwire.rest._base.SignalWireRestError.method_name: port-only: attr_reader for originating HTTP method
signalwire.rest._base.SignalWireRestError.status_code: port-only: attr_reader for HTTP status
signalwire.rest._base.SignalWireRestError.url: port-only: attr_reader for failed URL
signalwire.rest.client.RestClient.generated_http_client: port-only: the HttpClient the generated ResourceTree accessors build resources off of (§8 composition seam; Python has no equivalent public accessor)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.addresses: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.ai_agents: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.call_flows: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.conference_rooms: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.cxml_applications: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.cxml_scripts: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.cxml_webhooks: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.freeswitch_connectors: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.relay_applications: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.resources: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.sip_endpoints: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.sip_gateways: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.subscribers: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.swml_scripts: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.swml_webhooks: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.FabricNamespace.tokens: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.DatasphereNamespace.documents: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.LogsNamespace.conferences: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.LogsNamespace.fax: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.LogsNamespace.messages: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.LogsNamespace.voice: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.ProjectNamespace.tokens: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.RegistryNamespace.brands: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.RegistryNamespace.campaigns: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.RegistryNamespace.numbers: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.RegistryNamespace.orders: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.conference_tokens: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.conferences: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.room_recordings: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.room_sessions: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.room_tokens: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.rooms: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces._client_tree_generated.VideoNamespace.streams: port-only: attr_reader for sub-resource on the generated namespace container (Python uses @property; not recorded on the reference _client_tree_generated container which surfaces only __init__)
signalwire.rest.namespaces.datasphere_resources_generated.DatasphereDocuments.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.fabric_resources_generated.FabricAddresses.get: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.fabric_resources_generated.FabricAddresses.list: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.fax_resources_generated.FaxLogs.get: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.fax_resources_generated.FaxLogs.list: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.message_resources_generated.MessageLogs.get: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.message_resources_generated.MessageLogs.list: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.relay_rest_resources_generated.NumberGroups.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.relay_rest_resources_generated.PhoneNumbers.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.relay_rest_resources_generated.Queues.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.relay_rest_resources_generated.VerifiedCallers.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.video_resources_generated.VideoConferences.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.video_resources_generated.VideoRoomSessions.get: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.video_resources_generated.VideoRoomSessions.list: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.video_resources_generated.VideoRooms.delete: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.voice_resources_generated.VoiceLogs.get: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.rest.namespaces.voice_resources_generated.VoiceLogs.list: reference-oracle gap: base-inherited CRUD method the SIGNATURE oracle (python_signatures.json) records on this class but the SURFACE oracle (python_surface.json) omits; the route is real (exercised by REST-COVERAGE) and the generated resource emits it per the signature oracle — cannot fix the reference (read-only)
signalwire.runtime.Runtime: port-only: Ruby SDK runtime bootstrap (feat/lambda-support - not in Python module structure)
signalwire.runtime.Runtime.execution_mode: port-only: detects lambda/cgi/google_cloud_function/azure_function/server runtime
signalwire.runtime.Runtime.lambda?: port-only: Ruby predicate - true when inside AWS Lambda
signalwire.runtime.Runtime.lambda_base_url: port-only: constructs the AWS Lambda Function URL from env
signalwire.runtime.Runtime.serverless?: port-only: Ruby predicate - true inside any serverless platform
signalwire.serverless.lambda_handler.LambdaHandler: port-only: Lambda runtime support added in feat/lambda-support; not in Python module structure
signalwire.serverless.lambda_handler.LambdaHandler.__init__: port-only: Lambda runtime support
signalwire.serverless.lambda_handler.LambdaHandler.call: port-only: Lambda runtime support (Rack-style #call entrypoint)
signalwire.serverless.lambda_handler.LambdaHandler.for: port-only: LambdaHandler.for(agent) class-method factory
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.get_parameter_schema: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.register_tools: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.setup: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.builtin.custom_skills_skill.CustomSkillsSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.get_prompt_sections: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.datasphere.skill.DataSphereSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere.skill.DataSphereSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere.skill.DataSphereSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere.skill.DataSphereSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.datetime.skill.DateTimeSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.datetime.skill.DateTimeSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.google_maps.skill.GoogleMapsSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.google_maps.skill.GoogleMapsSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.info_gatherer.skill.InfoGathererSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.info_gatherer.skill.InfoGathererSkill.get_prompt_sections: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.info_gatherer.skill.InfoGathererSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.info_gatherer.skill.InfoGathererSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.info_gatherer.skill.InfoGathererSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.joke.skill.JokeSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.joke.skill.JokeSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.math.skill.MathSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.math.skill.MathSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.registry.SkillRegistry.external_paths: port-only: Ruby attr_reader for registered skill directories (Python parity: `self._external_paths`)
signalwire.skills.registry.SkillRegistry.get_factory: rename-carried: the Ruby name for the reference `get_skill_class`. enumerate_surface.rb renames it surface-side (SURFACE-DIFF passes); the signature oracle records `get_skill_class` with a shape the Ruby method does not match 1:1, so the Ruby name is carried here signature-side rather than renamed. The reference HAS the counterpart — not invented surface.
signalwire.skills.registry.SkillRegistry.last_registered: port-only: Ruby attr_reader recording the most recent skill name registered via #register_skill (test/audit helper)
signalwire.skills.registry.SkillRegistry.logger: port-only: Ruby attr_reader for the registry's namespaced logger (Python parity: `self.logger`)
signalwire.skills.registry.SkillRegistry.register: port-only: explicit registry registration (Ruby ships built-ins via register_builtins!)
signalwire.skills.registry.SkillRegistry.register_builtins: port-only: same as SkillRegistry.register_builtins! - signature audit strips Ruby ?/! suffixes
signalwire.skills.registry.SkillRegistry.register_builtins!: port-only: Ruby bang-convention to seed the registry with built-in skills
signalwire.skills.registry.SkillRegistry.registered: port-only: same as SkillRegistry.registered? - signature audit strips Ruby ?/! suffixes
signalwire.skills.registry.SkillRegistry.registered?: port-only: Ruby predicate - is_registered check
signalwire.skills.registry.SkillRegistry.reset: port-only: same as SkillRegistry.reset! - signature audit strips Ruby ?/! suffixes
signalwire.skills.registry.SkillRegistry.reset!: port-only: Ruby bang-convention to clear the registry (used in tests)
signalwire.skills.spider.skill.SpiderSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.spider.skill.SpiderSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.spider.skill.SpiderSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.spider.skill.SpiderSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.weather_api.skill.WeatherApiSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.weather_api.skill.WeatherApiSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.web_search.skill.WebSearchSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.web_search.skill.WebSearchSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.web_search.skill.WebSearchSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.web_search.skill.WebSearchSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.web_search.skill.WebSearchSkill.version: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.swml.SWML: port-only: SignalWire::SWML module with schema accessors
signalwire.swml.SWML.reset_schema!: port-only: Ruby bang-convention - clears the cached SWML schema (used in tests)
signalwire.swml.SWML.schema: port-only: module accessor for the shared SWML schema instance
signalwire.swml.document.Document: port-only: Ruby consolidated SWML builder+document; maps to Python SWMLBuilder/swml_renderer
signalwire.swml.document.Document.__init__: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.add_section: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.add_verb: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.add_verb_to_section: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.get_verbs: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.has_section?: port-only: Ruby predicate method (? suffix)
signalwire.swml.document.Document.render: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.render_pretty: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.reset: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.sections: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.document.Document.to_h: port-only: Ruby convention - to_h replaces Python to_dict
signalwire.swml.document.Document.version: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.schema.Schema: port-only: Ruby consolidated schema utils; maps to Python SchemaUtils
signalwire.swml.schema.Schema.__init__: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.schema.Schema.get_verb: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.schema.Schema.valid_verb?: port-only: Ruby predicate method (? suffix)
signalwire.swml.schema.Schema.verb_count: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.schema.Schema.verb_names: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.schema.Schema.verbs: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service: port-only: Ruby consolidated SWML service; maps to Python SWMLService
signalwire.swml.service.Service.__init__: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.document: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.config_file: port-only: Ruby attr_reader for the constructor `config_file:` arg (Python: `self._config_file`)
signalwire.swml.service.Service.execute_verb: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.get_all_functions: port-only: SWAIG hosting lifted from AgentBase (Python parity: ToolRegistry#get_all_functions)
signalwire.swml.service.Service.get_basic_auth_credentials: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.get_basic_auth_credentials_with_source: port-only: backwards-compat alias for `get_basic_auth_credentials(include_source: true)` (kept for callers from the pre-Python-parity API)
signalwire.swml.service.Service.get_function: port-only: SWAIG hosting lifted from AgentBase (Python parity: ToolRegistry#get_function)
signalwire.swml.service.Service.has_function: port-only: SWAIG hosting lifted from AgentBase (Python parity: ToolRegistry#has_function)
signalwire.swml.service.Service.get_full_url: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.host: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.method_missing: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.name: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.on_request: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.on_swml_request: port-only: extension hook on SWMLService (Python parity: WebMixin#on_swml_request — Ruby exposes the same hook directly on Service for subclass overrides)
signalwire.swml.service.Service.port: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.rack_app: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.register_routing_callback: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.remove_function: port-only: SWAIG hosting lifted from AgentBase (Python parity: ToolRegistry#remove_function)
signalwire.swml.service.Service.render: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.render_pretty: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.route: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.schema_path: port-only: Ruby attr_reader for the constructor `schema_path:` arg (Python: `self.schema_path`)
signalwire.swml.service.Service.schema_utils: port-only: Ruby lazy accessor for the SchemaUtils helper (Python: `self.schema_utils` instance attribute)
signalwire.swml.service.Service.schema_validation: port-only: Ruby attr_reader for the constructor `schema_validation:` flag (Python: `self._schema_validation`)
signalwire.swml.service.Service.serve: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.stop: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.validate_basic_auth: port-only: timing-safe credential check on Service (Python parity: AuthMixin#validate_basic_auth)
signalwire.swml.service.Service.define_tool: port-only: SWAIG hosting lifted from AgentBase to SWMLService per parity-rule (Phase 2 of CHECKLIST_TEMPLATE — SWMLService independently usable)
signalwire.swml.service.Service.define_tools: port-only: SWAIG hosting lifted from AgentBase to SWMLService per parity-rule
signalwire.swml.service.Service.list_tool_names: port-only: SWAIG hosting lifted from AgentBase to SWMLService per parity-rule
signalwire.swml.service.Service.on_function_call: port-only: SWAIG dispatcher lifted from AgentBase to SWMLService per parity-rule (AgentBase overrides via _swaig_pre_dispatch instead)
signalwire.swml.service.Service.register_swaig_function: port-only: SWAIG hosting lifted from AgentBase to SWMLService per parity-rule
signalwire.swml.service.Service.handle_additional_route: port-only: routing-callback dispatcher exposed at the Service level for Ruby's Rack adapter
signalwire.swml.service.Service.render_main_swml: port-only: extension point that AgentBase overrides with prompt-driven rendering (matches Python's _render_swml hook)
signalwire.swml.service.Service.swaig_pre_dispatch: port-only: extension point AgentBase overrides for token validation + dynamic config (matches Python's _swaig_pre_dispatch)
signalwire.core.agent_base.AgentBase.handle_additional_route: port-only: AgentBase exposes Service's handle_additional_route through inheritance — Ruby method-resolution makes the inherited method visible on the subclass
signalwire.relay.client.RelayClient.on_event: port-only: generic event-handler hook for integration probes (e.g. audit_relay_handshake harness); Python uses callback registration on individual events
signalwire.relay.client.RelayClient.send_json: port-only: public surface for emitting raw JSON-RPC frames (used by tests and the audit harness; Python keeps this private)
signalwire.rest._base.HttpClient.project_id: port-only: Ruby attr_reader exposes the constructor-set project_id (used by audit_rest_transport harness to build paths in the LAML namespace)
signalwire.rest.client.RestClient.project_id: port-only: Ruby attr_reader exposes the constructor-set project_id (used by tests and the audit harness)
signalwire.core.swml_schema.Schema.get_verb: port-only: pre-existing singleton sidecar; canonical SchemaUtils ships separately at signalwire.utils.schema_utils
signalwire.core.swml_schema.Schema.valid_verb: port-only: pre-existing singleton sidecar; canonical SchemaUtils ships separately at signalwire.utils.schema_utils
signalwire.swml.reset_schema: port-only: Ruby module-level helper for clearing the cached singleton (used in tests); canonical SchemaUtils ships separately
signalwire.swml.schema: port-only: Ruby module-level singleton accessor; canonical SchemaUtils ships separately at signalwire.utils.schema_utils
signalwire.utils.schema_utils.SchemaUtils.generate_method_signature: Python-source codegen helper; canonical Python signatures filter this method out (Python-only output shape)
signalwire.utils.schema_utils.SchemaUtils.generate_method_body: Python-source codegen helper; canonical Python signatures filter this method out (Python-only output shape)
signalwire.utils.schema_utils.SchemaUtils.full_validation_available?: @property in Python (filtered as bool-returning attribute); ports expose it as an explicit method per spec
signalwire.utils.schema_utils.SchemaUtils.schema: port-only: Ruby attr_reader exposing the loaded schema hash (Python: `self.schema` instance attribute filtered out by surface enumeration)
signalwire.utils.schema_utils.SchemaUtils.schema_path: port-only: Ruby attr_reader for the resolved schema file path (Python: `self.schema_path` instance attribute)
signalwire.utils.schema_utils.SchemaValidationError.errors: port-only: Ruby attr_reader for the structured validation errors list (Python: `self.errors`)
signalwire.utils.schema_utils.SchemaValidationError.verb_name: port-only: Ruby attr_reader for the verb that failed validation (Python: `self.verb_name`)
signalwire.utils.url_validator.UrlValidator: port-only: SignalWire::Utils::UrlValidator helper class (Python: `signalwire.utils.url_validator.UrlValidator` filtered as static helper)
signalwire.utils.url_validator.UrlValidator.validate_url: port-only: class-level URL validator method (Python: `validate_url` staticmethod)

# Cross-port parity batch — Ruby's reflection enumerator surfaces these
# overrides/helpers that Python's AST enumerator does not put in its surface.
signalwire.list_skills: port-only: mirrors Python's top-level list_skills() (now implemented — delegates to the skill registry, present in python_surface.json), also exposed by go + typescript; the griffe signatures enumerator doesn't capture the module-level re-export, so it reads as a Layer-A-only addition
signalwire.prefabs.concierge.ConciergeAgent.on_summary: port-only: prefab override of AgentBase#on_summary surfaced by Ruby's reflection enumerator; Python's AST enumerator treats it as the inherited signature (also surfaced by typescript)
signalwire.prefabs.faq_bot.FAQBotAgent.on_summary: port-only: prefab override of AgentBase#on_summary; reflection-surfaced in Ruby, inherited-signature in Python (also surfaced by typescript)
signalwire.prefabs.receptionist.ReceptionistAgent.on_summary: port-only: prefab no-op override of AgentBase#on_summary (mirrors Python's `pass`); reflection-surfaced in Ruby, inherited-signature in Python
signalwire.prefabs.survey.SurveyAgent.on_summary: port-only: prefab override of AgentBase#on_summary; reflection-surfaced in Ruby, inherited-signature in Python (also surfaced by typescript)
signalwire.utils.Utils: port-only: SignalWire::Utils module namespace (Python uses `signalwire.utils` package directly with no class wrapper)
signalwire.utils.Utils.is_serverless_mode: port-only: module-level helper for detecting serverless (Lambda/CGI) mode; Python keeps the equivalent in core/logging_config.get_execution_mode
signalwire.core.logging_config.LoggingConfig: port-only: SignalWire::Core::LoggingConfig wrapper class (Python keeps loggers as module-level helpers)
signalwire.core.logging_config.LoggingConfig.get_execution_mode: port-only: classmethod mirror of Python's module-level `get_execution_mode` helper
signalwire.rest._pagination.PaginatedIterator.data_key: port-only: Ruby attr_reader for the JSON-list key inside paginated responses (Python: instance attribute)
signalwire.rest._pagination.PaginatedIterator.done: port-only: Ruby flag indicating no more pages (Python: internal boolean)
signalwire.rest._pagination.PaginatedIterator.each: port-only: Ruby Enumerable interface (Python uses `__iter__` filtered out by surface enumeration)
signalwire.rest._pagination.PaginatedIterator.http: port-only: Ruby attr_reader for the underlying HttpClient (Python: instance attribute)
signalwire.rest._pagination.PaginatedIterator.index: port-only: Ruby attr_reader for the current item index inside the page (Python: instance attribute)
signalwire.rest._pagination.PaginatedIterator.items: port-only: Ruby attr_reader for the current page's items array (Python: instance attribute)
signalwire.rest._pagination.PaginatedIterator.next_item: port-only: Ruby cursor-advance helper (Python uses `__next__` filtered out by surface enumeration)
signalwire.rest._pagination.PaginatedIterator.params: port-only: Ruby attr_reader for the request params hash (Python: instance attribute)
signalwire.rest._pagination.PaginatedIterator.path: port-only: Ruby attr_reader for the request path (Python: instance attribute)
signalwire.rest.client.RestClient.http: port-only: Ruby attr_reader for the underlying HttpClient (Python: client uses internal `_http` private attribute)
signalwire.pom.pom.PromptObjectModel.debug: port-only: Ruby attr_accessor for the debug flag (Python: instance attribute on PromptObjectModel)
signalwire.pom.pom.PromptObjectModel.sections: port-only: Ruby attr_accessor for the underlying sections list (Python: `self.sections` instance attribute)
signalwire.pom.pom.PromptObjectModel.to_h: port-only: Ruby idiom replacing Python's to_dict (which is itself listed in PORT_OMISSIONS.md)
signalwire.pom.pom.Section.body: port-only: Ruby attr_accessor for body text (Python: instance attribute)
signalwire.pom.pom.Section.bullets: port-only: Ruby attr_accessor for bullets list (Python: instance attribute)
signalwire.pom.pom.Section.numbered: port-only: Ruby attr_accessor for the numbered flag (Python: instance attribute)
signalwire.pom.pom.Section.numbered_bullets: port-only: Ruby attr_accessor for the numberedBullets flag (Python: instance attribute, snake_case in Ruby; renders to camelCase JSON/YAML)
signalwire.pom.pom.Section.subsections: port-only: Ruby attr_accessor for the subsections list (Python: instance attribute)
signalwire.pom.pom.Section.title: port-only: Ruby attr_accessor for the section title (Python: instance attribute)
signalwire.pom.pom.Section.to_h: port-only: Ruby idiom replacing Python's to_dict (which is itself listed in PORT_OMISSIONS.md)
signalwire.core.agent_base.AgentBase.signing_key: ruby_idiom_port_only: AgentBase exposes a `signing_key` accessor; Python keeps it as private state (no public getter). Public access in Ruby for testability and middleware mounting.

# --- Idiomatic Ruby accessor aliases (RUBY_ERGONOMICS_MIGRATION.md prototype) ---
# Additive aliases over the Python-named get_/set_ originals (which stay for
# audit parity). Prototype scope: AgentBase prompt accessors only.
signalwire.core.agent_base.AgentBase.prompt: ruby-idiom alias (reader) over get_prompt; native `agent.prompt` accessor, Python name retained for parity
signalwire.core.agent_base.AgentBase.prompt_text: ruby-idiom alias (reader+writer) over get_raw_prompt/set_prompt_text; native `agent.prompt_text` / `agent.prompt_text=`
signalwire.core.agent_base.AgentBase.post_prompt: ruby-idiom alias (reader+writer) over get_post_prompt/set_post_prompt; native `agent.post_prompt` / `agent.post_prompt=`
signalwire.swml.service.Service.all_functions: ruby-idiom reader alias over get_all_functions
signalwire.swml.service.Service.basic_auth_credentials_with_source: ruby-idiom reader alias over get_basic_auth_credentials_with_source
signalwire.swml.service.Service.function?: ruby-idiom `?`-predicate alias over has_function

# --- Closed-set named constants (Ruby's idiom-track answer to the other
# ports' enums; IDIOM_PASS_JOURNAL.md §2/§4). Ruby already validated these
# closed sets inline; these add named constants as the single source of
# truth and rewire the existing validators to reference them (the named set
# and the validated set are literally the same frozen object — no drift).
# Mirrors SignalWire::Relay's constants idiom (flat NAME='value' + frozen
# ALL). Pure-additive: record_call/tap/add_skill still accept bare strings.
# The constant values ARE the wire strings, so they don't change any
# signature or wire behavior and add no enumerated surface EXCEPT the one
# convenience predicate below.
#
# Constant sets added (one line per set, per the idiom-pass task):
#   - SignalWire::Swaig::RecordFormat {wav,mp3,mp4} — record_call format; validator references RecordFormat::ALL.
#   - SignalWire::Swaig::RecordDirection {speak,listen,both} — record_call direction; validator references RecordDirection::ALL (DISTINCT from TapDirection — 'listen', not 'hear').
#   - SignalWire::Swaig::TapDirection {speak,hear,both} — tap direction; validator references TapDirection::ALL (DISTINCT from RecordDirection — 'hear', not 'listen').
#   - SignalWire::Swaig::Codec {PCMU,PCMA} — SWAIG tap codec; validator references Codec::ALL (the 2-value tap set only, NOT the RELAY device-codec superset).
#   - SignalWire::Skills::SkillName (18 built-ins) — the skill registry set; SkillRegistry.builtin_skill_names now derives from SkillName::ALL, so the named set IS what AgentBase#add_skill validates against.
#
# Only one of these registers as enumerated signature surface (the module-
# constant groups carry no methods the griffe/reflection enumerator emits);
# the SkillName convenience predicate does, hence this single excused line:
signalwire.skills.skill_name.builtin: port-only: SignalWire::Skills::SkillName.builtin?(name) — named-constant single-source-of-truth predicate for the built-in skill set (Ruby's idiom-track equivalent of the other ports' SkillName enum membership check); add_skill still accepts the bare string, the set stays open for custom skills
# Layer B (surface enumerator) renders the same predicate as a class-with-
# method instead of a module free function, and keeps the `?` suffix. Both
# spellings below describe the identical SkillName.builtin? helper above.
signalwire.skills.skill_name.SkillName: port-only: Ruby SignalWire::Skills::SkillName named-constant module (the built-in skill set; Python uses bare strings — see the constant-groups note above)
signalwire.skills.skill_name.SkillName.builtin?: port-only: Layer B class-form spelling of the SkillName.builtin?(name) membership predicate (same method as the Layer A `signalwire.skills.skill_name.builtin` entry above)

# --- Tier-2 idiom FLAGSHIP: SignalWire::Swaig::ParameterSchema ---
# (porting-sdk/IDIOM_PASS_JOURNAL.md §4 "Tier 2 flagship": the typed SWAIG
# tool-parameter builder.) Defining a SWAIG tool's `parameters` in Python
# (and the existing Ruby path) means hand-writing a JSON-Schema blob as
# nested Hashes. This adds an IDIOMATIC RUBY block DSL that constructs the
# EXACT SAME wire output — the Hash it returns is BYTE-IDENTICAL to the
# normalised hand-written `parameters` (a `{ 'type' => 'object',
# 'properties' => {...}, 'required' => [...] }` object, `required` omitted
# when empty). It is a typed CONVENIENCE over the same wire shape, NOT a new
# format: the untyped Hash path stays fully supported, so this is purely
# ADDITIVE (no Python equivalent → port-only). Property kinds: string,
# number, integer, boolean, enum (closed set), array (of a kind), object
# (nested). The `enum` kind INTEGRATES the Tier-1 frozen constants
# (RecordFormat/RecordDirection/TapDirection/Codec ::ALL) — pass any ALL
# array as the closed set and it lands as schema `enum:[...]` (single source
# of truth; the constant's value IS the wire string). Proven byte-identical
# across every kind + an enum property, and end-to-end through a real
# define_tool → render_swml → invoke, in tests/parameter_schema_test.rb (no
# mocks). Both audit layers (signatures + surface) enumerate the new public
# class; every public method is excused below.
#
# Layer A (signatures enumerator) symbols:
signalwire.swaig.parameter_schema.ParameterSchema.array: port-only: ParameterSchema DSL verb — declare an `array` property (with `of:` element kind) in the typed SWAIG-param builder (no Python equivalent; same wire shape as a hand-written array property)
signalwire.swaig.parameter_schema.ParameterSchema.boolean: port-only: ParameterSchema DSL verb — declare a `boolean` property in the typed SWAIG-param builder
signalwire.swaig.parameter_schema.ParameterSchema.build: port-only: ParameterSchema.build { ... } — class-level block-DSL entrypoint returning the JSON-Schema parameters Hash
signalwire.swaig.parameter_schema.ParameterSchema.enum: port-only: ParameterSchema DSL verb — declare a closed-set (`enum`) property; integrates the Tier-1 RecordFormat/RecordDirection/TapDirection/Codec ::ALL frozen sets
signalwire.swaig.parameter_schema.ParameterSchema.integer: port-only: ParameterSchema DSL verb — declare an `integer` property
signalwire.swaig.parameter_schema.ParameterSchema.number: port-only: ParameterSchema DSL verb — declare a `number` property
signalwire.swaig.parameter_schema.ParameterSchema.object: port-only: ParameterSchema DSL verb — declare a nested `object` property (recursive block)
signalwire.swaig.parameter_schema.ParameterSchema.require: port-only: singular fluent alias of `required` for single-property chains in the typed SWAIG-param builder
signalwire.swaig.parameter_schema.ParameterSchema.required: port-only: ParameterSchema DSL verb — mark properties required (folds into the top-level `required` list, same shape define_tool(required:) produces)
signalwire.swaig.parameter_schema.ParameterSchema.string: port-only: ParameterSchema DSL verb — declare a `string` property
signalwire.swaig.parameter_schema.ParameterSchema.to_json: port-only: JSON serialization of the built parameters Hash (Ruby idiom; same wire shape)
#
# Layer B (surface enumerator) additionally renders the class node, the
# constructor, and the `to_h`/`to_hash` renderers — same builder:
signalwire.swaig.parameter_schema.ParameterSchema: port-only: the typed SWAIG tool-parameter builder class itself (Tier-2 idiom flagship; Python defines parameters as a bare nested-Hash blob, no equivalent class)
signalwire.swaig.parameter_schema.ParameterSchema.__init__: port-only: Ruby `ParameterSchema.new` constructor (initialises empty properties/required; for fluent non-block use)
signalwire.swaig.parameter_schema.ParameterSchema.to_h: port-only: render the built JSON-Schema parameters Hash (byte-identical to the normalised hand-written `parameters`); Ruby idiom replacing Python's hand-written Hash literal
signalwire.swaig.parameter_schema.ParameterSchema.to_hash: port-only: Ruby implicit-conversion alias of `to_h` on the typed SWAIG-param builder

# --- Item H/I surface-align additions (2026-07) ---
signalwire.agents.bedrock.BedrockAgent.to_s: port-only: Ruby to_s companion to inspect (Python's __repr__ maps to inspect; to_s is the Ruby string-conversion idiom)
signalwire.core.agent.prompt.manager.PromptManager.pom: port-only: Ruby attr_reader exposing the backing PromptObjectModel (Python holds it as a private attribute)
signalwire.core.auth_error.AuthError: port-only: Ruby AuthError exception raised by AuthHandler.rack_dependency when auth is required-and-unauthed (Python raises framework HTTPException; Ruby ships a native error)
signalwire.core.auth_error.AuthError.__init__: port-only: Ruby AuthError exception raised by AuthHandler.rack_dependency when auth is required-and-unauthed (Python raises framework HTTPException; Ruby ships a native error)
signalwire.core.auth_error.AuthError.response: port-only: Ruby AuthError exception raised by AuthHandler.rack_dependency when auth is required-and-unauthed (Python raises framework HTTPException; Ruby ships a native error)
signalwire.core.auth_handler.AuthHandler.auth_methods: port-only: Ruby attr_reader on AuthHandler exposing constructor state (Python keeps it as an instance attribute)
signalwire.core.auth_handler.AuthHandler.security_config: port-only: Ruby attr_reader on AuthHandler exposing constructor state (Python keeps it as an instance attribute)
signalwire.core.pom_builder.PomBuilder.pom: port-only: Ruby attr_reader exposing the backing PromptObjectModel (Python holds it as a private attribute)
signalwire.core.security_config.SecurityConfig.allowed_hosts: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.basic_auth_password: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.basic_auth_user: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.cors_origins: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.domain: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.hsts_max_age: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.max_request_size: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.rate_limit: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.request_timeout: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.ssl_cert_path: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.ssl_enabled: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.ssl_key_path: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.ssl_verify_mode: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.security_config.SecurityConfig.use_hsts: port-only: Ruby attr_reader exposing a SecurityConfig field (Python reads the field via getter methods / attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.description: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.extra_swaig_fields: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.fillers: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.handler: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.is_external: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.is_typed_handler: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.name: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.parameters: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.required: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.secure: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.wait_file: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.wait_file_loops: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swaig_function.SWAIGFunction.webhook_url: port-only: Ruby attr_reader exposing a SWAIGFunction field (Python accesses these as instance attributes; readable attrs are the Ruby idiom)
signalwire.core.swml_builder.SWMLBuilder.service: port-only: Ruby attr_reader exposing the SWMLBuilder's backing service (Python holds it as a private attribute)
signalwire.core.swml_schema.Schema: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_schema.Schema.__init__: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_schema.Schema.valid_verb?: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_schema.Schema.verb_count: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_schema.Schema.verb_names: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_schema.Schema.verbs: port-only: Ruby SWML::Schema helper class (the schema-introspection surface Python keeps inside SchemaUtils; Ruby exposes it as a small dedicated class)
signalwire.core.swml_service.SWMLService.all_functions: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.basic_auth_credentials_with_source: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.config_file: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.define_tool: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.define_tools: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.document: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.execute_verb: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.function?: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.get_all_functions: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.get_basic_auth_credentials_with_source: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.get_full_url: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.get_function: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.handle_additional_route: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.has_function: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.host: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.list_tool_names: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.name: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.on_function_call: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.on_swml_request: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.port: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.rack_app: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.register_swaig_function: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.remove_function: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.render: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.render_main_swml: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.render_pretty: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.reset: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.route: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.schema_path: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.schema_utils: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.schema_validation: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.swaig_pre_dispatch: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.validate_basic_auth: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.core.swml_service.SWMLService.verb_registry: port-only: Ruby's SWML::Service hosts the tool/web mixin surface + attr_readers + Rack helpers directly on the base service (Python splits these across ToolMixin/WebMixin/AgentBase; folded onto the base is the Ruby idiom)
signalwire.web.web_service.WebService.allowed_extensions: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.blocked_extensions: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.directories: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.enable_cors: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.enable_directory_browsing: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.file_allowed?: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.max_file_size: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.port: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.web.web_service.WebService.security: port-only: Ruby attr_reader / predicate on WebService (Python holds these as instance attributes; readable attrs + `?`-predicates are the Ruby idiom)
signalwire.core.auth_handler.AuthHandler.rack_middleware: port-only: Ruby native Rack middleware — the framework-native equivalent of Python's flask_decorator (which Ruby also exposes under that name as an alias); ships the Rack replacement per L18
signalwire.core.auth_handler.AuthHandler.rack_dependency: port-only: Ruby native Rack dependency — the framework-native equivalent of Python's get_fastapi_dependency (also exposed under that name as an alias); ships the Rack replacement per L18
