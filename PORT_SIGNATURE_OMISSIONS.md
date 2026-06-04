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

signalwire.agent_server.AgentServer.__init__: kwargs-idiom — Ruby keyword constructor (`host:`, `port:`, `log_level:`) ≡ Python positional with default
signalwire.agent_server.AgentServer.run: kwargs-idiom — Ruby `run(event:, context:, host:, port:)` ≡ Python `run(event=None, context=None, host=None, port=None)`
signalwire.agent_server.AgentServer.register: kwargs-idiom — Ruby `register(agent, route: nil)` ≡ Python `register(agent, route=None)`
signalwire.core.agent_base.AgentBase.__init__: kwargs-idiom — Ruby keyword constructor (21 keyword params) ≡ Python positional with default
signalwire.core.swml_service.SWMLService.__init__: kwargs-idiom — Ruby keyword constructor (`name:`, `route:`, `host:`, `port:`, `basic_auth:`, `schema_path:`, `config_file:`, `schema_validation:`) ≡ Python positional with default
signalwire.core.contexts.Step.add_gather_question: kwargs-idiom — Ruby keyword args (`key:`, `question:`, `type:`, `confirm:`, `prompt:`, `functions:`) ≡ Python positional with default
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_section: kwargs-idiom — Ruby `(title, body=nil, bullets:, numbered:, numbered_bullets:, subsections:)` ≡ Python positional with default
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_to_section: kwargs-idiom — Ruby `(title, body_arg=nil, body:, bullet:, bullets:)` ≡ Python positional with default
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_section: kwargs-idiom — Ruby `(title, body=nil, bullets:, numbered:, numbered_bullets:, subsections:)` ≡ Python positional with default
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_to_section: kwargs-idiom — Ruby `(title, body_arg=nil, body:, bullet:, bullets:)` ≡ Python positional with default
signalwire.core.agent.tools.registry.ToolRegistry.define_tool: kwargs-idiom — Ruby keyword args (`name:`, `description:`, `parameters:`, ..., `swaig_fields:`) ≡ Python positional + `**swaig_fields`
signalwire.core.mixins.tool_mixin.ToolMixin.define_tool: kwargs-idiom — Ruby keyword args (`name:`, `description:`, `parameters:`, ..., `swaig_fields:`) ≡ Python positional + `**swaig_fields`
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_language: kwargs-idiom — Ruby positional `(name, code, voice, ...)` plus `speech_fillers:`, `function_fillers:`, `engine:`, `model:` keyword args ≡ Python positional with default
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_pattern_hint: kwargs-idiom — Ruby splats positional args plus optional keyword `ignore_case:`; ≡ Python `(hint, pattern, replace, ignore_case=False)`
signalwire.core.mixins.web_mixin.WebMixin.run: kwargs-idiom — Ruby `run(event:, context:, force_mode:, host:, port:)` ≡ Python `run(event=None, context=None, force_mode=None, host=None, port=None)`
signalwire.core.mixins.web_mixin.WebMixin.serve: kwargs-idiom — Ruby `serve(host:, port:)` ≡ Python `serve(host=None, port=None)`
signalwire.core.mixins.web_mixin.WebMixin.on_swml_request: kwargs-idiom — Ruby third positional optional + `request:` keyword ≡ Python `on_swml_request(request_data, callback_path, request)`
signalwire.core.swml_service.SWMLService.serve: kwargs-idiom — Ruby `serve(host:, port:, ssl_cert:, ssl_key:, ssl_enabled:, domain:)` ≡ Python positional with default
signalwire.core.swml_service.SWMLService.get_basic_auth_credentials: kwargs-idiom — Ruby `get_basic_auth_credentials(include_source:)` ≡ Python `get_basic_auth_credentials(include_source=False)`
signalwire.core.mixins.auth_mixin.AuthMixin.get_basic_auth_credentials: kwargs-idiom — Ruby keyword `include_source:` ≡ Python positional with default
signalwire.relay.client.RelayClient.__init__: kwargs-idiom — Ruby keyword constructor (`project:`, `token:`, `jwt_token:`, `host:`, `contexts:`, `max_active_calls:`) ≡ Python positional with default
signalwire.agent_server.AgentServer.setup_sip_routing: kwargs-idiom — Ruby keyword args (`route:`, `auto_map:`) ≡ Python positional with default
signalwire.core.agent.prompt.manager.PromptManager.prompt_add_subsection: kwargs-idiom — Ruby `bullets:` keyword ≡ Python positional with default
signalwire.core.agent_base.AgentBase.enable_sip_routing: kwargs-idiom — Ruby keyword args (`auto_map:`, `path:`) ≡ Python positional with default
signalwire.core.agent_base.AgentBase.on_debug_event: kwargs-idiom — Ruby `handler:` keyword ≡ Python positional with default
signalwire.core.contexts.GatherInfo.__init__: kwargs-idiom — Ruby `(output_key:, completion_action:, prompt:)` ≡ Python positional with default
signalwire.core.contexts.GatherInfo.add_question: kwargs-idiom — Ruby `(key:, question:, ...)` keyword args ≡ Python positional
signalwire.core.contexts.GatherQuestion.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.core.contexts.Step.set_gather_info: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.data_map.DataMap.expression: kwargs-idiom — Ruby `nomatch_output:` keyword ≡ Python positional with default
signalwire.core.data_map.DataMap.parameter: kwargs-idiom — Ruby `(required:, enum:)` keyword ≡ Python positional with default
signalwire.core.data_map.DataMap.webhook: kwargs-idiom — Ruby keyword args (`headers:`, `form_param:`, etc.) ≡ Python positional with default
signalwire.core.function_result.FunctionResult.__init__: kwargs-idiom — Ruby `post_process:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.connect: kwargs-idiom — Ruby keyword `final:`, `from_addr:` ≡ Python positional with default
signalwire.core.function_result.FunctionResult.create_payment_prompt: kwargs-idiom — Ruby keyword `card_type:`, `error_type:` ≡ Python positional with default
signalwire.core.function_result.FunctionResult.execute_rpc: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.execute_swml: kwargs-idiom — Ruby `transfer:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.join_conference: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.pay: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.play_background_file: kwargs-idiom — Ruby `wait:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.record_call: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.rpc_ai_message: kwargs-idiom — Ruby `role:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.rpc_dial: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.send_sms: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.stop_record_call: kwargs-idiom — Ruby `control_id:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.stop_tap: kwargs-idiom — Ruby `control_id:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.switch_context: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.swml_transfer: kwargs-idiom — Ruby `final:` keyword ≡ Python positional with default
signalwire.core.function_result.FunctionResult.tap: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.function_result.FunctionResult.wait_for_user: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_function_include: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.mixins.ai_config_mixin.AIConfigMixin.add_pronunciation: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.core.mixins.prompt_mixin.PromptMixin.prompt_add_subsection: kwargs-idiom — Ruby `bullets:` keyword ≡ Python positional with default
signalwire.core.security.session_manager.SessionManager.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.core.swml_service.SWMLService.register_routing_callback: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.prefabs.concierge.ConciergeAgent.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.prefabs.faq_bot.FAQBotAgent.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.prefabs.info_gatherer.InfoGathererAgent.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.relay.call.Action.wait: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.relay.call.Call.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.relay.call.Call.hangup: kwargs-idiom — Ruby `reason:` keyword ≡ Python positional with default
signalwire.relay.call.Call.live_transcribe: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.call.Call.on: kwargs-idiom — Ruby keyword `event:` ≡ Python positional with default
signalwire.relay.call.Call.record: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.call.Call.transfer: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.call.Call.wait_for_answered: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.relay.call.Call.wait_for_ended: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.relay.call.Call.wait_for_ending: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.relay.call.Call.wait_for_ringing: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.relay.call.RecordAction.pause: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.client.RelayClient.on_call: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.client.RelayClient.on_message: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.relay.event.RelayEvent.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.relay.message.Message.wait: kwargs-idiom — Ruby `timeout:` keyword ≡ Python positional with default
signalwire.rest._base.HttpClient.post: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.client.RestClient.__init__: kwargs-idiom — Ruby keyword constructor ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_ai_agent: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_call_flow: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_cxml_application: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_cxml_webhook: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_relay_application: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_relay_topic: kwargs-idiom — Ruby keyword args ≡ Python positional with default
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_swml_webhook: kwargs-idiom — Ruby keyword args ≡ Python positional with default

