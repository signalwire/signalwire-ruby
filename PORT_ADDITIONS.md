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

# Added symbols

signalwire.agent_server.AgentServer.host: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.agent_server.AgentServer.port: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.agent_server.AgentServer.rack_app: port-only: Ruby attr_reader exposing constructor state (idiomatic Ruby; Python uses property decorators or public fields)
signalwire.contexts.Contexts: port-only: SignalWire::Contexts module with create_simple_context helper
signalwire.contexts.Contexts.create_simple_context: port-only: Ruby counterpart of Python signalwire.core.contexts.create_simple_context (omitted)
signalwire.core.agent_base.AgentBase.add_function_include: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
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
signalwire.core.agent_base.AgentBase.define_contexts: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.define_tool: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.define_tools: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_debug_events: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_debug_routes: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.enable_mcp_server: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.extract_sip_username: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.extract_sip_username_from_request: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.get_basic_auth_credentials: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.get_prompt: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.has_skill?: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.host: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.list_skills: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.list_tool_names: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.logger: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.manual_set_proxy_url: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.name: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
signalwire.core.agent_base.AgentBase.on_function_call: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
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
signalwire.core.agent_base.AgentBase.update_global_data: port-only: mixin method collapsed onto SignalWire::AgentBase (Ruby single-inheritance + modules model replaces Python multiple inheritance)
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
signalwire.core.skill_base.SkillBase.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.get_param: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.params: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.required_env_vars: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_base.SkillBase.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.core.skill_base.SkillBase.version: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.core.skill_manager.SkillManager.clear: port-only: SkillManager#clear - no direct Python equivalent (Python unloads individually)
signalwire.core.skill_manager.SkillManager.get: port-only: SkillManager#get - Ruby shortened name; see PORT_OMISSIONS for get_skill
signalwire.core.skill_manager.SkillManager.load: port-only: SkillManager#load - Ruby shortened name; see PORT_OMISSIONS for load_skill
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
signalwire.prefabs.faq_bot.FAQBotAgent.handle_search: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.faq_bot.FAQBotAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.faq_bot.FAQBotAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.global_data: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.handle_start: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.info_gatherer.InfoGathererAgent.handle_submit: port-only: Ruby prefab handler method (Ruby naming differs from Python)
signalwire.prefabs.info_gatherer.InfoGathererAgent.name: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.prompt_sections: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.questions: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.route: port-only: Ruby attr_reader on prefab (configuration state)
signalwire.prefabs.info_gatherer.InfoGathererAgent.tools: port-only: Ruby attr_reader on prefab (configuration state)
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
signalwire.relay.event.CollectEvent.result_data: port-only: Ruby attr_reader on relay event (Python exposes same data as dataclass field)
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
signalwire.rest._base.CrudResource.update_method: port-only: per-resource override hook for PATCH vs PUT (default update verb)
signalwire.rest._base.HttpClient.base_url: port-only: attr_reader for base_url
signalwire.rest._base.SignalWireRestError.body: port-only: attr_reader for error body
signalwire.rest._base.SignalWireRestError.method_name: port-only: attr_reader for originating HTTP method
signalwire.rest._base.SignalWireRestError.status_code: port-only: attr_reader for HTTP status
signalwire.rest._base.SignalWireRestError.url: port-only: attr_reader for failed URL
signalwire.rest.client.RestClient.addresses: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.calling: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.chat: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.compat: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.datasphere: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.fabric: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.imported_numbers: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.logs: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.lookup: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.mfa: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.number_groups: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.phone_numbers: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.project: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.pubsub: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.queues: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.recordings: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.registry: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.short_codes: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.sip_profile: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.verified_callers: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.client.RestClient.video: port-only: attr_reader for REST namespace (Python exposes via @property)
signalwire.rest.namespaces.calling.CallingNamespace.end_call: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.accounts: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.applications: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.calls: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.conferences: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.faxes: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.laml_bins: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.messages: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.phone_numbers: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.queues: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.recordings: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.tokens: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.compat.CompatNamespace.transcriptions: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.datasphere.DatasphereNamespace.documents: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.addresses: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.ai_agents: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.call_flows: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.conference_rooms: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.cxml_applications: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.cxml_scripts: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.cxml_webhooks: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.freeswitch_connectors: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.relay_applications: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.resources: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.sip_endpoints: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.sip_gateways: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.subscribers: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.swml_scripts: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.swml_webhooks: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricNamespace.tokens: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.fabric.FabricResource.list_addresses: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.logs.LogsNamespace.conferences: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.logs.LogsNamespace.fax: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.logs.LogsNamespace.messages: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.logs.LogsNamespace.voice: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.project.ProjectNamespace.tokens: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.registry.RegistryNamespace.brands: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.registry.RegistryNamespace.campaigns: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.registry.RegistryNamespace.numbers: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.registry.RegistryNamespace.orders: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.conference_tokens: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.conferences: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.room_recordings: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.room_sessions: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.room_tokens: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.rooms: port-only: attr_reader for sub-resource (Python uses @property)
signalwire.rest.namespaces.video.VideoNamespace.streams: port-only: attr_reader for sub-resource (Python uses @property)
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
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.description: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.instance_key: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.name: port-only: Ruby attr_reader on skill (matches Python __init__ stored attribute)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.supports_multiple_instances?: port-only: Ruby predicate method (? suffix)
signalwire.skills.registry.SkillRegistry.get_factory: port-only: returns class-or-factory (see PORT_OMISSIONS for Python get_skill_class)
signalwire.skills.registry.SkillRegistry.register: port-only: explicit registry registration (Ruby ships built-ins via register_builtins!)
signalwire.skills.registry.SkillRegistry.register_builtins!: port-only: Ruby bang-convention to seed the registry with built-in skills
signalwire.skills.registry.SkillRegistry.registered?: port-only: Ruby predicate - is_registered check
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
signalwire.swml.service.Service.execute_verb: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.get_basic_auth_credentials: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.get_full_url: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.host: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.method_missing: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.name: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.on_request: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.port: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.rack_app: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.register_routing_callback: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.render: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.render_pretty: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.route: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.serve: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
signalwire.swml.service.Service.stop: port-only: consolidated Ruby SWML class (see signalwire.swml.document/schema/service class-level rationale)
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
