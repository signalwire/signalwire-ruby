# SignalWire AI Agents SDK Architecture

<!-- snippet-setup: every ruby example on this page assumes the SDK is required; supply demo Google creds so the web_search skill's presence check passes -->
```ruby
require 'signalwire'
ENV['GOOGLE_SEARCH_API_KEY']   ||= 'demo-key'
ENV['GOOGLE_SEARCH_ENGINE_ID'] ||= 'demo-engine-id'
```

## Overview

The SignalWire AI Agents SDK provides a Python framework for building, deploying, and managing AI agents as microservices. These agents are self-contained web applications that expose HTTP endpoints to interact with the SignalWire platform. The SDK simplifies the creation of custom AI agents by handling common functionality like HTTP routing, prompt management, and tool execution.

## Core Components

### Class Hierarchy

The SDK is built around a clear class hierarchy:

- **SWMLService**: The foundation class providing SWML (SignalWire Markup Language) document creation and HTTP service capabilities. SWML is the JSON document format that defines how an agent behaves during a call.
  - **AgentBase**: Extends SWMLService with AI agent-specific functionality
    - **Custom Agent Classes**: User implementations like SimpleAgent
    - **Prefab Agents**: Ready-to-use agent types for common scenarios

### Key Components

1. **SWML Document Management**
   - Schema validation for SWML documents
   - Dynamic SWML verb creation and validation
   - Document rendering and serving

2. **Prompt Object Model (POM)**
   - Structured format for defining AI prompts
   - Section-based organization (Personality, Goal, Instructions, etc.)
   - Programmatic prompt construction and manipulation

3. **SWAIG (SignalWire AI Gateway) Function Framework** -- SWAIG is the platform's AI tool-calling system with native access to the media stack. When the AI decides to call a function, SWAIG handles invocation, parameter passing, and result delivery.
   - Tool definition and registration system
   - Parameter validation using JSON schema
   - Security tokens for function execution
   - Handler registry for function execution

4. **HTTP Routing**
   - FastAPI-based web service
   - Endpoint routing for SWML, SWAIG, and other services
   - Custom routing callbacks for dynamic endpoint handling
   - SIP request routing for voice applications
   - Basic authentication

5. **State Management**
   - Session-based state tracking
   - Persistence options (file system, memory)
   - State lifecycle hooks (startup, hangup)

6. **Prefab Agents**
   - Ready-to-use agent implementations
   - Customizable configurations
   - Extensible designs for common use cases

7. **Skills System**
   - Modular skill architecture for extending agent capabilities
   - Automatic skill discovery from directory structure
   - Parameter-configurable skills for customization
   - Dependency validation (packages and environment variables)
   - Built-in skills (web_search, datetime, math)

## DataMap Tools

The DataMap system provides a declarative approach to creating SWAIG tools that integrate with REST APIs without requiring custom webhook infrastructure. DataMap tools execute on SignalWire's server infrastructure, simplifying deployment and eliminating the need to expose webhook endpoints.

### Architecture Overview

DataMap tools follow a pipeline execution model on the SignalWire server:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Function Call   │    │ Expression      │    │ Webhook         │    │ Response        │
│ (Arguments)     │━━━▶│ Processing      │━━━▶│ Execution       │━━━▶│ Generation      │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         │                       │                       │                       │
    ┌────▼────┐             ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
    │Variable │             │Pattern  │             │HTTP     │             │Template │
    │Expansion│             │Matching │             │Request  │             │Rendering│
    │         │             │         │             │         │             │         │
    └─────────┘             └─────────┘             └─────────┘             └─────────┘
```

### Core Components

1. **Builder Pattern**: Fluent interface for constructing data_map configurations
   ```ruby
   tool = SignalWire::DataMap.new('function_name')
          .description('Function purpose')
          .parameter('param', 'string', 'Description', required: true)
          .webhook('GET', 'https://api.example.com/endpoint')
          .output(SignalWire::Swaig::FunctionResult.new('Response template'))
   ```

2. **Processing Pipeline**: Ordered execution with early termination
   - **Expressions**: Pattern matching against arguments
   - **Webhooks**: HTTP API calls with variable substitution
   - **Foreach**: Array iteration for response processing
   - **Output**: Final response generation using SwaigFunctionResult

3. **Variable Expansion**: Dynamic substitution using `${variable}` syntax
   - Function arguments: `${args.parameter_name}`
   - API responses: `${response.field.nested_field}`
   - Array elements: `${foreach.item_field}`
   - Global data: `${global_data.key}`
   - Metadata: `${meta_data.call_id}`

### Tool Types

The system supports different tool patterns:

1. **API Integration Tools**: Direct REST API calls
   ```ruby
   weather_tool = SignalWire::DataMap.new('get_weather')
                  .webhook('GET', 'https://api.weather.com/v1/current?q=${location}')
                  .output(SignalWire::Swaig::FunctionResult.new('Weather: ${response.current.condition}'))
   ```

2. **Expression-Based Tools**: Pattern matching without API calls
   ```ruby
   control_tool = SignalWire::DataMap.new('file_control')
                  .expression('${args.command}', /start.*/, SignalWire::Swaig::FunctionResult.new.add_action('start', true))
                  .expression('${args.command}', /stop.*/, SignalWire::Swaig::FunctionResult.new.add_action('stop', true))
   ```

3. **Array Processing Tools**: Handle list responses
   ```ruby
   search_tool = SignalWire::DataMap.new('search_docs')
                 .webhook('GET', 'https://api.docs.com/search')
                 .foreach({ 'input_key' => 'results', 'output_key' => 'formatted', 'append' => 'Found: ${this.title}\n' })
                 .output(SignalWire::Swaig::FunctionResult.new('${formatted}'))
   ```

### Integration with Agent Architecture

DataMap tools integrate with the existing agent architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AgentBase       │    │ SWAIG           │    │ SignalWire      │
│                 │    │ Function        │    │ Server          │
│ .register_      │━━━▶│ Registry        │━━━▶│ Execution       │
│  swaig_function │    │                 │    │ Environment     │
│                 │    │ data_map field  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
    ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
    │DataMap  │             │Function │             │Variable │
    │Builder  │             │Definition│             │Expansion│
    │         │             │         │             │         │
    └─────────┘             └─────────┘             └─────────┘
```

