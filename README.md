# SignalWire AI Agents Ruby SDK

A Ruby framework for building, deploying, and managing AI agents as microservices that interact with the [SignalWire](https://signalwire.com) platform.

## Features

- **Agent Framework** — Build AI agents with structured prompts, tools, and skills
- **SWML Generation** — Automatic SWML document creation for the SignalWire AI platform
- **SWAIG Functions** — Define tools the AI can call during conversations
- **DataMap Tools** — Server-side API integrations without webhook infrastructure
- **Contexts & Steps** — Structured multi-step conversation workflows
- **Skills System** — Modular, reusable capabilities (datetime, math, web search, etc.)
- **Prefab Agents** — Ready-to-use agent patterns (surveys, reception, FAQ, etc.)
- **Multi-Agent Hosting** — Run multiple agents on a single server
- **RELAY Client** — Real-time WebSocket-based call control and messaging
- **REST Client** — Full SignalWire REST API access with typed resources
- **Rack Compatible** — Run standalone or mount in Rails, Sinatra, or any Rack app

## Quick Start

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'my-agent')

agent.set_prompt_text("You are a helpful assistant.")

agent.define_tool(
  name: 'get_time',
  description: 'Get the current time',
  parameters: {}
) do |args, raw_data|
  SignalWire::FunctionResult.new("The current time is #{Time.now}")
end

agent.run
```

## Installation

```bash
gem install signalwire
```

Or in your Gemfile:

```ruby
gem 'signalwire'
```

## Rack / Rails Integration

```ruby
# config/routes.rb (Rails)
mount MyAgent.rack_app => '/agent'

# config.ru (Rack)
run MyAgent.rack_app
```

## Documentation

See the [docs/](docs/) directory for comprehensive guides.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `3000` |
| `SWML_BASIC_AUTH_USER` | Basic auth username | auto-generated |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password | auto-generated |
| `SWML_PROXY_URL_BASE` | Proxy/tunnel base URL | auto-detected |
| `SIGNALWIRE_PROJECT_ID` | Project ID for RELAY/REST | — |
| `SIGNALWIRE_API_TOKEN` | API token for RELAY/REST | — |
| `SIGNALWIRE_SPACE` | Space hostname | — |

## License

Copyright (c) SignalWire. All rights reserved.
