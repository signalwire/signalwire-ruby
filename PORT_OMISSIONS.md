# PORT_OMISSIONS.md

Symbols present in `python_surface.json` (the Python SDK reference at
`/home/devuser/src/porting-sdk/python_surface.json`) that this Ruby port
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

signalwire.agent_server.AgentServer.register_global_routing_callback: not_yet_implemented: global routing callback on AgentServer
signalwire.agents.bedrock.BedrockAgent: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.__init__: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.__repr__: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_inference_params: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_llm_model: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_llm_temperature: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_post_prompt_llm_params: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_prompt_llm_params: Bedrock agent omitted - not core to the port
signalwire.agents.bedrock.BedrockAgent.set_voice: Bedrock agent omitted - not core to the port
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
signalwire.core.agent.prompt.manager.PromptManager: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.__init__: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.define_contexts: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.get_contexts: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.get_post_prompt: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.get_prompt: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.get_raw_prompt: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_section: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_subsection: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_to_section: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.prompt_has_section: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.set_post_prompt: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.set_prompt_pom: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.prompt.manager.PromptManager.set_prompt_text: prompt management inlined in SignalWire::AgentBase; no standalone PromptManager
signalwire.core.agent.tools.decorator.ToolDecorator: Ruby uses keyword-arg registration, not decorators; ToolDecorator has no equivalent
signalwire.core.agent.tools.decorator.ToolDecorator.create_class_decorator: Ruby uses keyword-arg registration, not decorators; ToolDecorator has no equivalent
signalwire.core.agent.tools.decorator.ToolDecorator.create_instance_decorator: Ruby uses keyword-arg registration, not decorators; ToolDecorator has no equivalent
signalwire.core.agent.tools.registry.ToolRegistry: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.__init__: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.define_tool: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.get_all_functions: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.get_function: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.has_function: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.register_class_decorated_tools: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.register_swaig_function: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.registry.ToolRegistry.remove_function: tool registry inlined in SignalWire::AgentBase; no standalone ToolRegistry
signalwire.core.agent.tools.type_inference.create_typed_handler_wrapper: type inference for decorator-based tool registration; not applicable to Ruby
signalwire.core.agent.tools.type_inference.infer_schema: type inference for decorator-based tool registration; not applicable to Ruby
signalwire.core.agent_base.AgentBase.auto_map_sip_usernames: not_yet_implemented: auto-map SIP usernames helper
signalwire.core.agent_base.AgentBase.get_full_url: Ruby uses attr_reader accessors (host/port/route) plus manual_set_proxy_url; no get_full_url helper
signalwire.core.agent_base.AgentBase.get_name: Ruby exposes SignalWire::AgentBase#name (attr_reader) instead
signalwire.core.auth_handler.AuthHandler: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.__init__: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.flask_decorator: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.get_auth_info: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.get_fastapi_dependency: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.verify_api_key: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.verify_basic_auth: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.auth_handler.AuthHandler.verify_bearer_token: Ruby basic-auth in SignalWire::AgentBase directly (rack middleware); no flask/fastapi decorator class
signalwire.core.config_loader.ConfigLoader: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.__init__: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.find_config_file: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.get: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.get_config: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.get_config_file: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.get_section: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.has_config: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.merge_with_env: config loader not ported - Ruby uses ENV directly
signalwire.core.config_loader.ConfigLoader.substitute_vars: config loader not ported - Ruby uses ENV directly
signalwire.core.contexts.Context.to_dict: Ruby convention: SignalWire::Contexts::Context#to_h replaces to_dict
signalwire.core.contexts.ContextBuilder.to_dict: Ruby convention: to_h replaces to_dict
signalwire.core.contexts.ContextBuilder.validate: Ruby convention: SignalWire::Contexts::ContextBuilder#validate! (bang) replaces validate
signalwire.core.contexts.GatherInfo.to_dict: Ruby convention: to_h replaces to_dict
signalwire.core.contexts.GatherQuestion.to_dict: Ruby convention: to_h replaces to_dict
signalwire.core.contexts.Step.to_dict: Ruby convention: to_h replaces to_dict
signalwire.core.contexts.create_simple_context: Ruby exposes SignalWire::Contexts.create_simple_context (module function) - emitted under signalwire.contexts.Contexts in port surface
signalwire.core.data_map.create_expression_tool: Ruby exposes SignalWire::DataMap.create_expression_tool as a class method
signalwire.core.data_map.create_simple_api_tool: Ruby exposes SignalWire::DataMap.create_simple_api_tool as a class method
signalwire.core.function_result.FunctionResult.to_dict: Ruby convention: SignalWire::Swaig::FunctionResult#to_h replaces to_dict
signalwire.core.logging_config.configure_logging: SignalWire::Logging exposes the same surface without a separate config class
signalwire.core.logging_config.get_execution_mode: SignalWire::Logging exposes the same surface without a separate config class
signalwire.core.logging_config.get_logger: SignalWire::Logging exposes the same surface without a separate config class
signalwire.core.logging_config.reset_logging_configuration: SignalWire::Logging exposes the same surface without a separate config class
signalwire.core.logging_config.strip_control_chars: SignalWire::Logging exposes the same surface without a separate config class
signalwire.core.mixins.ai_config_mixin.AIConfigMixin: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_function_include: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_hint: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_hints: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_internal_filler: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_language: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_mcp_server: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_pattern_hint: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_pronunciation: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.enable_debug_events: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.enable_mcp_server: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_function_includes: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_global_data: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_internal_fillers: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_languages: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_native_functions: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_param: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_params: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_post_prompt_llm_params: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_prompt_llm_params: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.set_pronunciations: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.update_global_data: mixin class collapsed into SignalWire::AgentBase (Ruby single-inheritance + modules); methods present on AgentBase
signalwire.core.mixins.auth_mixin.AuthMixin: mixin class collapsed into SignalWire::AgentBase; get_basic_auth_credentials lives on AgentBase
signalwire.core.mixins.auth_mixin.AuthMixin.get_basic_auth_credentials: mixin class collapsed into SignalWire::AgentBase; get_basic_auth_credentials lives on AgentBase
signalwire.core.mixins.auth_mixin.AuthMixin.validate_basic_auth: mixin class collapsed into SignalWire::AgentBase; get_basic_auth_credentials lives on AgentBase
signalwire.core.mixins.mcp_server_mixin.MCPServerMixin: mixin class collapsed into SignalWire::AgentBase (add_mcp_server/enable_mcp_server)
signalwire.core.mixins.prompt_mixin.PromptMixin: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.contexts: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.define_contexts: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.get_post_prompt: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.get_prompt: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_section: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_subsection: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_to_section: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_has_section: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.reset_contexts: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.set_post_prompt: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.set_prompt_pom: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.prompt_mixin.PromptMixin.set_prompt_text: mixin class collapsed into SignalWire::AgentBase prompt methods
signalwire.core.mixins.serverless_mixin.ServerlessMixin: serverless handling in SignalWire::Serverless::LambdaHandler, not a mixin
signalwire.core.mixins.serverless_mixin.ServerlessMixin.handle_serverless_request: serverless handling in SignalWire::Serverless::LambdaHandler, not a mixin
signalwire.core.mixins.skill_mixin.SkillMixin: mixin class collapsed into SignalWire::AgentBase skill methods
signalwire.core.mixins.skill_mixin.SkillMixin.add_skill: mixin class collapsed into SignalWire::AgentBase skill methods
signalwire.core.mixins.skill_mixin.SkillMixin.has_skill: mixin class collapsed into SignalWire::AgentBase skill methods
signalwire.core.mixins.skill_mixin.SkillMixin.list_skills: mixin class collapsed into SignalWire::AgentBase skill methods
signalwire.core.mixins.skill_mixin.SkillMixin.remove_skill: mixin class collapsed into SignalWire::AgentBase skill methods
signalwire.core.mixins.state_mixin.StateMixin: mixin class collapsed into SignalWire::AgentBase (validate_tool_token via SessionManager)
signalwire.core.mixins.state_mixin.StateMixin.validate_tool_token: mixin class collapsed into SignalWire::AgentBase (validate_tool_token via SessionManager)
signalwire.core.mixins.tool_mixin.ToolMixin: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.tool_mixin.ToolMixin.define_tool: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.tool_mixin.ToolMixin.define_tools: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.tool_mixin.ToolMixin.on_function_call: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.tool_mixin.ToolMixin.register_swaig_function: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.tool_mixin.ToolMixin.tool: mixin class collapsed into SignalWire::AgentBase tool methods
signalwire.core.mixins.web_mixin.WebMixin: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.as_router: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.enable_debug_routes: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.get_app: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.manual_set_proxy_url: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.on_request: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.on_swml_request: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.register_routing_callback: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.run: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.serve: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.set_dynamic_config_callback: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.mixins.web_mixin.WebMixin.setup_graceful_shutdown: mixin class collapsed into SignalWire::AgentBase HTTP methods
signalwire.core.pom_builder.PomBuilder: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.__init__: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.add_section: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.add_subsection: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.add_to_section: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.from_sections: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.get_section: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.has_section: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.render_markdown: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.render_xml: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.to_dict: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.pom_builder.PomBuilder.to_json: POM builder collapsed into SignalWire::AgentBase prompt methods
signalwire.core.security.session_manager.SessionManager.create_tool_token: Ruby SignalWire::Security::SessionManager#create_token covers this - different name
signalwire.core.security.session_manager.SessionManager.generate_token: Ruby SignalWire::Security::SessionManager#create_token covers this - different name
signalwire.core.security.session_manager.SessionManager.validate_tool_token: Ruby SignalWire::Security::SessionManager#validate_token covers this - different name
signalwire.core.security_config.SecurityConfig: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.__init__: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.get_basic_auth: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.get_cors_config: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.get_security_headers: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.get_ssl_context_kwargs: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.get_url_scheme: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.load_from_env: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.log_config: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.should_allow_host: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security_config.SecurityConfig.validate_ssl_config: security-config class not ported - settings live in SignalWire::AgentBase and middleware
signalwire.core.security.webhook_middleware.make_webhook_validation_dependency: FastAPI-only idiom — Ruby ships SignalWire::Security::WebhookMiddleware (Rack) instead; same WebhookValidator core
signalwire.core.skill_base.SkillBase.define_tool: Ruby SignalWire::Skills::SkillBase#register_tools does this via SignalWire::AgentBase#define_tool
signalwire.core.skill_base.SkillBase.get_instance_key: Ruby uses SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.core.skill_base.SkillBase.get_skill_data: not_yet_implemented: skill-data share helpers
signalwire.core.skill_base.SkillBase.update_skill_data: not_yet_implemented: skill-data share helpers
signalwire.core.skill_base.SkillBase.validate_env_vars: not_yet_implemented: env-var validation helper
signalwire.core.skill_base.SkillBase.validate_packages: not_yet_implemented: package validation (Python-specific; gem ecosystem differs)
signalwire.core.skill_manager.SkillManager.get_skill: Ruby SignalWire::Skills::SkillManager#get covers this - different name
signalwire.core.skill_manager.SkillManager.has_skill: Ruby SignalWire::Skills::SkillManager#loaded? covers this - different name
signalwire.core.skill_manager.SkillManager.list_loaded_skills: Ruby SignalWire::Skills::SkillManager#loaded_keys covers this - different name
signalwire.core.skill_manager.SkillManager.load_skill: Ruby SignalWire::Skills::SkillManager#load covers this - different name
signalwire.core.skill_manager.SkillManager.unload_skill: Ruby SignalWire::Skills::SkillManager#unload covers this - different name
signalwire.core.swaig_function.SWAIGFunction: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swaig_function.SWAIGFunction.__call__: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swaig_function.SWAIGFunction.__init__: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swaig_function.SWAIGFunction.execute: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swaig_function.SWAIGFunction.to_swaig: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swaig_function.SWAIGFunction.validate_args: SWAIG functions registered as hashes in Ruby (SignalWire::AgentBase#register_swaig_function); no SWAIGFunction wrapper class
signalwire.core.swml_builder.SWMLBuilder: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.__getattr__: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.__init__: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.add_section: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.ai: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.answer: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.build: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.hangup: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.play: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.render: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.reset: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_builder.SWMLBuilder.say: consolidated into SignalWire::SWML::Document - render/add_verb/add_section live there
signalwire.core.swml_handler.AIVerbHandler: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.AIVerbHandler.build_config: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.AIVerbHandler.get_verb_name: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.AIVerbHandler.validate_config: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.SWMLVerbHandler: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.SWMLVerbHandler.build_config: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.SWMLVerbHandler.get_verb_name: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.SWMLVerbHandler.validate_config: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.VerbHandlerRegistry: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.VerbHandlerRegistry.__init__: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.VerbHandlerRegistry.get_handler: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.VerbHandlerRegistry.has_handler: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_handler.VerbHandlerRegistry.register_handler: SWML verb handlers are schema-driven in SignalWire::SWML::Schema/Service; no per-verb handler classes
signalwire.core.swml_renderer.SwmlRenderer: consolidated into SignalWire::SWML::Document#render and SignalWire::Swaig::FunctionResult
signalwire.core.swml_renderer.SwmlRenderer.render_function_response_swml: consolidated into SignalWire::SWML::Document#render and SignalWire::Swaig::FunctionResult
signalwire.core.swml_renderer.SwmlRenderer.render_swml: consolidated into SignalWire::SWML::Document#render and SignalWire::Swaig::FunctionResult
signalwire.core.swml_service.SWMLService: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.__getattr__: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.__init__: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.add_section: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.add_verb: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.add_verb_to_section: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.as_router: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.extract_sip_username: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.full_validation_enabled: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.get_basic_auth_credentials: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.get_document: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.manual_set_proxy_url: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.on_request: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.register_routing_callback: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.register_verb_handler: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.render_document: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.reset_document: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.serve: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.core.swml_service.SWMLService.stop: consolidated into SignalWire::SWML::Service - see port_surface.json signalwire.swml.service
signalwire.list_skills: not_yet_implemented: top-level list_skills helper; use SignalWire::Skills::SkillRegistry#list_skills
signalwire.livewire.Agent: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.llm_node: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.on_enter: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.on_exit: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.on_user_turn_completed: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.session: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.stt_node: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.tts_node: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.update_instructions: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Agent.update_tools: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentHandoff: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentHandoff.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentServer: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentServer.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentServer.rtc_session: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.generate_reply: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.history: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.interrupt: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.say: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.start: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.update_agent: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.AgentSession.userdata: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.ChatContext: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.ChatContext.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.ChatContext.append: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceLLM: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceLLM.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceSTT: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceSTT.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceTTS: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.InferenceTTS.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobContext: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobContext.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobContext.connect: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobContext.wait_for_participant: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobProcess: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.JobProcess.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.Room: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.RunContext: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.RunContext.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.RunContext.userdata: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.StopResponse: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.ToolError: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.function_tool: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.CartesiaTTS: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.CartesiaTTS.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.DeepgramSTT: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.DeepgramSTT.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.ElevenLabsTTS: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.ElevenLabsTTS.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.OpenAILLM: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.OpenAILLM.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.SileroVAD: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.SileroVAD.__init__: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.plugins.SileroVAD.load: LiveKit compatibility shim - to be added once core port is stable
signalwire.livewire.run_app: LiveKit compatibility shim - to be added once core port is stable
signalwire.mcp_gateway.gateway_service.MCPGateway: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.gateway_service.MCPGateway.__init__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.gateway_service.MCPGateway.run: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.gateway_service.MCPGateway.shutdown: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.gateway_service.main: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.__init__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.call_method: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.call_tool: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.get_tools: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.start: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPClient.stop: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.__init__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.create_client: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.get_service: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.get_service_tools: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.list_services: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.shutdown: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPManager.validate_services: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPService: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPService.__hash__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.mcp_manager.MCPService.__post_init__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.Session: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.Session.is_alive: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.Session.is_expired: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.Session.touch: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.__init__: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.close_session: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.create_session: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.get_service_session_count: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.get_session: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.list_sessions: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.mcp_gateway.session_manager.SessionManager.shutdown: MCP gateway service is a separate daemon; Ruby agents consume MCP via SignalWire::AgentBase#add_mcp_server
signalwire.pom.pom.PromptObjectModel.to_dict: Ruby convention: to_h replaces to_dict (see SignalWire::POM::PromptObjectModel#to_h)
signalwire.pom.pom.Section.to_dict: Ruby convention: to_h replaces to_dict (see SignalWire::POM::Section#to_h)
signalwire.pom.pom_tool.detect_file_format: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.load_pom: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.main: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.pom.pom_tool.render_pom: pom_tool is a Python CLI utility; Ruby ships the POM library only
signalwire.prefabs.concierge.ConciergeAgent.check_availability: not_yet_implemented: concierge check_availability tool
signalwire.prefabs.concierge.ConciergeAgent.get_directions: not_yet_implemented: concierge get_directions tool
signalwire.prefabs.concierge.ConciergeAgent.on_summary: not_yet_implemented: concierge on_summary hook
signalwire.prefabs.faq_bot.FAQBotAgent.on_summary: not_yet_implemented: FAQ-bot on_summary hook
signalwire.prefabs.faq_bot.FAQBotAgent.search_faqs: Ruby uses SignalWire::Prefabs::FaqBot#handle_search - different name
signalwire.prefabs.info_gatherer.InfoGathererAgent.on_swml_request: not_yet_implemented: InfoGatherer on_swml_request hook
signalwire.prefabs.info_gatherer.InfoGathererAgent.set_question_callback: not_yet_implemented: question callback setter
signalwire.prefabs.info_gatherer.InfoGathererAgent.start_questions: Ruby uses SignalWire::Prefabs::InfoGatherer#handle_start - different name
signalwire.prefabs.info_gatherer.InfoGathererAgent.submit_answer: Ruby uses SignalWire::Prefabs::InfoGatherer#handle_submit - different name
signalwire.prefabs.receptionist.ReceptionistAgent.on_summary: not_yet_implemented: receptionist on_summary hook
signalwire.prefabs.survey.SurveyAgent.log_response: not_yet_implemented: survey log_response hook
signalwire.prefabs.survey.SurveyAgent.on_summary: not_yet_implemented: survey on_summary hook
signalwire.prefabs.survey.SurveyAgent.validate_response: not_yet_implemented: survey validate_response hook
signalwire.relay.call.Action.is_done: Ruby uses is_done? and done? (idiomatic Ruby predicates)
signalwire.relay.call.Call.__repr__: Ruby uses inspect/to_s idioms
signalwire.relay.call.Call.pass_: Ruby uses SignalWire::Relay::Call#pass_call - pass is a Ruby keyword
signalwire.relay.call.Call.tap: Ruby uses SignalWire::Relay::Call#tap_audio - tap is a Ruby core method
signalwire.relay.call.Call.wait_for: not_yet_implemented: Call#wait_for predicate wait helper
signalwire.relay.client.RelayClient.__aenter__: Python async-context-manager protocol; Ruby uses block-style Client.new { |c| ... }
signalwire.relay.client.RelayClient.__aexit__: Python async-context-manager protocol; Ruby uses block-style Client.new { |c| ... }
signalwire.relay.client.RelayClient.__del__: Ruby finalizers differ; no explicit __del__ equivalent
signalwire.relay.client.RelayClient.connect: Ruby auto-connects on Client.new (constructor); no separate connect method
signalwire.relay.client.RelayClient.disconnect: Ruby SignalWire::Relay::Client#stop covers this - different name
signalwire.relay.client.RelayClient.relay_protocol: Ruby SignalWire::Relay::Client#protocol covers this - different name
signalwire.relay.message.Message.__repr__: Ruby uses inspect/to_s idioms
signalwire.relay.message.Message.is_done: Ruby uses is_done? and done? predicates
signalwire.relay.message.Message.on: Ruby uses SignalWire::Relay::Message#on_event and #on_completed - different name
signalwire.rest._base.CrudWithAddresses: not_yet_implemented: CrudWithAddresses mixin (list_addresses helper)
signalwire.rest._base.CrudWithAddresses.list_addresses: not_yet_implemented: list_addresses helper
signalwire.rest._pagination.PaginatedIterator.__iter__: not_yet_implemented: paginated iterator
signalwire.rest._pagination.PaginatedIterator.__next__: not_yet_implemented: paginated iterator
signalwire.rest.call_handler.PhoneCallHandler: Ruby SignalWire::REST::PhoneCallHandler is an empty marker (matches Python - no methods on either)
signalwire.rest.namespaces.calling.CallingNamespace.end: Ruby uses SignalWire::REST::Namespaces::CallingNamespace#end_call - end is a Ruby keyword
signalwire.run_agent: Ruby agents use agent.serve directly; no top-level run_agent convenience
signalwire.search.document_processor.DocumentProcessor: search subsystem omitted - vector search/indexing not ported
signalwire.search.document_processor.DocumentProcessor.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.document_processor.DocumentProcessor.create_chunks: search subsystem omitted - vector search/indexing not ported
signalwire.search.index_builder.IndexBuilder: search subsystem omitted - vector search/indexing not ported
signalwire.search.index_builder.IndexBuilder.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.index_builder.IndexBuilder.build_index: search subsystem omitted - vector search/indexing not ported
signalwire.search.index_builder.IndexBuilder.build_index_from_sources: search subsystem omitted - vector search/indexing not ported
signalwire.search.index_builder.IndexBuilder.validate_index: search subsystem omitted - vector search/indexing not ported
signalwire.search.migration.SearchIndexMigrator: search subsystem omitted - vector search/indexing not ported
signalwire.search.migration.SearchIndexMigrator.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.migration.SearchIndexMigrator.get_index_info: search subsystem omitted - vector search/indexing not ported
signalwire.search.migration.SearchIndexMigrator.migrate_pgvector_to_sqlite: search subsystem omitted - vector search/indexing not ported
signalwire.search.migration.SearchIndexMigrator.migrate_sqlite_to_pgvector: search subsystem omitted - vector search/indexing not ported
signalwire.search.models.resolve_model_alias: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.close: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.create_schema: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.delete_collection: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.get_stats: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.list_collections: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorBackend.store_chunks: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend.close: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend.fetch_candidates: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend.get_stats: search subsystem omitted - vector search/indexing not ported
signalwire.search.pgvector_backend.PgVectorSearchBackend.search: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.detect_language: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.ensure_nltk_resources: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.get_synonyms: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.get_wordnet_pos: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.load_spacy_model: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.preprocess_document_content: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.preprocess_query: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.remove_duplicate_words: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.set_global_model: search subsystem omitted - vector search/indexing not ported
signalwire.search.query_processor.vectorize_query: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_engine.SearchEngine: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_engine.SearchEngine.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_engine.SearchEngine.get_stats: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_engine.SearchEngine.search: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_service.SearchService: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_service.SearchService.__init__: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_service.SearchService.search_direct: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_service.SearchService.start: search subsystem omitted - vector search/indexing not ported
signalwire.search.search_service.SearchService.stop: search subsystem omitted - vector search/indexing not ported
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.__init__: Ruby built-in skills use the SignalWire::Skills::SkillBase constructor
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.get_tools: Ruby built-in skills register tools in setup, not get_tools
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.datasphere.skill.DataSphereSkill.cleanup: not_yet_implemented: per-skill cleanup hook
signalwire.skills.datasphere.skill.DataSphereSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.datasphere.skill.DataSphereSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.datetime.skill.DateTimeSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.datetime.skill.DateTimeSkill.get_parameter_schema: not_yet_implemented: per-skill get_parameter_schema override
signalwire.skills.datetime.skill.DateTimeSkill.setup: not_yet_implemented: per-skill explicit setup hook (Ruby uses register_tools)
signalwire.skills.google_maps.skill.GoogleMapsClient: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.__init__: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.compute_route: internal HTTP client not exposed in Ruby port
signalwire.skills.google_maps.skill.GoogleMapsClient.validate_address: internal HTTP client not exposed in Ruby port
signalwire.skills.info_gatherer.skill.InfoGathererSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.joke.skill.JokeSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.math.skill.MathSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.math.skill.MathSkill.get_parameter_schema: not_yet_implemented: per-skill get_parameter_schema override
signalwire.skills.math.skill.MathSkill.setup: not_yet_implemented: per-skill explicit setup hook
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.cleanup: search subsystem omitted
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_global_data: search subsystem omitted
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_prompt_sections: search subsystem omitted
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.__init__: Ruby built-in skills use SignalWire::Skills::SkillBase constructor
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.get_tools: Ruby built-in skills register tools in setup
signalwire.skills.registry.SkillRegistry.__init__: Ruby SignalWire::Skills::SkillRegistry is a singleton module; no constructor
signalwire.skills.registry.SkillRegistry.discover_skills: not_yet_implemented: filesystem discover_skills (Ruby ships built-ins explicitly via register_builtins!)
signalwire.skills.registry.SkillRegistry.get_skill_class: Ruby SignalWire::Skills::SkillRegistry#get_factory returns class-or-factory - different name
signalwire.skills.registry.SkillRegistry.list_all_skill_sources: not_yet_implemented: external skill source listing
signalwire.skills.spider.skill.SpiderSkill.__init__: Ruby built-in skills use SignalWire::Skills::SkillBase constructor
signalwire.skills.spider.skill.SpiderSkill.cleanup: not_yet_implemented: per-skill cleanup hook
signalwire.skills.spider.skill.SpiderSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
signalwire.skills.weather_api.skill.WeatherApiSkill.__init__: Ruby built-in skills use SignalWire::Skills::SkillBase constructor
signalwire.skills.weather_api.skill.WeatherApiSkill.get_tools: Ruby built-in skills register tools in setup
signalwire.skills.web_search.skill.GoogleSearchScraper: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.__init__: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_html_content: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_reddit_content: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.extract_text_from_url: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.is_reddit_url: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_and_scrape: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_and_scrape_best: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.GoogleSearchScraper.search_google: part of search subsystem; scraper class omitted
signalwire.skills.web_search.skill.WebSearchSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.web_search.skill.WebSearchSkill.get_instance_key: Ruby SignalWire::Skills::SkillBase#instance_key (attr_reader)
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
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.get_hints: not_yet_implemented: per-skill get_hints override
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.search_wiki: not_yet_implemented: extracted search_wiki helper
signalwire.start_agent: Ruby agents use agent.serve directly; no top-level start_agent convenience
signalwire.utils.schema_utils.SchemaUtils: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.__init__: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.full_validation_available: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.generate_method_body: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.generate_method_signature: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.get_all_verb_names: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.get_verb_parameters: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.get_verb_properties: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.get_verb_required_properties: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.load_schema: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.validate_document: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.utils.schema_utils.SchemaUtils.validate_verb: SchemaUtils consolidated into SignalWire::SWML::Schema - see port_surface.json signalwire.swml.schema
signalwire.web.web_service.WebService: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
signalwire.web.web_service.WebService.__init__: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
signalwire.web.web_service.WebService.add_directory: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
signalwire.web.web_service.WebService.remove_directory: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
signalwire.web.web_service.WebService.start: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
signalwire.web.web_service.WebService.stop: standalone WebService not ported; static files served from SignalWire::Server::AgentServer