1. **Registration**: DataMap tools are registered as SWAIG functions
2. **Execution**: Tools run on SignalWire infrastructure, not agent servers
3. **Response**: Results are returned to the agent as function responses

### Configuration Architecture

DataMap configurations use a hierarchical structure:

```json
{
  "function": "tool_name",
  "description": "Tool description", 
  "parameters": {
    "type": "object",
    "properties": {...},
    "required": [...]
  },
  "data_map": {
    "expressions": [...],
    "webhooks": [...], 
    "foreach": "path",
    "output": {...},
    "error_keys": [...]
  }
}
```

This structure separates:
- **Function Metadata**: Name, description, parameters
- **Processing Logic**: Expressions, webhooks, array handling
- **Output Definition**: Response templates and actions

### Benefits and Trade-offs

**Benefits:**
- No webhook infrastructure required
- Simplified deployment model
- Built-in authentication and error handling
- Server-side execution (no agent load)
- Automatic variable expansion

**Trade-offs:**
- Limited to REST API patterns
- No complex processing logic
- Server-side execution (no local state access)
- SignalWire platform dependency

**When to Choose DataMap vs Skills vs Custom Tools:**
- **DataMap**: Simple REST API integrations, read-only operations
- **Skills**: Multi-step workflows, state management, complex logic
- **Custom Tools**: Full control, database access, agent-side processing

## Skills System

The Skills System provides a modular architecture for extending agent capabilities through self-contained, reusable components. Skills are automatically discovered, validated, and can be configured with parameters.

### Architecture Overview

The skills system follows a three-layer architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Agent Layer     │    │ Management      │    │ Skills Layer    │
│                 │    │ Layer           │    │                 │
│ AgentBase       │━━━▶│ SkillManager    │━━━▶│ SkillBase       │
│ #add_skill      │    │ #add_skill      │    │ #setup          │
│ #remove_skill   │    │ #remove_skill   │    │ #register_tools │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
    ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
    │Request  │             │Registry │             │Skill    │
    │Routing  │             │Discovery│             │Instance │
    │         │             │         │             │         │
    └─────────┘             └─────────┘             └─────────┘
```

### Core Components

1. **SkillBase**: Abstract base class defining the skill interface
   - Dependency validation (packages and environment variables)
   - Tool registration with the agent
   - Parameter support for configuration
   - Lifecycle management (setup, cleanup)

2. **SkillManager**: Manages skill loading and lifecycle
   - Skill discovery and registration
   - Dependency validation and error reporting
   - Parameter passing to skills
   - Integration with agent prompt and tool systems

3. **SkillRegistry**: Automatic skill discovery system
   - Directory-based skill discovery
   - Class introspection and registration
   - Metadata extraction for skill information

### Skill Lifecycle

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Discovery       │    │ Loading         │    │ Registration    │
│                 │    │                 │    │                 │
│ 1. Scan dirs    │━━━▶│ 1. Validate     │━━━▶│ 1. Add tools    │
│ 2. Import mods  │    │    deps         │    │ 2. Add prompts  │
│ 3. Find classes │    │ 2. Create       │    │ 3. Add hints    │
│ 4. Register     │    │    instance     │    │ 4. Store ref    │
│                 │    │ 3. Call setup() │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Parameter System

Skills support configurable parameters for customization:

```ruby
# Default behavior
agent.add_skill('web_search')

# Custom configuration
agent.add_skill('web_search', {
  'num_results' => 3,
  'delay' => 0.5
})
```

Parameters are passed to the skill constructor and accessible via `params`:

```ruby
class WebSearchSkill < SignalWire::Skills::SkillBase
  def setup
    @num_results = params.fetch('num_results', 1)
    @delay = params.fetch('delay', 0)
    # Configure behavior based on parameters
    true
  end
