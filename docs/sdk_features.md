# SignalWire AI Agents SDK: Why the SDK, Not Raw SWML

<!-- snippet-setup: every ruby example on this page assumes the SDK (and, for the prefab examples, the prefab classes) is required; supply demo Google creds so the web_search skill's presence check passes -->
```ruby
require 'signalwire'
require 'signalwire/prefabs/info_gatherer'
require 'signalwire/prefabs/receptionist'
ENV['GOOGLE_SEARCH_API_KEY']   ||= 'demo-key'
ENV['GOOGLE_SEARCH_ENGINE_ID'] ||= 'demo-engine-id'
```

## The Problem with Raw SWML

SWML (SignalWire Markup Language) is a JSON document format that defines how an agent behaves during a call -- 30+ verbs, an AI verb with dozens of parameters, SWAIG (SignalWire AI Gateway) function definitions with JSON Schema, post-prompt URLs, webhook authentication, language arrays, pronunciation rules, hints, global data, contexts, steps, gather configs. Writing it by hand means constructing deeply nested JSON, manually building authenticated webhook URLs, hand-coding parameter schemas, and deploying separate webhook servers for your tools. Every agent becomes a bespoke JSON engineering project.

The SDK eliminates all of this. You write Ruby. The SDK generates correct SWML, serves it over HTTP, and handles its own webhook callbacks -- all in one process, deployable to any platform.

---

## The Self-Referencing Pipeline

The SDK's core architectural insight is that the agent is both the **SWML generator** and the **SWAIG webhook handler** in a single stateless microservice.

```
SignalWire requests SWML → Agent generates document
  ↓
SWML contains webhook URLs → URLs point back to the agent itself
  ↓
AI calls a function → SignalWire POSTs to agent's /swaig/ endpoint
  ↓
Agent executes function locally → Returns result to AI
  ↓
Call ends → SignalWire POSTs analytics to agent's /post_prompt/ endpoint
```

The agent auto-detects its own public URL -- including behind ngrok, load balancers, API Gateway, or any reverse proxy (via `X-Forwarded-Host`, `Forwarded` header, or `SWML_PROXY_URL_BASE` env var). It embeds Basic Auth credentials directly into the webhook URLs. It generates per-call security tokens for each function. The developer writes none of this:

<!-- snippet: no-run ends by starting a blocking server (agent.run / server.run) -->
```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'weather', route: '/weather')
agent.prompt_add_section('Role', 'You help with weather.')

agent.define_tool(
  name:        'get_weather',
  description: 'Get weather',
  parameters:  {
    'city' => { 'type' => 'string', 'description' => 'The city to look up' }
  }
) do |args, _raw_data|
  city = args['city']
  # ... fetch weather ...
  SignalWire::Swaig::FunctionResult.new("72F and sunny in #{city}")
end

agent.run
```

That's a complete agent: HTTP server, SWML generation, authenticated webhook routing, function execution, and response formatting. The generated SWML contains the full AI configuration, function schemas, and webhook URLs pointing back to the running process -- all computed automatically.

---

## Prompt Object Model (POM)

Raw SWML prompts are flat strings. The SDK provides structured prompt building:

```ruby
agent.prompt_add_section('Role', 'You are a travel booking assistant.')
agent.prompt_add_section('Rules', nil,
    bullets: ['Never make up flight information',
              'Always confirm before booking',
              'Use the search tool for real data'])
agent.prompt_add_section('Personality', 'Friendly but professional.')
```

POM sections are rendered by the platform into a format the LLM understands with proper hierarchy. You can add subsections, append to existing sections, check if sections exist, and compose prompts programmatically -- including from skills that inject their own sections.

---

## Tools: Three Ways

### 1. Block-Defined Functions (Local Execution)

```ruby
agent.define_tool(
  name:        'lookup_order',
  description: 'Look up an order',
  parameters:  {
    'order_id' => { 'type' => 'string', 'description' => 'The order ID to look up' }
  }
) do |args, _raw_data|
  order  = db.get(args['order_id'])
  result = SignalWire::Swaig::FunctionResult.new("Order #{order.id}: #{order.status}")
  result.update_global_data('current_order' => order.to_h)
  result
end
```

