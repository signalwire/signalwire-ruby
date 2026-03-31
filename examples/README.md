# Examples

Standalone Ruby scripts demonstrating the SignalWire AI Agents SDK. Each example uses `require 'signalwire'` and can be run directly.

## Agent Examples

| File | Description |
|------|-------------|
| [simple_agent.rb](simple_agent.rb) | Basic agent with tools, hints, and language configuration |
| [simple_static.rb](simple_static.rb) | Minimal static agent with voice, params, hints, and structured prompts |
| [simple_dynamic_agent.rb](simple_dynamic_agent.rb) | Per-request dynamic configuration callback for multi-tenant deployments |
| [simple_dynamic_enhanced.rb](simple_dynamic_enhanced.rb) | Enhanced dynamic config: VIP, department, customer ID, language |
| [comprehensive_dynamic.rb](comprehensive_dynamic.rb) | Tier-based dynamic config with industry prompts, A/B testing, and voice selection |
| [custom_path.rb](custom_path.rb) | Agent with a custom HTTP path (`/chat`) and query-param personalisation |
| [declarative.rb](declarative.rb) | Declarative agent config with prompt sections, post-prompt, and summary callback |
| [multi_agent_server.rb](multi_agent_server.rb) | Three agents (sales, support, receptionist) hosted on one AgentServer |
| [multi_endpoint.rb](multi_endpoint.rb) | Multiple SWML routes (`/voice`, `/info`) on a single AgentServer |
| [contexts_demo.rb](contexts_demo.rb) | Multi-step workflows using the contexts and steps system |
| [gather_info.rb](gather_info.rb) | GatherInfo in steps for structured data collection (patient intake) |
| [datamap_demo.rb](datamap_demo.rb) | Server-side DataMap tools (weather API, calculator, jokes) |
| [advanced_datamap.rb](advanced_datamap.rb) | Advanced DataMap patterns: expressions, webhooks, form encoding, foreach |
| [skills_demo.rb](skills_demo.rb) | Built-in skills: datetime, math, and joke |
| [session_state.rb](session_state.rb) | Global data, post-prompt analysis, and on_summary callback |
| [call_flow.rb](call_flow.rb) | Verb management (pre-answer, post-answer, post-AI), recording, debug events |
| [llm_params.rb](llm_params.rb) | LLM parameter tuning: precise, creative, and customer-service personalities |
| [kubernetes.rb](kubernetes.rb) | K8s-ready agent with /health, /ready, environment-based port |
| [lambda_agent.rb](lambda_agent.rb) | Serverless pattern: agent with exportable Rack app for Lambda/Cloud Functions |

## Skill Examples

| File | Description |
|------|-------------|
| [joke_agent.rb](joke_agent.rb) | Joke skill integration (requires `API_NINJAS_KEY`) |
| [joke_skill.rb](joke_skill.rb) | Joke skill via the modular skills system with DataMap |
| [web_search.rb](web_search.rb) | Web search skill via Google Custom Search API |
| [web_search_multi_instance.rb](web_search_multi_instance.rb) | Multiple web search instances (general, news, quick) |
| [wikipedia.rb](wikipedia.rb) | Wikipedia search skill for factual information retrieval |
| [datasphere.rb](datasphere.rb) | DataSphere skill with multiple instances and custom tool names |
| [datasphere_multi_instance.rb](datasphere_multi_instance.rb) | DataSphere multi-instance with custom tool names |
| [datasphere_serverless_env.rb](datasphere_serverless_env.rb) | DataSphere serverless from environment variables |
| [datasphere_webhook_env.rb](datasphere_webhook_env.rb) | Webhook-based DataSphere from environment variables |
| [mcp_gateway.rb](mcp_gateway.rb) | MCP gateway skill connecting to Model Context Protocol servers |

## Prefab Examples

| File | Description |
|------|-------------|
| [dynamic_info_gatherer.rb](dynamic_info_gatherer.rb) | Dynamic InfoGatherer with callback-based question selection |
| [prefab_info_gatherer.rb](prefab_info_gatherer.rb) | InfoGatherer prefab: collect structured answers from callers |
| [prefab_survey.rb](prefab_survey.rb) | Survey prefab: conduct automated phone surveys with ratings and open-ended questions |
| [concierge.rb](concierge.rb) | ConciergeAgent prefab: hotel virtual concierge with amenity/service lookups |
| [receptionist.rb](receptionist.rb) | ReceptionistAgent prefab: call routing with department transfers |
| [faq_bot.rb](faq_bot.rb) | FAQBotAgent prefab: answer questions from a pre-defined knowledge base |

## SWML Service Examples

| File | Description |
|------|-------------|
| [auto_vivified.rb](auto_vivified.rb) | Auto-vivified verb methods on SWMLService |
| [swml_service.rb](swml_service.rb) | Basic SWMLService (non-AI): voicemail, recording, and call transfer |
| [dynamic_swml_service.rb](dynamic_swml_service.rb) | Dynamic SWML service with routing callbacks for VIP/new callers |
| [swml_service_routing.rb](swml_service_routing.rb) | SWML service with sub-path routing (customer, product) |

## FunctionResult Action Examples

| File | Description |
|------|-------------|
| [swaig_features.rb](swaig_features.rb) | FunctionResult actions: connect, hangup, hold, say, metadata, SMS, chaining |
| [record_call.rb](record_call.rb) | Call recording: start, stop, voicemail, compliance workflows |
| [room_and_sip.rb](room_and_sip.rb) | Room joining, SIP REFER transfers, and ad-hoc conferences |
| [tap.rb](tap.rb) | TAP configuration: WebSocket/RTP monitoring, multi-stream management |

## Client Examples

| File | Description |
|------|-------------|
| [relay_demo.rb](relay_demo.rb) | RELAY WebSocket client: answer calls, play TTS, record, handle messages |
| [rest_demo.rb](rest_demo.rb) | REST HTTP client: manage AI agents, phone numbers, video rooms, queues |

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
ruby examples/relay_demo.rb

# For skill examples that require API keys:
API_NINJAS_KEY=your-key ruby examples/joke_agent.rb
```

## More Examples

Additional examples for the RELAY and REST clients are in their respective directories:

- [relay/examples/](../relay/examples/) -- RELAY WebSocket examples (answer, dial, IVR)
- [rest/examples/](../rest/examples/) -- REST API examples (all 12 namespaces)