end
```

### Error Handling

The system provides detailed error reporting for common issues:

- **Missing Dependencies**: Lists specific missing packages or environment variables
- **Discovery Failures**: Reports issues during skill discovery or import
- **Setup Failures**: Provides details when skill setup fails
- **Parameter Validation**: Validates parameter types and values

Error messages are actionable and specific:
```
Failed to load skill 'web_search': Missing required environment variables: ['GOOGLE_SEARCH_API_KEY', 'GOOGLE_SEARCH_ENGINE_ID']
```

### Integration Points

Skills integrate with existing agent systems:

1. **SWAIG Tools**: Skills register tools that become available to the AI
2. **Prompt System**: Skills can add prompt sections and hints
3. **Global Data**: Skills can contribute to agent context
4. **State Management**: Skills can access agent state if needed

This architecture enables one-liner integration while maintaining flexibility and extensibility.

## Security Model

The SDK implements a multi-layer security model:

1. **Transport Security**
   - HTTPS support for encrypted communications
   - SSL certificate configuration

2. **Authentication**
   - HTTP Basic Authentication for all endpoints
   - Configurable via environment variables or programmatically

3. **Authorization**
   - Function-specific security tokens
   - Token validation for secure function calls
   - SessionManager-based security scope
   - `secure=True` option on tool definitions (default)

4. **State Isolation**
   - Per-call state separation
   - Call ID validation

## Extension Points

The SDK is designed to be highly extensible:

1. **Custom Agents**: Extend AgentBase to create specialized agents
   ```ruby
   class CustomAgent < SignalWire::AgentBase
     def initialize
       super(name: 'custom', route: '/custom')
     end
   end
   ```

2. **Tool Registration**: Add new tools with `define_tool` and a block handler
<!-- snippet: no-run illustrative fragment: AgentBase instance methods (define_tool/prompt_add_section/set_dynamic_config_callback) shown outside an agent class -->
   ```ruby
   define_tool(
     name: 'tool_name',
     description: 'Tool description',
     parameters: {},
     secure: true
   ) do |args, raw_data|
     # Tool implementation
     SignalWire::Swaig::FunctionResult.new('Done')
   end
   ```

3. **Prompt Customization**: Add sections, hints, languages
   ```ruby
   agent.add_language('English', 'en-US', 'elevenlabs.josh')
   agent.add_hints(['SignalWire', 'SWML', 'SWAIG'])
   ```

4. **Session Management**: The SDK includes session management for secure function calls

5. **Request Handling**: Override request handling methods
   ```ruby
   def on_swml_request(request_data = nil, callback_path = nil, request: nil)
     # Custom request handling
   end
   ```

6. **Custom Prefabs**: Create reusable agent patterns
   ```ruby
   class MyCustomPrefab < SignalWire::AgentBase
     def initialize(config_param1:, config_param2:, **kwargs)
       super(**kwargs)
       # Configure the agent based on parameters
       prompt_add_section('Personality', "Customized based on: #{config_param1}")
     end
   end
   ```

7. **Dynamic Configuration**: Per-request agent configuration for flexible behavior
<!-- snippet: no-run illustrative fragment: AgentBase instance methods (define_tool/prompt_add_section/set_dynamic_config_callback) shown outside an agent class -->
   ```ruby
   def configure_agent_dynamically(query_params, body_params, headers, agent)
     # Configure agent differently based on request data
     # agent is the actual AgentBase instance
     tier = query_params.fetch('tier', 'standard')
     agent.set_params({ 'end_of_speech_timeout' => tier == 'premium' ? 300 : 500 })
   end

   set_dynamic_config_callback(method(:configure_agent_dynamically))
   ```

8. **Skills Integration**: Add capabilities with one-liner calls
   ```ruby
   # Add built-in skills
   agent.add_skill('web_search')
   agent.add_skill('datetime')
   agent.add_skill('math')

   # Configure skills with parameters
   agent.add_skill('web_search', {
     'num_results' => 3,
     'delay' => 0.5
   })
   ```

9. **Custom Skills**: Create reusable skill modules
   ```ruby
   require 'signalwire'

   class MyCustomSkill < SignalWire::Skills::SkillBase
     def name = 'my_skill'
     def description = 'A custom skill'
     def required_packages = ['some_gem']
     def required_env_vars = ['API_KEY']

     def setup
       # Initialize the skill
       true
     end

     def register_tools
       # Register tools with the agent using the wrapper method
       # This automatically includes swaig_fields
       define_tool(name: 'my_tool', description: '...', parameters: {}) do |args, raw_data|
         SignalWire::Swaig::FunctionResult.new('...')
       end
     end
   end
   ```

### Dynamic Configuration

The dynamic configuration system enables agents to adapt their behavior on a per-request basis by examining incoming HTTP request data. This architectural pattern supports complex use cases like multi-tenant applications, A/B testing, and personalization while maintaining a single agent deployment.

#### Architecture Overview

Dynamic configuration intercepts the SWML document generation process to apply request-specific configuration:

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐    ┌──────────────┐
│ HTTP        │    │ Dynamic Config   │    │ Agent Instance      │    │ SWML         │
│ Request     │━━━▶│ Callback         │━━━▶│ (AgentBase)         │━━━▶│ Document     │
└─────────────┘    └──────────────────┘    └─────────────────────┘    └──────────────┘
       │                     │                        │                      │
       │                     │                        │                      │
   ┌───▼────┐           ┌────▼─────┐            ┌─────▼──────┐          ┌────▼────┐
   │Query   │           │Request   │            │Direct      │          │Rendered │
   │Params  │           │Data      │            │Agent       │          │Response │
   │Body    │           │Analysis  │            │Config      │          │         │
   │Headers │           │Logic     │            │            │          │         │
   └────────┘           └──────────┘            └────────────┘          └─────────┘
```