# from_payload classmethod — Ruby static method has no explicit cls receiver

signalwire.relay.event.CallReceiveEvent.from_payload: classmethod-cls — Ruby `def self.from_payload(payload)` ≡ Python `@classmethod from_payload(cls, payload)`
signalwire.relay.event.CallStateEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.CallingErrorEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.CollectEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.ConferenceEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.ConnectEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.DenoiseEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.DetectEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.DialEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.EchoEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.FaxEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.HoldEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.MessageReceiveEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.MessageStateEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.PayEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.PlayEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.QueueEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.RecordEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.ReferEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.RelayEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.SendDigitsEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.StreamEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.TapEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver
signalwire.relay.event.TranscribeEvent.from_payload: classmethod-cls — Ruby static factory method has no explicit `cls` receiver

# Ruby **kwargs collapse — Call methods forward a hash to RELAY (matches TS port BACKLOG)

signalwire.relay.call.Call.ai: kwargs-collapse — Ruby `def ai(**kwargs)` forwards hash to RELAY (TS port has same BACKLOG entry)
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
signalwire.pom.pom.PromptObjectModel.to_dict: Ruby convention — to_h replaces to_dict (see SignalWire::POM::PromptObjectModel#to_h in PORT_OMISSIONS.md)
signalwire.pom.pom.PromptObjectModel.to_json: Ruby JSON convention — `to_json(*_args)` accepts the optional state argument that Ruby's JSON.generate forwards
signalwire.pom.pom.Section.render_markdown: Ruby keyword-arg idiom — `level:` and `section_number:` are keyword in Ruby, positional with default in Python
signalwire.pom.pom.Section.render_xml: Ruby keyword-arg idiom — `indent:` and `section_number:` are keyword in Ruby, positional with default in Python
signalwire.pom.pom.Section.to_dict: Ruby convention — to_h replaces to_dict (see SignalWire::POM::Section#to_h in PORT_OMISSIONS.md)

# Cross-port parity methods — Ruby keyword-arg idiom (positional-with-default in Python)

signalwire.agent_server.AgentServer.register_global_routing_callback: kwargs-idiom — Ruby `path:` keyword ≡ Python positional
signalwire.prefabs.info_gatherer.InfoGathererAgent.on_swml_request: kwargs-idiom — Ruby third param `request:` is keyword ≡ Python positional (matches WebMixin.on_swml_request)
signalwire.relay.call.Call.wait_for: kwargs-idiom — Ruby `predicate:`/`timeout:` keywords ≡ Python positional with default
