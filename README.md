<!-- Header -->
<div align="center">
    <a href="https://signalwire.com" target="_blank">
        <img src="https://github.com/user-attachments/assets/0c8ed3b9-8c50-4dc6-9cc4-cc6cd137fd50" width="500" />
    </a>

# SignalWire SDK for Ruby

_Build AI voice agents, control live calls over WebSocket, and manage every SignalWire resource over REST -- all from one gem._

<p align="center">
  <a href="https://developer.signalwire.com/sdks/agents-sdk" target="_blank">Documentation</a> &middot;
  <a href="https://github.com/signalwire/signalwire-docs/issues/new/choose" target="_blank">Report an Issue</a> &middot;
  <a href="https://rubygems.org/gems/signalwire-sdk" target="_blank">RubyGems</a>
</p>

<a href="https://discord.com/invite/F2WNYTNjuF" target="_blank"><img src="https://img.shields.io/badge/Discord%20Community-5865F2" alt="Discord" /></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/MIT-License-blue" alt="MIT License" /></a>
<a href="https://github.com/signalwire/signalwire-ruby" target="_blank"><img src="https://img.shields.io/github/stars/signalwire/signalwire-ruby" alt="GitHub Stars" /></a>

<a href="https://codespaces.new/signalwire/signalwire-ruby" target="_blank"><img src="https://github.com/codespaces/badge.svg" alt="Open in GitHub Codespaces" /></a>
<a href="https://replit.com/new/github/signalwire/signalwire-ruby" target="_blank"><img src="https://replit.com/badge/github/signalwire/signalwire-ruby" alt="Run on Replit" /></a>

</div>

---

## What's in this SDK

| Capability | What it does | Quick link |
|-----------|-------------|------------|
| **AI Agents** | Build voice agents that handle calls autonomously -- the platform runs the AI pipeline, your code defines the persona, tools, and call flow | [Agent Guide](#ai-agents) |
| **RELAY Client** | Control live calls and SMS/MMS in real time over WebSocket -- answer, play, record, collect DTMF, conference, transfer, and more | [RELAY docs](relay/README.md) |
| **REST Client** | Manage SignalWire resources over HTTP -- phone numbers, SIP endpoints, Fabric AI agents, video rooms, messaging, and 18+ API namespaces | [REST docs](rest/README.md) |

```bash
gem install signalwire-sdk
```

> Published as `signalwire-sdk` on RubyGems. The require path is still `signalwire`, so `require 'signalwire'` works unchanged.

---

## AI Agents

Each agent is a self-contained microservice that generates [SWML](docs/swml_service_guide.md) (SignalWire Markup Language) and handles [SWAIG](docs/swaig_reference.md) (SignalWire AI Gateway) tool calls. The SignalWire platform runs the entire AI pipeline (STT, LLM, TTS) -- your agent just defines the behavior.

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'my-agent', route: '/')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')
agent.prompt_add_section('Role', 'You are a helpful assistant.')

agent.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new("The time is #{Time.now.strftime('%H:%M:%S')}")
end

agent.run
```

Test locally without running a server:

```bash
swaig-test my_agent.rb --list-tools
swaig-test my_agent.rb --dump-swml
swaig-test my_agent.rb --exec get_time
```

### Agent Features

- **Prompt Object Model (POM)** -- structured prompt composition via `prompt_add_section`
- **SWAIG tools** -- define functions with `define_tool` and a block that the AI calls mid-conversation, with native access to the call's media stack
- **Skills system** -- add capabilities with one-liners: `agent.add_skill('datetime')`
- **Contexts and steps** -- structured multi-step workflows with navigation control
- **DataMap tools** -- tools that execute on SignalWire's servers, calling REST APIs without your own webhook
- **Dynamic configuration** -- per-request agent customization for multi-tenant deployments
- **Call flow control** -- pre-answer, post-answer, and post-AI verb insertion
- **Prefab agents** -- ready-to-use archetypes (InfoGatherer, Survey, FAQ, Receptionist, Concierge)
- **Multi-agent hosting** -- serve multiple agents on a single server with `AgentServer`
- **SIP routing** -- route SIP calls to agents based on usernames
- **Session state** -- persistent conversation state with global data and post-prompt summaries
- **Security** -- auto-generated basic auth, function-specific HMAC tokens, SSL support
- **Rack compatible** -- run standalone or mount in Rails, Sinatra, or any Rack app
- **Serverless** -- auto-detects Lambda, CGI, Google Cloud Functions, Azure Functions

### Agent Examples

The [`examples/`](examples/) directory contains 39 working examples:

| Example | What it demonstrates |
|---------|---------------------|
| [simple_agent.rb](examples/simple_agent.rb) | POM prompts, SWAIG tools, hints, language config, LLM tuning |
| [contexts_demo.rb](examples/contexts_demo.rb) | Multi-step workflow with context switching and step navigation |
| [datamap_demo.rb](examples/datamap_demo.rb) | Server-side API tools without webhooks |
| [skills_demo.rb](examples/skills_demo.rb) | Loading built-in skills (datetime, math, joke) |
| [call_flow.rb](examples/call_flow.rb) | Call flow verbs, debug events, recording workflows |
| [session_state.rb](examples/session_state.rb) | Global data, post-prompt analysis, on_summary callback |
| [multi_agent_server.rb](examples/multi_agent_server.rb) | Multiple agents on one server with AgentServer |
| [lambda_agent.rb](examples/lambda_agent.rb) | Serverless deployment with exportable Rack app |
| [comprehensive_dynamic.rb](examples/comprehensive_dynamic.rb) | Per-request dynamic configuration, multi-tenant routing |

See [examples/README.md](examples/README.md) for the full list organized by category.

---

## RELAY Client

Real-time call control and messaging over WebSocket. The RELAY client connects to SignalWire via the Blade protocol and gives you threaded, imperative control over live phone calls and SMS/MMS.

```ruby
require 'signalwire'