#### Component Interaction

1. **Request Processing**: The framework extracts query parameters, body data, and headers from incoming requests
2. **Callback Invocation**: If a dynamic configuration callback is registered, it's called with the request data
3. **Agent Configuration**: The callback receives the actual agent instance (AgentBase) and configures it directly using familiar AgentBase methods
4. **SWML Generation**: The configuration is applied during SWML document rendering
5. **Response Delivery**: The customized SWML document is returned to the client

#### Request Processing Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ Dynamic Configuration Request Flow                                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│ 1. HTTP Request arrives (GET/POST /)                                          │
│                         │                                                       │
│ 2. Extract request data │                                                       │
│    ┌────────────────────▼────────────────────┐                                 │
│    │ • Query Parameters (URL params)        │                                 │
│    │ • Body Parameters (POST JSON)          │                                 │
│    │ • Headers (HTTP headers)               │                                 │
│    └────────────────────┬────────────────────┘                                 │
│                         │                                                       │
│ 3. Check for callback   │                                                       │
│    ┌────────────────────▼────────────────────┐                                 │
│    │ if dynamic_config_callback is set:     │                                 │
│    │   - Call callback with request data    │                                 │
│    │     and agent instance                 │                                 │
│    │   - Apply configuration directly to    │                                 │
│    │     the agent                          │                                 │
│    │ else:                                   │                                 │
│    │   - Use static agent configuration     │                                 │
│    └────────────────────┬────────────────────┘                                 │
│                         │                                                       │
│ 4. Generate SWML        │                                                       │
│    ┌────────────────────▼────────────────────┐                                 │
│    │ • Render AI verb with configuration    │                                 │
│    │ • Include languages, params, prompts   │                                 │
│    │ • Apply hints and global data          │                                 │
│    │ • Generate function URLs with tokens   │                                 │
│    └────────────────────┬────────────────────┘                                 │
│                         │                                                       │
│ 5. Return SWML Document │                                                       │
│    ┌────────────────────▼────────────────────┐                                 │
│    │ • Complete SWML with customizations    │                                 │
│    │ • Ready for SignalWire platform        │                                 │
│    └─────────────────────────────────────────┘                                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Direct Agent Configuration

The dynamic configuration callback receives the actual agent instance, allowing direct manipulation of the agent's configuration for a single request:

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ Agent Configuration Methods Available in Callback                             │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│ ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐              │
│ │ Prompt Sections │   │ Language Config │   │ AI Parameters   │              │
│ │ ─────────────── │   │ ─────────────── │   │ ─────────────── │              │
│ │ • add_section() │   │ • add_language()│   │ • set_params()  │              │
│ │ • set_prompt()  │   │ • voice config  │   │ • timeouts      │              │
│ │ • post_prompt   │   │ • fillers       │   │ • volumes       │              │
│ └─────────────────┘   └─────────────────┘   └─────────────────┘              │
│                                                                               │
│ ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐              │
│ │ Global Data     │   │ Hints & Speech  │   │ Functions       │              │
│ │ ─────────────── │   │ ─────────────── │   │ ─────────────── │              │
│ │ • set_global()  │   │ • add_hints()   │   │ • native_funcs()│              │
│ │ • update_data() │   │ • pronunciation │   │ • recognition   │              │
│ │ • session data  │   │ • recognition   │   │ • external URLs │              │
│ └─────────────────┘   └─────────────────┘   └─────────────────┘              │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

#### Performance Considerations

The dynamic configuration system is designed with performance in mind:

1. **Lightweight Callbacks**: Configuration callbacks should be fast and avoid heavy computations
2. **Stateless Operation**: Each request is processed independently without shared state
3. **Per-Request Scope**: Configuration changes are applied per-request and reset afterward
4. **Caching Opportunities**: External configuration data can be cached at the application level

#### Memory Management

```
Request 1 ┌─────────────┐    Request 2 ┌─────────────┐    Request 3 ┌─────────────┐
Lifecycle │ RECEIVE     │    Lifecycle │ RECEIVE     │    Lifecycle │ RECEIVE     │
          │ REQUEST     │              │ REQUEST     │              │ REQUEST     │
          │ ↓           │              │ ↓           │              │ ↓           │
          │ CONFIGURE   │              │ CONFIGURE   │              │ CONFIGURE   │
          │ AGENT       │              │ AGENT       │              │ AGENT       │
          │ ↓           │              │ ↓           │              │ ↓           │
          │ RENDER SWML │              │ RENDER SWML │              │ RENDER SWML │
          │ ↓           │              │ ↓           │              │ ↓           │
          │ RESET       │              │ RESET       │              │ RESET       │
          │ CONFIG      │              │ CONFIG      │              │ CONFIG      │
          └─────────────┘              └─────────────┘              └─────────────┘
               │                             │                             │
               ▼                             ▼                             ▼
          Agent returns                Agent returns                Agent returns
          to baseline                  to baseline                  to baseline
```

#### Use Case Patterns

The dynamic configuration architecture supports several key patterns:

