# PORT_SIGNATURE_OMISSIONS.md

Documented signature divergences between this Ruby port and the Python
reference. Names-only divergences live in PORT_OMISSIONS.md /
PORT_ADDITIONS.md and are inherited automatically.

Excused divergences:

1. **Idiom-level**: Ruby is dynamically typed; v1 emits ``any`` for
   every parameter type. Structural drift (param name, count, kind) is
   what's caught. Typed drift requires .rbs annotations or YARD metadata
   and is deferred to a follow-up sweep.

2. **Port maintenance backlog**: real param/arity divergences that
   should be reduced as the Ruby port catches up to Python.


## Idiom: Ruby constructors (initialize)

signalwire.agent_base.AgentBase.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.agent_server.AgentServer.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.contexts.context.Context.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.contexts.context_builder.ContextBuilder.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.contexts.gather_info.GatherInfo.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.contexts.gather_question.GatherQuestion.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.contexts.step.Step.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.agent_base.AgentBase.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.contexts.Context.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.contexts.ContextBuilder.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.contexts.GatherInfo.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.contexts.GatherQuestion.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.contexts.Step.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.data_map.DataMap.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.function_result.FunctionResult.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.security.session_manager.SessionManager.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.skill_base.SkillBase.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.core.skill_manager.SkillManager.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.data_map.DataMap.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.prefabs.concierge.ConciergeAgent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.prefabs.faq_bot.FAQBotAgent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.prefabs.info_gatherer.InfoGathererAgent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.prefabs.receptionist.ReceptionistAgent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.prefabs.survey.SurveyAgent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.action.Action.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.ai_action.AIAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.AIAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.Action.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.Call.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.CollectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.DetectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.FaxAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.PayAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.PlayAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.RecordAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.StandaloneCollectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.StreamAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.TapAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call.TranscribeAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call_receive_event.CallReceiveEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.call_state_event.CallStateEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.calling_error_event.CallingErrorEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.client.RelayClient.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.client.RelayError.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.collect_action.CollectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.collect_event.CollectEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.conference_event.ConferenceEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.connect_event.ConnectEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.denoise_event.DenoiseEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.detect_action.DetectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.detect_event.DetectEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.dial_event.DialEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.echo_event.EchoEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.fax_action.FaxAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.fax_event.FaxEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.hold_event.HoldEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.message.Message.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.message_receive_event.MessageReceiveEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.message_state_event.MessageStateEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.pay_action.PayAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.pay_event.PayEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.play_action.PlayAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.play_event.PlayEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.queue_event.QueueEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.record_action.RecordAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.record_event.RecordEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.refer_event.ReferEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.relay_error.RelayError.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.relay_event.RelayEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.send_digits_event.SendDigitsEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.standalone_collect_action.StandaloneCollectAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.stream_action.StreamAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.stream_event.StreamEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.tap_action.TapAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.tap_event.TapEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.transcribe_action.TranscribeAction.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.relay.transcribe_event.TranscribeEvent.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.base_resource.BaseResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.client.RestClient.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.http_client.HttpClient.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.addresses.AddressesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.addresses_resource.AddressesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.calling.CallingNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.calling_namespace.CallingNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.chat.ChatResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.chat_resource.ChatResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat.CompatAccounts.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat.CompatNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat.CompatPhoneNumbers.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat_accounts.CompatAccounts.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat_namespace.CompatNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.datasphere.DatasphereDocuments.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.datasphere.DatasphereNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.datasphere_documents.DatasphereDocuments.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.datasphere_namespace.DatasphereNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.fabric.FabricNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.fabric.FabricTokens.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.fabric_tokens.FabricTokens.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.imported_numbers.ImportedNumbersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.imported_numbers_resource.ImportedNumbersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.logs.LogsNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.logs_namespace.LogsNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.lookup.LookupResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.lookup_resource.LookupResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.mfa.MfaResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.mfa_resource.MfaResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.number_groups.NumberGroupsResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.number_groups_resource.NumberGroupsResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.project.ProjectNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.project.ProjectTokens.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.project_namespace.ProjectNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.project_tokens.ProjectTokens.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.pub_sub_resource.PubSubResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.pubsub.PubSubResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.queues.QueuesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.queues_resource.QueuesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.recordings.RecordingsResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.recordings_resource.RecordingsResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.registry.RegistryNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.registry_namespace.RegistryNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.short_codes.ShortCodesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.short_codes_resource.ShortCodesResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.sip_profile.SipProfileResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.sip_profile_resource.SipProfileResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.verified_callers.VerifiedCallersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.verified_callers_resource.VerifiedCallersResource.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.video.VideoNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.namespaces.video_namespace.VideoNamespace.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.rest_client.RestClient.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.rest.signal_wire_rest_error.SignalWireRestError.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.DocumentProcessor.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.IndexBuilder.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.SearchEngine.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.SearchService.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.search_service.SearchRequest.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.search_service.SearchResponse.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.search.search_service.SearchResult.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.skills.skill_base.SkillBase.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.skills.skill_manager.SkillManager.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands
signalwire.swaig.function_result.FunctionResult.__init__: Ruby constructor (initialize) signature follows Ruby conventions; types are dynamically inferred (any) until .rbs lands

## Backlog: real signature divergences (1185 symbols)