client = SignalWire::Relay::Client.new(
  project:  'your-project-id',
  token:    'your-api-token',
  space:    'example.signalwire.com',
  contexts: ['default']
)

client.on_call do |call|
  call.answer
  action = call.play([{ 'type' => 'tts', 'params' => { 'text' => 'Welcome!' } }])
  action.wait
  call.hangup
end

client.run
```

- 57+ calling methods (play, record, collect, detect, tap, stream, AI, conferencing, and more)
- SMS/MMS messaging with delivery tracking
- Action objects with `wait`, `stop`, `pause`, `resume`
- Thread-safe with auto-reconnect and exponential backoff

See the **[RELAY documentation](relay/README.md)** for the full guide, API reference, and examples.

---

## REST Client

Synchronous REST client for managing SignalWire resources and controlling calls over HTTP. No WebSocket required.

```ruby
require 'signalwire'

client = SignalWire::REST::RestClient.new(
  project: 'your-project-id',
  token:   'your-api-token',
  host:    'example.signalwire.com'
)

client.fabric.ai_agents.create(name: 'Support Bot', prompt: { 'text' => 'You are helpful.' })
client.calling.play(call_id, play: [{ 'type' => 'tts', 'text' => 'Hello!' }])
client.phone_numbers.search(area_code: '512')
client.datasphere.documents.search(query_string: 'billing policy')
```

- 21 namespaced API surfaces: Fabric (13 resource types), Calling (37 commands), Video, Datasphere, Compat (Twilio-compatible), Phone Numbers, SIP, Queues, Recordings, and more
- Hash returns -- raw JSON, no wrapper objects to learn
- Single `RestClient` with namespaced sub-objects for every API

See the **[REST documentation](rest/README.md)** for the full guide, API reference, and examples.

---

## Installation

```bash
# From RubyGems
gem install signalwire-sdk

# Or in your Gemfile
gem 'signalwire-sdk', require: 'signalwire'
```

Published as `signalwire-sdk` on RubyGems (the bare `signalwire` name belongs to the unrelated legacy SignalWire Ruby client). The `require:` hint keeps `require 'signalwire'` working unchanged.

Requires Ruby >= 3.0.

## Documentation

Full reference documentation is available at **[developer.signalwire.com/sdks/agents-sdk](https://developer.signalwire.com/sdks/agents-sdk)**.

Guides are also available in the [`docs/`](docs/) directory:

### Getting Started

- [Agent Guide](docs/agent_guide.md) -- creating agents, prompt configuration, dynamic setup
- [Architecture](docs/architecture.md) -- SDK architecture and core concepts
- [SDK Features](docs/sdk_features.md) -- feature overview, SDK vs raw SWML comparison

### Core Features

- [SWAIG Reference](docs/swaig_reference.md) -- function results, actions, post_data lifecycle
- [Contexts and Steps](docs/contexts_guide.md) -- structured workflows, navigation, gather mode
- [DataMap Guide](docs/datamap_guide.md) -- serverless API tools without webhooks
- [LLM Parameters](docs/llm_parameters.md) -- temperature, top_p, barge confidence tuning
- [SWML Service Guide](docs/swml_service_guide.md) -- low-level construction of SWML documents

### Skills and Extensions

- [Skills System](docs/skills_system.md) -- built-in skills and the modular framework
- [Third-Party Skills](docs/third_party_skills.md) -- creating and publishing custom skills
- [MCP Gateway](docs/mcp_gateway_reference.md) -- Model Context Protocol integration

### Deployment

- [CLI Guide](docs/cli_guide.md) -- `swaig-test` command reference
- [Cloud Functions](docs/cloud_functions_guide.md) -- Lambda, Cloud Functions, Azure deployment
- [Configuration](docs/configuration.md) -- environment variables, SSL, proxy setup
- [Security](docs/security.md) -- authentication and security model

### Reference

- [API Reference](docs/api_reference.md) -- complete class and method reference
- [Skills Parameter Schema](docs/skills_parameter_schema.md) -- skill parameter definitions

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `SIGNALWIRE_PROJECT_ID` | RELAY, REST | Project identifier |
| `SIGNALWIRE_API_TOKEN` | RELAY, REST | API token |
| `SIGNALWIRE_SPACE` | RELAY, REST | Space hostname (e.g. `example.signalwire.com`) |
| `SWML_BASIC_AUTH_USER` | Agents | Basic auth username (default: auto-generated) |
| `SWML_BASIC_AUTH_PASSWORD` | Agents | Basic auth password (default: auto-generated) |
| `SWML_PROXY_URL_BASE` | Agents | Base URL when behind a reverse proxy |
| `SWML_SSL_ENABLED` | Agents | Enable HTTPS (`true`, `1`, `yes`) |
| `SWML_SSL_CERT_PATH` | Agents | Path to SSL certificate |
| `SWML_SSL_KEY_PATH` | Agents | Path to SSL private key |
| `SIGNALWIRE_LOG_LEVEL` | All | Logging level (`debug`, `info`, `warn`, `error`) |
| `SIGNALWIRE_LOG_MODE` | All | Set to `off` to suppress all logging |

## Testing

```bash
# Install dev dependencies
bundle install

# Run the test suite
rake test

# Run by category
ruby -Ilib -Itest test/unit/**/*_test.rb
ruby -Ilib -Itest test/integration/**/*_test.rb

# Coverage
COVERAGE=1 rake test
```

## License

MIT -- see [LICENSE](LICENSE) for details.