1. **Multi-Tenant Applications**
   ```
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ Tenant A    │    │ Same Agent   │    │ Config A    │
   │ Request     │━━━▶│ Instance     │━━━▶│ Applied     │
   └─────────────┘    └──────────────┘    └─────────────┘
   
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ Tenant B    │    │ Same Agent   │    │ Config B    │
   │ Request     │━━━▶│ Instance     │━━━▶│ Applied     │
   └─────────────┘    └──────────────┘    └─────────────┘
   ```

2. **A/B Testing and Experimentation**
   ```
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ Control     │    │ Decision     │    │ Version A   │
   │ Group       │━━━▶│ Logic        │━━━▶│ Config      │
   └─────────────┘    └──────────────┘    └─────────────┘
   
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ Test        │    │ Decision     │    │ Version B   │
   │ Group       │━━━▶│ Logic        │━━━▶│ Config      │
   └─────────────┘    └──────────────┘    └─────────────┘
   ```

3. **Geographic and Cultural Localization**
   ```
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ US Request  │    │ Locale       │    │ English     │
   │ (en-US)     │━━━▶│ Detection    │━━━▶│ Voice + USD │
   └─────────────┘    └──────────────┘    └─────────────┘
   
   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
   │ MX Request  │    │ Locale       │    │ Spanish     │
   │ (es-MX)     │━━━▶│ Detection    │━━━▶│ Voice + MXN │
   └─────────────┘    └──────────────┘    └─────────────┘
   ```

#### Integration Points

Dynamic configuration integrates with other SDK components:

- **State Management**: Can access and configure state based on request data
- **SWAIG Functions**: Functions are generated with proper URLs and security tokens
- **SIP Routing**: Can be combined with SIP username routing for voice applications
- **Authentication**: Respects existing authentication mechanisms
- **Logging**: Configuration decisions can be logged for debugging and analytics

#### Error Handling and Fallbacks

The system includes robust error handling:

```ruby
def configure_agent_dynamically(query_params, body_params, headers, agent)
  # Primary configuration logic — agent is the actual AgentBase instance
  tier = query_params.fetch("tier", "standard")
  if tier == "premium"
    agent.params = { "end_of_speech_timeout" => 300 }
    agent.add_hints(["premium support", "priority handling"])
  end
rescue Signalwire::ConfigurationError => e
  # Log error and apply safe defaults
  agent.logger.error("dynamic_config_error: #{e.message}")
  # Agent retains its base configuration
rescue => e
  # Catch-all - agent continues with existing configuration
  agent.logger.error("dynamic_config_critical: #{e.message}")
end
```

#### Migration Strategy

The architecture supports gradual migration from static to dynamic configuration:

1. **Phase 1**: Deploy dynamic agent with static configuration callback
2. **Phase 2**: Add request parameter detection and basic customization
3. **Phase 3**: Implement full dynamic behavior based on use case requirements
4. **Phase 4**: Remove static configuration and rely entirely on dynamic system

This approach ensures zero downtime and allows for testing and validation at each phase.

## Prefab Agents

The SDK includes a collection of prefab agents that provide ready-to-use implementations for common use cases. These prefabs can be used directly or serve as templates for custom implementations.

### Built-in Prefab Types

1. **InfoGathererAgent**
   - Purpose: Collect specific information from users in a structured conversation
   - Configuration: Define fields to collect, validation rules, and confirmation templates
   - Use cases: Form filling, survey collection, intake processes

2. **FAQBotAgent**
   - Purpose: Answer questions based on a provided knowledge base
   - Configuration: Data sources, retrieval methods, citation options
   - Use cases: FAQ bots, documentation assistants, support agents

3. **ConciergeAgent**
   - Purpose: Handle routing and delegation between multiple specialized agents
   - Configuration: Connected agents, routing logic, handoff protocols
   - Use cases: Front-desk services, triage systems, switchboard operators

4. **SurveyAgent**
   - Purpose: Conduct structured surveys with rating scales and open-ended questions
   - Configuration: Survey questions, rating scales, branching logic
   - Use cases: Customer satisfaction surveys, feedback collection, market research

5. **ReceptionistAgent**
   - Purpose: Greet callers and transfer them to appropriate departments
   - Configuration: Department list with names, descriptions, and transfer numbers
   - Use cases: Call routing, front desk services, automated phone systems

### Creating Custom Prefabs

Users can create their own prefab agents by extending `AgentBase` or any existing prefab. Custom prefabs can be created within your project or packaged as reusable libraries.

Key steps for creating custom prefabs:

1. **Extend the base class**:
   ```ruby
   class MyCustomPrefab < SignalWire::AgentBase
     def initialize(custom_param:, **kwargs)
       super(**kwargs)
       @custom_param = custom_param
     end
   end
   ```

2. **Configure defaults**:
<!-- snippet: no-run illustrative fragment: AgentBase instance methods (define_tool/prompt_add_section/set_dynamic_config_callback) shown outside an agent class -->
   ```ruby
   # Set standard prompt sections
   prompt_add_section('Personality', 'I am a specialized agent for...')
   prompt_add_section('Goal', 'Help users with...')

   # Register any tools this prefab needs with define_tool
   ```