The SDK converts this into a SWAIG function definition with JSON Schema parameters, creates a secure webhook URL, routes inbound POST requests to the handler, parses arguments, and formats the response -- including the 20+ SWAIG actions (transfer, hold, context_switch, toggle_functions, etc.) that tools can return.

In the Ruby SDK you always declare the parameter schema explicitly via the `parameters:` keyword, as shown above. (The Python reference also offers inferring the schema from function type hints and docstrings; Ruby has no equivalent introspection, so the `parameters:` hash is the single source of truth for a tool's arguments.)

### 2. DataMap (Server-Side Execution)

```ruby
data_map = SignalWire::DataMap.new('check_stock')
           .purpose('Check product stock levels')
           .parameter('sku', 'string', 'Product SKU', required: true)
           .webhook('GET', 'https://api.warehouse.com/stock/${args.sku}')
           .output(SignalWire::Swaig::FunctionResult.new('Stock for ${args.sku}: ${response.quantity} units'))
           .fallback_output(SignalWire::Swaig::FunctionResult.new('Could not check stock right now'))

agent.register_swaig_function(data_map.to_swaig_function)
```

DataMap tools execute on SignalWire's servers -- no webhook needed. The SDK generates the `data_map` structure in the SWML with variable expansion (`${args.*}`, `${response.*}`, `${global_data.*}`), foreach iteration, expression matching, and error handling. Your agent never receives the callback; SignalWire handles the entire API call.

### 3. Skills (Packaged Integrations)

```ruby
agent.add_skill('web_search', 'api_key' => '...', 'engine_id' => '...')
agent.add_skill('datetime')
agent.add_skill('math')
```

One line. The skill auto-registers its tools, injects prompt sections, adds speech hints, and validates dependencies. No manual wiring.

---

## The Skills System

Skills are self-contained modules that package tools, prompts, hints, and configuration into a single `add_skill()` call. Each skill:

- Inherits from `SkillBase` with `setup` and `register_tools` methods
- Declares `required_env_vars` for dependency validation
- Calls `define_tool` to register SWAIG functions
- Can inject prompt sections via `get_prompt_sections`
- Can provide speech hints via `get_hints`
- Can contribute global data via `get_global_data`
- Supports multiple instances with different configs (e.g., two `web_search` skills with different engines)

**Built-in skills:** `datetime`, `math`, `web_search`, `wikipedia_search`, `weather_api`, `google_maps`, `datasphere`, `datasphere_serverless`, `native_vector_search`, `spider`, `mcp_gateway`, `swml_transfer`, `play_background_file`, `info_gatherer`, `api_ninjas_trivia`, `joke`, `claude_skills`.

The elegance is composability: skills don't know about each other, but they all register cleanly into the same agent. A single agent can combine web search, datetime, a custom booking tool, and a DataMap stock checker -- all declared as you configure the agent, all generating correct SWML with proper function definitions, all routed to the right handler.

---

## Contexts and Steps: Priming the State Machine

The contexts/steps system lets you define structured workflows declaratively. Instead of hoping the LLM follows instructions about conversation flow, you mechanically enforce it:

```ruby
ctx = agent.define_contexts

greeting = ctx.add_context('default')
step1 = greeting.add_step('welcome')
step1.text = 'Greet the user and ask how you can help.'
step1.valid_steps = %w[collect_info]
step1.functions = %w[check_hours]  # Only this tool available here

step2 = greeting.add_step('collect_info')
step2.text = "Collect the user's name and email."
step2.step_criteria = 'User has provided both name and email'
step2.set_gather_info(output_key: 'user_profile')
step2.add_gather_question(key: 'name',  question: 'What is your name?',  type: 'string')
step2.add_gather_question(key: 'email', question: 'What is your email?', type: 'string', confirm: true)
step2.valid_steps = %w[confirm]

step3 = greeting.add_step('confirm')
step3.text = 'Confirm the information and say goodbye.'
step3.functions = 'none'  # No tools -- just confirm and end
```

This generates SWML with a complete contexts/steps structure. The platform enforces navigation rules, restricts which functions are available at each step, collects structured data with typed questions and confirmation, and tracks transitions with trigger attribution in the enriched call_log. The LLM can't skip steps, can't call restricted tools, and can't navigate to disallowed contexts -- not because it was told not to, but because the mechanisms don't exist in its world. This is PGI (Programmatically Governed Inference) in practice.

**Multi-context** agents can define separate conversation modes (e.g., "sales" and "support") with isolated function sets, and use `set_valid_contexts()` to control switching. Context transitions support 4-mode reset (consolidate x full_reset) with conversation history summarization or archival.

---

## Programmatically Governed Inference (PGI)

The contexts/steps system is the SDK's implementation of a broader architectural discipline: **Programmatically Governed Inference**. PGI starts from a single design rule: *do not tell the AI anything it does not need to know.*

Current AI models are extraordinarily good at language -- understanding loosely phrased human input, mapping intent onto structured actions, and rendering system decisions back into natural speech. They are also inconsistent, non-deterministic, and prone to confident error. These are not bugs that will be fixed in the next model generation. They are properties of probabilistic inference itself. The industry's dominant response -- prompt harder and hope ("prompt and pray") -- treats the model as the brain of the system. PGI rejects this entirely. The model is not the brain. It is a controlled participant inside a deterministic system that was always in charge.

### The Four Layers

PGI is enforced through four layers of constraint, each operating independently. Only the first depends on the model's cooperation. The remaining three are mechanical.

**Layer 1: Semantic Constraints** -- The model receives a prompt describing its role and instructions for how to behave. This is the weakest layer; it depends on probabilistic compliance. PGI treats it as guidance, not enforcement. The remaining layers are the law.

**Layer 2: Schema Constraints** -- At each step, the model sees only the tools registered for that step. Tools belonging to other steps do not exist in its function schema. The model cannot call them, reference them, or reason about them. This is the difference between telling someone not to open a door and removing the door from the building.

**Layer 3: Transition Constraints** -- Each step defines which steps it can transition to. The platform validates every transition against this whitelist. The model cannot skip phases, loop back to completed steps, or jump to unreachable states. The conversational flow is governed by the same deterministic logic as any well-designed state machine.

**Layer 4: Execution Authority** -- When the model calls a tool, it is making a request, not issuing a command. The tool handler accesses authoritative state, applies business logic, and returns both a response for the model to speak and a set of actions for the platform to execute. The model does not update state. The model does not decide what happens next. The platform does.

### PGI in Practice: Blackjack

```ruby
betting = ctx.add_step('betting')
betting.functions = %w[place_bet]
betting.valid_steps = %w[playing]

playing = ctx.add_step('playing')
playing.functions = %w[hit stand double_down]
playing.valid_steps = %w[hand_complete]

lost = ctx.add_step('you_lost')
lost.functions = []
lost.valid_steps = []
```

During the betting step, the model can only call `place_bet`. It cannot deal cards, draw cards, or resolve hands because those functions are not in its schema. When the tool handler transitions to the playing step, `place_bet` disappears and `hit`, `stand`, `double_down` appear. The model's capabilities change not because it was told to behave differently, but because the available operations were mechanically replaced.

The `you_lost` step has zero functions and zero valid transitions. The game is over. A user can beg, negotiate, or attempt social engineering. None of it works, because the mechanism for continuing does not exist. There is nothing for the model to comply with or resist. The interaction is structurally complete.

The tool handler demonstrates execution authority -- the model has no idea a step change is about to happen:

```ruby
agent.define_tool(name: 'hit', description: 'Draw another card') do |_args, raw_data|
  game = raw_data['global_data']['game_state']
  card = game['deck'].pop
  game['player_hand'] << card
  score = calculate_hand(game['player_hand'])

  result = SignalWire::Swaig::FunctionResult.new(
    "You drew #{format_card(card)}. Your total is #{score}."
  )
  result.update_global_data('game_state' => game)

  result.swml_change_step('you_lost') if score > 21

  result
end
```

The model speaks the result. The platform changes the step. The model's world changes without its participation.

### Data Isolation

PGI extends to how data flows through the system. The model operates on a projection of reality, not the full truth. Authoritative state lives in structured data (`global_data`) that the model sees only in curated subsets. In a blackjack game, the model knows the player's chip count and visible cards. It does not know the deck composition, the dealer's hidden card, or the internal scoring calculations. In an ordering system, the model knows which items have been added. It does not know the internal pricing logic, tax calculations, or inventory state.

The model cannot hallucinate a price it has never seen. It cannot promise availability it has no knowledge of. It can only report what the system tells it to report.

### Why PGI, Not Guardrails

PGI produces a property that makes it fundamentally different from guardrails, output filtering, or any other containment strategy: **the model does not know it is being governed.** It does not know that other tools exist elsewhere in the system. It does not know that a state machine is managing the interaction. It sees its current world -- a prompt, a set of functions, a conversation history -- and operates within it. There is nothing to reason around, nothing to game, nothing to circumvent.

The strongest test of any PGI system: replace the model with a rigid scripted menu ("press 1 for tacos, press 2 for drinks") and the system would still produce correct outcomes. The tool handlers would still validate input, enforce business rules, and manage state. The experience would be worse, but every order would be accurate and every transition would follow the rules. The model makes the interaction natural. The software makes it correct. In a PGI system, those are independent properties.

The SDK's contexts/steps/function restrictions are the primitives that make PGI mechanical rather than aspirational. The developer defines steps, scopes tools to steps, declares transitions, and writes tool handlers that return structured results with platform actions. The platform enforces all of it. The developer brings domain expertise. The SDK provides the governance infrastructure.

---

## Deployment: One `run()` Call

<!-- snippet: no-run ends by starting a blocking server (agent.run / server.run) -->
```ruby
agent = SignalWire::AgentBase.new(name: 'my_agent', route: '/')
# ... configure prompt, tools, skills ...
agent.run
```

That single call auto-detects the environment and does the right thing:

| Environment | Detection | What Happens |
|-------------|-----------|--------------|
| **Standalone** | Default | Starts a WEBrick HTTP server (Rack) |
| **AWS Lambda** | `AWS_LAMBDA_FUNCTION_NAME` env var | Returns a Lambda-formatted response Hash |
| **CGI** | `GATEWAY_INTERFACE` env var | Reads the request env, writes the response to stdout |
| **Google Cloud Functions** | GCF environment markers | Detected by `Runtime`; served via the standard HTTP server |
| **Azure Functions** | Azure environment markers | Detected by `Runtime`; served via the standard HTTP server |

Each mode handles authentication differently (HTTP Basic Auth, API Gateway authorizers, function-level auth), constructs webhook URLs using the correct public endpoint, and formats request/response bodies per platform. You write one agent, deploy it anywhere.

In the Ruby port, `agent.run` ships dedicated request/response handling for **Lambda** and **CGI**; Google Cloud Functions and Azure Functions are recognised by the runtime detector but currently fall through to the standard HTTP server rather than emitting a platform-native response shape. (The Python reference additionally returns Flask-compatible and Azure `HttpResponse` objects for those two platforms.)

For standalone mode, the SDK provides:
- Kubernetes health (`/health`) and readiness (`/ready`) probes
- SSL/TLS support via the `serve(ssl_enabled:, ssl_cert:, ssl_key:)` keyword arguments
- Debug events endpoint (`/debug_events`) for inspection

(The Python reference additionally exposes SSL via `SWML_SSL_*` env vars and a CORS configuration option; the Ruby port has neither -- configure SSL through `serve` keyword arguments instead.)

---

## Multi-Agent Hosting

<!-- snippet: no-run ends by starting a blocking server (agent.run / server.run) -->
```ruby
require 'signalwire'

sales   = SignalWire::AgentBase.new(name: 'sales',   route: '/sales')
support = SignalWire::AgentBase.new(name: 'support', route: '/support')
triage  = SignalWire::AgentBase.new(name: 'triage',  route: '/triage')
# ... configure each agent's prompt, tools, skills ...

server = SignalWire::AgentServer.new(host: '0.0.0.0', port: 3000)
server.register(sales)
server.register(support)
server.register(triage)
server.run
```

One process, multiple agents, route-based dispatch. Each agent gets its own SWML endpoint and SWAIG callback routing. SIP routing can map usernames to specific agents.

---

## Dynamic Configuration and Multi-Tenancy

```ruby
agent.set_dynamic_config_callback do |_query_params, _body, headers, ephemeral|
  tenant = headers['X-Tenant-ID'] || 'default'
  config = load_tenant_config(tenant)
  ephemeral.prompt_add_section('Company', config['company_info'])
  ephemeral.global_data = { 'tenant_id' => tenant, 'tier' => config['tier'] }
  ephemeral.add_skill('advanced_search') if config['tier'] == 'premium'
end
```

Each inbound request creates an **ephemeral copy** of the agent. The callback customizes it per-request -- different prompts, skills, global data, languages, tools. The original agent is unchanged. This enables multi-tenancy from a single deployment: one agent instance serves hundreds of tenants with tailored behavior.

---

## Search

The Ruby port provides document search through the `native_vector_search` skill in
**remote (network) mode only**. The skill POSTs queries to a remote search server
over HTTP (using `net/http` from the standard library) and formats the returned
results for the agent. The Python reference's local/offline `.swsearch` index mode,
its index-building/document-processing pipeline, and the `sw-search` CLI are not
part of the Ruby gem -- run that pipeline (and the search server it feeds) from the
Python reference, then point the Ruby skill at the server.

**In agents:**
```ruby
agent.add_skill('native_vector_search',
  'remote_url'  => 'http://localhost:8001',
  'index_name'  => 'knowledge',
  'tool_name'   => 'search_docs',
  'description' => 'Search product documentation')
```

Supported skill parameters: `remote_url` (required), `index_name`, `tool_name`,
`description`, `count` (default 3), `similarity_threshold` (default 0.5), and
`hints`. No extra gems or install tiers are required.

---

## Prefab Agents

Production-ready patterns for common use cases:

```ruby
require 'signalwire'

# Collect structured data
gatherer = SignalWire::Prefabs::InfoGatherer.new(questions: [
  { 'key_name' => 'name',  'question_text' => 'What is your name?' },
  { 'key_name' => 'issue', 'question_text' => 'Describe your issue', 'confirm' => true }
])

# Route calls to departments
receptionist = SignalWire::Prefabs::Receptionist.new(departments: [
  { 'name' => 'Sales',   'number' => '+15551234567', 'description' => 'Product inquiries' },
  { 'name' => 'Support', 'number' => '+15559876543', 'description' => 'Technical help' }
])
```

In the Ruby port a prefab is a helper object rather than an `AgentBase` subclass: it produces the prompt sections, global data, and tool handlers that you wire into a plain `SignalWire::AgentBase.new(...)` for serving (the `examples/info_gatherer_example.rb` and `examples/receptionist_agent_example.rb` files show the full wiring).

Five prefabs: **InfoGatherer**, **Survey**, **Receptionist**, **FaqBot**, **Concierge**. Each generates complete SWML with appropriate prompts, tools, and workflows. You instantiate, customize, deploy.

---

## AI Configuration

Everything the platform supports, the SDK exposes as methods:

```ruby
# LLM tuning
agent.set_prompt_llm_params(temperature: 0.3, top_p: 0.9, barge_confidence: 0.7)

# Multi-language
agent.add_language('Spanish', 'es', 'google.es-ES-Neural2-A',
                   speech_fillers: ['Un momento...'], function_fillers: ['Buscando...'])

# Speech recognition
agent.add_hints(%w[SignalWire SWML SWAIG])
agent.add_pronunciation('SignalWire', 'Signal Wire')

# Vision, thinking, inner dialog
agent.params = { 'enable_vision' => true, 'vision_model' => 'gpt-4o' }
agent.params = { 'enable_thinking' => true, 'thinking_model' => 'o4-mini' }

# Interruption control
agent.set_params(
  'barge_match_string' => '^(stop|cancel|nevermind)$',
  'barge_min_words'    => 2,
  'barge_confidence'   => 0.8
)

# Native functions with custom fillers
agent.native_functions = %w[check_time wait_for_user]
agent.add_internal_filler('check_time', 'en', ['Let me check the time...'])

# Call recording -- enable when constructing the agent:
# SignalWire::AgentBase.new(name: 'my-agent', record_call: true)

# Call flow verbs
agent.add_pre_answer_verb('play', { 'url' => 'ringback.wav' })
agent.add_post_ai_verb('hangup', {})
```

Each of these would require understanding and manually constructing the correct SWML JSON structure. The SDK provides named methods with proper defaults.

---

## swaig-test CLI

Test without deploying:

```bash
# List available tools
swaig-test my_agent.rb --list-tools

# Execute a specific tool (function arguments are passed as --param key=value)
swaig-test my_agent.rb --exec get_weather --param city="San Francisco"

# Dump generated SWML for inspection
swaig-test my_agent.rb --dump-swml

# Test with serverless environment simulation
swaig-test my_agent.rb --simulate-serverless lambda --dump-swml

# Multi-agent: run the server, then target a specific agent's route by URL
swaig-test --url http://user:pass@localhost:3000/support --list-tools
swaig-test --url http://user:pass@localhost:3000/sales --exec check_inventory
```

The Ruby `swaig-test` simulates the `lambda` serverless platform and passes function arguments via repeatable `--param key=value` flags. (The Python reference also offers `--route` / `--agent-class` selectors for picking an agent out of a multi-agent file in-process; the Ruby CLI has no such selectors -- point `--url` at the running agent's route instead.)

---

## Authentication

The SDK handles auth automatically:

- **Auto-generated credentials:** If no env vars set, generates `user_XXXX` / random password and prints to console
- **Environment variables:** `SWML_BASIC_AUTH_USER` / `SWML_BASIC_AUTH_PASSWORD`
- **Embedded in URLs:** Webhook URLs include `user:pass@host` automatically
- **Per-function tokens:** Secure functions get `__token=...` query params with expiration
- **Platform-specific:** Auth is applied per execution mode -- the standard HTTP server and the Lambda/CGI handlers each enforce Basic Auth on inbound requests

---

## What You'd Have to Build Without the SDK

| Capability | Without SDK | With SDK |
|-----------|-------------|----------|
| SWML document | Hand-craft JSON | Auto-generated from Ruby |
| Webhook server | Build and deploy separately | Built into the agent process |
| URL routing | Manual Rack/WEBrick setup | Automatic route registration |
| Auth tokens | Manual JWT/token system | Auto-generated per call/function |
| Proxy detection | Parse headers yourself | Automatic (ngrok, LB, CDN) |
| Tool schemas | Write JSON Schema by hand | `define_tool` block |
| Serverless deploy | Platform-specific handler code | `agent.run` auto-detects |
| Multi-language | Manually construct language arrays | `add_language` one-liner |
| State machine | Manually build contexts JSON | Fluent `define_contexts` API |
| Structured data collection | Build gather configs by hand | `add_gather_question` chain |
| Search/RAG | Build entire pipeline | `add_skill('native_vector_search')` |
| Multi-agent | Separate deployments + router | `AgentServer` with route registration |
| Dynamic config | Custom middleware | `set_dynamic_config_callback` block |
| Post-call analytics | Parse raw webhook payload | `on_summary` callback |
| Health checks | Manual endpoints | Built-in `/health` and `/ready` |
| Call recording | Manual SWML verb insertion | `record_call: true` constructor option |
| SSL/TLS | Manual cert configuration | `serve(ssl_enabled:, ssl_cert:, ssl_key:)` |

The SDK turns what would be a multi-file infrastructure project into a few lines of Ruby. The SWML is correct by construction. The webhooks route themselves. The auth is automatic. The deployment is universal. The developer focuses on what the agent should *do*, not how to wire it together.
