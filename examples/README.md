# Examples

Standalone Ruby scripts demonstrating the SignalWire AI Agents SDK. Each example uses `require 'signalwire'` and can be run directly.

The file names mirror the Python reference SDK so the examples are easy to cross-reference. `audit_example_parity.py` enforces this matching.

## Agent Examples

| File | Description |
|------|-------------|
| [simple_agent.rb](simple_agent.rb) | Basic agent with tools, hints, and language configuration |
| [simple_static_agent.rb](simple_static_agent.rb) | Minimal static agent with voice, params, hints, and structured prompts |
| [simple_dynamic_agent.rb](simple_dynamic_agent.rb) | Per-request dynamic configuration callback for multi-tenant deployments |
| [simple_dynamic_enhanced.rb](simple_dynamic_enhanced.rb) | Enhanced dynamic config: VIP, department, customer ID, language |
| [comprehensive_dynamic_agent.rb](comprehensive_dynamic_agent.rb) | Tier-based dynamic config with industry prompts, A/B testing, and voice selection |
| [custom_path_agent.rb](custom_path_agent.rb) | Agent with a custom HTTP path (`/chat`) and query-param personalisation |
| [declarative_agent.rb](declarative_agent.rb) | Declarative agent config with prompt sections, post-prompt, and summary callback |
| [multi_agent_server.rb](multi_agent_server.rb) | Three agents (sales, support, receptionist) hosted on one AgentServer |
| [multi_endpoint_agent.rb](multi_endpoint_agent.rb) | Multiple SWML routes (`/voice`, `/info`) on a single AgentServer |
| [contexts_demo.rb](contexts_demo.rb) | Multi-step workflows using the contexts and steps system |
| [gather_info_demo.rb](gather_info_demo.rb) | GatherInfo in steps for structured data collection (patient intake) |
| [gather_per_question_functions_demo.rb](gather_per_question_functions_demo.rb) | Per-question function whitelisting in gather_info |
| [step_function_inheritance_demo.rb](step_function_inheritance_demo.rb) | Step functions inherit from previous step when omitted |
| [datamap_demo.rb](datamap_demo.rb) | Server-side DataMap tools (weather API, calculator, jokes) |
| [advanced_datamap_demo.rb](advanced_datamap_demo.rb) | Advanced DataMap patterns: expressions, webhooks, form encoding, foreach |
| [skills_demo.rb](skills_demo.rb) | Built-in skills: datetime, math, and joke |
| [session_and_state_demo.rb](session_and_state_demo.rb) | Global data, post-prompt analysis, and on_summary callback |
| [call_flow_and_actions_demo.rb](call_flow_and_actions_demo.rb) | Verb management (pre-answer, post-answer, post-AI), recording, debug events |
| [llm_params_demo.rb](llm_params_demo.rb) | LLM parameter tuning: precise, creative, and customer-service personalities |
| [kubernetes_ready_agent.rb](kubernetes_ready_agent.rb) | K8s-ready agent with /health, /ready, environment-based port |
| [lambda_agent.rb](lambda_agent.rb) | Serverless pattern: agent with exportable Rack app for Lambda/Cloud Functions |
| [mcp_agent.rb](mcp_agent.rb) | MCP-enabled agent demonstrating MCP integration |

## Skill Examples

| File | Description |
|------|-------------|
| [joke_agent.rb](joke_agent.rb) | Joke skill integration (requires `API_NINJAS_KEY`) |
| [joke_skill_demo.rb](joke_skill_demo.rb) | Joke skill via the modular skills system with DataMap |
| [web_search_agent.rb](web_search_agent.rb) | Web search skill via Google Custom Search API |
| [web_search_multi_instance_demo.rb](web_search_multi_instance_demo.rb) | Multiple web search instances (general, news, quick) |
| [wikipedia_demo.rb](wikipedia_demo.rb) | Wikipedia search skill for factual information retrieval |
| [datasphere.rb](datasphere.rb) | DataSphere skill with multiple instances and custom tool names |
| [datasphere_multi_instance_demo.rb](datasphere_multi_instance_demo.rb) | DataSphere multi-instance with custom tool names |
| [datasphere_serverless_env.rb](datasphere_serverless_env.rb) | DataSphere serverless from environment variables |
| [datasphere_webhook_env_demo.rb](datasphere_webhook_env_demo.rb) | Webhook-based DataSphere from environment variables |