3. **Add specialized tools**:
<!-- snippet: no-run illustrative fragment: AgentBase instance methods (define_tool/prompt_add_section/set_dynamic_config_callback) shown outside an agent class -->
   ```ruby
   define_tool(
     name: 'specialized_function',
     description: 'Do something specialized',
     parameters: {}
   ) do |args, raw_data|
     # Implementation
     SignalWire::Swaig::FunctionResult.new('Function result')
   end
   ```

4. **Create a factory method** (optional):
   ```ruby
   # Create an instance from a configuration hash
   def self.create(config_hash, **kwargs)
     new(
       custom_param: config_hash.fetch('custom_param', 'default'),
       name: config_hash.fetch('name', 'custom_prefab'),
       **kwargs
     )
   end
   ```

### Prefab Customization Points

When designing prefabs, consider exposing these customization points:

1. **Constructor parameters**: Allow users to configure key behavior
2. **Override methods**: Document which methods can be safely overridden
3. **Extension hooks**: Provide callback methods for custom logic
4. **Configuration files**: Support loading settings from external sources
5. **Runtime customization**: Allow changing behavior after initialization

### Prefab Best Practices

1. **Clear Documentation**: Document the purpose, parameters, and extension points
2. **Sensible Defaults**: Provide working defaults that make sense for the use case
3. **Error Handling**: Implement robust error handling with helpful messages
4. **Modular Design**: Keep prefabs focused on a specific use case
5. **Consistent Interface**: Maintain consistent patterns across related prefabs

## Implementation Details

### POM Structure

The POM (Prompt Object Model) represents a structured approach to prompt construction:

```
┌───────────────────────────────────────────────┐
│ Prompt                                        │
├───────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────────┐  │
│ │ Personality     │  │ Goal                │  │
│ └─────────────────┘  └─────────────────────┘  │
│ ┌─────────────────┐  ┌─────────────────────┐  │
│ │ Instructions    │  │ Hints               │  │
│ └─────────────────┘  └─────────────────────┘  │
│ ┌─────────────────┐  ┌─────────────────────┐  │
│ │ Languages       │  │ Custom Sections     │  │
│ └─────────────────┘  └─────────────────────┘  │
└───────────────────────────────────────────────┘
```

### Contexts and Steps Architecture

The Contexts and Steps system enhances traditional POM prompts by adding structured, workflow-driven guidance on top of the base prompt. This system adds guided workflow execution while maintaining the foundational prompt structure.

#### Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ ContextBuilder                                              │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐   ┌─────────────────┐   ┌─────────────┐ │
│ │ Context A       │   │ Context B       │   │ Context C   │ │
│ │ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────┐ │ │
│ │ │ Step 1      │ │   │ │ Step 1      │ │   │ │ Step 1  │ │ │
│ │ │ - Content   │ │   │ │ - Content   │ │   │ │ - Content│ │ │
│ │ │ - Criteria  │ │   │ │ - Criteria  │ │   │ │ - Criteria│ │ │
│ │ │ - Functions │ │   │ │ - Functions │ │   │ │ - Functions│ │ │
│ │ │ - Navigation│ │   │ │ - Navigation│ │   │ │ - Navigation│ │ │
│ │ └─────────────┘ │   │ └─────────────┘ │   │ └─────────┘ │ │
│ │ ┌─────────────┐ │   │ ┌─────────────┐ │   │           │ │ │
│ │ │ Step 2      │ │   │ │ Step 2      │ │   │           │ │ │
│ │ └─────────────┘ │   │ └─────────────┘ │   │           │ │ │
│ └─────────────────┘   └─────────────────┘   └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### Navigation Flow Control

The system implements sophisticated navigation control through two primary mechanisms:

**Intra-Context Navigation (Steps within a Context):**
```
Context: Customer Service
┌────────────┐    valid_steps    ┌──────────────┐    valid_steps    ┌──────────────┐
│  greeting  │ ────────────────▶ │   identify   │ ────────────────▶ │   resolve    │
└────────────┘                  └──────────────┘                  └──────────────┘
      │                               │                                   │
      │ valid_steps = ["identify"]    │ valid_steps = ["resolve", "escalate"] │
      └───────────────────────────────┘                                   │
                                                                          │
                                      ┌──────────────┐ ◀────────────────────┘
                                      │   escalate   │   valid_steps = ["escalate"]
                                      └──────────────┘
```

**Inter-Context Navigation (Switching between Contexts):**
```
┌─────────────────┐    valid_contexts    ┌─────────────────┐    valid_contexts    ┌─────────────────┐
│     Triage      │ ─────────────────▶   │   Technical     │ ─────────────────▶   │    Billing      │
│                 │                      │   Support       │                      │                 │
└─────────────────┘                      └─────────────────┘                      └─────────────────┘
         │                                        │                                        │
         │ valid_contexts = ["technical", "billing", "general"]      │                    │
         └────────────────────────────────────────────────────────────┘                    │
                                                                                           │
         ┌─────────────────┐ ◀──────────────────────────────────────────────────────────────┘
         │    General      │                 valid_contexts = ["triage"]
         │   Inquiries     │
         └─────────────────┘
```

#### Function Restriction System

Each step can restrict available AI functions to enhance security and user experience:

