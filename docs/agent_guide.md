# SignalWire AI Agent Guide

## Table of Contents
- [Introduction](#introduction)
- [Architecture Overview](#architecture-overview)
- [Creating an Agent](#creating-an-agent)
- [Prompt Building](#prompt-building)
- [SWAIG Functions (SignalWire AI Gateway)](#swaig-functions)
- [Skills System](#skills-system)
- [Multilingual Support](#multilingual-support)
- [Agent Configuration](#agent-configuration)
- [Dynamic Agent Configuration](#dynamic-agent-configuration)
  - [Overview](#overview)
  - [Setting Up Dynamic Configuration](#setting-up-dynamic-configuration)
  - [Dynamic Configuration Methods](#dynamic-configuration-methods)
  - [Request Data Access](#request-data-access)
  - [Configuration Examples](#configuration-examples)
  - [Use Cases](#use-cases)
  - [Migration Guide](#migration-guide)
  - [Best Practices](#best-practices)
- [Advanced Features](#advanced-features)
  - [State Management](#state-management)
  - [SIP Routing](#sip-routing)
  - [Custom Routing](#custom-routing)
- [Prefab Agents](#prefab-agents)
- [API Reference](#api-reference)
- [Examples](#examples)

## Introduction

The `AgentBase` class provides the foundation for creating AI-powered agents using the SignalWire AI Agent SDK. It extends the `SWMLService` class, inheriting all its SWML (SignalWire Markup Language) document creation and serving capabilities, while adding AI-specific functionality. SWML is the JSON document format that tells the SignalWire platform how an agent should behave during a call.

Key features of `AgentBase` include:

- Structured prompt building with POM (Prompt Object Model)
- SWAIG (SignalWire AI Gateway) function definitions -- SWAIG is the platform's AI tool-calling system with native access to the media stack
- Multilingual support
- Agent configuration (hint handling, pronunciation rules, etc.)
- State management for conversations

This guide explains how to create and customize your own AI agents, with examples based on the SDK's sample implementations.

## Architecture Overview

The Agent SDK architecture consists of several layers:

1. **SWMLService**: The base layer for SWML document creation and serving
2. **AgentBase**: Extends SWMLService with AI agent functionality
3. **Custom Agents**: Your specific agent implementations that extend AgentBase

Here's how these components relate to each other:

```
┌─────────────┐
│ Your Agent  │ (Extends AgentBase with your specific functionality)
└─────▲───────┘
      │
┌─────┴───────┐
│  AgentBase  │ (Adds AI functionality to SWMLService)
└─────▲───────┘
      │
┌─────┴───────┐
│ SWMLService │ (Provides SWML document creation and web service)
└─────────────┘
```

## Creating an Agent

To create an agent, extend the `AgentBase` class and define your agent's behavior:

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:    'my-agent',
  route:   '/agent',
  host:    '0.0.0.0',
  port:    3000,
  use_pom: true # Enable Prompt Object Model
)

# Define agent personality and behavior
agent.prompt_add_section('Personality', 'You are a helpful and friendly assistant.')
agent.prompt_add_section('Goal', 'Help users with their questions and tasks.')
agent.prompt_add_section('Instructions', nil, bullets: [
  'Answer questions clearly and concisely',
  "If you don't know, say so",
  'Use the provided tools when appropriate'
])

# Add a post-prompt for summary
agent.post_prompt = 'Please summarize the key points of this conversation.'
```

## Running Your Agent

The SignalWire AI Agent SDK provides a `run()` method that automatically detects the execution environment and configures the agent appropriately. This method works across all deployment modes:

### Deployment with `run()`

```ruby
agent = SignalWire::AgentBase.new(name: 'my-agent', route: '/agent')

puts 'Starting agent server...'
puts 'Note: Works in any deployment mode (server/CGI/Lambda)'
agent.run # Auto-detects environment
```

The `run()` method automatically detects and configures for:

- **HTTP Server**: When run directly, starts an HTTP server
- **CGI**: When CGI environment variables are detected, operates in CGI mode  
- **AWS Lambda**: When Lambda environment is detected, configures for serverless execution

### Deployment Modes

#### HTTP Server Mode
When run directly (e.g., `ruby my_agent.rb`), the agent starts an HTTP server:

```ruby
# Automatically starts HTTP server when run directly
agent.run
```

#### CGI Mode  
When CGI environment variables are present, operates in CGI mode with clean HTTP output:

```ruby
# Same code - automatically detects CGI environment
agent.run
```

#### AWS Lambda Mode
When AWS Lambda environment is detected, configures for serverless execution:

```ruby
# Same code - automatically detects Lambda environment  
agent.run
```

### Environment Detection

The SDK automatically detects the execution environment:

| Environment | Detection Method | Behavior |
|-------------|------------------|----------|
| **HTTP Server** | Default when no serverless environment detected | Starts a Rack/WEBrick server on specified host/port |
| **CGI** | `GATEWAY_INTERFACE` environment variable present | Processes single CGI request and exits |
| **AWS Lambda** | `AWS_LAMBDA_FUNCTION_NAME` environment variable | Handles Lambda event/context |
| **Google Cloud** | `FUNCTION_NAME` or `K_SERVICE` variables | Processes Cloud Function request |
| **Azure Functions** | `AZURE_FUNCTIONS_*` variables | Handles Azure Function request |

### Logging Configuration

The SDK includes a central logging system that automatically configures based on the deployment environment:

```ruby
# Logging is automatically configured based on environment
# No manual setup required in most cases

# Optional: Override logging mode via environment variable
# SIGNALWIRE_LOG_MODE=off      # Disable all logging
# SIGNALWIRE_LOG_MODE=stderr   # Log to stderr
# SIGNALWIRE_LOG_MODE=default  # Use default logging
# SIGNALWIRE_LOG_MODE=auto     # Auto-detect (default)
# SIGNALWIRE_LOG_LEVEL=debug   # Set log verbosity
```

The logging system automatically:
- **CGI Mode**: Sets logging to 'off' to avoid interfering with HTTP headers
- **Lambda Mode**: Configures appropriate logging for serverless environment
- **Server Mode**: Uses structured logging with timestamps and levels
- **Debug Mode**: Enhanced logging when debug flags are set

## Prompt Building

There are several ways to build prompts for your agent:

### 1. Using Prompt Sections (POM)

The Prompt Object Model (POM) provides a structured way to build prompts:

```ruby
# Add a section with just body text
agent.prompt_add_section('Personality', 'You are a friendly assistant.')

# Add a section with bullet points
agent.prompt_add_section('Instructions', nil, bullets: [
  'Answer questions clearly',
  'Be helpful and polite',
  'Use functions when appropriate'
])

# Add a section with both body and bullets
agent.prompt_add_section('Context',
                         'The user is calling about technical support.',
                         bullets: ['They may need help with their account',
                                   'Check for existing tickets'])
```

### 2. Using Raw Text Prompts

For simpler agents, you can set the prompt directly as text:

```ruby
agent.set_prompt_text(<<~PROMPT)
  You are a helpful assistant. Your goal is to provide clear and concise information
  to the user. Answer their questions to the best of your ability.
PROMPT
```

### 3. Setting a Post-Prompt

The post-prompt is sent to the AI after the conversation for summary or analysis:

```ruby
agent.set_post_prompt(<<~POST)
  Analyze the conversation and extract:
  1. Main topics discussed
  2. Action items or follow-ups needed
  3. Whether the user's questions were answered satisfactorily
POST
```

## SWAIG Functions

SWAIG (SignalWire AI Gateway) functions allow the AI agent to perform actions and access external systems during a call. The AI decides when to call a function based on the conversation; SWAIG handles invocation, parameter passing, and delivering the result back to the AI. There are two types of SWAIG functions you can define:

### SWAIG functions ARE LLM tools — descriptions matter

Before writing your first SWAIG function, internalize this: a SWAIG function is **exactly the same concept** as a "tool" in native OpenAI / Anthropic tool calling. There is no separate "SWAIG layer" between your function and the model. Each SWAIG function is rendered into the OpenAI tool schema format on every turn:

```json
{
  "type": "function",
  "function": {
    "name":        "your_function_name",
    "description": "your description text",
    "parameters":  { /* your JSON schema */ }
  }
}
```

That schema is sent to the model as part of the same API call that produces the next assistant message. The model reads:

- the **function `description`** to decide WHEN to call this tool
- the **per-parameter `description` strings** inside `parameters` to decide HOW to fill in each argument

This means **descriptions are prompt engineering**, not developer documentation. They are not a comment for the next human reading the code — they are instructions to the LLM that directly determine whether the model picks your tool when the user's request matches it.

Compare:

| Bad (model often misses the tool) | Good (model picks it reliably) |
|---|---|
| `description: "Lookup function"` | `description: "Look up a customer's account details by their account number. Use this BEFORE quoting any account-specific information (balance, plan, status, billing date). Don't use it for general product questions."` |
| `description: "the id"` (parameter) | `description: "The customer's 8-digit account number, no dashes or spaces. Ask the user if they don't provide it."` |

A vague description is the #1 cause of "the model has the right tool but doesn't call it" failures. When you find yourself debugging why the model isn't picking a tool that obviously matches the user's request, the first thing to check is whether the description tells the model — in plain language — when to use it and what makes it the right choice over sibling tools.

**Tool count matters too.** LLM tool selection accuracy degrades noticeably past ~7-8 simultaneously-active tools per call. If you have many tools, partition them across steps using `step.set_functions(...)` so only the relevant subset is active at any moment. See `contexts_guide.md` for the per-step whitelist mechanism.

### 1. Local Webhook Functions (Standard)

These are the traditional SWAIG functions that are handled locally by your agent:

```ruby
require 'signalwire'

agent.define_tool(
  name:        'get_weather',
  description: 'Get the current weather for a location',
  parameters:  {
    'location' => {
      'type'        => 'string',
      'description' => 'The city or location to get weather for'
    }
  },
  secure: true # Optional; pass secure: true to require a per-call token
) do |args, _raw_data|
  # Extract the location parameter
  location = args['location'] || 'Unknown location'

  # Here you would typically call a weather API
  # For this example, we'll return mock data
  weather_data = "It's sunny and 72°F in #{location}."

  # Return a FunctionResult
  SignalWire::Swaig::FunctionResult.new(weather_data)
end
```

### 2. External Webhook Functions

External webhook functions allow you to delegate function execution to external services instead of handling them locally. This is useful when you want to:
- Use existing web services or APIs directly
- Distribute function processing across multiple servers
- Integrate with third-party systems that provide their own endpoints

To create an external webhook function, pass a `webhook_url:` keyword to `define_tool`:

```ruby
agent.define_tool(
  name:        'get_weather_external',
  description: 'Get weather from external service',
  parameters:  {
    'location' => {
      'type'        => 'string',
      'description' => 'The city or location to get weather for'
    }
  },
  webhook_url: 'https://your-service.com/weather-endpoint'
) do |_args, _raw_data|
  # This block will never be called locally when webhook_url is provided.
  # The external service at webhook_url will receive the function call instead.
  SignalWire::Swaig::FunctionResult.new('This should not be reached for external webhooks')
end
```

#### How External Webhooks Work

When you specify a `webhook_url`:

1. **Function Registration**: The function is registered with your agent as usual
2. **SWML Generation**: The generated SWML includes the external webhook URL instead of your local endpoint
3. **SignalWire Processing**: When the AI calls the function, SignalWire makes an HTTP POST request directly to your external URL
4. **Payload Format**: The external service receives a JSON payload with the function call data:

```json
{
    "function": "get_weather_external",
    "argument": {
        "parsed": [{"location": "New York"}],
        "raw": "{\"location\": \"New York\"}"
    },
    "call_id": "abc123-def456-ghi789",
    "call": { /* call information */ },
    "vars": { /* call variables */ }
}
```

5. **Response Handling**: Your external service should return a JSON response that SignalWire will process.

#### Mixing Local and External Functions

You can mix both types of functions in the same agent:

```ruby
agent = SignalWire::AgentBase.new(name: 'hybrid-agent', route: '/hybrid')

# Local function - handled by this agent
agent.define_tool(
  name:        'get_help',
  description: 'Get help information',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new('I can help you with weather and news!')
end

# External function - handled by external service
agent.define_tool(
  name:        'get_weather',
  description: 'Get current weather',
  parameters:  {
    'location' => { 'type' => 'string', 'description' => 'City name' }
  },
  webhook_url: 'https://weather-service.com/api/weather'
) do |_args, _raw_data|
  # This won't be called for external webhooks
end

# Another external function - different service
agent.define_tool(
  name:        'get_news',
  description: 'Get latest news',
  parameters:  {
    'topic' => { 'type' => 'string', 'description' => 'News topic' }
  },
  webhook_url: 'https://news-service.com/api/news'
) do |_args, _raw_data|
  # This won't be called for external webhooks
end
```

#### Testing External Webhooks

You can test external webhook functions using the CLI tool:

```bash
# Test local function
swaig-test examples/my_agent.rb --exec get_help

# Test external webhook function
swaig-test examples/my_agent.rb --verbose --exec get_weather --param location "New York"

# List all functions with their types
swaig-test examples/my_agent.rb --list-tools
```

The CLI tool will automatically detect external webhook functions and make HTTP requests to the external services, simulating what SignalWire does in production.

### 3. Explicit Parameter Schemas

> **Ruby note:** the Python reference SDK can infer a function's JSON Schema from
> type hints, the docstring, and `Literal`/`Optional` annotations. Ruby has no
> equivalent type-hint reflection, so the Ruby port does not auto-infer
> schemas — you always pass an explicit `parameters:` hash to `define_tool`.
> The block always receives `|args, raw_data|`, so there is no special "typed
> handler" signature to learn.

Define the same weather tool by writing the schema explicitly:

```ruby
agent.define_tool(
  name:        'get_weather',
  description: 'Get the weather forecast.',
  parameters:  {
    'city'  => { 'type' => 'string', 'description' => 'Name of the city to look up' },
    'units' => {
      'type'        => 'string',
      'description' => 'Temperature units to use',
      'enum'        => %w[celsius fahrenheit]
    }
  }
) do |args, _raw_data|
  city  = args['city']  || 'unknown'
  units = args['units'] || 'celsius'
  SignalWire::Swaig::FunctionResult.new("It's sunny in #{city} (showing #{units})")
end
```

The first block argument (`args`) is a plain Hash of the parsed parameters. Map
Python's inferred types onto JSON Schema yourself:

| Desired type | JSON Schema `type` |
|---|---|
| string | `'string'` |
| integer | `'integer'` |
| float | `'number'` |
| boolean | `'boolean'` |
| array | `'array'` (with `'items'` if homogeneous) |
| object | `'object'` |
| one-of a fixed set | `'string'` with `'enum'` |

**Accessing raw_data:**

The second block argument carries the raw request data (call metadata, vars, etc.):

```ruby
agent.define_tool(
  name:        'check_call',
  description: 'Check the current call.',
  parameters:  {
    'query' => { 'type' => 'string', 'description' => 'What to check' }
  }
) do |args, raw_data|
  call_id = raw_data&.dig('call_id') || 'unknown'
  SignalWire::Swaig::FunctionResult.new("Call #{call_id}: query=#{args['query']}")
end
```

### Function Parameters

The parameters for a SWAIG function are defined using JSON Schema:

<!-- snippet: no-compile ruby keyword-argument/hash-pair shape fragment (bare label, not standalone) -->
```ruby
parameters: {
  'parameter_name' => {
    'type'        => 'string', # Can be string, number, integer, boolean, array, object
    'description' => 'Description of the parameter',
    # Optional attributes:
    'enum'        => %w[option1 option2], # For enumerated values
    'minimum'     => 0,                   # For numeric types
    'maximum'     => 100,                 # For numeric types
    'pattern'     => '^[A-Z]+$'           # For string validation
  }
}
```

### Function Results

To return results from a SWAIG function, use the `SignalWire::Swaig::FunctionResult` class:

```ruby
# Basic result with just text
SignalWire::Swaig::FunctionResult.new("Here's the result")

# Result with a single action
SignalWire::Swaig::FunctionResult.new("Here's the result with an action")
                                 .add_action('say', 'I found the information you requested.')

# Result with multiple actions using add_actions
SignalWire::Swaig::FunctionResult.new('Multiple actions example')
                                 .add_actions([
                                   { 'playback_bg' => { 'file' => 'https://example.com/music.mp3' } },
                                   { 'set_global_data' => { 'key' => 'value' } }
                                 ])

# Alternative way to add multiple actions sequentially
SignalWire::Swaig::FunctionResult.new('Sequential actions example')
                                 .add_action('say', 'I found the information you requested.')
                                 .add_action('playback_bg', { 'file' => 'https://example.com/music.mp3' })
```

In the examples above:
- `add_action(name, data)` adds a single action with the given name and data
- `add_actions(actions)` adds multiple actions at once from a list of action objects

### Native Functions

The agent can use SignalWire's built-in functions:

```ruby
# Enable native functions
agent.native_functions = %w[check_time wait_seconds]
```

### Function Includes

You can include functions from remote sources:

```ruby
# Include remote functions
agent.add_function_include(
  'https://api.example.com/functions',
  %w[get_weather get_news],
  meta_data: { 'session_id' => 'unique-session-123' } # Use for session tracking, NOT credentials
)
```

### SWAIG Function Security

The SDK implements an automated security mechanism for SWAIG functions to ensure that only authorized calls can be made to your functions. This is important because SWAIG functions often provide access to sensitive operations or data.

#### Token-Based Security

Pass `secure: true` to a function to enable token-based security (the Ruby port
defaults `secure:` to `false`, so opt in explicitly per function that needs it):

```ruby
agent.define_tool(
  name:        'get_account_details',
  description: 'Get customer account details',
  parameters:  { 'account_id' => { 'type' => 'string' } },
  secure:      true # Require a per-call token for this function
) do |args, raw_data|
  # Implementation
end
```

When a function is marked as secure:

1. The SDK automatically generates a secure token for each function when rendering the SWML document
2. The token is added to the function's URL as a query parameter: `?token=X2FiY2RlZmcuZ2V0X3RpbWUuMTcxOTMxNDI1...`
3. When the function is called, the token is validated before executing the function

These security tokens have important properties:
- **Completely stateless**: The system doesn't need to store tokens or track sessions
- **Self-contained**: Each token contains all information needed for validation
- **Function-specific**: A token for one function can't be used for another
- **Session-bound**: Tokens are tied to a specific call/session ID
- **Time-limited**: Tokens expire after a configurable duration (default: 60 minutes)
- **Cryptographically signed**: Tokens can't be tampered with or forged

This stateless design provides several benefits:
- **Server resilience**: Tokens remain valid even if the server restarts
- **No memory consumption**: No need to track sessions or store tokens in memory
- **High scalability**: Multiple servers can validate tokens without shared state
- **Load balancing**: Requests can be distributed across multiple servers freely

The token system secures both SWAIG functions and post-prompt endpoints:
- SWAIG function calls for interactive AI capabilities
- Post-prompt requests for receiving conversation summaries

You can leave token security off for functions that expose only public data
(this is the default in the Ruby port):

```ruby
agent.define_tool(
  name:        'get_public_information',
  description: "Get public information that doesn't require security",
  parameters:  {},
  secure:      false # No token required for this function
) do |args, raw_data|
  # Implementation
end
```

#### Token Expiration

The default token expiration is 60 minutes (3600 seconds), but you can configure this when initializing your agent:

```ruby
agent = SignalWire::AgentBase.new(
  name:              'my_agent',
  token_expiry_secs: 1800 # Set token expiration to 30 minutes
)
```

The expiration timer resets each time a function is successfully called, so as long as there is activity at least once within the expiration period, the tokens will remain valid throughout the entire conversation.

#### Custom Token Validation

You can override the default token validation by implementing your own `validate_tool_token` method in your custom agent class.

## Skills System

The Skills System allows you to extend your agents with reusable capabilities via one-liner calls. Skills are modular, reusable components that can be easily added to any agent and configured with parameters.

### Quick Start

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'skillful-agent', route: '/skillful')

# Add skills with one-liners
agent.add_skill('web_search') # Web search capability
agent.add_skill('datetime')   # Current date/time info
agent.add_skill('math')       # Mathematical calculations

# Configure skills with parameters
agent.add_skill('web_search', {
  'num_results' => 3,  # Get 3 search results instead of default 1
  'delay'       => 0.5 # Add delay between requests
})
```

### Available Built-in Skills

#### Web Search Skill (`web_search`)
Provides web search capabilities using Google Custom Search API with web scraping.

**Requirements:**
- Ruby standard library only (`net/http`, `json`, `uri`) — no extra gems needed

**Parameters:**
- `api_key` (required): Google Custom Search API key
- `search_engine_id` (required): Google Custom Search Engine ID
- `num_results` (default: 1): Number of search results to return
- `delay` (default: 0): Delay in seconds between requests
- `tool_name` (default: "web_search"): Custom name for the search tool
- `no_results_message` (default: "I couldn't find any results for '{query}'. This might be due to a very specific query or temporary issues. Try rephrasing your search or asking about a different topic."): Custom message to return when no search results are found. Use `{query}` as a placeholder for the search query.

**Multiple Instance Support:**
The web_search skill supports multiple instances with different search engines and tool names, allowing you to search different data sources:

**Example:**
```ruby
# Basic single instance
agent.add_skill('web_search', {
  'api_key'          => 'your-google-api-key',
  'search_engine_id' => 'your-search-engine-id'
})
# Creates tool: web_search

# Fast single result (previous default)
agent.add_skill('web_search', {
  'api_key'          => 'your-google-api-key',
  'search_engine_id' => 'your-search-engine-id',
  'num_results'      => 1,
  'delay'            => 0
})

# Multiple results with delay
agent.add_skill('web_search', {
  'api_key'          => 'your-google-api-key',
  'search_engine_id' => 'your-search-engine-id',
  'num_results'      => 5,
  'delay'            => 1.0
})

# Multiple instances with different search engines
agent.add_skill('web_search', {
  'api_key'          => 'your-google-api-key',
  'search_engine_id' => 'general-search-engine-id',
  'tool_name'        => 'search_general',
  'num_results'      => 1
})
# Creates tool: search_general

agent.add_skill('web_search', {
  'api_key'          => 'your-google-api-key',
  'search_engine_id' => 'news-search-engine-id',
  'tool_name'        => 'search_news',
  'num_results'      => 3,
  'delay'            => 0.5
})
# Creates tool: search_news

# Custom no results message
agent.add_skill('web_search', {
  'api_key'            => 'your-google-api-key',
  'search_engine_id'   => 'your-search-engine-id',
  'no_results_message' => "Sorry, I couldn't find information about '{query}'. Please try a different search term."
})
```

#### DateTime Skill (`datetime`)
Provides current date and time information with timezone support.

**Requirements:**
- Ruby standard library only (uses `Time`) — no extra gems needed

**Tools Added:**
- `get_current_time`: Get current time with optional timezone
- `get_current_date`: Get current date with optional timezone

**Example:**
```ruby
agent.add_skill('datetime')
# Agent can now tell users the current time and date
```

#### Math Skill (`math`)
Provides safe mathematical expression evaluation.

**Requirements:**
- None (uses built-in Ruby functionality)

**Tools Added:**
- `calculate`: Evaluate mathematical expressions safely

**Example:**
```ruby
agent.add_skill('math')
# Agent can now perform calculations like "2 + 3 * 4"
```

#### DataSphere Skill (`datasphere`)
Provides knowledge search capabilities using SignalWire DataSphere, a cloud-hosted document search and retrieval-augmented generation (RAG) service.

**Requirements:**
- Ruby standard library only (`net/http`) — no extra gems needed

**Parameters:**
- `space_name` (required): SignalWire space name
- `project_id` (required): SignalWire project ID 
- `token` (required): SignalWire authentication token
- `document_id` (required): DataSphere document ID to search
- `count` (default: 1): Number of search results to return
- `distance` (default: 3.0): Distance threshold for search matching
- `tags` (optional): List of tags to filter search results
- `language` (optional): Language code to limit search
- `pos_to_expand` (optional): List of parts of speech for synonym expansion (e.g., ["NOUN", "VERB"])
- `max_synonyms` (optional): Maximum number of synonyms to use for each word
- `tool_name` (default: "search_knowledge"): Custom name for the search tool
- `no_results_message` (default: "I couldn't find any relevant information for '{query}' in the knowledge base. Try rephrasing your question or asking about a different topic."): Custom message when no results found

**Multiple Instance Support:**
The DataSphere skill supports multiple instances with different tool names, allowing you to search multiple knowledge bases:

**Example:**
```ruby
# Basic single instance
agent.add_skill('datasphere', {
  'space_name'  => 'my-space',
  'project_id'  => 'my-project',
  'token'       => 'my-token',
  'document_id' => 'general-knowledge'
})
# Creates tool: search_knowledge

# Multiple instances for different knowledge bases
agent.add_skill('datasphere', {
  'space_name'  => 'my-space',
  'project_id'  => 'my-project',
  'token'       => 'my-token',
  'document_id' => 'product-docs',
  'tool_name'   => 'search_products',
  'tags'        => %w[Products Features],
  'count'       => 3
})
# Creates tool: search_products

agent.add_skill('datasphere', {
  'space_name'         => 'my-space',
  'project_id'         => 'my-project',
  'token'              => 'my-token',
  'document_id'        => 'support-kb',
  'tool_name'          => 'search_support',
  'no_results_message' => "I couldn't find support information about '{query}'. Try contacting our support team.",
  'distance'           => 5.0
})
# Creates tool: search_support
```

#### Native Vector Search Skill (`native_vector_search`)
Provides document search via a remote search server using vector similarity and
keyword search. The Ruby port implements **remote (network) mode only**: it POSTs
queries to a search server over HTTP using the Ruby standard library (`net/http`).
The Python reference's local/offline `.swsearch` index mode and the `sw-search`
index-building CLI are not part of the Ruby gem.

**Requirements:**
- A reachable search server URL (`remote_url`). No extra gems are required --
  the skill uses `net/http` from the standard library.

**Parameters:**
- `remote_url` (required): URL of the remote search server (e.g., "http://localhost:8001")
- `index_name` (optional): Index name on the remote server
- `tool_name` (default: "search_knowledge"): Custom name for the search tool
- `description` (optional): Tool description
- `count` (default: 3): Number of search results to return
- `similarity_threshold` (default: 0.5): Minimum similarity score for results
- `hints` (optional): Extra speech hints to merge into the agent's hint list

**Multiple Instance Support:**
The native vector search skill supports multiple instances with different servers/indexes and tool names:

**Example:**
```ruby
# Remote mode connecting to a search server (the only supported mode)
agent.add_skill('native_vector_search', {
  'tool_name'   => 'search_knowledge',
  'description' => 'Search the knowledge base',
  'remote_url'  => 'http://localhost:8001',
  'index_name'  => 'concepts',
  'count'       => 3
})
# Creates tool: search_knowledge

# A second instance against a different index/tool name
agent.add_skill('native_vector_search', {
  'tool_name'   => 'search_examples',
  'description' => 'Search code examples',
  'remote_url'  => 'http://localhost:8001',
  'index_name'  => 'examples'
})
# Creates tool: search_examples
```

### Skill Management

```ruby
# Check what skills are loaded
loaded_skills = agent.list_skills
puts "Loaded skills: #{loaded_skills.join(', ')}"

# Check if a specific skill is loaded (note the Ruby predicate `?`)
if agent.has_skill?('web_search')
  puts 'Web search is available'
end

# Remove a skill (if needed)
agent.remove_skill('math')
```

### Advanced Skill Configuration with swaig_fields

Skills support a special `swaig_fields` parameter that allows you to customize how SWAIG functions are registered. When you pass `'swaig_fields'` to a skill, `SkillBase` pops it out of the params and exposes it via the `swaig_fields` reader, so the skill can merge those fields into the tool definitions it registers (`define_tool` also accepts a `swaig_fields:` keyword for the same effect).

```ruby
# Add a skill with swaig_fields to customize SWAIG function properties
agent.add_skill('math', {
  'precision'    => 2, # Regular skill parameter
  'swaig_fields' => {  # Special fields merged into SWAIG function automatically
    'secure'  => false, # Override default security requirement
    'fillers' => {
      'en-US' => ['Let me calculate that...', 'Computing the result...'],
      'es-ES' => ['Déjame calcular eso...', 'Calculando el resultado...']
    }
  }
})

# Add web search with custom security and fillers
agent.add_skill('web_search', {
  'num_results'  => 3,
  'delay'        => 0.5,
  'swaig_fields' => {
    'secure'  => true, # Require authentication
    'fillers' => {
      'en-US' => ['Searching the web...', 'Looking that up...', 'Finding information...']
    }
  }
})
```

The `swaig_fields` can include any parameter accepted by `AgentBase.define_tool()`:
- `secure`: Boolean indicating if the function requires authentication
- `fillers`: Dictionary mapping language codes to arrays of filler phrases
- Any other fields supported by the SWAIG function system

**Implementation Note**: `SkillBase` stores `swaig_fields` in its `swaig_fields` reader (popped from the params hash in the constructor). When a skill registers tools through the agent's `define_tool`, pass `swaig_fields: swaig_fields` so those fields are merged into each tool definition.

### Error Handling

The skills system provides detailed error messages for common issues:

```ruby
begin
  agent.add_skill('web_search')
rescue ArgumentError => e
  puts "Failed to load skill: #{e.message}"
  # Output: "Failed to load skill 'web_search': Missing required environment variables: ['GOOGLE_SEARCH_API_KEY']"
end
```

### Creating Custom Skills

You can create your own skills by subclassing `SignalWire::Skills::SkillBase`.
Override the instance methods that describe the skill (`name`, `description`,
`version`, `required_env_vars`) and the hooks that wire it into an agent
(`setup`, `register_tools`, `get_hints`, `get_prompt_sections`,
`get_global_data`). Unlike the Python reference SDK — which reads class-level
constants and a `define_tool` wrapper — the Ruby skill returns an array of tool
definitions from `register_tools`:

```ruby
require 'signalwire'

class WeatherSkill < SignalWire::Skills::SkillBase
  def name;              'weather'; end
  def description;       'Get weather information for locations'; end
  def version;           '1.0.0'; end
  def required_env_vars; %w[WEATHER_API_KEY]; end

  # Setup the skill -- read params and validate before tools are registered.
  def setup
    @default_units = get_param('units', default: 'fahrenheit')
    @timeout       = get_param('timeout', default: 10)
    @api_key       = get_param('api_key', env_var: 'WEATHER_API_KEY')
    return false if @api_key.nil? || @api_key.empty?

    true
  end

  # Return an array of tool definitions; each handler is a block (proc).
  def register_tools
    [
      {
        name:        'get_weather',
        description: 'Get current weather for a location',
        parameters:  {
          'location' => { 'type' => 'string', 'description' => 'City or location name' },
          'units'    => {
            'type'        => 'string',
            'description' => 'Temperature units (fahrenheit or celsius)',
            'enum'        => %w[fahrenheit celsius]
          }
        },
        handler:     method(:handle_get_weather)
      }
    ]
  end

  # Handle weather requests.
  def handle_get_weather(args, _raw_data)
    location = args['location'].to_s
    units    = args['units'] || @default_units

    return SignalWire::Swaig::FunctionResult.new('Please provide a location') if location.empty?

    # Your weather API integration here
    weather_data = "Weather for #{location}: 72°F and sunny"
    SignalWire::Swaig::FunctionResult.new(weather_data)
  end

  # Return speech recognition hints.
  def get_hints
    %w[weather temperature forecast conditions]
  end

  # Return prompt sections to add to the agent.
  def get_prompt_sections
    [
      {
        'title'   => 'Weather Information',
        'body'    => 'You can provide current weather information for any location.',
        'bullets' => [
          'Use get_weather tool when users ask about weather',
          'Always specify the location clearly',
          'Include temperature and conditions in your response'
        ]
      }
    ]
  end
end
```

**Using the custom skill:**
```ruby
# Register the skill class once, then add it to your agent by name:
SignalWire.register_skill(WeatherSkill)

agent.add_skill('weather', {
  'units'   => 'celsius',
  'timeout' => 15
})
```

### Skills with Dynamic Configuration

Skills work with dynamic configuration:

```ruby
agent = SignalWire::AgentBase.new(name: 'dynamic-skill-agent')

agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Add different skills based on request parameters
  tier = query_params['tier'] || 'basic'

  # Basic skills for all users
  ephemeral.add_skill('datetime')
  ephemeral.add_skill('math')

  # Premium skills for premium users
  case tier
  when 'premium'
    ephemeral.add_skill('web_search', {
      'num_results' => 5,
      'delay'       => 0.5
    })
  when 'basic'
    ephemeral.add_skill('web_search', {
      'num_results' => 1,
      'delay'       => 0
    })
  end
end
```

### Best Practices

1. **Choose appropriate parameters**: Configure skills for your use case
   ```ruby
   # For speed (customer service)
   agent.add_skill('web_search', { 'num_results' => 1, 'delay' => 0 })

   # For research (detailed analysis)
   agent.add_skill('web_search', { 'num_results' => 5, 'delay' => 1.0 })
   ```

2. **Handle missing dependencies gracefully**:
   ```ruby
   begin
     agent.add_skill("web_search")
   rescue ArgumentError => e
     agent.logger.warn("Web search unavailable: #{e.message}")
     # Continue without web search capability
   end
   ```

3. **Document your custom skills**: Include clear descriptions and parameter documentation

4. **Test skills in isolation**: Create simple test scripts to verify skill functionality

For more detailed information about the skills system architecture and advanced customization, see the [Skills System Guide](skills_system.md).

## Multilingual Support

Agents can support multiple languages:

```ruby
# Add English language
agent.add_language(
  'English',
  'en-US',
  'en-US-Neural2-F',
  speech_fillers:   ['Let me think...', 'One moment please...'],
  function_fillers: ["I'm looking that up...", 'Let me check that...']
)

# Add Spanish language
agent.add_language(
  'Spanish',
  'es',
  'rime.spore:multilingual',
  speech_fillers: ['Un momento por favor...', 'Estoy pensando...']
)
```

### Voice Formats

There are different ways to specify voices:

```ruby
# Simple format
agent.add_language('English', 'en-US', 'en-US-Neural2-F')

# Explicit parameters with engine and model
agent.add_language(
  'British English',
  'en-GB',
  'spore',
  engine: 'rime',
  model:  'multilingual'
)

# Combined string format
agent.add_language('Spanish', 'es', 'rime.spore:multilingual')
```

## Agent Configuration

### Adding Hints

Hints help the AI understand certain terms better:

```ruby
# Simple hints (list of words)
agent.add_hints(%w[SignalWire SWML SWAIG])

# Pattern hint with replacement
agent.add_pattern_hint(
  hint:        'AI Agent',
  pattern:     'AI\\s+Agent',
  replace:     'A.I. Agent',
  ignore_case: true
)
```

### Adding Pronunciation Rules

Pronunciation rules help the AI speak certain terms correctly:

```ruby
# Add pronunciation rule
# (Ruby's add_pronunciation takes phrase, replacement, and an optional
#  language_code: keyword -- there is no ignore_case: keyword in this port.)
agent.add_pronunciation('API', 'A P I')
agent.add_pronunciation('SIP', 'sip')
```

### Setting AI Parameters

Configure various AI behavior parameters:

```ruby
# Set AI parameters
agent.set_params({
  'wait_for_user'         => false,
  'end_of_speech_timeout' => 1000,
  'ai_volume'             => 5,
  'languages_enabled'     => true,
  'local_tz'              => 'America/Los_Angeles'
})
```

### Setting Global Data

Provide global data for the AI to reference:

```ruby
# Set global data
agent.set_global_data({
  'company_name'       => 'SignalWire',
  'product'            => 'AI Agent SDK',
  'supported_features' => [
    'Voice AI',
    'Telephone integration',
    'SWAIG functions'
  ]
})
```

### Customizing LLM Parameters

The SDK provides methods to fine-tune the Language Model parameters for both the main prompt and post-prompt, giving you precise control over the AI's behavior:

```ruby
# Set LLM parameters for the main prompt
# These parameters are passed to the server which validates them based on the model
agent.set_prompt_llm_params(
  temperature:       0.7, # Controls randomness
  top_p:             0.9, # Nucleus sampling threshold
  barge_confidence:  0.6, # ASR confidence to interrupt
  presence_penalty:  0.0, # Penalizes token repetition
  frequency_penalty: 0.0  # Penalizes frequent word usage
)

# Set different parameters for the post-prompt
agent.set_post_prompt_llm_params(
  temperature: 0.3,  # Lower temperature for consistent summaries
  top_p:       0.95  # Slightly wider token selection
)
```

**Common Use Cases:**

- **Customer Service**: Low temperature (0.2-0.4) for consistent, professional responses
- **Creative Tasks**: Higher temperature (0.7-0.9) for varied, creative outputs
- **Technical Support**: Very low temperature (0.1-0.3) with high confidence for accuracy
- **General Assistant**: Medium temperature (0.5-0.7) for balanced interaction

For detailed information about each parameter and advanced tuning strategies, see [LLM Parameters Guide](llm_parameters.md).

## Dynamic Agent Configuration

Dynamic agent configuration allows you to configure agents per-request based on parameters from the HTTP request (query parameters, body data, headers). This enables patterns like multi-tenant applications, A/B testing, personalization, and localization.

### Overview

There are two main approaches to agent configuration:

#### Static Configuration (Traditional)
```ruby
agent = SignalWire::AgentBase.new(name: 'static-agent')

# Configuration happens once at startup
agent.add_language('English', 'en-US', 'rime.spore:mistv2')
agent.set_params({ 'end_of_speech_timeout' => 500 })
agent.prompt_add_section('Role', 'You are a customer service agent.')
agent.global_data = { 'service_level' => 'standard' }
```

**Pros**: Simple, fast, predictable
**Cons**: Same behavior for all users, requires separate agents for different configurations

#### Dynamic Configuration (New)
```ruby
agent = SignalWire::AgentBase.new(name: 'dynamic-agent')

# No static configuration - set up dynamic callback instead
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Configuration happens fresh for each request
  tier = query_params['tier'] || 'standard'

  if tier == 'premium'
    ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
    ephemeral.set_params({ 'end_of_speech_timeout' => 300 }) # Faster
    ephemeral.prompt_add_section('Role', 'You are a premium customer service agent.')
    ephemeral.global_data = { 'service_level' => 'premium' }
  else
    ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
    ephemeral.set_params({ 'end_of_speech_timeout' => 500 }) # Standard
    ephemeral.prompt_add_section('Role', 'You are a customer service agent.')
    ephemeral.global_data = { 'service_level' => 'standard' }
  end
end
```

**Pros**: Highly flexible, single agent serves multiple configurations, enables advanced use cases
**Cons**: Slightly more complex, configuration overhead per request

### Setting Up Dynamic Configuration

Use the `set_dynamic_config_callback()` method to register a callback function that will be called for each request:

```ruby
agent = SignalWire::AgentBase.new(name: 'my-agent', route: '/agent')

# Register the dynamic configuration callback. The block is called for
# every request to configure the agent and receives four arguments:
#
#   query_params (Hash):  Query string parameters from the URL
#   body         (Hash):  Parsed JSON body from POST requests
#   headers      (Hash):  HTTP headers from the request
#   ephemeral    (AgentBase): The per-request agent copy to configure
agent.set_dynamic_config_callback do |query_params, body, headers, ephemeral|
  # Your dynamic configuration logic here
end
```

The callback function receives four parameters:
- **query_params**: Dictionary of URL query parameters
- **body_params**: Dictionary of parsed JSON body (empty for GET requests)
- **headers**: Dictionary of HTTP headers
- **agent**: The agent instance to configure dynamically

### Dynamic Configuration Methods

The `agent` parameter in your callback is the actual agent instance, allowing you to use all the same configuration methods you would use during initialization:

#### Language Configuration
```ruby
# Add languages with voice configuration
agent.add_language('English', 'en-US', 'rime.spore:mistv2')
agent.add_language('Spanish', 'es-ES', 'rime.spore:mistv2')
```

#### Prompt Building
```ruby
# Add prompt sections
agent.prompt_add_section('Role', 'You are a helpful assistant.')
agent.prompt_add_section('Guidelines', nil, bullets: [
  'Be professional and courteous',
  'Provide accurate information',
  'Ask clarifying questions when needed'
])

# Set raw prompt text
agent.prompt_text = 'You are a specialized AI assistant...'

# Set post-prompt for summary
agent.post_prompt = 'Summarize the key points of this conversation.'
```

#### AI Parameters
```ruby
# Configure AI behavior
agent.set_params({
  'end_of_speech_timeout'  => 300,
  'attention_timeout'      => 20_000,
  'background_file_volume' => -30
})
```

#### Global Data
```ruby
# Set data available to the AI
agent.set_global_data({
  'customer_tier'    => 'premium',
  'features_enabled' => %w[advanced_support priority_queue],
  'session_info'     => { 'start_time' => '2024-01-01T00:00:00Z' }
})

# Update existing global data
agent.update_global_data({ 'additional_info' => 'value' })
```

#### Speech Recognition Hints
```ruby
# Add hints for better speech recognition
agent.add_hints(%w[SignalWire SWML API technical])
agent.add_pronunciation('API', 'A P I')
```

#### Function Configuration
```ruby
# Set native functions
agent.native_functions = %w[transfer hangup]

# Add function includes
agent.add_function_include(
  'https://api.example.com/functions',
  %w[get_account_info update_profile]
)
```

### Request Data Access

Your callback function receives detailed information about the incoming request:

#### Query Parameters
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Extract query parameters
  tier        = query_params['tier'] || 'standard'
  language    = query_params['language'] || 'en'
  customer_id = query_params['customer_id']
  debug       = (query_params['debug'] || '').downcase == 'true'

  # Use parameters for configuration
  ephemeral.set_params({ 'end_of_speech_timeout' => 300 }) if tier == 'premium'

  ephemeral.set_global_data({ 'customer_id' => customer_id }) if customer_id
end

# Request: GET /agent?tier=premium&language=es&customer_id=12345&debug=true
```

#### POST Body Parameters
```ruby
agent.set_dynamic_config_callback do |_query_params, body, _headers, ephemeral|
  # Extract from POST body
  user_profile = body['user_profile'] || {}
  preferences  = body['preferences'] || {}

  # Configure based on profile
  ephemeral.add_language('Spanish', 'es-ES', 'rime.spore:mistv2') if user_profile['language'] == 'es'

  ephemeral.set_params({ 'end_of_speech_timeout' => 200 }) if preferences['voice_speed'] == 'fast'
end

# Request: POST /agent with JSON body:
# {
#   "user_profile": {"language": "es", "region": "mx"},
#   "preferences": {"voice_speed": "fast", "tone": "formal"}
# }
```

#### HTTP Headers
```ruby
agent.set_dynamic_config_callback do |_query_params, _body, headers, ephemeral|
  # Extract headers
  user_agent = headers['user-agent'] || ''
  auth_token = headers['authorization'] || ''
  locale     = headers['accept-language'] || 'en-US'

  # Configure based on headers
  ephemeral.set_params({ 'end_of_speech_timeout' => 400 }) if user_agent.downcase.include?('mobile') # Longer for mobile

  ephemeral.add_language('Spanish', 'es-ES', 'rime.spore:mistv2') if locale.start_with?('es')
end
```

### Configuration Examples

#### Simple Multi-Tenant Configuration
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  tenant = query_params['tenant'] || 'default'

  # Tenant-specific configuration
  case tenant
  when 'healthcare'
    ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
    ephemeral.prompt_add_section('Compliance',
                                 'Follow HIPAA guidelines and maintain patient confidentiality.')
    ephemeral.set_global_data({
      'industry'         => 'healthcare',
      'compliance_level' => 'hipaa'
    })
  when 'finance'
    ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
    ephemeral.prompt_add_section('Compliance',
                                 'Follow financial regulations and protect sensitive data.')
    ephemeral.set_global_data({
      'industry'         => 'finance',
      'compliance_level' => 'pci'
    })
  end
end
```

#### Language and Localization
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  language = query_params['language'] || 'en'
  region   = query_params['region'] || 'us'

  # Configure language and voice
  case language
  when 'es'
    if region == 'mx'
      ephemeral.add_language('Spanish (Mexico)', 'es-MX', 'rime.spore:mistv2')
    else
      ephemeral.add_language('Spanish', 'es-ES', 'rime.spore:mistv2')
    end

    ephemeral.prompt_add_section('Language', 'Respond in Spanish.')
  when 'fr'
    ephemeral.add_language('French', 'fr-FR', 'rime.alois')
    ephemeral.prompt_add_section('Language', 'Respond in French.')
  else
    ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
  end

  # Regional customization
  currency = case region
             when 'us' then 'USD'
             when 'eu' then 'EUR'
             else 'MXN'
             end

  ephemeral.set_global_data({
    'language' => language,
    'region'   => region,
    'currency' => currency
  })
end
```

#### A/B Testing Configuration
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Determine test group (could be from query param, user ID hash, etc.)
  test_group = query_params['test_group'] || 'A'

  if test_group == 'A'
    # Control group - standard configuration
    ephemeral.set_params({ 'end_of_speech_timeout' => 500 })
    ephemeral.prompt_add_section('Style', 'Use a standard conversational approach.')
    ephemeral.set_global_data({ 'test_group' => 'A', 'features' => %w[basic] })
  else
    # Test group B - experimental features
    ephemeral.set_params({ 'end_of_speech_timeout' => 300 })
    ephemeral.prompt_add_section('Style',
                                 'Use an enhanced, more interactive conversational approach.')
    ephemeral.set_global_data({ 'test_group' => 'B', 'features' => %w[basic enhanced] })
  end
end
```

#### Customer Tier-Based Configuration
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  customer_id = query_params['customer_id']
  tier        = query_params['tier'] || 'standard'

  # Base configuration
  ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')

  # Tier-specific configuration
  features =
    case tier
    when 'enterprise'
      ephemeral.set_params({
        'end_of_speech_timeout' => 200,    # Fastest response
        'attention_timeout'     => 30_000  # Longest attention span
      })
      ephemeral.prompt_add_section('Service Level',
                                   'You provide white-glove enterprise support with priority handling.')
      %w[all_features dedicated_support custom_integration]
    when 'premium'
      ephemeral.set_params({
        'end_of_speech_timeout' => 300,
        'attention_timeout'     => 20_000
      })
      ephemeral.prompt_add_section('Service Level',
                                   'You provide premium support with enhanced features.')
      %w[premium_features priority_support]
    else
      ephemeral.set_params({
        'end_of_speech_timeout' => 500,
        'attention_timeout'     => 15_000
      })
      ephemeral.prompt_add_section('Service Level',
                                   'You provide standard customer support.')
      %w[basic_features]
    end

  # Set global data
  global_data = { 'tier' => tier, 'features' => features }
  global_data['customer_id'] = customer_id if customer_id
  ephemeral.set_global_data(global_data)
end
```

### Use Cases

#### Multi-Tenant SaaS Applications
Perfect for SaaS platforms where each customer needs different agent behavior:

```ruby
# Different tenants get different capabilities
# /agent?tenant=acme&industry=healthcare
# /agent?tenant=globex&industry=finance
```

Benefits:
- Single agent deployment serves all customers
- Tenant-specific branding and behavior
- Industry-specific compliance and terminology
- Custom feature sets per subscription level

#### A/B Testing and Experimentation
Test different agent configurations with real users:

```ruby
# Split traffic between different configurations
# /agent?test_group=A  (control)
# /agent?test_group=B  (experimental)
```

Benefits:
- Compare agent performance metrics
- Test new features with subset of users
- Gradual rollout of improvements
- Data-driven optimization

#### Personalization and User Preferences
Adapt agent behavior to individual user preferences:

```ruby
# Personalized based on user profile
# /agent?user_id=123&voice_speed=fast&formality=casual
```

Benefits:
- Improved user experience
- Accessibility support (voice speed, etc.)
- Cultural and linguistic adaptation
- Learning from user interactions

#### Geographic and Cultural Localization
Adapt to different regions and cultures:

```ruby
# Location-based configuration
# /agent?country=mx&language=es&timezone=America/Mexico_City
```

Benefits:
- Local language and dialect support
- Cultural appropriateness
- Regional business practices
- Time zone aware responses

### Migration Guide

#### Converting Static Agents to Dynamic

**Step 1: Move Configuration to Callback**

Before (Static):
```ruby
agent = SignalWire::AgentBase.new(name: 'my-agent')

# Static configuration
agent.add_language('English', 'en-US', 'rime.spore:mistv2')
agent.set_params({ 'end_of_speech_timeout' => 500 })
agent.prompt_add_section('Role', 'You are a helpful assistant.')
agent.global_data = { 'version' => '1.0' }
```

After (Dynamic):
```ruby
agent = SignalWire::AgentBase.new(name: 'my-agent')

# Set up dynamic configuration
agent.set_dynamic_config_callback do |_query_params, _body, _headers, ephemeral|
  # Same configuration, but now dynamic
  ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
  ephemeral.set_params({ 'end_of_speech_timeout' => 500 })
  ephemeral.prompt_add_section('Role', 'You are a helpful assistant.')
  ephemeral.global_data = { 'version' => '1.0' }
end
```

**Step 2: Add Parameter-Based Logic**

```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Start with base configuration
  ephemeral.add_language('English', 'en-US', 'rime.spore:mistv2')
  ephemeral.prompt_add_section('Role', 'You are a helpful assistant.')

  # Add parameter-based customization
  timeout = (query_params['timeout'] || '500').to_i
  ephemeral.set_params({ 'end_of_speech_timeout' => timeout })

  version = query_params['version'] || '1.0'
  ephemeral.global_data = { 'version' => version }
end
```

**Step 3: Test Both Approaches**

You can support both static and dynamic patterns during migration. Build a
configuration method you can call either eagerly (static) or from the dynamic
callback:

```ruby
def configure(target)
  # Original/shared configuration
  target.add_language('English', 'en-US', 'rime.spore:mistv2')
  # ... rest of config
end

agent = SignalWire::AgentBase.new(name: 'my-agent')

if use_dynamic
  agent.set_dynamic_config_callback do |_query_params, _body, _headers, ephemeral|
    configure(ephemeral) # New dynamic configuration
  end
else
  configure(agent) # Keep static configuration for backward compatibility
end
```

### Best Practices

#### Performance Considerations

1. **Keep Callbacks Lightweight**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Good: Simple parameter extraction and configuration
  tier = query_params['tier'] || 'standard'
  ephemeral.set_params(TIER_CONFIGS[tier])

  # Avoid: Heavy computation or external API calls
  # customer_data = expensive_api_call(customer_id) # Don't do this
end
```

2. **Cache Configuration Data**
```ruby
# Pre-compute configuration templates once, at load time
TIER_CONFIGS = {
  'basic'      => { 'end_of_speech_timeout' => 500 },
  'premium'    => { 'end_of_speech_timeout' => 300 },
  'enterprise' => { 'end_of_speech_timeout' => 200 }
}.freeze

agent = SignalWire::AgentBase.new(name: 'my-agent')

agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  tier = query_params['tier'] || 'basic'
  ephemeral.set_params(TIER_CONFIGS.fetch(tier, TIER_CONFIGS['basic']))
end
```

3. **Use Default Values**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Always provide defaults
  language = query_params['language'] || 'en'
  tier     = query_params['tier'] || 'standard'

  # Handle invalid values gracefully
  language = 'en' unless %w[en es fr].include?(language)
end
```

#### Security Considerations

1. **Validate Input Parameters**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Validate and sanitize inputs
  tier = query_params['tier'] || 'standard'
  tier = 'basic' unless %w[basic premium enterprise].include?(tier) # Safe default

  # Validate numeric parameters
  timeout =
    begin
      Integer(query_params['timeout'] || '500')
    rescue ArgumentError, TypeError
      500 # Safe default
    end
  timeout = timeout.clamp(100, 2000) # Clamp to reasonable range
end
```

2. **Protect Sensitive Configuration**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Don't expose internal configuration via parameters
  # Bad: ephemeral.set_global_data({ 'api_key' => query_params['api_key'] })

  # Good: Use internal mapping for call-related data only
  customer_id = query_params['customer_id']
  if customer_id && valid_customer?(customer_id)
    # Store call-related customer info, NOT sensitive credentials
    ephemeral.set_global_data({
      'customer_id'   => customer_id,
      'customer_tier' => customer_tier(customer_id),
      'account_type'  => 'premium'
    })
  end
end
```

3. **Rate Limiting for Complex Configurations**
```ruby
# Memoize expensive lookups in a process-level cache
CUSTOMER_CONFIG_CACHE = {}

def customer_config(customer_id)
  CUSTOMER_CONFIG_CACHE[customer_id] ||= database.customer_settings(customer_id)
end

agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  customer_id = query_params['customer_id']
  if customer_id
    config = customer_config(customer_id)
    ephemeral.set_global_data(config)
  end
end
```

#### Error Handling

1. **Graceful Degradation**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  begin
    # Try custom configuration
    apply_custom_config(query_params, ephemeral)
  rescue StandardError => e
    # Log error but don't fail the request
    agent.logger.error("config_error: #{e.message}")

    # Fall back to default configuration
    apply_default_config(ephemeral)
  end
end
```

2. **Configuration Validation**
```ruby
agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  # Validate required parameters. Use `next` (not `return`) to bail out of
  # the block early.
  if query_params['tenant'].nil? || query_params['tenant'].empty?
    ephemeral.set_global_data({ 'error' => 'Missing tenant parameter' })
    next
  end

  # Validate configuration makes sense
  language = query_params['language'] || 'en'
  region   = query_params['region'] || 'us'

  if language == 'es' && region == 'us'
    # Adjust for Spanish speakers in US
    ephemeral.add_language('Spanish (US)', 'es-US', 'rime.spore:mistv2')
  end
end
```

Dynamic agent configuration enables sophisticated, multi-tenant AI applications while maintaining the familiar AgentBase API. Start with simple parameter-based configuration and gradually add more complex logic as your use cases evolve.

## Advanced Features

### Debug Events

The debug events system provides real-time visibility into what the AI module is doing during a call. When enabled, the module POSTs structured JSON events to your agent throughout the call lifecycle — session start/end, barge interruptions, LLM errors, step changes, and more.

#### Basic Setup

```ruby
agent = SignalWire::AgentBase.new(name: 'my_agent')
agent.enable_debug_events # That's it — events are auto-logged
agent.serve
```

With just `enable_debug_events`, every debug event is logged through the agent's structured logger. No other configuration is needed — the SDK automatically:
- Registers a `/debug_events` endpoint on the agent
- Sets `debug_webhook_url` and `debug_webhook_level` in the SWML params
- Logs each incoming event with its type and payload

#### Custom Event Handler

To act on specific events (alerting, metrics, custom logging), register a handler:

```ruby
agent = SignalWire::AgentBase.new(name: 'my_agent')
agent.enable_debug_events

agent.on_debug_event do |event_type, data|
  call_id = data['call_id']

  case event_type
  when 'barge'
    puts "[#{call_id}] Caller interrupted after #{data['barge_elapsed_ms']}ms"
  when 'llm_error'
    puts "[#{call_id}] LLM error: #{data['event']}"
    alert_ops_team(data)
  when 'session_end'
    duration = (data['duration_ms'] || 0) / 1000.0
    puts format('[%s] Call ended after %.1fs — reason: %s', call_id, duration, data['reason'])
  end
end

agent.serve
```

The handler is called for every event in addition to the default structured logging.

#### Verbosity Levels

- **Level 1** (default): High-level events — session start/end, barge, errors, step changes, hold, filler, gather flow, action processing
- **Level 2+**: Adds high-volume events — every LLM request/response, conversation history additions

```ruby
agent.enable_debug_events(2) # Include LLM request/response events
```

For the complete list of event types and their payloads, see the [API Reference](api_reference.md#debug-events).

### Session Lifecycle Hooks

SignalWire provides special SWAIG functions that are automatically called at specific points during a voice session's lifecycle. These hooks enable you to perform initialization tasks when a call starts and cleanup tasks when a call ends.

#### Overview

Session lifecycle hooks are special SWAIG functions that SignalWire calls automatically:
- `startup_hook`: Called immediately when a new voice session begins
- `hangup_hook`: Called when a voice session ends (regardless of how it ended)

These hooks are particularly useful for:
- Initializing session state or resources
- Loading user preferences or history
- Logging session start/end events
- Cleaning up temporary resources
- Saving session data for analytics

#### Implementation

To implement lifecycle hooks, define them as regular SWAIG functions with these specific names:

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'my-agent')

# Shared session state captured by the hook blocks (one hash per process).
sessions = {}

agent.define_tool(
  name:        'startup_hook',
  description: 'Called when the voice session starts',
  parameters:  {}
) do |_args, raw_data|
  call_id     = raw_data['call_id']
  from_number = raw_data['from_number']
  to_number   = raw_data['to_number']

  # Initialize session state in the captured hash.
  sessions[call_id] = {
    session_start:     Time.now,
    from:              from_number,
    to:                to_number,
    interaction_count: 0
  }

  puts "Session started: #{call_id} from #{from_number}"

  SignalWire::Swaig::FunctionResult.new('Session initialized successfully')
end

agent.define_tool(
  name:        'hangup_hook',
  description: 'Called when the voice session ends',
  parameters:  {}
) do |_args, raw_data|
  call_id = raw_data['call_id']
  state   = sessions[call_id]

  if state
    duration = Time.now - state[:session_start]
    puts "Session ended: #{call_id}"
    puts "Duration: #{duration} seconds"
    puts "Interactions: #{state[:interaction_count]}"

    # Clean up session data.
    sessions.delete(call_id)
  end

  SignalWire::Swaig::FunctionResult.new('Session cleanup completed')
end
```

#### Common Use Cases

##### 1. User Preference Loading
```ruby
agent.define_tool(
  name:        'startup_hook',
  description: 'Called when the voice session starts',
  parameters:  {}
) do |_args, raw_data|
  caller_id = raw_data['from_number']

  # Application-specific: load preferences from your database.
  preferences = my_load_user_preferences(caller_id)

  # Store in the captured session hash for later turns.
  sessions[raw_data['call_id']] = {
    user_preferences: preferences,
    language:         preferences['language'] || 'en-US',
    previous_orders:  preferences['recent_orders'] || []
  }

  SignalWire::Swaig::FunctionResult.new('User preferences loaded')
end
```

##### 2. Analytics and Logging
```ruby
agent.define_tool(
  name:        'hangup_hook',
  description: 'Called when the voice session ends',
  parameters:  {}
) do |_args, raw_data|
  call_id = raw_data['call_id']
  state   = sessions[call_id] || {}

  analytics_data = {
    call_id:          call_id,
    duration:         state[:duration],
    functions_called: state.fetch(:functions_called, []),
    outcome:          state.fetch(:outcome, 'unknown')
  }

  # Application-specific: POST the hash to your analytics service.
  my_send_to_analytics(analytics_data)

  SignalWire::Swaig::FunctionResult.new('Analytics data sent')
end
```

#### Important Notes

1. **Function Names**: The hooks must be named exactly `startup_hook` and `hangup_hook` for SignalWire to call them
2. **Error Handling**: Always implement proper error handling in hooks - failures shouldn't crash the voice session
3. **Timing**: `startup_hook` is called before the AI starts speaking to the caller
4. **Session Data**: Any data you need to persist across the session should be stored in external storage (Redis, database, etc.)
5. **Return Values**: Both hooks must return a `SignalWire::Swaig::FunctionResult` object

### SIP Routing

SIP routing allows your agents to receive voice calls via SIP addresses. The SDK supports both individual agent-level routing and centralized server-level routing.

#### Individual Agent SIP Routing

Enable SIP routing on a single agent:

```ruby
# Enable SIP routing with automatic username mapping based on agent name
agent.enable_sip_routing(auto_map: true)

# Register additional SIP usernames for this agent
agent.register_sip_username('support_agent')
agent.register_sip_username('help_desk')
```

When `auto_map=True`, the agent automatically registers SIP usernames based on:
- The agent's name (e.g., `support@domain`)
- The agent's route path (e.g., `/support` becomes `support@domain`)
- Common variations (e.g., removing vowels for shorter dialing)

#### Server-Level SIP Routing (Multi-Agent)

For multi-agent setups, centralized routing is more efficient:

```ruby
# Create an AgentServer
server = SignalWire::AgentServer.new(host: '0.0.0.0', port: 3000)

# Register multiple agents
server.register(registration_agent) # Route: /register
server.register(support_agent)       # Route: /support

# Set up central SIP routing
server.setup_sip_routing(route: '/sip', auto_map: true)

# Register additional SIP username mappings
server.register_sip_username('signup', '/register')    # signup@domain → registration agent
server.register_sip_username('help', '/support')       # help@domain → support agent
```

With server-level routing:
- Each agent is reachable via its name (when `auto_map=True`)
- Additional SIP usernames can be mapped to specific agent routes
- All SIP routing is handled at a single endpoint (`/sip` by default)

#### How SIP Routing Works

1. A SIP call comes in with a username (e.g., `support@yourdomain`)
2. The SDK extracts the username part (`support`)
3. The system checks if this username is registered:
   - In individual routing: The current agent checks its own username list
   - In server routing: The server checks its central mapping table
4. If a match is found, the call is routed to the appropriate agent

### Custom Routing

You can dynamically handle requests to different paths using routing callbacks.
Register each callback with a block; the block receives the parsed
`request_data` Hash and returns either `nil` (process normally) or a Hash of
SWML modifications. Overriding `on_swml_request` is one of the few cases where
subclassing `SignalWire::AgentBase` is the right tool:

```ruby
class CustomAgent < SignalWire::AgentBase
  def initialize
    super(name: 'custom-agent')

    # Enable custom routing in the constructor or anytime after initialization
    register_routing_callback('/customer') do |request_data|
      # Extract any relevant data
      customer_id = request_data['customer_id']

      # You can redirect to another agent/service if needed
      if customer_id&.start_with?('vip-')
        next "/vip-handler/#{customer_id}"
      end

      # Or return nil to process the request with on_swml_request
      nil
    end

    register_routing_callback('/product') do |request_data|
      nil
    end
  end

  # Customize SWML based on the route in on_swml_request.
  def on_swml_request(request_data = nil, callback_path = nil, request: nil)
    if callback_path == '/customer'
      # Serve customer-specific content
      return {
        'sections' => {
          'main' => [
            { 'answer' => {} },
            { 'play' => { 'url' => 'say:Welcome to customer service!' } }
          ]
        }
      }
    end
    # Other path handling...
    nil
  end
end
```

### Customizing SWML Requests

You can modify the SWML document based on request data by overriding the
`on_swml_request` method in a subclass. Return `nil` to use the default
document, or a Hash of modifications to apply:

```ruby
class CustomAgent < SignalWire::AgentBase
  # Customize the SWML document based on request data.
  #
  #   request_data: The request data (body for POST or query params for GET)
  #   callback_path: The path that triggered the routing callback
  #
  # Returns nil (default document) or a Hash of modifications.
  def on_swml_request(request_data = nil, callback_path = nil, request: nil)
    if request_data && request_data.key?('caller_type')
      # Example: change the AI behavior based on caller type
      if request_data['caller_type'] == 'vip'
        return {
          'sections' => {
            'main' => [
              # Keep the first verb (answer)
              # Modify the AI verb parameters
              {
                'ai' => {
                  'params' => {
                    'wait_for_user'         => false,
                    'end_of_speech_timeout' => 500 # More responsive
                  }
                }
              }
            ]
          }
        }
      end
    end

    # You can also use the callback_path to serve different content based on the route
    if callback_path == '/customer'
      return {
        'sections' => {
          'main' => [
            { 'answer' => {} },
            { 'play' => { 'url' => 'say:Welcome to our customer service line.' } }
          ]
        }
      }
    end

    # Return nil to use the default document
    nil
  end
end
```

### Conversation Summary Handling

Process conversation summaries:

```ruby
def on_summary(summary, raw_data = nil)
  # summary:  Hash with the summary payload, or nil if no summary was found
  # raw_data: complete raw POST data from the request
  return unless summary

  # Log the summary
  logger.info("conversation_summary: #{summary.inspect}")

  # Save the summary to a database, send notifications, etc.
  # ...
end
```

### Custom Webhook URLs

You can override the default webhook URLs for SWAIG functions and post-prompt delivery:

```ruby
# In your agent initialization or setup code:

# Override the webhook URL for all SWAIG functions
agent.web_hook_url = 'https://external-service.example.com/handle-swaig'

# Override the post-prompt delivery URL
agent.post_prompt_url = 'https://analytics.example.com/conversation-summaries'

# These assignments allow you to:
# 1. Send function calls to external services instead of handling them locally
# 2. Send conversation summaries to analytics services or other systems
# 3. Use special URLs with pre-configured authentication
```

### External Input Checking

The SDK exposes a `/check_for_input` endpoint so external systems can push new
messages into an ongoing conversation. The default implementation returns an
empty response. Advanced applications can subclass `AgentBase` and override the
Rack-level handler to plug in custom storage and authentication; the specific
hook name is part of the private interface and may change between releases.

This endpoint is useful for asynchronous conversations where users send
messages through different channels that need to be incorporated into the
agent's conversation.

## Prefab Agents

Prefab agents are pre-configured agent implementations designed for specific use cases. They provide ready-to-use functionality with customization options, saving development time and ensuring consistent patterns.

### Built-in Prefabs

The SDK includes several built-in prefab agents.

> **Ruby note:** in the Python reference SDK each prefab *is* an `AgentBase`
> subclass you serve directly. The Ruby port models prefabs as configuration
> helpers under `SignalWire::Prefabs::` — you construct the prefab, then apply
> its `prompt_sections`, `global_data`, and tool handlers to a plain
> `SignalWire::AgentBase`. The constructor keywords also differ from Python
> (see each example below). The prefab classes are `InfoGatherer`, `FaqBot`,
> `Concierge`, `Survey`, and `Receptionist`.

#### InfoGatherer

Collects structured information from users. The Ruby prefab takes `questions:`
(each a Hash with `key_name`/`question_text` and an optional `confirm`), rather
than Python's `fields=`/`confirmation_template=`:

```ruby
require 'signalwire'

gatherer = SignalWire::Prefabs::InfoGatherer.new(
  questions: [
    { 'key_name' => 'full_name', 'question_text' => 'What is your full name?' },
    { 'key_name' => 'email', 'question_text' => 'What is your email address?', 'confirm' => true },
    { 'key_name' => 'reason', 'question_text' => 'How can I help you today?' }
  ],
  name:  'info-gatherer',
  route: '/info-gatherer'
)

# Wrap it in an agent for serving.
agent = SignalWire::AgentBase.new(name: gatherer.name, route: gatherer.route)

gatherer.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end
agent.global_data = gatherer.global_data

agent.define_tool(name: 'start_questions', description: 'Start the question sequence', parameters: {}) do |args, raw_data|
  gatherer.handle_start(args, raw_data)
end
agent.define_tool(
  name:        'submit_answer',
  description: 'Submit an answer to the current question',
  parameters:  { 'answer' => { 'type' => 'string', 'description' => "The caller's answer" } }
) do |args, raw_data|
  gatherer.handle_submit(args, raw_data)
end

agent.serve(host: '0.0.0.0', port: 8000)
```

#### FaqBot

Answers questions from a knowledge base. The Ruby prefab takes an in-memory
`faqs:` array (each entry a Hash with `question`/`answer`) and a `persona:`,
rather than Python's `knowledge_base_path=`/`citation_style=`:

```ruby
require 'signalwire'

faq_bot = SignalWire::Prefabs::FaqBot.new(
  faqs: [
    { 'question' => 'What is SignalWire?', 'answer' => 'A communications platform with voice, video, and messaging APIs.' },
    { 'question' => 'What is SWML?', 'answer' => 'SignalWire Markup Language for defining communications workflows.' }
  ],
  persona: "I'm a product documentation assistant.",
  name:    'knowledge-base',
  route:   '/knowledge-base'
)

agent = SignalWire::AgentBase.new(name: faq_bot.name, route: faq_bot.route)

faq_bot.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end
agent.global_data = faq_bot.global_data

agent.define_tool(
  name:        'search_faq',
  description: 'Search the FAQ knowledge base',
  parameters:  { 'query' => { 'type' => 'string', 'description' => 'Search query' } }
) do |args, raw_data|
  faq_bot.handle_search(args, raw_data)
end

agent.serve(host: '0.0.0.0', port: 8000)
```

#### Concierge

> **Ruby note:** the Ruby `Concierge` prefab is a *venue/hospitality* concierge
> (it answers amenity and service questions for a venue), not a call-router. It
> takes `venue_name:`, `services:`, and `amenities:` — there is no `routing_map:`
> in this port. For request-based routing, use custom routing callbacks (see
> [Custom Routing](#custom-routing)) instead.

Acts as a virtual concierge for a venue, answering amenity and service questions:

```ruby
require 'signalwire'

concierge = SignalWire::Prefabs::Concierge.new(
  venue_name: 'Oceanview Resort',
  services:   ['room service', 'spa bookings', 'restaurant reservations'],
  amenities:  {
    'infinity pool' => { 'hours' => '7:00 AM - 10:00 PM', 'location' => 'Main Level' },
    'spa'           => { 'hours' => '9:00 AM - 8:00 PM', 'location' => 'East Wing', 'reservation' => 'Required' }
  },
  welcome_message: 'Welcome to Oceanview Resort! How may I help you today?',
  name:            'concierge',
  route:           '/concierge'
)

agent = SignalWire::AgentBase.new(name: concierge.name, route: concierge.route)

concierge.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end
agent.global_data = concierge.global_data

agent.define_tool(
  name:        'get_amenity_info',
  description: 'Get information about a venue amenity',
  parameters:  { 'amenity' => { 'type' => 'string', 'description' => 'Name of the amenity' } }
) do |args, raw_data|
  concierge.handle_amenity_info(args, raw_data)
end
agent.define_tool(
  name:        'get_service_info',
  description: 'Get information about a venue service',
  parameters:  { 'service' => { 'type' => 'string', 'description' => 'Name of the service' } }
) do |args, raw_data|
  concierge.handle_service_info(args, raw_data)
end

agent.serve(host: '0.0.0.0', port: 8000)
```

#### Survey

Conducts structured surveys with different question types (the Ruby `Survey`
prefab takes `survey_name:`, `questions:`, `introduction:`, and `conclusion:`):

```ruby
require 'signalwire'

survey = SignalWire::Prefabs::Survey.new(
  survey_name:  'Customer Satisfaction',
  introduction: "We'd like to know about your recent experience with our product.",
  questions: [
    {
      'id'    => 'satisfaction',
      'text'  => 'How satisfied are you with our product?',
      'type'  => 'rating',
      'scale' => 5
    },
    {
      'id'   => 'feedback',
      'text' => 'Do you have any specific feedback about how we can improve?',
      'type' => 'open_ended'
    }
  ]
)

agent = SignalWire::AgentBase.new(name: survey.name, route: survey.route)

survey.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end
agent.global_data = survey.global_data

agent.define_tool(name: 'start_survey', description: 'Start the survey', parameters: {}) do |args, raw_data|
  survey.handle_start(args, raw_data)
end
agent.define_tool(
  name:        'submit_survey_answer',
  description: 'Submit an answer to the current survey question',
  parameters:  { 'answer' => { 'type' => 'string', 'description' => "The respondent's answer" } }
) do |args, raw_data|
  survey.handle_submit(args, raw_data)
end

agent.serve(host: '0.0.0.0', port: 8000)
```

#### Receptionist

Handles call routing and department transfers. The Ruby `Receptionist` prefab
takes `departments:` (each a Hash with `name`/`description`/`number`) and a
`greeting:` (set the voice on the wrapping agent, not the prefab):

```ruby
require 'signalwire'

receptionist = SignalWire::Prefabs::Receptionist.new(
  departments: [
    { 'name' => 'sales', 'description' => 'For product inquiries and pricing', 'number' => '+15551235555' },
    { 'name' => 'support', 'description' => 'For technical assistance', 'number' => '+15551236666' },
    { 'name' => 'billing', 'description' => 'For payment and invoice questions', 'number' => '+15551237777' }
  ],
  greeting: 'Thank you for calling ACME Corp. How may I direct your call?',
  name:     'acme-receptionist',
  route:    '/reception'
)

agent = SignalWire::AgentBase.new(name: receptionist.name, route: receptionist.route)
agent.add_language('English', 'en-US', 'rime.spore:mistv2')

receptionist.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end
agent.global_data = receptionist.global_data

agent.define_tool(
  name:        'transfer_to_department',
  description: 'Transfer the caller to a specific department',
  parameters:  { 'department' => { 'type' => 'string', 'description' => 'Department name' } }
) do |args, raw_data|
  receptionist.handle_transfer(args, raw_data)
end

agent.serve(host: '0.0.0.0', port: 8000)
```

### Creating Your Own Prefabs

In Ruby, the idiomatic way to build a reusable, parameterized agent is a
**factory method** that constructs and returns a fully configured
`SignalWire::AgentBase` — rather than subclassing. (You can also wrap an
existing prefab the same way.)

#### Basic Prefab Structure

A well-designed factory should:

1. Build a `SignalWire::AgentBase` (or wrap another prefab)
2. Take configuration parameters as keyword arguments
3. Apply configuration to set up the agent
4. Provide appropriate default values
5. Register domain-specific tools

Example of a factory for a custom support agent:

```ruby
require 'signalwire'

def build_customer_support_agent(product_name:, knowledge_base_path: nil,
                                 support_email: nil, escalation_path: nil, **agent_opts)
  agent = SignalWire::AgentBase.new(**agent_opts)

  # Configure prompt
  agent.prompt_add_section('Personality', "I am a customer support agent for #{product_name}.")
  agent.prompt_add_section('Goal', 'Help customers solve their problems effectively.')

  # Standard instructions (with conditional content)
  instructions = [
    'Be professional but friendly.',
    "Verify the customer's identity before sharing account details."
  ]
  instructions << "For complex issues, offer to escalate to #{escalation_path}." if escalation_path
  agent.prompt_add_section('Instructions', nil, bullets: instructions)

  # Register default tools only when the relevant config is present
  register_knowledge_base_tool(agent) if knowledge_base_path

  agent.define_tool(
    name:        'escalate_issue',
    description: 'Escalate a customer issue to a human agent',
    parameters:  {
      'issue_summary'  => { 'type' => 'string', 'description' => 'Brief summary of the issue' },
      'customer_email' => { 'type' => 'string', 'description' => "Customer's email address" }
    }
  ) do |_args, _raw_data|
    # Implementation...
    SignalWire::Swaig::FunctionResult.new('Issue escalated successfully.')
  end

  agent.define_tool(
    name:        'send_support_email',
    description: 'Send a follow-up email to the customer',
    parameters:  {
      'customer_email'   => { 'type' => 'string' },
      'issue_summary'    => { 'type' => 'string' },
      'resolution_steps' => { 'type' => 'string' }
    }
  ) do |_args, _raw_data|
    # Implementation...
    SignalWire::Swaig::FunctionResult.new('Follow-up email sent successfully.')
  end

  agent
end

def register_knowledge_base_tool(agent)
  # Register the knowledge base search tool if configured.
  # Implementation...
end
```

#### Using the Custom Factory

```ruby
# Build a configured agent from the factory
support_agent = build_customer_support_agent(
  product_name:        'SignalWire Voice API',
  knowledge_base_path: './product_docs',
  support_email:       'support@example.com',
  escalation_path:     'tier 2 support',
  name:                'voice-support',
  route:               '/voice-support'
)

# Start the agent
support_agent.serve(host: '0.0.0.0', port: 8000)
```

#### Customizing Existing Prefabs

You can also wrap and customize the built-in prefabs in a factory — apply the
prefab's configuration, then layer on extra prompt sections and tools:

```ruby
require 'signalwire'

def build_enhanced_gatherer(questions:, **agent_opts)
  gatherer = SignalWire::Prefabs::InfoGatherer.new(questions: questions, **agent_opts)
  agent    = SignalWire::AgentBase.new(name: gatherer.name, route: gatherer.route)

  gatherer.prompt_sections.each do |section|
    agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
  end
  agent.global_data = gatherer.global_data

  # Add an additional instruction
  agent.prompt_add_section('Instructions', nil, bullets: ['Verify all information carefully.'])

  # Add an additional custom tool
  agent.define_tool(
    name:        'check_customer',
    description: 'Check customer status in database',
    parameters:  { 'email' => { 'type' => 'string' } }
  ) do |_args, _raw_data|
    # Implementation...
    SignalWire::Swaig::FunctionResult.new('Customer status: Active')
  end

  agent
end
```

### Best Practices for Prefab Design

1. **Clear Documentation**: Document the purpose, parameters, and extension points
2. **Sensible Defaults**: Provide working defaults that make sense for the use case
3. **Error Handling**: Implement robust error handling with helpful messages
4. **Modular Design**: Keep prefabs focused on a specific use case
5. **Consistent Interface**: Maintain consistent patterns across related prefabs
6. **Extension Points**: Provide clear ways for others to extend your prefab
7. **Configuration Options**: Make all key behaviors configurable

### Making Prefabs Distributable

To create distributable prefabs that can be used across multiple projects:

1. **Gem Structure**: Package your prefabs as a proper Ruby gem
2. **Documentation**: Include clear usage examples 
3. **Configuration**: Support both code and file-based configuration
4. **Testing**: Include tests for your prefab
5. **Publishing**: Publish to RubyGems or share via GitHub

Example gem structure:

```
my-prefab-agents/
├── README.md
├── my_prefab_agents.gemspec
├── examples/
│   └── support_agent_example.rb
└── lib/
    └── my_prefab_agents/
        ├── support.rb
        ├── retail.rb
        └── utils/
            └── knowledge_base.rb
```

## API Reference

### Constructor Parameters

`SignalWire::AgentBase.new(...)` keyword arguments:

- `name:`: Agent name/identifier (default: `'agent'`)
- `route:`: HTTP route path (default: `'/'`)
- `host:`: Host to bind to (default: `'0.0.0.0'`)
- `port:`: Port to bind to (default: `nil`, resolved to 3000)
- `basic_auth:`: Optional `[username, password]` array
- `use_pom:`: Whether to use POM for prompts (default: `true`)
- `token_expiry_secs:`: Security token expiry time (default: `3600`)
- `auto_answer:`: Auto-answer calls (default: `true`)
- `record_call:`: Record calls (default: `false`)
- `schema_path:`: Optional path to schema.json file
- `suppress_logs:`: Whether to suppress structured logs (default: `false`)
- `signing_key:`: Webhook signature key (or set `SIGNALWIRE_SIGNING_KEY`)

### Prompt Methods

- `prompt_add_section(title, body = nil, bullets: nil, numbered: nil, numbered_bullets: false)`
- `prompt_add_subsection(parent_title, title, body = nil, bullets: nil)`
- `prompt_add_to_section(title, body_arg = nil, body: nil, bullet: nil, bullets: nil)`
- `set_prompt_text(text)` / `agent.prompt_text = text`
- `set_post_prompt(text)` / `agent.post_prompt = text`
- Readers: `agent.prompt`, `agent.post_prompt`, `agent.prompt_text`

> The Python `setPersonality` / `setGoal` / `setInstructions` camelCase
> convenience methods are not part of the Ruby port — call `prompt_add_section`
> with the relevant title directly.

### SWAIG Methods

- `define_tool(name:, description:, parameters: {}, secure: false, fillers: nil, webhook_url: nil, ...) { |args, raw_data| ... }` (block-based; there is no decorator form)
- `register_swaig_function(func_def)`
- `set_native_functions(names)` / `agent.native_functions = names`
- `add_function_include(url, functions, meta_data: nil)`
- Predicate/readers: `agent.function?(name)`, `agent.get_function(name)`, `agent.all_functions`, `agent.list_tool_names`

> The Python `add_native_function` / `remove_native_function` helpers are not in
> the Ruby port — assign the full list via `set_native_functions` /
> `agent.native_functions =`.

### Configuration Methods

- `add_hint(hint)` and `add_hints(hints)`
- `add_pattern_hint(hint:, pattern:, replace:, ignore_case: false)`
- `add_pronunciation(phrase, pronunciation, language_code: 'en-US')` (no `ignore_case:` in this port)
- `add_language(name, code, voice, speech_fillers: nil, function_fillers: nil, engine: nil, model: nil)`
- `set_param(key, value)` and `set_params(params_hash)`
- `set_global_data(data_hash)` / `agent.global_data = data_hash` and `update_global_data(data_hash)`

### State Methods

Per-call state is managed internally by the agent's `SessionManager` (used for
SWAIG token minting/validation). The Python `get_state` / `set_state` /
`update_state` / `clear_state` / `cleanup_expired_state` helpers are not exposed
as public `AgentBase` methods in the Ruby port; persist your own session data in
a captured Hash or external store (see [Session Lifecycle Hooks](#session-lifecycle-hooks)).

### SIP Routing Methods

- `enable_sip_routing(auto_map: true, path: '/sip')`: Enable SIP routing for an agent
- `register_sip_username(username)`: Register a SIP username for an agent

> The Python `auto_map_sip_usernames()` helper is not separately exposed in the
> Ruby port — auto-mapping happens via `enable_sip_routing(auto_map: true)`.

#### AgentServer SIP Methods

- `SignalWire::AgentServer#setup_sip_routing(route: '/sip', auto_map: true)`: Set up central SIP routing for a server
- `SignalWire::AgentServer#register_sip_username(username, route)`: Map a SIP username to an agent route

### Service Methods

- `serve(host: nil, port: nil)`: Start the web server (Rack/WEBrick)
- `rack_app` (aliased `as_rack_app`): Return a Rack-compatible application for this agent (Ruby uses Rack, not FastAPI)
- `on_swml_request(request_data = nil, callback_path = nil, request: nil)`: Customize SWML based on request data and path (override in a subclass)
- `on_summary(...) { |summary, raw_data| ... }`: Handle post-prompt summaries (block form)
- `on_function_call(name, args, raw_data)`: Process SWAIG function calls
- `register_routing_callback(path) { |request_data| ... }`: Register a block for custom path routing
- `set_web_hook_url(url)` / `agent.web_hook_url = url`: Override the default web_hook_url
- `set_post_prompt_url(url)` / `agent.post_prompt_url = url`: Override the default post_prompt_url

### Endpoint Methods

The SDK provides several endpoints for different purposes:

- Root endpoint (`/`): Serves the main SWML document
- SWAIG endpoint (`/swaig`): Handles SWAIG function calls
- Post-prompt endpoint (`/post_prompt`): Processes conversation summaries
- Check-for-input endpoint (`/check_for_input`): Supports checking for new input from external systems
- Debug endpoint (`/debug`): Serves the SWML document with debug headers
- Debug events endpoint (`/debug_events`): Receives real-time debug events from the AI module (see [Debug Events](#debug-events))
- SIP routing endpoint (configurable, default `/sip`): Handles SIP routing requests

## Testing

The SignalWire AI Agent SDK provides a `swaig-test` CLI tool (shipped as the
gem's executable) that lets you test agents locally and simulate serverless
environments without deployment.

> **Ruby note:** the Ruby `swaig-test` supports `--list-tools`, `--exec` with
> `--param key value`, `--dump-swml`, `--simulate-serverless`, `--url`,
> `--raw`, and `--verbose`. The platform-specific flags shown in some examples
> below (`--aws-function-name`, `--aws-region`, `--cgi-host`, `--gcp-project`,
> `--azure-*`, `--env-file`, `--full-request`, `--format-json`, `--list-agents`,
> `--agent-class`) come from the Python reference CLI and may not be available
> in the Ruby port — run `swaig-test --help` to see the supported flags.

### Local Agent Testing

Test your agents locally before deployment:

```bash
# Discover agents in a file
swaig-test examples/my_agent.rb

# List available functions
swaig-test examples/my_agent.rb --list-tools

# Test SWAIG functions
swaig-test examples/my_agent.rb --exec get_weather --param location "New York"

# Generate SWML documents
swaig-test examples/my_agent.rb --dump-swml
```

### Serverless Environment Simulation

Test your agents in simulated serverless environments to ensure they work correctly when deployed:

#### AWS Lambda Testing

```bash
# Basic Lambda environment simulation
swaig-test examples/my_agent.rb --simulate-serverless lambda --dump-swml

# Test with custom Lambda configuration
swaig-test examples/my_agent.rb --simulate-serverless lambda \
  --aws-function-name my-production-function \
  --aws-region us-west-2 \
  --exec my_function --param value

# Test function execution in Lambda context
swaig-test examples/my_agent.rb --simulate-serverless lambda \
  --exec get_weather --param location "Miami" \
  --full-request
```

#### CGI Environment Testing

```bash
# Test CGI environment
swaig-test examples/my_agent.rb --simulate-serverless cgi \
  --cgi-host my-server.com \
  --cgi-https \
  --dump-swml

# Test function in CGI context
swaig-test examples/my_agent.rb --simulate-serverless cgi \
  --cgi-host example.com \
  --exec my_function --param value
```

#### Google Cloud Functions Testing

```bash
# Test Cloud Functions environment
swaig-test examples/my_agent.rb --simulate-serverless cloud_function \
  --gcp-project my-project \
  --gcp-function-url https://my-function.cloudfunctions.net \
  --dump-swml
```

#### Azure Functions Testing

```bash
# Test Azure Functions environment
swaig-test examples/my_agent.rb --simulate-serverless azure_function \
  --azure-env production \
  --azure-function-url https://my-function.azurewebsites.net \
  --exec my_function
```

### Environment Variable Management

Use environment files for consistent testing across different platforms:

```bash
# Create environment file for production testing
cat > production.env << EOF
AWS_LAMBDA_FUNCTION_NAME=prod-my-agent
AWS_REGION=us-east-1
API_KEY=prod_api_key_123
DEBUG=false
TIMEOUT=60
EOF

# Test with environment file
swaig-test examples/my_agent.rb --simulate-serverless lambda \
  --env-file production.env \
  --exec critical_function --param input "test"

# Override specific variables
swaig-test examples/my_agent.rb --simulate-serverless lambda \
  --env-file production.env \
  --env DEBUG=true \
  --dump-swml
```

### Cross-Platform Testing

Test the same agent across multiple platforms to ensure compatibility:

```bash
# Test across all platforms
for platform in lambda cgi cloud_function azure_function; do
  echo "Testing $platform..."
  swaig-test examples/my_agent.rb --simulate-serverless $platform \
    --exec my_function --param value
done

# Compare SWML generation across platforms
swaig-test examples/my_agent.rb --simulate-serverless lambda --dump-swml > lambda.swml
swaig-test examples/my_agent.rb --simulate-serverless cgi --cgi-host example.com --dump-swml > cgi.swml
diff lambda.swml cgi.swml
```

### Webhook URL Verification

The serverless simulation automatically generates platform-appropriate webhook URLs:

| Platform | Example Webhook URL |
|----------|-------------------|
| Lambda (Function URL) | `https://abc123.lambda-url.us-east-1.on.aws/swaig/` |
| Lambda (API Gateway) | `https://api123.execute-api.us-east-1.amazonaws.com/prod/swaig/` |
| CGI | `https://example.com/cgi-bin/agent.cgi/swaig/` |
| Cloud Functions | `https://my-function-abc123.cloudfunctions.net/swaig/` |
| Azure Functions | `https://my-function.azurewebsites.net/swaig/` |

Verify webhook URLs are generated correctly:

```bash
# Check Lambda webhook URL
swaig-test examples/my_agent.rb --simulate-serverless lambda \
  --dump-swml --format-json | jq '.sections.main[1].ai.SWAIG.defaults.web_hook_url'

# Check CGI webhook URL
swaig-test examples/my_agent.rb --simulate-serverless cgi \
  --cgi-host my-production-server.com \
  --dump-swml --format-json | jq '.sections.main[1].ai.SWAIG.defaults.web_hook_url'
```

### Testing Best Practices

1. **Test locally first**: Always test your agent in local mode before serverless simulation
2. **Test target platforms**: Test on all platforms where you plan to deploy
3. **Use environment files**: Create reusable environment configurations for different stages
4. **Verify webhook URLs**: Ensure URLs are generated correctly for your target platform
5. **Test function execution**: Verify that functions work correctly in serverless context
6. **Use verbose mode**: Enable `--verbose` for debugging environment setup and execution

### Multi-Agent Testing

For files with multiple agents, specify which agent to test:

```bash
# Discover available agents
swaig-test multi_agent_file.rb --list-agents

# Test specific agent
swaig-test multi_agent_file.rb --agent-class MyAgent --simulate-serverless lambda --dump-swml

# Test different agents across platforms
swaig-test multi_agent_file.rb --agent-class AgentA --simulate-serverless lambda --exec function1
swaig-test multi_agent_file.rb --agent-class AgentB --simulate-serverless cgi --cgi-host example.com --exec function2
```

For more detailed testing documentation, see the [CLI Guide](cli_guide.md).

## Examples

### Simple Question-Answering Agent

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:    'simple',
  route:   '/simple',
  use_pom: true
)

# Configure agent personality
agent.prompt_add_section('Personality', 'You are a friendly and helpful assistant.')
agent.prompt_add_section('Goal', 'Help users with basic tasks and answer questions.')
agent.prompt_add_section('Instructions', nil, bullets: [
  'Be concise and direct in your responses.',
  "If you don't know something, say so clearly.",
  'Use the get_time function when asked about the current time.'
])

agent.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  formatted_time = Time.now.strftime('%H:%M:%S')
  SignalWire::Swaig::FunctionResult.new("The current time is #{formatted_time}")
end

puts 'Starting agent server...'
puts 'Note: Works in any deployment mode (server/CGI/Lambda)'
agent.run
```

### Multi-Language Customer Service Agent

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:    'customer-service',
  route:   '/support',
  use_pom: true
)

# Configure agent personality
agent.prompt_add_section('Personality',
                         'You are a helpful customer service representative for SignalWire.')
agent.prompt_add_section('Knowledge',
                         'You can answer questions about SignalWire products and services.')
agent.prompt_add_section('Instructions', nil, bullets: [
  'Greet customers politely',
  'Answer questions about SignalWire products',
  'Use check_account_status when customer asks about their account',
  'Use create_support_ticket for unresolved issues'
])

# Add language support
agent.add_language(
  'English',
  'en-US',
  'en-US-Neural2-F',
  speech_fillers:   ['Let me think...', 'One moment please...'],
  function_fillers: ["I'm looking that up...", 'Let me check that...']
)

agent.add_language(
  'Spanish',
  'es',
  'rime.spore:multilingual',
  speech_fillers: ['Un momento por favor...', 'Estoy pensando...']
)

# Enable languages
agent.set_params({ 'languages_enabled' => true })

# Add company information
agent.set_global_data({
  'company_name'  => 'SignalWire',
  'support_hours' => '9am-5pm ET, Monday through Friday',
  'support_email' => 'support@signalwire.com'
})

agent.define_tool(
  name:        'check_account_status',
  description: "Check the status of a customer's account",
  parameters:  {
    'account_id' => { 'type' => 'string', 'description' => "The customer's account ID" }
  }
) do |args, _raw_data|
  account_id = args['account_id']
  # In a real implementation, this would query a database
  SignalWire::Swaig::FunctionResult.new("Account #{account_id} is in good standing.")
end

agent.define_tool(
  name:        'create_support_ticket',
  description: 'Create a support ticket for an unresolved issue',
  parameters:  {
    'issue'    => { 'type' => 'string', 'description' => 'Brief description of the issue' },
    'priority' => {
      'type'        => 'string',
      'description' => 'Ticket priority',
      'enum'        => %w[low medium high critical]
    }
  }
) do |args, _raw_data|
  issue    = args['issue'] || ''
  priority = args['priority'] || 'medium'

  # Generate a ticket ID (in a real system, this would create a database entry)
  ticket_id = format('TICKET-%04d', issue.hash % 10_000)

  SignalWire::Swaig::FunctionResult.new(
    "Support ticket #{ticket_id} has been created with #{priority} priority. " \
    'A support representative will contact you shortly.'
  )
end

puts 'Starting customer service agent...'
puts 'Note: Works in any deployment mode (server/CGI/Lambda)'
agent.run
```

### Dynamic Agent Configuration Examples

For working examples of dynamic agent configuration, see these files in the `examples` directory:

- **`simple_static_agent.rb`**: Traditional static configuration approach
- **`simple_dynamic_agent.rb`**: Same agent but using dynamic configuration
- **`simple_dynamic_enhanced.rb`**: Enhanced version that actually uses request parameters
- **`comprehensive_dynamic_agent.rb`**: Advanced multi-tier, multi-industry dynamic agent
- **`custom_path_agent.rb`**: Dynamic agent with custom routing path
- **`multi_agent_server.rb`**: Multiple specialized dynamic agents on one server

These examples demonstrate the progression from static to dynamic configuration and show real-world use cases like multi-tenant applications, A/B testing, and personalization.

For more examples, see the `examples` directory in the SignalWire AI Agent SDK repository.

## Search

The Ruby `native_vector_search` skill queries a **remote search server** over HTTP
(see [Native Vector Search Skill](#native-vector-search-skill-native_vector_search)
above). The Ruby gem does not ship an index-building CLI and does not read local
`.swsearch` files; index building and document processing live in the Python
reference. To use search from a Ruby agent, point the skill at a running search
server via `remote_url`.