# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the SignalWire AI Agents SDK for Ruby -- a framework for building, deploying, and managing AI agents as microservices. The SDK provides tools for creating self-contained web applications that expose HTTP endpoints to interact with the SignalWire platform.

## Development Commands

### Testing
```bash
# Run all tests
rake test

# Run specific test files
ruby -Ilib:tests tests/unit/core/test_agent_base.rb

# Run with verbose output
rake test TESTOPTS="--verbose"

# Syntax-check a file
ruby -c lib/signalwire/agent/agent_base.rb
```

### Installation and Setup
```bash
# Install dependencies
bundle install

# Install the gem in development mode
gem build signalwire.gemspec && gem install signalwire-*.gem

# Or add to Gemfile:
#   gem 'signalwire', path: '.'
```

### CLI Tools
```bash
# Test SWAIG functions locally (from bin/)
ruby bin/swaig-test examples/simple_agent.rb --list-tools
ruby bin/swaig-test examples/simple_agent.rb --exec tool_name --param value

# Build search indexes
ruby bin/sw-search ./docs --output knowledge.swsearch
```

## Architecture Overview

### Core Components
1. **AgentBase** (`lib/signalwire/agent/agent_base.rb`) -- Base class for all AI agents
2. **SWMLService** (`lib/signalwire/swml/service.rb`) -- Foundation for SWML document management
3. **AgentServer** (`lib/signalwire/server/agent_server.rb`) -- Multi-agent hosting server
4. **Skills System** (`lib/signalwire/skills/`) -- Modular capabilities framework
5. **Contexts and Steps** (`lib/signalwire/contexts/context_builder.rb`) -- Structured workflow management
6. **DataMap Tools** (`lib/signalwire/datamap/data_map.rb`) -- Server-side API integration without webhooks
7. **RELAY Client** (`lib/signalwire/relay/`) -- Real-time call control over WebSocket
8. **REST Client** (`lib/signalwire/rest/`) -- Synchronous REST API for all SignalWire resources

### Key Patterns

#### Agent Creation
Agents inherit from `SignalWire::AgentBase` and define:
- Prompt Object Model (POM) sections via `prompt_add_section`
- SWAIG functions via `define_tool` with block handlers
- Skills integration via `add_skill` method
- All configuration methods return `self` for chaining

#### Tool Definition
```ruby
agent.define_tool(
  name: 'get_weather',
  description: 'Get current weather',
  parameters: {
    'city' => { 'type' => 'string', 'description' => 'City name' }
  }
) do |args, raw_data|
  SignalWire::Swaig::FunctionResult.new("Weather in #{args['city']}: 72F")
end
```

#### Skills System
Skills are self-contained modules in `lib/signalwire/skills/builtin/`. Each skill:
- Inherits from `SkillBase`
- Implements `register_tools` method
- Has optional configuration via `params` hash
- Is loaded via `agent.add_skill('skill_name', config_hash)`

#### DataMap Tools
Server-side tools that execute on SignalWire servers:
```ruby
dm = SignalWire::DataMap.new('get_weather')
     .purpose('Get weather')
     .parameter('city', 'string', 'City name', required: true)
     .webhook('GET', 'https://api.weather.com?q=${args.city}')
     .output(SignalWire::Swaig::FunctionResult.new('Temp: ${response.temp}F'))
```

#### Contexts and Steps System
```ruby
ctx = agent.define_contexts.add_context('default')
step1 = ctx.add_step('greeting')
step1.set_text('Greet the user warmly.')
step1.set_valid_steps(['collect_info'])
```

### Module Structure
```
lib/signalwire/
    agent/agent_base.rb      # Central agent class
    swml/                    # SWML document and service
    swaig/function_result.rb # Tool response builder
    contexts/                # Context/step workflow system
    datamap/data_map.rb      # Server-side DataMap tools
    skills/                  # Skill base, manager, registry, builtins
    prefabs/                 # InfoGatherer, Survey, Receptionist, etc.
    relay/                   # RELAY WebSocket client
    rest/                    # REST HTTP client with namespaces
    server/agent_server.rb   # Multi-agent hosting
    security/                # Session management
    logging.rb               # Logging utilities
    version.rb               # Version constant
```

### Testing Architecture
- Unit tests in `tests/unit/` organized by component
- Uses Minitest (stdlib)
- Test fixtures in `tests/conftest.rb` (if present)
- Syntax validation: `ruby -c <file>`

### RELAY Client
- WebSocket + JSON-RPC 2.0 protocol for real-time call control
- Thread-based (not async) -- uses `Mutex` and `ConditionVariable`
- Supports inbound/outbound calls, messaging, DTMF, recording, etc.
- Auto-reconnect with exponential backoff

### REST Client
- Synchronous HTTP client with `net/http`
- Namespaced sub-objects: `client.fabric`, `client.calling`, `client.video`, etc.
- Returns plain Hashes (parsed JSON), no wrapper objects
- Covers all SignalWire APIs: Fabric, Calling, Video, Datasphere, Compat, etc.

## Important Implementation Notes

### Ruby Idioms
- Use blocks for tool handlers (not lambdas or procs, though those work too)
- All mutator methods return `self` for fluent chaining
- String keys in hashes (matches JSON serialization)
- `FunctionResult` uses the builder pattern with chainable methods

### Agent Lifecycle
- `agent.run` or `agent.serve` starts a WEBrick HTTP server (blocking)
- `agent.rack_app` returns a Rack-compatible app for custom mounting
- `AgentServer` hosts multiple agents on a single port

### Security
- Basic auth auto-generated unless `SWML_BASIC_AUTH_USER`/`SWML_BASIC_AUTH_PASSWORD` set
- Timing-safe comparison via `Rack::Utils.secure_compare`
- Session management via `SessionManager`

### Deployment
- Local development: `agent.run` (WEBrick)
- Multi-agent: `AgentServer.new.register(agent).run`
- Production: Mount `agent.rack_app` in Puma/Unicorn/Falcon

## Common Development Workflows

### Adding New Skills
1. Create file in `lib/signalwire/skills/builtin/`
2. Implement skill class inheriting from `SkillBase`
3. Define `SKILL_NAME`, `SKILL_DESCRIPTION`
4. Implement `setup` (returns bool) and `register_tools`
5. Add tests in `tests/unit/skills/`

### Testing Agents
1. Syntax check: `ruby -c examples/my_agent.rb`
2. Use `swaig-test` for local function testing
3. Test SWML generation by calling `agent.render_swml`
4. Use `rake test` for the full test suite