```
┌─────────────────────────────────────────────────┐
│ Function Access Control by Step                │
├─────────────────────────────────────────────────┤
│                                                 │
│ Public Context                                  │
│ ┌─────────────────┐                             │
│ │ Initial Contact │ Functions: ["datetime"]     │
│ └─────────────────┘                             │
│                                                 │
│ Authenticated Context                           │
│ ┌─────────────────┐                             │
│ │ User Verified   │ Functions: ["datetime",     │
│ └─────────────────┘            "web_search"]    │
│                                                 │
│ Sensitive Context                               │
│ ┌─────────────────┐                             │
│ │ Account Access  │ Functions: "none"           │
│ └─────────────────┘                             │
└─────────────────────────────────────────────────┘
```

#### SWML Generation Process

The contexts system integrates with the existing SWML generation pipeline:

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ ContextBuilder  │ ───▶ │ Context Data    │ ───▶ │ SWML AI Verb    │
│                 │      │ Serialization   │      │ Generation      │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         │                        │                        │
         │                        │                        ▼
         │                        │               ┌─────────────────┐
         │                        │               │ prompt: {       │
         │                        │               │   contexts: {   │
         │                        │               │     "context1": │
         │                        │               │       steps: {} │
         │                        │               │   }             │
         │                        │               │ }               │
         │                        │               └─────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│ Step Content    │      │ Navigation      │
│ - Text/POM      │      │ - valid_steps   │
│ - Functions     │      │ - valid_contexts│
│ - Criteria      │      │ - Restrictions  │
└─────────────────┘      └─────────────────┘
```

#### Integration with Existing Systems

**Coexistence with Traditional Prompts:**
```
┌─────────────────────────────────────────────────┐
│ Agent Configuration                             │
├─────────────────────────────────────────────────┤
│ ┌─────────────────┐   ┌─────────────────────┐   │
│ │ Traditional     │   │ Contexts and        │   │
│ │ POM Sections    │   │ Steps Workflow      │   │
│ │ (from skills,   │   │                     │   │
│ │ global config)  │   │                     │   │
│ └─────────────────┘   └─────────────────────┘   │
│         │                       │               │
│         └───────────┬───────────┘               │
│                     ▼                           │
│           ┌─────────────────┐                   │
│           │ Combined SWML   │                   │
│           │ Output          │                   │
│           └─────────────────┘                   │
└─────────────────────────────────────────────────┘
```

**Skills and Function Integration:**
- Skills continue to work normally
- Function restrictions apply per-step
- DataMap tools integrate directly
- State management remains unchanged

#### Implementation Details

**Context Validation Rules:**
- Single context must be named "default"
- Multiple contexts can have any names
- Context names must be unique within an agent
- All referenced contexts in navigation must exist

**Step Content Rules:**
- Cannot mix `set_text()` with `add_section()` in same step
- POM sections support full feature set (bullets, numbering, etc.)
- Direct text provides simpler prompt definition
- Content is mandatory for each step

**Navigation Validation:**
- Referenced steps in `valid_steps` must exist in same context
- Referenced contexts in `valid_contexts` must exist in agent
- Empty lists explicitly block navigation
- Omitted navigation settings have specific defaults

**Function Security:**
- Functions must match exact names from agent's registered functions
- "none" keyword blocks all functions
- Missing `set_functions()` allows all functions
- Function restrictions are enforced at SWML generation time

#### Performance Considerations

**Memory Usage:**
- Contexts are built once at agent initialization
- Serialization occurs only during SWML requests
- Navigation validation happens at build time

**Execution Flow:**
- No runtime performance impact
- SWML generation includes contexts data
- SignalWire server handles workflow execution

**Scalability:**
- Supports complex multi-context workflows
- No limit on number of contexts or steps
- Efficient serialization format for large workflows

#### When to Use Contexts vs DataMap vs Skills vs Custom Tools

**Use Contexts and Steps when:**
- Building guided, multi-step workflows
- Need explicit control over conversation flow
- Want to restrict function access by conversation stage
- Creating customer service or support flows
- Building applications, surveys, or onboarding processes

**Use DataMap when:**
- Integrating with REST APIs
- Need serverless tool execution
- Want rapid API tool development
- Building simple request/response tools

**Use Skills when:**
- Adding reusable capabilities
- Need one-liner integration
- Building general-purpose agent features
- Want community-developed functionality

**Use Custom Tools when:**
- Need complex business logic
- Require custom webhook endpoints
- Building agent-specific functionality
- Need maximum flexibility and control

The architecture supports using all these approaches together, allowing developers to choose the right tool for each specific requirement within a single agent.

### SWAIG Function Definition

Functions are defined with:
- Name
- Description
- Parameters schema
- Implementation
- Security settings

Example:
<!-- snippet: no-run illustrative fragment: AgentBase instance methods (define_tool/prompt_add_section/set_dynamic_config_callback) shown outside an agent class -->
```ruby
define_tool(
  name: 'get_weather',
  description: 'Get the current weather for a location',
  parameters: {
    'location' => {
      'type' => 'string',
      'description' => 'The city or location to get weather for'
    }
  }
) do |args, raw_data|
  location = args.fetch('location', 'Unknown location')
  SignalWire::Swaig::FunctionResult.new("It's sunny and 72°F in #{location}.")