signalwire.agent_base.AgentBase.add_answer_verb: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_function_include: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_hint: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_hints: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_internal_filler: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_language: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_mcp_server: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_pattern_hint: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_post_ai_verb: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_post_answer_verb: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_pre_answer_verb: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_pronunciation: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_skill: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.add_swaig_query_params: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.as_rack_app: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.clear_post_ai_verbs: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.clear_post_answer_verbs: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.clear_pre_answer_verbs: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.clear_swaig_query_params: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.contexts: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.define_contexts: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.define_tool: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.define_tools: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.enable_debug_events: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.enable_debug_routes: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.enable_mcp_server: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.enable_sip_routing: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.extract_sip_username: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.extract_sip_username_from_request: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.get_basic_auth_credentials: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.get_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.handle_additional_route: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.has_skill: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.list_skills: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.list_tool_names: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.logger: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.manual_set_proxy_url: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.on_debug_event: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.on_function_call: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.on_summary: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.prompt_add_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.prompt_add_subsection: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.prompt_add_to_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.prompt_has_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.rack_app: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.register_sip_username: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.register_swaig_function: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.remove_skill: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.render_swml: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.reset_contexts: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.run: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.serve: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_dynamic_config_callback: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_function_includes: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_global_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_internal_fillers: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_languages: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_native_functions: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_param: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_params: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_post_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_post_prompt_llm_params: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_post_prompt_url: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_prompt_llm_params: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_prompt_pom: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_prompt_text: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_pronunciations: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.set_web_hook_url: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_base.AgentBase.update_global_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.agent_server.AgentServer.get_agent: BACKLOG / param-mismatch/ param[1] (route)/ type 'string' vs 'any'; return-mismatch/ returns 'optional<class/signalwire.core.agent
signalwire.agent_server.AgentServer.get_agents: BACKLOG / return-mismatch/ returns 'list<tuple<string,class/signalwire.core.agent_base.AgentBase>>' vs 'any
signalwire.agent_server.AgentServer.register: BACKLOG / param-mismatch/ param[1] (agent)/ type 'class/signalwire.core.agent_base.AgentBase' vs 'any'; param-mismatch/ param[2] (
signalwire.agent_server.AgentServer.register_sip_username: BACKLOG / param-mismatch/ param[1] (username)/ type 'string' vs 'any'; param-mismatch/ param[2] (route)/ type 'string' vs 'any'
signalwire.agent_server.AgentServer.run: BACKLOG / param-count-mismatch/ reference has 5 param(s), port has 1/ reference=['self', 'event', 'context', 'ho
signalwire.agent_server.AgentServer.serve_static_files: BACKLOG / param-mismatch/ param[1] (directory)/ type 'string' vs 'any'; param-mismatch/ param[2] (route)/ type 'string' vs 'any'; 
signalwire.agent_server.AgentServer.setup_sip_routing: BACKLOG / param-mismatch/ param[1] (route)/ kind 'positional' vs 'keyword'; type 'string' vs 'any'; defaul; param-mismatch/ param[
signalwire.agent_server.AgentServer.unregister: BACKLOG / param-mismatch/ param[1] (route)/ type 'string' vs 'any'; return-mismatch/ returns 'bool' vs 'any'
signalwire.contexts.context.Context.add_bullets: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_enter_filler: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_exit_filler: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_system_bullets: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.add_system_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.get_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.move_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.name: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.remove_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_consolidate: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_enter_fillers: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_exit_fillers: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_full_reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_initial_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_isolated: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_post_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_system_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_user_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_valid_contexts: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.set_valid_steps: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context.Context.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.add_context: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.attach_agent: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.get_context: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.context_builder.ContextBuilder.validate: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.create_simple_context: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.add_question: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.completion_action: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.output_key: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.questions: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_info.GatherInfo.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.confirm: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.functions: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.key: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.question: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.gather_question.GatherQuestion.type: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.add_bullets: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.add_gather_question: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.add_section: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.clear_sections: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.name: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_end: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_functions: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_gather_info: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_reset_consolidate: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_reset_full_reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_reset_system_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_reset_user_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_skip_to_next_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_skip_user_turn: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_step_criteria: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_text: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_valid_contexts: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.set_valid_steps: BACKLOG / missing-reference/ in port, not in reference
signalwire.contexts.step.Step.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.core.agent_base.AgentBase.add_answer_verb: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.add_post_ai_verb: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.add_post_answer_verb: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.add_pre_answer_verb: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.add_swaig_query_params: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.clear_post_ai_verbs: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.clear_post_answer_verbs: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.clear_pre_answer_verbs: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.clear_swaig_query_params: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.enable_sip_routing: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.on_debug_event: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.on_summary: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.register_sip_username: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.set_post_prompt_url: BACKLOG / missing-port/ in reference, not in port
signalwire.core.agent_base.AgentBase.set_web_hook_url: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_bullets: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_enter_filler: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_exit_filler: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_section: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_system_bullets: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.add_system_section: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.get_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.move_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.remove_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_consolidate: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_enter_fillers: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_exit_fillers: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_full_reset: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_initial_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_isolated: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_post_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_system_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_user_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_valid_contexts: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Context.set_valid_steps: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.ContextBuilder.add_context: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.ContextBuilder.get_context: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.ContextBuilder.reset: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.GatherInfo.add_question: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.add_bullets: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.add_gather_question: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.add_section: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.clear_sections: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_end: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_functions: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_gather_info: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_reset_consolidate: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_reset_full_reset: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_reset_system_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_reset_user_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_skip_to_next_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_skip_user_turn: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_step_criteria: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_text: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_valid_contexts: BACKLOG / missing-port/ in reference, not in port
signalwire.core.contexts.Step.set_valid_steps: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.body: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.description: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.error_keys: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.expression: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.fallback_output: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.foreach: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.global_error_keys: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.output: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.parameter: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.params: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.purpose: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.to_swaig_function: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.webhook: BACKLOG / missing-port/ in reference, not in port
signalwire.core.data_map.DataMap.webhook_expressions: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.add_action: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.add_actions: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.add_dynamic_hints: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.clear_dynamic_hints: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.connect: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.create_payment_action: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.create_payment_parameter: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.create_payment_prompt: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.enable_extensive_data: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.enable_functions_on_timeout: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.execute_rpc: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.execute_swml: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.hangup: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.hold: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.join_conference: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.join_room: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.pay: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.play_background_file: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.record_call: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.remove_global_data: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.remove_metadata: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.replace_in_history: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.rpc_ai_message: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.rpc_ai_unhold: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.rpc_dial: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.say: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.send_sms: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.set_end_of_speech_timeout: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.set_metadata: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.set_post_process: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.set_response: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.set_speech_event_timeout: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.simulate_user_input: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.sip_refer: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.stop_background_file: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.stop_record_call: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.stop_tap: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.switch_context: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.swml_change_context: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.swml_change_step: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.swml_transfer: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.swml_user_event: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.tap: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.toggle_functions: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.update_global_data: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.update_settings: BACKLOG / missing-port/ in reference, not in port
signalwire.core.function_result.FunctionResult.wait_for_user: BACKLOG / missing-port/ in reference, not in port
signalwire.core.security.session_manager.SessionManager.validate_token: BACKLOG / param-mismatch/ param[1] (call_id)/ name 'call_id' vs 'function_name'; type 'string' vs 'any'; param-mismatch/ param[2] 
signalwire.core.skill_base.SkillBase.cleanup: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.get_global_data: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.get_hints: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.get_parameter_schema: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.get_prompt_sections: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.register_tools: BACKLOG / missing-port/ in reference, not in port
signalwire.core.skill_base.SkillBase.setup: BACKLOG / missing-port/ in reference, not in port
signalwire.data_map.DataMap.body: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.create_expression_tool: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.create_simple_api_tool: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.description: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.error_keys: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.expression: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.fallback_output: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.foreach: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.function_name: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.global_error_keys: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.output: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.parameter: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.params: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.purpose: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.to_swaig_function: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.webhook: BACKLOG / missing-reference/ in port, not in reference
signalwire.data_map.DataMap.webhook_expressions: BACKLOG / missing-reference/ in port, not in reference
signalwire.logging.global_level: BACKLOG / missing-reference/ in port, not in reference
signalwire.logging.logger: BACKLOG / missing-reference/ in port, not in reference
signalwire.logging.reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.logging.suppressed: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.call: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.completed: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.done: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.is_done: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.on_completed: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.result: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.action.Action.wait: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.ai_action.AIAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call.AIAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.Action.wait: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.Call.ai: BACKLOG / param-count-mismatch/ reference has 16 param(s), port has 4/ reference=['self', 'control_id', 'agent',; return-mismatch/
signalwire.relay.call.Call.ai_hold: BACKLOG / param-count-mismatch/ reference has 4 param(s), port has 2/ reference=['self', 'timeout', 'prompt', 'k; return-mismatch/
signalwire.relay.call.Call.ai_message: BACKLOG / param-count-mismatch/ reference has 6 param(s), port has 2/ reference=['self', 'message_text', 'role',; return-mismatch/
signalwire.relay.call.Call.ai_unhold: BACKLOG / param-count-mismatch/ reference has 3 param(s), port has 2/ reference=['self', 'prompt', 'kwargs'] por; return-mismatch/
signalwire.relay.call.Call.amazon_bedrock: BACKLOG / param-count-mismatch/ reference has 8 param(s), port has 2/ reference=['self', 'prompt', 'SWAIG', 'ai_; return-mismatch/
signalwire.relay.call.Call.answer: BACKLOG / param-mismatch/ param[1] (kwargs)/ required False vs True; default {} vs '<absent>'; return-mismatch/ returns 'dict<any,
signalwire.relay.call.Call.bind_digit: BACKLOG / param-count-mismatch/ reference has 7 param(s), port has 4/ reference=['self', 'digits', 'bind_method'; return-mismatch/
signalwire.relay.call.Call.clear_digit_bindings: BACKLOG / param-count-mismatch/ reference has 3 param(s), port has 2/ reference=['self', 'realm', 'kwargs'] port; return-mismatch/
signalwire.relay.call.Call.collect: BACKLOG / param-count-mismatch/ reference has 11 param(s), port has 5/ reference=['self', 'digits', 'speech', 'i; return-mismatch/
signalwire.relay.call.Call.connect: BACKLOG / param-count-mismatch/ reference has 8 param(s), port has 3/ reference=['self', 'devices', 'ringback', ; return-mismatch/
signalwire.relay.call.Call.denoise: BACKLOG / return-mismatch/ returns 'dict<any,any>' vs 'any'
signalwire.relay.call.Call.denoise_stop: BACKLOG / return-mismatch/ returns 'dict<any,any>' vs 'any'
signalwire.relay.call.Call.detect: BACKLOG / param-mismatch/ param[1] (detect)/ name 'detect' vs 'detect_opts'; type 'dict<string,any>' vs 'a; param-mismatch/ param[
signalwire.relay.call.Call.disconnect: BACKLOG / return-mismatch/ returns 'dict<any,any>' vs 'any'
signalwire.relay.call.Call.echo: BACKLOG / param-count-mismatch/ reference has 4 param(s), port has 2/ reference=['self', 'timeout', 'status_url'; return-mismatch/
signalwire.relay.call.Call.ended: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call.Call.hangup: BACKLOG / param-mismatch/ param[1] (reason)/ kind 'positional' vs 'keyword'; type 'string' vs 'any'; defau; return-mismatch/ retur
signalwire.relay.call.Call.hold: BACKLOG / return-mismatch/ returns 'dict<any,any>' vs 'any'
signalwire.relay.call.Call.join_conference: BACKLOG / param-count-mismatch/ reference has 22 param(s), port has 3/ reference=['self', 'name', 'muted', 'beep; return-mismatch/
signalwire.relay.call.Call.join_room: BACKLOG / param-count-mismatch/ reference has 4 param(s), port has 3/ reference=['self', 'name', 'status_url', '; return-mismatch/
signalwire.relay.call.Call.leave_conference: BACKLOG / param-count-mismatch/ reference has 3 param(s), port has 2/ reference=['self', 'conference_id', 'kwarg; return-mismatch/
signalwire.relay.call.Call.leave_room: BACKLOG / param-count-mismatch/ reference has 2 param(s), port has 1/ reference=['self', 'kwargs'] port=['self']; return-mismatch/
signalwire.relay.call.Call.live_transcribe: BACKLOG / param-mismatch/ param[1] (action)/ kind 'positional' vs 'keyword'; type 'dict<string,any>' vs 'a; param-mismatch/ param[
signalwire.relay.call.Call.live_translate: BACKLOG / param-count-mismatch/ reference has 4 param(s), port has 3/ reference=['self', 'action', 'status_url',; return-mismatch/
signalwire.relay.call.Call.on: BACKLOG / param-mismatch/ param[1] (event_type)/ type 'string' vs 'any'; param-mismatch/ param[2] (handler)/ kind 'positional' vs 
signalwire.relay.call.Call.pay: BACKLOG / param-count-mismatch/ reference has 22 param(s), port has 5/ reference=['self', 'payment_connector_url; return-mismatch/
signalwire.relay.call.Call.play: BACKLOG / param-mismatch/ param[1] (media)/ type 'list<dict<string,any>>' vs 'any'; param-mismatch/ param[2] (volume)/ type 'optio
signalwire.relay.call.Call.play_and_collect: BACKLOG / param-mismatch/ param[1] (media)/ type 'list<dict<string,any>>' vs 'any'; param-mismatch/ param[2] (collect)/ type 'dict
signalwire.relay.call.Call.queue_enter: BACKLOG / param-count-mismatch/ reference has 5 param(s), port has 4/ reference=['self', 'queue_name', 'control_; return-mismatch/
signalwire.relay.call.Call.queue_leave: BACKLOG / param-count-mismatch/ reference has 6 param(s), port has 4/ reference=['self', 'queue_name', 'control_; return-mismatch/
signalwire.relay.call.Call.receive_fax: BACKLOG / param-mismatch/ param[1] (control_id)/ type 'optional<string>' vs 'any'; param-mismatch/ param[2] (on_completed)/ type '
signalwire.relay.call.Call.record: BACKLOG / param-mismatch/ param[1] (audio)/ kind 'positional' vs 'keyword'; type 'optional<dict<string,any; param-mismatch/ param[
signalwire.relay.call.Call.refer: BACKLOG / param-count-mismatch/ reference has 4 param(s), port has 3/ reference=['self', 'device', 'status_url',; return-mismatch/
signalwire.relay.call.Call.send_digits: BACKLOG / param-count-mismatch/ reference has 3 param(s), port has 4/ reference=['self', 'digits', 'control_id']; return-mismatch/
signalwire.relay.call.Call.send_fax: BACKLOG / param-count-mismatch/ reference has 7 param(s), port has 5/ reference=['self', 'document', 'identity',; return-mismatch/
signalwire.relay.call.Call.stream: BACKLOG / param-count-mismatch/ reference has 12 param(s), port has 5/ reference=['self', 'url', 'name', 'codec'; return-mismatch/
signalwire.relay.call.Call.transcribe: BACKLOG / param-count-mismatch/ reference has 5 param(s), port has 4/ reference=['self', 'control_id', 'status_u; return-mismatch/
signalwire.relay.call.Call.transfer: BACKLOG / param-mismatch/ param[1] (dest)/ kind 'positional' vs 'keyword'; type 'string' vs 'any'; param-mismatch/ param[2] (kwarg
signalwire.relay.call.Call.unhold: BACKLOG / return-mismatch/ returns 'dict<any,any>' vs 'any'
signalwire.relay.call.Call.user_event: BACKLOG / param-mismatch/ param[1] (event)/ type 'optional<string>' vs 'any'; param-mismatch/ param[2] (kwargs)/ required False vs
signalwire.relay.call.Call.wait_for_ended: BACKLOG / param-mismatch/ param[1] (timeout)/ kind 'positional' vs 'keyword'; type 'optional<float>' vs 'a; return-mismatch/ retur
signalwire.relay.call.CollectAction.start_input_timers: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.CollectAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.CollectAction.volume: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.DetectAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.FaxAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.PayAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.PlayAction.pause: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.PlayAction.resume: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.PlayAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.PlayAction.volume: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.RecordAction.pause: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.RecordAction.resume: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.RecordAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.StandaloneCollectAction.start_input_timers: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.StandaloneCollectAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.StreamAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.TapAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call.TranscribeAction.stop: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.call_receive_event.CallReceiveEvent.call_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.context: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.device: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.direction: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.node_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.project_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.segment_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_receive_event.CallReceiveEvent.tag: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_state_event.CallStateEvent.call_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_state_event.CallStateEvent.device: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_state_event.CallStateEvent.direction: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_state_event.CallStateEvent.end_reason: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.call_state_event.CallStateEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.calling_error_event.CallingErrorEvent.code: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.calling_error_event.CallingErrorEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.calling_error_event.CallingErrorEvent.message: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.client.RelayClient.dial: BACKLOG / param-mismatch/ param[1] (devices)/ type 'list<list<dict<string,any>>>' vs 'any'; param-mismatch/ param[2] (tag)/ name '
signalwire.relay.client.RelayClient.execute: BACKLOG / param-mismatch/ param[1] (method)/ type 'string' vs 'any'; param-mismatch/ param[2] (params)/ type 'dict<string,any>' vs
signalwire.relay.client.RelayClient.on_call: BACKLOG / param-mismatch/ param[1] (handler)/ name 'handler' vs 'block'; kind 'positional' vs 'keyword'; t; return-mismatch/ retur
signalwire.relay.client.RelayClient.on_message: BACKLOG / param-mismatch/ param[1] (handler)/ name 'handler' vs 'block'; kind 'positional' vs 'keyword'; t; return-mismatch/ retur
signalwire.relay.client.RelayClient.receive: BACKLOG / param-mismatch/ param[1] (contexts)/ type 'list<string>' vs 'any'; return-mismatch/ returns 'void' vs 'any'
signalwire.relay.client.RelayClient.run: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.relay.client.RelayClient.send_message: BACKLOG / param-mismatch/ param[1] (to_number)/ name 'to_number' vs 'to'; type 'string' vs 'any'; param-mismatch/ param[2] (from_n
signalwire.relay.client.RelayClient.unreceive: BACKLOG / param-mismatch/ param[1] (contexts)/ type 'list<string>' vs 'any'; return-mismatch/ returns 'void' vs 'any'
signalwire.relay.collect_action.CollectAction.start_input_timers: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_action.CollectAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_action.CollectAction.volume: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_event.CollectEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_event.CollectEvent.final: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_event.CollectEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_event.CollectEvent.result_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.collect_event.CollectEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.conference_event.ConferenceEvent.conference_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.conference_event.ConferenceEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.conference_event.ConferenceEvent.name: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.conference_event.ConferenceEvent.status: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.connect_event.ConnectEvent.connect_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.connect_event.ConnectEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.connect_event.ConnectEvent.peer: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.denoise_event.DenoiseEvent.denoised: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.denoise_event.DenoiseEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.detect_action.DetectAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.detect_event.DetectEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.detect_event.DetectEvent.detect: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.detect_event.DetectEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.dial_event.DialEvent.call_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.dial_event.DialEvent.dial_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.dial_event.DialEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.dial_event.DialEvent.tag: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.echo_event.EchoEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.echo_event.EchoEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.event.CallReceiveEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.CallStateEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.CallingErrorEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.CollectEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.ConferenceEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.ConnectEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.DenoiseEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.DetectEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.DialEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.EchoEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.FaxEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.HoldEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.MessageReceiveEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.MessageStateEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.PayEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.PlayEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.QueueEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.RecordEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.ReferEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.RelayEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.SendDigitsEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.StreamEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.TapEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.TranscribeEvent.from_payload: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.event.parse_event: BACKLOG / missing-port/ in reference, not in port
signalwire.relay.fax_action.FaxAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.fax_event.FaxEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.fax_event.FaxEvent.fax: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.fax_event.FaxEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.hold_event.HoldEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.hold_event.HoldEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message.Message.done: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message.Message.result: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message.Message.wait: BACKLOG / param-mismatch/ param[1] (timeout)/ kind 'positional' vs 'keyword'; type 'optional<float>' vs 'a; return-mismatch/ retur
signalwire.relay.message_receive_event.MessageReceiveEvent.body: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.context: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.direction: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.from_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.media: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.message_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.message_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.segments: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.tags: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_receive_event.MessageReceiveEvent.to_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.body: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.context: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.direction: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.from_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.media: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.message_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.message_state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.reason: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.segments: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.tags: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.message_state_event.MessageStateEvent.to_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.parse_event: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.pay_action.PayAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.pay_event.PayEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.pay_event.PayEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.pay_event.PayEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_action.PlayAction.pause: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_action.PlayAction.resume: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_action.PlayAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_action.PlayAction.volume: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_event.PlayEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_event.PlayEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.play_event.PlayEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.position: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.queue_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.queue_name: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.size: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.queue_event.QueueEvent.status: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_action.RecordAction.pause: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_action.RecordAction.resume: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_action.RecordAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.duration: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.record: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.size: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.record_event.RecordEvent.url: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.refer_event.ReferEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.refer_event.ReferEvent.sip_notify_response_code: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.refer_event.ReferEvent.sip_refer_response_code: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.refer_event.ReferEvent.sip_refer_to: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.refer_event.ReferEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_error.RelayError.code: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_error.RelayError.error_message: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_event.RelayEvent.call_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_event.RelayEvent.event_type: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_event.RelayEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_event.RelayEvent.params: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.relay_event.RelayEvent.timestamp: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.send_digits_event.SendDigitsEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.send_digits_event.SendDigitsEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.send_digits_event.SendDigitsEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.standalone_collect_action.StandaloneCollectAction.start_input_timers: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.standalone_collect_action.StandaloneCollectAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_action.StreamAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_event.StreamEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_event.StreamEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_event.StreamEvent.name: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_event.StreamEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.stream_event.StreamEvent.url: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_action.TapAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_event.TapEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_event.TapEvent.device: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_event.TapEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_event.TapEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.tap_event.TapEvent.tap: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_action.TranscribeAction.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.control_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.duration: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.from_payload: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.recording_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.size: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.state: BACKLOG / missing-reference/ in port, not in reference
signalwire.relay.transcribe_event.TranscribeEvent.url: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.crud_resource.CrudResource.update_method: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.base_url: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.patch: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.post: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.project_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.http_client.HttpClient.put: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.addresses.AddressesResource.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.addresses.AddressesResource.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.addresses.AddressesResource.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.addresses.AddressesResource.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.addresses_resource.AddressesResource.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.addresses_resource.AddressesResource.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.addresses_resource.AddressesResource.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.addresses_resource.AddressesResource.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.auto_materialized_webhook.AutoMaterializedWebhook.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.call_flows_resource.CallFlowsResource.deploy_version: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.call_flows_resource.CallFlowsResource.list_addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.call_flows_resource.CallFlowsResource.list_versions: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling.CallingNamespace.ai_hold: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.ai_message: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.ai_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.ai_unhold: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.collect: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.collect_start_input_timers: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.collect_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.denoise: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.denoise_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.detect: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.detect_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.dial: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.disconnect: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.live_transcribe: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.live_translate: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.play: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.play_pause: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.play_resume: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.play_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.play_volume: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.receive_fax_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.record: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.record_pause: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.record_resume: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.record_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.refer: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.send_fax_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.stream_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.tap: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.tap_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.transcribe: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.transcribe_stop: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.transfer: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling.CallingNamespace.user_event: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.calling_namespace.CallingNamespace.ai_hold: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.ai_message: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.ai_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.ai_unhold: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.collect: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.collect_start_input_timers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.collect_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.denoise: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.denoise_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.detect: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.detect_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.dial: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.disconnect: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.end_call: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.live_transcribe: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.live_translate: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.play: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.play_pause: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.play_resume: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.play_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.play_volume: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.receive_fax_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.record: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.record_pause: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.record_resume: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.record_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.refer: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.send_fax_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.stream_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.tap: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.tap_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.transcribe: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.transcribe_stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.transfer: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.calling_namespace.CallingNamespace.user_event: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.chat.ChatResource.create_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.chat_resource.ChatResource.create_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat.CompatAccounts.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatAccounts.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatAccounts.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatAccounts.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatApplications.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatCalls.start_recording: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatCalls.start_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatCalls.stop_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatCalls.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatCalls.update_recording: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.delete_recording: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.get_participant: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.get_recording: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.list_participants: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.list_recordings: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.remove_participant: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.start_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.stop_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.update_participant: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatConferences.update_recording: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatFaxes.delete_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatFaxes.get_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatFaxes.list_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatFaxes.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatLamlBins.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatMessages.delete_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatMessages.get_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatMessages.list_media: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatMessages.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.import_number: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.list_available_countries: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.purchase: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.search_local: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.search_toll_free: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatPhoneNumbers.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatQueues.dequeue_member: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatQueues.get_member: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatQueues.list_members: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatQueues.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatRecordings.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatRecordings.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatRecordings.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTokens.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTokens.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTokens.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTranscriptions.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTranscriptions.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat.CompatTranscriptions.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.compat_accounts.CompatAccounts.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_accounts.CompatAccounts.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_accounts.CompatAccounts.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_accounts.CompatAccounts.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_applications.CompatApplications.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_calls.CompatCalls.start_recording: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_calls.CompatCalls.start_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_calls.CompatCalls.stop_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_calls.CompatCalls.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_calls.CompatCalls.update_recording: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.delete_recording: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.get_participant: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.get_recording: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.list_participants: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.list_recordings: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.remove_participant: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.start_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.stop_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.update_participant: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_conferences.CompatConferences.update_recording: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_faxes.CompatFaxes.delete_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_faxes.CompatFaxes.get_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_faxes.CompatFaxes.list_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_faxes.CompatFaxes.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_laml_bins.CompatLamlBins.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_messages.CompatMessages.delete_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_messages.CompatMessages.get_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_messages.CompatMessages.list_media: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_messages.CompatMessages.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.accounts: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.applications: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.calls: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.conferences: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.faxes: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.laml_bins: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.messages: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.phone_numbers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.queues: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.recordings: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_namespace.CompatNamespace.transcriptions: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.import_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.list_available_countries: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.purchase: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.search_local: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.search_toll_free: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_phone_numbers.CompatPhoneNumbers.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_queues.CompatQueues.dequeue_member: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_queues.CompatQueues.get_member: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_queues.CompatQueues.list_members: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_queues.CompatQueues.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_recordings.CompatRecordings.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_recordings.CompatRecordings.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_recordings.CompatRecordings.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_tokens.CompatTokens.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_tokens.CompatTokens.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_tokens.CompatTokens.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_transcriptions.CompatTranscriptions.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_transcriptions.CompatTranscriptions.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.compat_transcriptions.CompatTranscriptions.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.conference_logs.ConferenceLogs.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.conference_rooms_resource.ConferenceRoomsResource.list_addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.cxml_applications_resource.CxmlApplicationsResource.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.datasphere.DatasphereDocuments.delete_chunk: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.datasphere.DatasphereDocuments.get_chunk: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.datasphere.DatasphereDocuments.list_chunks: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.datasphere.DatasphereDocuments.search: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.datasphere_documents.DatasphereDocuments.delete_chunk: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.datasphere_documents.DatasphereDocuments.get_chunk: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.datasphere_documents.DatasphereDocuments.list_chunks: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.datasphere_documents.DatasphereDocuments.search: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.datasphere_namespace.DatasphereNamespace.documents: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric.AutoMaterializedWebhook.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.CallFlowsResource.deploy_version: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.CallFlowsResource.list_addresses: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.CallFlowsResource.list_versions: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.ConferenceRoomsResource.list_addresses: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.CxmlApplicationsResource.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricAddresses.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricAddresses.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricTokens.create_embed_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricTokens.create_guest_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricTokens.create_invite_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricTokens.create_subscriber_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.FabricTokens.refresh_subscriber_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.assign_domain_application: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.assign_phone_route: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.GenericResources.list_addresses: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.SubscribersResource.create_sip_endpoint: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.SubscribersResource.delete_sip_endpoint: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.SubscribersResource.get_sip_endpoint: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.SubscribersResource.list_sip_endpoints: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric.SubscribersResource.update_sip_endpoint: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.fabric_addresses.FabricAddresses.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_addresses.FabricAddresses.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.ai_agents: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.call_flows: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.conference_rooms: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.cxml_applications: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.cxml_scripts: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.cxml_webhooks: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.freeswitch_connectors: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.relay_applications: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.resources: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.sip_endpoints: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.sip_gateways: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.subscribers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.swml_scripts: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.swml_webhooks: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_namespace.FabricNamespace.tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_resource.FabricResource.list_addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_tokens.FabricTokens.create_embed_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_tokens.FabricTokens.create_guest_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_tokens.FabricTokens.create_invite_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_tokens.FabricTokens.create_subscriber_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fabric_tokens.FabricTokens.refresh_subscriber_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fax_logs.FaxLogs.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.fax_logs.FaxLogs.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.assign_domain_application: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.assign_phone_route: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.generic_resources.GenericResources.list_addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.imported_numbers.ImportedNumbersResource.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.imported_numbers_resource.ImportedNumbersResource.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.logs.ConferenceLogs.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.FaxLogs.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.FaxLogs.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.MessageLogs.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.MessageLogs.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.VoiceLogs.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.VoiceLogs.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs.VoiceLogs.list_events: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.logs_namespace.LogsNamespace.conferences: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.logs_namespace.LogsNamespace.fax: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.logs_namespace.LogsNamespace.messages: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.logs_namespace.LogsNamespace.voice: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.lookup.LookupResource.phone_number: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.lookup_resource.LookupResource.phone_number: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.message_logs.MessageLogs.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.message_logs.MessageLogs.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.mfa.MfaResource.call: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.mfa.MfaResource.sms: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.mfa.MfaResource.verify: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.mfa_resource.MfaResource.call: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.mfa_resource.MfaResource.sms: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.mfa_resource.MfaResource.verify: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.number_groups.NumberGroupsResource.add_membership: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.number_groups.NumberGroupsResource.delete_membership: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.number_groups.NumberGroupsResource.get_membership: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.number_groups.NumberGroupsResource.list_memberships: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.number_groups_resource.NumberGroupsResource.add_membership: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.number_groups_resource.NumberGroupsResource.delete_membership: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.number_groups_resource.NumberGroupsResource.get_membership: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.number_groups_resource.NumberGroupsResource.list_memberships: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.search: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_ai_agent: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_call_flow: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_cxml_application: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_cxml_webhook: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_relay_application: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_relay_topic: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers.PhoneNumbersResource.set_swml_webhook: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.search: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_ai_agent: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_call_flow: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_cxml_application: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_cxml_webhook: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_relay_application: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_relay_topic: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.phone_numbers_resource.PhoneNumbersResource.set_swml_webhook: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.project.ProjectTokens.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.project.ProjectTokens.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.project.ProjectTokens.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.project_namespace.ProjectNamespace.tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.project_tokens.ProjectTokens.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.project_tokens.ProjectTokens.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.project_tokens.ProjectTokens.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.pub_sub_resource.PubSubResource.create_token: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.pubsub.PubSubResource.create_token: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.queues.QueuesResource.get_member: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.queues.QueuesResource.get_next_member: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.queues.QueuesResource.list_members: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.queues_resource.QueuesResource.get_member: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.queues_resource.QueuesResource.get_next_member: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.queues_resource.QueuesResource.list_members: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.recordings.RecordingsResource.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.recordings.RecordingsResource.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.recordings.RecordingsResource.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.recordings_resource.RecordingsResource.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.recordings_resource.RecordingsResource.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.recordings_resource.RecordingsResource.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry.RegistryBrands.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryBrands.create_campaign: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryBrands.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryBrands.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryBrands.list_campaigns: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryCampaigns.create_order: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryCampaigns.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryCampaigns.list_numbers: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryCampaigns.list_orders: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryCampaigns.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryNumbers.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry.RegistryOrders.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.registry_brands.RegistryBrands.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_brands.RegistryBrands.create_campaign: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_brands.RegistryBrands.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_brands.RegistryBrands.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_brands.RegistryBrands.list_campaigns: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_campaigns.RegistryCampaigns.create_order: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_campaigns.RegistryCampaigns.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_campaigns.RegistryCampaigns.list_numbers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_campaigns.RegistryCampaigns.list_orders: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_campaigns.RegistryCampaigns.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_namespace.RegistryNamespace.brands: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_namespace.RegistryNamespace.campaigns: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_namespace.RegistryNamespace.numbers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_namespace.RegistryNamespace.orders: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_numbers.RegistryNumbers.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.registry_orders.RegistryOrders.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.short_codes.ShortCodesResource.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.short_codes.ShortCodesResource.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.short_codes.ShortCodesResource.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.short_codes_resource.ShortCodesResource.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.short_codes_resource.ShortCodesResource.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.short_codes_resource.ShortCodesResource.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.sip_profile.SipProfileResource.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.sip_profile.SipProfileResource.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.sip_profile_resource.SipProfileResource.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.sip_profile_resource.SipProfileResource.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.subscribers_resource.SubscribersResource.create_sip_endpoint: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.subscribers_resource.SubscribersResource.delete_sip_endpoint: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.subscribers_resource.SubscribersResource.get_sip_endpoint: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.subscribers_resource.SubscribersResource.list_sip_endpoints: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.subscribers_resource.SubscribersResource.update_sip_endpoint: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.verified_callers.VerifiedCallersResource.redial_verification: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.verified_callers.VerifiedCallersResource.submit_verification: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.verified_callers_resource.VerifiedCallersResource.redial_verification: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.verified_callers_resource.VerifiedCallersResource.submit_verification: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video.VideoConferenceTokens.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoConferenceTokens.reset: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoConferences.create_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoConferences.list_conference_tokens: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoConferences.list_streams: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomRecordings.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomRecordings.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomRecordings.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomRecordings.list_events: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomSessions.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomSessions.list: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomSessions.list_events: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomSessions.list_members: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomSessions.list_recordings: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRoomTokens.create: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRooms.create_stream: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoRooms.list_streams: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoStreams.delete: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoStreams.get: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video.VideoStreams.update: BACKLOG / missing-port/ in reference, not in port
signalwire.rest.namespaces.video_conference_tokens.VideoConferenceTokens.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_conference_tokens.VideoConferenceTokens.reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_conferences.VideoConferences.create_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_conferences.VideoConferences.list_conference_tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_conferences.VideoConferences.list_streams: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.conference_tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.conferences: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.room_recordings: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.room_sessions: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.room_tokens: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.rooms: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_namespace.VideoNamespace.streams: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_recordings.VideoRoomRecordings.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_recordings.VideoRoomRecordings.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_recordings.VideoRoomRecordings.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_recordings.VideoRoomRecordings.list_events: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_sessions.VideoRoomSessions.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_sessions.VideoRoomSessions.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_sessions.VideoRoomSessions.list_events: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_sessions.VideoRoomSessions.list_members: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_sessions.VideoRoomSessions.list_recordings: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_room_tokens.VideoRoomTokens.create: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_rooms.VideoRooms.create_stream: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_rooms.VideoRooms.list_streams: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_streams.VideoStreams.delete: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_streams.VideoStreams.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.video_streams.VideoStreams.update: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.voice_logs.VoiceLogs.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.voice_logs.VoiceLogs.list: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.namespaces.voice_logs.VoiceLogs.list_events: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.addresses: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.calling: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.chat: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.compat: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.datasphere: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.fabric: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.imported_numbers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.logs: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.lookup: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.mfa: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.number_groups: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.phone_numbers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.project: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.project_id: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.pubsub: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.queues: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.recordings: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.registry: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.short_codes: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.sip_profile: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.verified_callers: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.rest_client.RestClient.video: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.signal_wire_rest_error.SignalWireRestError.body: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.signal_wire_rest_error.SignalWireRestError.method_name: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.signal_wire_rest_error.SignalWireRestError.status_code: BACKLOG / missing-reference/ in port, not in reference
signalwire.rest.signal_wire_rest_error.SignalWireRestError.url: BACKLOG / missing-reference/ in port, not in reference
signalwire.runtime.execution_mode: BACKLOG / missing-reference/ in port, not in reference
signalwire.runtime.lambda: BACKLOG / missing-reference/ in port, not in reference
signalwire.runtime.lambda_base_url: BACKLOG / missing-reference/ in port, not in reference
signalwire.runtime.serverless: BACKLOG / missing-reference/ in port, not in reference
signalwire.search.preprocess_document_content: BACKLOG / missing-port/ in reference, not in port
signalwire.search.preprocess_query: BACKLOG / missing-port/ in reference, not in port
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.api_ninjas_trivia.skill.ApiNinjasTriviaSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.claude_skills.skill.ClaudeSkillsSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.datasphere.skill.DataSphereSkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.datasphere.skill.DataSphereSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.datasphere.skill.DataSphereSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.datasphere.skill.DataSphereSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.datasphere.skill.DataSphereSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.datasphere.skill.DataSphereSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.datasphere_serverless.skill.DataSphereServerlessSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.datetime.skill.DateTimeSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.datetime.skill.DateTimeSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.google_maps.skill.GoogleMapsSkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.google_maps.skill.GoogleMapsSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.google_maps.skill.GoogleMapsSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.google_maps.skill.GoogleMapsSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.google_maps.skill.GoogleMapsSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.info_gatherer.skill.InfoGathererSkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.info_gatherer.skill.InfoGathererSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.info_gatherer.skill.InfoGathererSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.info_gatherer.skill.InfoGathererSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.info_gatherer.skill.InfoGathererSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.joke.skill.JokeSkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.joke.skill.JokeSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.joke.skill.JokeSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.joke.skill.JokeSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.joke.skill.JokeSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.math.skill.MathSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.math.skill.MathSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.mcp_gateway.skill.MCPGatewaySkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.native_vector_search.skill.NativeVectorSearchSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.play_background_file.skill.PlayBackgroundFileSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.registry.SkillRegistry.list_skills: BACKLOG / missing-port/ in reference, not in port
signalwire.skills.registry.SkillRegistry.register_skill: BACKLOG / missing-port/ in reference, not in port
signalwire.skills.skill_base.SkillBase.cleanup: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.description: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.get_global_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.get_hints: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.get_param: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.get_parameter_schema: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.get_prompt_sections: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.instance_key: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.name: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.params: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.register_tools: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.required_env_vars: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.setup: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_base.SkillBase.version: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.clear: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.get: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.load: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.loaded: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.loaded_keys: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.size: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_manager.SkillManager.unload: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.get_factory: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.list_skills: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.register: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.register_builtins: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.register_skill: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.registered: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.skill_registry.SkillRegistry.reset: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.spider.skill.SpiderSkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.spider.skill.SpiderSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.spider.skill.SpiderSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.spider.skill.SpiderSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.spider.skill.SpiderSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.get_hints: BACKLOG / return-mismatch/ returns 'list<string>' vs 'any'
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.swml_transfer.skill.SWMLTransferSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.weather_api.skill.WeatherApiSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.weather_api.skill.WeatherApiSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.weather_api.skill.WeatherApiSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.web_search.skill.WebSearchSkill.get_global_data: BACKLOG / return-mismatch/ returns 'dict<string,any>' vs 'any'
signalwire.skills.web_search.skill.WebSearchSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.web_search.skill.WebSearchSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<dict<string,any>>' vs 'any'
signalwire.skills.web_search.skill.WebSearchSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.web_search.skill.WebSearchSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.skills.web_search.skill.WebSearchSkill.supports_multiple_instances: BACKLOG / missing-reference/ in port, not in reference
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.get_parameter_schema: BACKLOG / param-mismatch/ param[0] (cls)/ name 'cls' vs 'self'; kind 'cls' vs 'self'; return-mismatch/ returns 'dict<string,dict<s
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.get_prompt_sections: BACKLOG / return-mismatch/ returns 'list<any>' vs 'any'
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.register_tools: BACKLOG / return-mismatch/ returns 'void' vs 'any'
signalwire.skills.wikipedia_search.skill.WikipediaSearchSkill.setup: BACKLOG / return-mismatch/ returns 'bool' vs 'any'
signalwire.swaig.function_result.FunctionResult.action: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.add_action: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.add_actions: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.add_dynamic_hints: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.clear_dynamic_hints: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.connect: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.create_payment_action: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.create_payment_parameter: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.create_payment_prompt: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.enable_extensive_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.enable_functions_on_timeout: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.execute_rpc: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.execute_swml: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.hangup: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.hold: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.join_conference: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.join_room: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.pay: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.play_background_file: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.post_process: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.record_call: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.remove_global_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.remove_metadata: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.replace_in_history: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.response: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.rpc_ai_message: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.rpc_ai_unhold: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.rpc_dial: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.say: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.send_sms: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.set_end_of_speech_timeout: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.set_metadata: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.set_post_process: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.set_response: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.set_speech_event_timeout: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.simulate_user_input: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.sip_refer: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.stop: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.stop_background_file: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.stop_record_call: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.stop_tap: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.switch_context: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.swml_change_context: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.swml_change_step: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.swml_transfer: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.swml_user_event: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.tap: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.to_h: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.to_json: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.toggle_functions: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.update_global_data: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.update_settings: BACKLOG / missing-reference/ in port, not in reference
signalwire.swaig.function_result.FunctionResult.wait_for_user: BACKLOG / missing-reference/ in port, not in reference
signalwire.swml.reset_schema: BACKLOG / missing-reference/ in port, not in reference
signalwire.swml.schema: BACKLOG / missing-reference/ in port, not in reference
