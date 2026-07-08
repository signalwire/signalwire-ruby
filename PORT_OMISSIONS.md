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
- **Bedrock** (9 symbols under `signalwire.agents.bedrock.*`): omitted.
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
- **Ruby-keyword conflicts** (`Call.pass_`, `Call.tap`,
  `CallingNamespace.end`, `Message.on`, `Action.is_done`,
  `Message.is_done`, various `to_dict`/`validate` methods): Ruby provides
  equivalents under different names (see matching PORT_ADDITIONS.md
  entries).
- **Renamed symbols on SessionManager, SkillManager, SkillRegistry,
  RelayClient**: Ruby uses shortened idiomatic names (see PORT_ADDITIONS
  entries for the Ruby counterparts).
- **Per-skill `get_hints`/`get_parameter_schema`/`setup`/`cleanup` hooks**
  (~20 symbols): not yet implemented on individual Ruby skills; Ruby
  built-ins register tools inline via `register_tools`.

Everything explicitly marked `not_yet_implemented:` is a deliberate
deferral — track those for future work.

# Omitted symbols

signalwire.cli.build_search.console_entry_point: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.build_search.main: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.build_search.migrate_command: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.build_search.remote_command: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.build_search.search_command: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.build_search.validate_command: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.agent_loader.discover_agents_in_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.agent_loader.discover_services_in_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.agent_loader.load_agent_from_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.agent_loader.load_service_from_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.CustomArgumentParser: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.CustomArgumentParser.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.CustomArgumentParser.error: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.CustomArgumentParser.parse_args: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.CustomArgumentParser.print_usage: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.argparse_helpers.parse_function_arguments: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.dynamic_config.apply_dynamic_config: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.ServiceCapture: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.ServiceCapture.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.ServiceCapture.capture: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.discover_agents_in_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.load_agent_from_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.load_and_simulate_service: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.core.service_loader.simulate_request_to_service: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.Colors: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.DokkuProjectGenerator: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.DokkuProjectGenerator.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.DokkuProjectGenerator.generate: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.cmd_config: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.cmd_deploy: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.cmd_init: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.cmd_logs: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.cmd_scale: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.generate_password: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.main: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.print_error: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.print_header: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.print_step: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.print_success: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.print_warning: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.prompt: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.dokku.prompt_yes_no: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.execution.datamap_exec.execute_datamap_function: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.execution.datamap_exec.simple_template_expand: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.execution.webhook_exec.execute_external_webhook_function: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.Colors: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.ProjectGenerator: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.ProjectGenerator.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.ProjectGenerator.generate: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.generate_password: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_agent_template: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_app_template: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_env_credentials: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_readme_template: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_test_template: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.get_web_index_template: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.main: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.mask_token: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.print_error: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.print_step: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.print_success: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.print_warning: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.prompt: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.prompt_multiselect: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.prompt_select: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.prompt_yes_no: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.run_interactive: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.init_project.run_quick: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.output.output_formatter.display_agent_tools: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.output.output_formatter.format_result: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.output.swml_dump.handle_dump_swml: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.output.swml_dump.setup_output_suppression: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.adapt_for_call_type: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_comprehensive_post_data: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_fake_node_id: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_fake_sip_from: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_fake_sip_to: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_fake_swml_post_data: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_fake_uuid: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_generation.generate_minimal_post_data: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_overrides.apply_convenience_mappings: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_overrides.apply_overrides: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_overrides.parse_value: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.data_overrides.set_nested_value: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.__contains__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.__getitem__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.get: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.items: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.keys: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockHeaders.values: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.__contains__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.__getitem__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.get: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.items: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.keys: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockQueryParams.values: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockRequest: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockRequest.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockRequest.body: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockRequest.client: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockRequest.json: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockURL: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockURL.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.MockURL.__str__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator.__init__: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator.activate: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator.add_override: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator.deactivate: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.ServerlessSimulator.get_current_env: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.create_mock_request: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.simulation.mock_env.load_env_file: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.swaig_test_wrapper.main: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.test_swaig.console_entry_point: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.test_swaig.main: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.test_swaig.print_help_examples: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.test_swaig.print_help_platforms: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.AgentInfo: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.CallData: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.DataMapConfig: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.FunctionInfo: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.PostData: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.cli.types.VarsData: Ruby SDK does not ship a CLI; Python CLI is a separate tool
signalwire.core.agent.tools.decorator.ToolDecorator: impossible: Python @tool class/instance decorator API relies on the decorator protocol; Ruby registers tools via define_tool(name:, description:, parameters:, &handler) directly (TS + PHP both omit this as impossible)
signalwire.core.agent.tools.decorator.ToolDecorator.create_class_decorator: impossible: Python @tool decorator-protocol method; Ruby registers tools via define_tool directly (TS + PHP both omit as impossible)
signalwire.core.agent.tools.decorator.ToolDecorator.create_instance_decorator: impossible: Python @tool decorator-protocol method; Ruby registers tools via define_tool directly (TS + PHP both omit as impossible)
signalwire.core.agent.tools.registry.ToolRegistry.register_class_decorated_tools: impossible: discovers @tool-decorated class methods via the Python decorator protocol; Ruby has no method-decorator feature to discover, so there is nothing to register (TS + PHP both omit as impossible)
signalwire.core.mixins.mcp_server_mixin.MCPServerMixin: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.core.mixins.tool_mixin.ToolMixin.tool: impossible: Python @tool class/instance decorator relies on the decorator protocol; Ruby has no method-decorator feature — tools register via define_tool(name:, description:, parameters:, &handler) directly (TS + PHP both omit this as impossible)
signalwire.core.security.webhook_middleware.make_webhook_validation_dependency: impossible: framework-bound factory returning a FastAPI dependency; Ruby ships the equivalent as the SignalWire::Security::WebhookMiddleware Rack middleware (a PORT_ADDITION) — the FastAPI-dependency FORM has no Rack analog (TS/PHP ship native middleware likewise)
signalwire.livewire.Agent: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.llm_node: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.on_enter: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.on_exit: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.on_user_turn_completed: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.session: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.stt_node: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.tts_node: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.update_instructions: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Agent.update_tools: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentHandoff: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentHandoff.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentServer: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentServer.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentServer.rtc_session: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.generate_reply: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.history: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.interrupt: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.say: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.start: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.update_agent: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.AgentSession.userdata: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.ChatContext: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.ChatContext.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.ChatContext.append: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceLLM: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceLLM.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceSTT: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceSTT.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceTTS: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.InferenceTTS.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobContext: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobContext.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobContext.connect: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobContext.wait_for_participant: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobProcess: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.JobProcess.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.Room: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.RunContext: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.RunContext.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.RunContext.userdata: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.StopResponse: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.ToolError: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.function_tool: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.CartesiaTTS: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.CartesiaTTS.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.DeepgramSTT: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.DeepgramSTT.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.ElevenLabsTTS: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.ElevenLabsTTS.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.OpenAILLM: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.OpenAILLM.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.SileroVAD: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.SileroVAD.__init__: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.plugins.SileroVAD.load: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.livewire.run_app: approved: livewire is LiveKit-agents-compat; LiveKit ships no Ruby agents SDK (only Python + Node/TS), so it is not ported to Ruby — invented surface otherwise (user, 2026-07)
signalwire.mcp_gateway.gateway_service.MCPGateway: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.gateway_service.MCPGateway.__init__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.gateway_service.MCPGateway.run: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.gateway_service.MCPGateway.shutdown: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.gateway_service.main: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.__init__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.call_method: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.call_tool: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.get_tools: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.start: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPClient.stop: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.__init__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.create_client: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.get_service: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.get_service_tools: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.list_services: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.shutdown: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPManager.validate_services: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPService: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPService.__hash__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.mcp_manager.MCPService.__post_init__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.Session: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.Session.is_alive: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.Session.is_expired: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.Session.touch: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.__init__: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.close_session: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.create_session: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.get_service_session_count: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.get_session: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.list_sessions: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.mcp_gateway.session_manager.SessionManager.shutdown: approved: Python-only MCP gateway subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.pom.pom_tool.detect_file_format: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.load_pom: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.main: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.render_pom: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.relay.client.RelayClient.__aenter__: impossible: Python async-context-manager protocol dunder; Ruby uses block form / explicit connect+disconnect — no __aenter__ equivalent (TS/PHP omit identically)
signalwire.relay.client.RelayClient.__aexit__: impossible: Python async-context-manager protocol dunder; Ruby uses block form / explicit connect+disconnect (TS/PHP omit identically)
signalwire.relay.client.RelayClient.__del__: impossible: Python finalizer dunder; Ruby has no deterministic __del__ finalizer protocol (TS/PHP omit identically)
signalwire.relay.client.RelayClient.relay_protocol: impossible: Python property exposing the internal relay-protocol object; Ruby keeps the protocol object private (no public accessor) — internal plumbing, not public surface (TS/PHP omit identically)
signalwire.relay.message.Message.__repr__: impossible: Python object-repr dunder; Ruby provides the equivalent via the shared MessageSerialization module's inspect/to_s, but the __repr__ NAME itself has no standalone Ruby form (mirrors Call.__repr__; TS/PHP omit identically)
signalwire.rest.call_handler.PhoneCallHandler: Ruby SignalWire::REST::PhoneCallHandler is an empty marker (matches Python - no methods on either)
signalwire.rest.namespaces.calling.CallingNamespace.end: Ruby uses SignalWire::REST::Namespaces::CallingNamespace#end_call - end is a Ruby keyword
signalwire.search.document_processor.DocumentProcessor: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.document_processor.DocumentProcessor.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.document_processor.DocumentProcessor.create_chunks: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.index_builder.IndexBuilder: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.index_builder.IndexBuilder.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.index_builder.IndexBuilder.build_index: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.index_builder.IndexBuilder.build_index_from_sources: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.index_builder.IndexBuilder.validate_index: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.migration.SearchIndexMigrator: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.migration.SearchIndexMigrator.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.migration.SearchIndexMigrator.get_index_info: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.migration.SearchIndexMigrator.migrate_pgvector_to_sqlite: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.migration.SearchIndexMigrator.migrate_sqlite_to_pgvector: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.models.resolve_model_alias: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.close: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.create_schema: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.delete_collection: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.get_stats: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.list_collections: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorBackend.store_chunks: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend.close: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend.fetch_candidates: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend.get_stats: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.pgvector_backend.PgVectorSearchBackend.search: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.detect_language: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.ensure_nltk_resources: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.get_synonyms: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.get_wordnet_pos: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.load_spacy_model: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.preprocess_document_content: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.preprocess_query: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.remove_duplicate_words: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.set_global_model: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.query_processor.vectorize_query: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_engine.SearchEngine: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_engine.SearchEngine.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_engine.SearchEngine.get_stats: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_engine.SearchEngine.search: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_service.SearchService: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_service.SearchService.__init__: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_service.SearchService.search_direct: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_service.SearchService.start: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.search.search_service.SearchService.stop: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.google_maps.skill.GoogleMapsClient: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.__init__: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.compute_route: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.validate_address: internal HTTP client not exposed in Ruby port
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.cleanup: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_global_data: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_prompt_sections: approved: Python-only RAG/vector-search subsystem, not ported to any SDK — user, 2026-07 pass (§I.1)
signalwire.skills.registry.SkillRegistry.get_skill_class: Ruby SignalWire::Skills::SkillRegistry#get_factory returns class-or-factory - different name
signalwire.skills.web_search.skill.GoogleSearchScraper: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.__init__: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_html_content: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_reddit_content: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_text_from_url: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.is_reddit_url: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_and_scrape: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_and_scrape_best: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_google: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill_improved.GoogleSearchScraper: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.GoogleSearchScraper.__init__: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.GoogleSearchScraper.extract_text_from_url: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.GoogleSearchScraper.search_and_scrape: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.GoogleSearchScraper.search_and_scrape_best: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.GoogleSearchScraper.search_google: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.get_global_data: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.get_hints: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.web_search.skill_improved.WebSearchSkill.get_parameter_schema: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.get_prompt_sections: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.register_tools: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_improved.WebSearchSkill.setup: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.GoogleSearchScraper: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.GoogleSearchScraper.__init__: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.GoogleSearchScraper.extract_text_from_url: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.GoogleSearchScraper.search_and_scrape: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.GoogleSearchScraper.search_google: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.get_global_data: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.get_hints: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.web_search.skill_original.WebSearchSkill.get_parameter_schema: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.get_prompt_sections: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.register_tools: search subsystem variant (Python has three parallel skill files); not ported
signalwire.skills.web_search.skill_original.WebSearchSkill.setup: search subsystem variant (Python has three parallel skill files); not ported