end
```

### HTTP Routing

The SDK uses FastAPI for routing with these key endpoints:

- **/** (GET/POST): Main endpoint that returns the SWML document
- **/swaig/** (POST): Endpoint for executing SWAIG functions
- **/post_prompt/** (POST): Endpoint for receiving conversation summaries
- **/sip/** (GET/POST): Optional endpoint for SIP routing

The SDK also supports dynamic creation of custom routing endpoints:

- **Custom routing callbacks**: Register callbacks for specific paths (e.g., `/customer`, `/product`)
- **Dynamic content serving**: Serve different SWML documents based on the request path
- **Request inspection**: Examine request data to make routing decisions
- **Redirection**: Optionally redirect requests to other endpoints

## Deployment Options

The SDK supports multiple deployment models:

1. **Standalone Mode**
   - Single agent on dedicated port
   - Direct invocation via `agent.run()` (auto-detects deployment mode)

2. **Multi-Agent Mode**
   - Multiple agents on same server with different routes
   - `app.include_router(agent.as_router(), prefix=agent.route)`

3. **Reverse Proxy Integration**
   - Set `SWML_PROXY_URL_BASE` for proper webhook URL generation
   - Enable SSL termination at proxy level

4. **Direct HTTPS Mode**
   - Configure with SSL certificates
   - `agent.serve(ssl_cert="cert.pem", ssl_key="key.pem")`

## Best Practices

1. **Prompt Structure**
   - Use POM for clear, structured prompts
   - Keep personality and goal sections concise
   - Use specific instructions for behavior guidance

2. **SWAIG Functions**
   - Define clear parameter schemas
   - Provide comprehensive descriptions for AI context
   - Implement proper error handling
   - Return structured responses

3. **Session Lifecycle**
   - Implement `startup_hook` and `hangup_hook` SWAIG functions to track session lifecycle
   - Use these hooks to initialize and clean up session resources
   - Store any persistent data in your preferred external storage

4. **Security**
   - Use HTTPS in production
   - Set strong authentication credentials
   - Enable security for sensitive operations with `secure=True`

5. **Deployment**
   - Use environment variables for configuration
   - Implement proper logging
   - Monitor agent performance and usage

6. **Prefab Usage**
   - Use existing prefabs for common patterns
   - Extend prefabs rather than starting from scratch
   - Create your own prefabs for reusable patterns
   - Share prefabs across projects for consistency

## Schema Validation

The SDK uses JSON Schema validation for:
- SWML document structure
- POM section validation
- SWAIG function parameter validation

Schema definitions are loaded from the `schema.json` file, which provides the complete specification for all supported SWML verbs and structures.

## Logging

The SDK uses structlog for structured logging with JSON output format. Key events logged include:
- Service initialization
- Request handling
- Function execution
- Authentication events
- Error conditions

## Configuration

Configuration options are available through:
1. **Constructor Parameters**: Direct configuration in code
2. **Environment Variables**: System-level configuration
3. **Method Calls**: Runtime configuration updates

Key environment variables:
- `SWML_BASIC_AUTH_USER`: Username for basic auth
- `SWML_BASIC_AUTH_PASSWORD`: Password for basic auth
- `SWML_PROXY_URL_BASE`: Base URL when behind reverse proxy
- `SWML_SSL_ENABLED`: Enable HTTPS
- `SWML_SSL_CERT_PATH`: Path to SSL certificate
- `SWML_SSL_KEY_PATH`: Path to SSL key
- `SWML_DOMAIN`: Domain name for the service
- `SWML_SKIP_SCHEMA_VALIDATION`: When set to `1`/`true`/`yes`, disables SWML schema validation (a security/strictness knob — off by default; leave unset in production)
- `SWML_ALLOW_PRIVATE_URLS`: When set to `1`/`true`/`yes`, allows the URL validator to accept private / loopback / link-local hosts (a security knob — off by default; leave unset unless you intentionally target internal hosts)

## Request Flow

### SWML Document Request (GET/POST /)

1. Client requests the root endpoint
2. Authentication is validated 
3. `on_swml_request()` is called to allow customization
4. Current SWML document is rendered and returned

### SWAIG Function Call (POST /swaig/)

1. Client sends a POST request to the SWAIG endpoint
2. Authentication is validated
3. Function name and arguments are extracted
4. Token validation occurs for secure functions
5. Function is executed and result returned

### Post-Prompt Processing (POST /post_prompt/)

1. Client sends conversation summary data
2. Authentication is validated
3. Summary is extracted from request
4. `on_summary()` is called to process the data

## Session Management

The SDK provides session management for secure function call authentication:

```
┌───────────────┐     ┌─────────────────┐     ┌───────────────┐
│ Session       │     │ Token           │     │ Validation    │
│ Manager       │━━━━▶│ Generation      │━━━━▶│ Layer         │
└───────────────┘     └─────────────────┘     └───────────────┘
```

Components:
- **SessionManager**: Handles session creation, activation, and termination
- **Token Management**: Secure token generation and validation for function calls

Session lifecycle can be tracked by implementing special SWAIG functions:
- **startup_hook**: Called when a new call/session starts
- **hangup_hook**: Called when a call/session ends

These hooks are optional but useful for:
- Initializing session-specific resources
- Loading user preferences or history
- Cleaning up temporary data
- Logging session metrics

Note: For persistent state storage across calls, integrate your preferred backend (Redis, PostgreSQL, etc.) directly in your agent code.