## Prefab Examples

| File | Description |
|------|-------------|
| [info_gatherer_example.rb](info_gatherer_example.rb) | InfoGatherer prefab: collect structured answers from callers |
| [dynamic_info_gatherer_example.rb](dynamic_info_gatherer_example.rb) | Dynamic InfoGatherer with callback-based question selection |
| [survey_agent_example.rb](survey_agent_example.rb) | Survey prefab: conduct automated phone surveys |
| [concierge_agent_example.rb](concierge_agent_example.rb) | ConciergeAgent prefab: hotel virtual concierge with amenity/service lookups |
| [receptionist_agent_example.rb](receptionist_agent_example.rb) | ReceptionistAgent prefab: call routing with department transfers |
| [faq_bot_agent.rb](faq_bot_agent.rb) | FAQBotAgent prefab: answer questions from a pre-defined knowledge base |

## SWML Service Examples

| File | Description |
|------|-------------|
| [auto_vivified_example.rb](auto_vivified_example.rb) | Auto-vivified verb methods on SWMLService |
| [basic_swml_service.rb](basic_swml_service.rb) | Basic SWMLService (non-AI): voicemail, recording, and call transfer |
| [swml_service_example.rb](swml_service_example.rb) | Three approaches to building SWML documents (direct, fluent, AI verb) |
| [swml_service_routing_example.rb](swml_service_routing_example.rb) | SWML service with sub-path routing (customer, product) |
| [dynamic_swml_service.rb](dynamic_swml_service.rb) | Dynamic SWML service with routing callbacks for VIP/new callers |
| [swmlservice_swaig_standalone.rb](swmlservice_swaig_standalone.rb) | SWMLService hosting SWAIG functions without AgentBase |
| [swmlservice_ai_sidecar.rb](swmlservice_ai_sidecar.rb) | SWMLService emitting `<ai_sidecar>` and dispatching tools |

## FunctionResult Action Examples

| File | Description |
|------|-------------|
| [swaig_features_agent.rb](swaig_features_agent.rb) | FunctionResult actions: connect, hangup, hold, say, metadata, SMS, chaining |
| [record_call_example.rb](record_call_example.rb) | Call recording: start, stop, voicemail, compliance workflows |
| [room_and_sip_example.rb](room_and_sip_example.rb) | Room joining, SIP REFER transfers, and ad-hoc conferences |
| [tap_example.rb](tap_example.rb) | TAP configuration: WebSocket/RTP monitoring, multi-stream management |

## Client Examples

| File | Description |
|------|-------------|
| [relay_answer_and_welcome.rb](relay_answer_and_welcome.rb) | RELAY WebSocket client: answer calls, play TTS, record, handle messages |
| [rest_demo.rb](rest_demo.rb) | REST HTTP client: manage AI agents, phone numbers, video rooms, queues |

## Audit Harnesses

These harnesses are driven by `porting-sdk/scripts/audit_*.py` to prove
the SDK's transports issue real bytes on the wire (no stubs). They are
not intended for direct use.

| File | Description |
|------|-------------|
| [relay_audit_harness.rb](relay_audit_harness.rb) | RELAY: connect/subscribe/event-dispatch over real WebSocket |
| [skills_audit_harness.rb](skills_audit_harness.rb) | Skills: each network skill issues a real outbound HTTP request |
| [rest_audit_harness.rb](rest_audit_harness.rb) | REST: each documented operation hits the wire with the right shape |

## Running

```bash
# Install dependencies
cd /path/to/signalwire-ruby
bundle install

# Run any example
ruby examples/simple_agent.rb

# For RELAY/REST examples, set environment variables first:
export SIGNALWIRE_PROJECT_ID=your-project-id
export SIGNALWIRE_API_TOKEN=your-api-token
export SIGNALWIRE_SPACE=your-space.signalwire.com
ruby examples/relay_answer_and_welcome.rb

# For skill examples that require API keys:
API_NINJAS_KEY=your-key ruby examples/joke_agent.rb
```

## More Examples

Additional examples for the RELAY and REST clients are in their respective directories:

- [relay/examples/](../relay/examples/) -- RELAY WebSocket examples (answer, dial, IVR)
- [rest/examples/](../rest/examples/) -- REST API examples (all 12 namespaces)
