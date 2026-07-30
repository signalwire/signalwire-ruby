# SignalWire AI Agents SDK - Complete API Reference

<!-- snippet-setup: every ruby example on this page assumes the SDK is required -->
```ruby
require 'signalwire'
```

This document provides a comprehensive reference for all public APIs in the SignalWire AI Agents SDK.

## Table of Contents

1. [AgentBase Class](#agentbase-class) - Core agent functionality
2. [SwaigFunctionResult Class](#swaigfunctionresult-class) - SWAIG (SignalWire AI Gateway) function response handling
3. [DataMap Class](#datamap-class) - Serverless API tools that execute on SignalWire's servers
4. [Context System](#context-system) - Structured workflows
5. [State Management](#state-management) - Persistent state
6. [Skills System](#skills-system) - Modular capabilities
7. [Utility Classes](#utility-classes) - Supporting classes

---

## AgentBase Class

The `AgentBase` class is the foundation for creating AI agents. It extends `SWMLService` (the base class for generating SWML -- SignalWire Markup Language -- documents) and provides comprehensive functionality for building conversational AI agents.

### Constructor

<!-- snippet: no-run constructor/config signature illustration referencing assumed placeholder locals (name/function_name/contexts/MyAgent) -->
```ruby
SignalWire::AgentBase.new(
  name:,                          # String
  route: "/",                     # String
  host: "0.0.0.0",                # String
  port: 3000,                     # Integer
  basic_auth: nil,                # [username, password] or nil
  use_pom: true,                  # Boolean
  token_expiry_secs: 3600,        # Integer
  auto_answer: true,              # Boolean
  record_call: false,             # Boolean
  record_format: "mp4",           # String
  record_stereo: true,            # Boolean
  default_webhook_url: nil,       # String or nil
  agent_id: nil,                  # String or nil
  native_functions: nil,          # Array<String> or nil
  schema_path: nil,               # String or nil
  suppress_logs: false,           # Boolean
  enable_post_prompt_override: false, # Boolean
  check_for_input_override: false,    # Boolean
  config_file: nil                # String or nil
)
```

**Parameters:**
- `name` (str): Human-readable name for the agent
- `route` (str): HTTP route path for the agent (default: "/")
- `host` (str): Host address to bind to (default: "0.0.0.0")
- `port` (int): Port number to listen on (default: 3000)
- `basic_auth` (Optional[Tuple[str, str]]): Username/password for HTTP basic auth
- `use_pom` (bool): Whether to use Prompt Object Model (default: True)
- `token_expiry_secs` (int): Security token expiration time (default: 3600)
- `auto_answer` (bool): Automatically answer incoming calls (default: True)
- `record_call` (bool): Record calls by default (default: False)
- `record_format` (str): Recording format: "mp4", "wav", "mp3" (default: "mp4")
- `record_stereo` (bool): Record in stereo (default: True)
- `default_webhook_url` (Optional[str]): Default webhook URL for functions
- `agent_id` (Optional[str]): Unique identifier for the agent
- `native_functions` (Optional[List[str]]): List of native function names to enable
- `schema_path` (Optional[str]): Path to custom SWML schema file
- `suppress_logs` (bool): Suppress logging output (default: False)
- `enable_post_prompt_override` (bool): Allow post-prompt URL override (default: False)
- `check_for_input_override` (bool): Allow check-for-input URL override (default: False)
- `config_file` (Optional[str]): Path to JSON configuration file with environment variable substitution support. See [Configuration Guide](configuration.md) for details.

### Core Methods

#### Deployment and Execution

##### `run(event=None, context=None, force_mode=None, host=None, port=None)`
Auto-detects deployment environment and runs the agent appropriately.

**Parameters:**
- `event`: Event object for serverless environments
- `context`: Context object for serverless environments  
- `force_mode` (str): Force specific mode: "server", "lambda", "cgi", "cloud_function"
- `host` (Optional[str]): Override host address
- `port` (Optional[int]): Override port number

**Usage:**
<!-- snippet: no-run ends by starting a blocking server (agent.run/serve) -->
```ruby
# Auto-detect environment
agent.run

# Force server mode
agent.run(force_mode: "server", host: "localhost", port: 8080)

# Lambda handler
def lambda_handler(event, context)
  agent.run(event: event, context: context)
end
```

##### `serve(host=None, port=None)`
Explicitly run as HTTP server using FastAPI/Uvicorn.

**Parameters:**
- `host` (Optional[str]): Host address to bind to
- `port` (Optional[int]): Port number to listen on

**Usage:**
<!-- snippet: no-run ends by starting a blocking server (agent.run/serve) -->
```ruby
agent.serve                          # Use constructor defaults
agent.serve(host: "0.0.0.0", port: 3000)
```

### Prompt Configuration

#### Text-Based Prompts

##### `prompt_text=` (assignment) / `set_prompt_text(text)` (chainable)
Set the agent's prompt as raw text. The `prompt_text =` assignment is the
idiomatic Ruby form; the chainable `set_prompt_text` (returns `self`) remains for
fluent building. (Read it back with `agent.prompt_text`.)

**Parameters:**
- `text` (String): The complete prompt text

**Usage:**
```ruby
agent.prompt_text = "You are a helpful customer service agent."
```

##### `post_prompt=` (assignment) / `set_post_prompt(text)` (chainable)
Set additional text to append after the main prompt. The `post_prompt =`
assignment is the idiomatic Ruby form; the chainable `set_post_prompt` (returns
`self`) remains for fluent building. (Read it back with `agent.post_prompt`.)

**Parameters:**
- `text` (String): Text to append after main prompt

**Usage:**
```ruby
agent.post_prompt = "Always be polite and professional."
```

#### LLM Parameter Configuration

##### `set_prompt_llm_params`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def set_prompt_llm_params(**params) # => AgentBase
```
Set Language Model parameters for the main prompt. Accepts any parameters which will be passed through to the SignalWire server. The server validates and applies parameters based on the target model's capabilities.

**Common Parameters:**
- `temperature`: Controls randomness. Lower = more focused
- `top_p`: Nucleus sampling threshold
- `barge_confidence`: ASR confidence to interrupt
- `presence_penalty`: Topic diversity control
- `frequency_penalty`: Repetition control

Note: No defaults are sent unless explicitly set. Invalid parameters for the selected model will be handled/ignored by the server.

**Usage:**
```ruby
# Configure for consistent, professional responses
agent.set_prompt_llm_params(
  temperature: 0.3,
  top_p: 0.9,
  barge_confidence: 0.7,
  presence_penalty: 0.1,
  frequency_penalty: 0.2
)
```

##### `set_post_prompt_llm_params`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def set_post_prompt_llm_params(**params) # => AgentBase
```
Set Language Model parameters for the post-prompt. Accepts any parameters which will be passed through to the SignalWire server. The server validates and applies parameters based on the target model's capabilities.

**Common Parameters:**
- `temperature`: Controls randomness. Lower = more focused
- `top_p`: Nucleus sampling threshold
- `presence_penalty`: Topic diversity control
- `frequency_penalty`: Repetition control

Note: barge_confidence is not applicable to post-prompt. No defaults are sent unless explicitly set.

**Usage:**
```ruby
# Configure for focused summaries
agent.set_post_prompt_llm_params(
  temperature: 0.2,
  top_p: 0.9
)
```

#### Structured Prompts (POM)

##### `prompt_add_section`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def prompt_add_section(
  title,                      # String (positional)
  body = nil,                 # String (positional)
  bullets: nil,               # Array<String>
  numbered: false,            # Boolean
  numbered_bullets: false,    # Boolean
  subsections: nil            # Array<Hash>
) # => AgentBase
```
Add a structured section to the prompt using Prompt Object Model.

**Parameters:**
- `title` (str): Section title/heading
- `body` (str): Main section content (default: "")
- `bullets` (Optional[List[str]]): List of bullet points
- `numbered` (bool): Use numbered sections (default: False)
- `numbered_bullets` (bool): Use numbered bullet points (default: False)
- `subsections` (Optional[List[Dict]]): Nested subsections

**Usage:**
```ruby
# Simple section
agent.prompt_add_section("Role", "You are a customer service representative.")

# Section with bullets
agent.prompt_add_section(
  "Guidelines",
  "Follow these principles:",
  bullets: ["Be helpful", "Stay professional", "Listen carefully"]
)

# Numbered bullets
agent.prompt_add_section(
  "Process",
  "Follow these steps:",
  bullets: ["Greet the customer", "Identify their need", "Provide solution"],
  numbered_bullets: true
)
```

##### `prompt_add_to_section`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def prompt_add_to_section(
  title,                      # String (positional)
  body: nil,                  # String
  bullet: nil,                # String
  bullets: nil                # Array<String>
) # => AgentBase
```
Add content to an existing prompt section.

**Parameters:**
- `title` (str): Title of existing section to modify
- `body` (Optional[str]): Additional body text to append
- `bullet` (Optional[str]): Single bullet point to add
- `bullets` (Optional[List[str]]): Multiple bullet points to add

**Usage:**
```ruby
# Add body text to existing section
agent.prompt_add_to_section("Guidelines", body: "Remember to always verify customer identity.")

# Add single bullet
agent.prompt_add_to_section("Process", bullet: "Document the interaction")

# Add multiple bullets
agent.prompt_add_to_section("Process", bullets: ["Follow up", "Close ticket"])
```

##### `prompt_add_subsection`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def prompt_add_subsection(
  parent_title,               # String (positional)
  title,                      # String (positional)
  body = nil,                 # String (positional)
  bullets: nil                # Array<String>
) # => AgentBase
```
Add a subsection to an existing prompt section.

**Parameters:**
- `parent_title` (str): Title of parent section
- `title` (str): Subsection title
- `body` (str): Subsection content (default: "")
- `bullets` (Optional[List[str]]): Subsection bullet points

**Usage:**
```ruby
agent.prompt_add_subsection(
  "Guidelines",
  "Escalation Rules",
  "Escalate when:",
  bullets: ["Customer is angry", "Technical issue beyond scope"]
)
```

### Voice and Language Configuration

##### `add_language`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_language(
  name,                       # String (positional)
  code = nil,                 # String (positional)
  voice = nil,                # String (positional)
  speech_fillers: nil,        # Array<String>
  function_fillers: nil,      # Array<String>
  engine: nil,                # String
  model: nil                  # String
) # => AgentBase
```
Configure voice and language settings for the agent.

**Parameters:**
- `name` (str): Human-readable language name
- `code` (str): Language code (e.g., "en-US", "es-ES")
- `voice` (str): Voice identifier (e.g., "rime.spore", "nova.luna")
- `speech_fillers` (Optional[List[str]]): Filler phrases during speech processing
- `function_fillers` (Optional[List[str]]): Filler phrases during function execution
- `engine` (Optional[str]): TTS engine to use
- `model` (Optional[str]): AI model to use

**Usage:**
```ruby
# Basic language setup
agent.add_language("English", "en-US", "rime.spore")

# With custom fillers
agent.add_language(
  "English",
  "en-US",
  "nova.luna",
  speech_fillers: ["Let me think...", "One moment..."],
  function_fillers: ["Processing...", "Looking that up..."]
)
```

##### `languages=` (assignment) / `set_languages(languages)` (chainable)
Set multiple language configurations at once. The `languages =` assignment is the
idiomatic Ruby form; the chainable `set_languages` (returns `self`) remains for
fluent building.

**Parameters:**
- `languages` (Array<Hash>): List of language configuration hashes

**Usage:**
```ruby
agent.languages = [
    { "name" => "English", "code" => "en-US", "voice" => "rime.spore" },
    { "name" => "Spanish", "code" => "es-ES", "voice" => "nova.luna" }
]
```

### Speech Recognition Configuration

##### `add_hint(hint: str) -> AgentBase`
Add a single speech recognition hint.

**Parameters:**
- `hint` (str): Word or phrase to improve recognition accuracy

**Usage:**
```ruby
agent.add_hint("SignalWire")
```

##### `add_hints(hints: List[str]) -> AgentBase`
Add multiple speech recognition hints.

**Parameters:**
- `hints` (List[str]): List of words/phrases for better recognition

**Usage:**
```ruby
agent.add_hints(["SignalWire", "SWML", "API", "webhook", "SIP"])
```

##### `add_pattern_hint`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_pattern_hint(
  hint,                       # String (positional)
  pattern,                    # String (positional)
  replace,                    # String (positional)
  ignore_case: false          # Boolean
) # => AgentBase
```
Add a pattern-based hint for speech recognition.

**Parameters:**
- `hint` (str): The hint phrase
- `pattern` (str): Regex pattern to match
- `replace` (str): Replacement text
- `ignore_case` (bool): Case-insensitive matching (default: False)

**Usage:**
```ruby
agent.add_pattern_hint(
  "phone number",
  '(\d{3})-(\d{3})-(\d{4})',
  '(\1) \2-\3'
)
```

##### `add_pronunciation`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_pronunciation(
  replace,                    # String (positional)
  with_text,                  # String (positional)
  ignore_case: false          # Boolean
) # => AgentBase
```
Add pronunciation rules for text-to-speech.

**Parameters:**
- `replace` (str): Text to replace
- `with_text` (str): Replacement pronunciation
- `ignore_case` (bool): Case-insensitive replacement (default: False)

**Usage:**
```ruby
agent.add_pronunciation("API", "A P I")
agent.add_pronunciation("SWML", "swim-el")
```

##### `pronunciations=` (assignment) / `set_pronunciations(pronunciations)` (chainable)

```ruby
agent.pronunciations = pronunciations   # idiomatic assignment
agent.set_pronunciations(pronunciations) # chainable, returns self
```
Set multiple pronunciation rules at once. The `pronunciations =` assignment is the
idiomatic Ruby form; the chainable `set_pronunciations` (returns `self`) remains
for fluent building.

**Parameters:**
- `pronunciations` (Array<Hash>): List of pronunciation rule hashes

**Usage:**
```ruby
agent.pronunciations = [
    { "replace" => "API", "with" => "A P I" },
    { "replace" => "SWML", "with" => "swim-el", "ignore_case" => true }
]
```

### AI Parameters Configuration

##### `set_param(key: str, value: Any) -> AgentBase`
Set a single AI parameter.

**Parameters:**
- `key` (str): Parameter name
- `value` (Any): Parameter value

**Usage:**
```ruby
agent.set_param("ai_model", "gpt-4.1-nano")
agent.set_param("end_of_speech_timeout", 500)
```

##### `params=` (assignment) / `set_params(params)` (chainable)
Set multiple AI parameters at once. The `params =` assignment is the idiomatic
Ruby form; the chainable `set_params` (returns `self`) remains for fluent
building. (For a single parameter, use `set_param(key, value)` — it takes two
arguments, so it stays a method.)

**Parameters:**
- `params` (Hash): Hash of parameter key-value pairs

**Common Parameters:**
- `ai_model`: AI model to use ("gpt-4.1-nano", "gpt-4.1-mini", etc.)
- `end_of_speech_timeout`: Milliseconds to wait for speech end (default: 1000)
- `attention_timeout`: Milliseconds before attention timeout (default: 30000)
- `background_file_volume`: Volume for background audio (-60 to 0 dB)
- `temperature`: AI creativity/randomness (0.0 to 2.0)
- `max_tokens`: Maximum response length
- `top_p`: Nucleus sampling parameter (0.0 to 1.0)

**Usage:**
```ruby
agent.params = {
    "ai_model" => "gpt-4.1-nano",
    "end_of_speech_timeout" => 500,
    "attention_timeout" => 15000,
    "background_file_volume" => -20,
    "temperature" => 0.7
}
```

### Global Data Management

##### `global_data=` (assignment) / `set_global_data(data)` (chainable)
Set global data available to the AI and functions. The `global_data =` assignment
is the idiomatic Ruby form; the chainable `set_global_data` (returns `self`)
remains for fluent building. (To merge into existing global data instead of
replacing it, use `update_global_data`.)

**Parameters:**
- `data` (Hash): Global data hash

**Usage:**
```ruby
agent.global_data = {
    "company_name" => "Acme Corp",
    "support_hours" => "9 AM - 5 PM EST",
    "escalation_number" => "+1-555-0123"
}
```

##### `update_global_data(data: Dict[str, Any]) -> AgentBase`
Update existing global data (merge with existing).

**Parameters:**
- `data` (Dict[str, Any]): Data to merge with existing global data

**Usage:**
```ruby
agent.update_global_data({
  "current_promotion" => "20% off all services",
  "promotion_expires" => "2024-12-31"
})
```

### Function Definition

##### `define_tool`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def define_tool(
  name:,                      # String
  description:,               # String
  parameters:,                # Hash — property_name => JSON-schema hash (REQUIRED)
  handler:,                   # Callable (REQUIRED; pass nil and give a block)
  secure: true,               # Boolean
  fillers: nil,               # Hash — language code => Array<String>
  wait_file: nil,             # String — audio URL played while the tool runs
  wait_file_loops: nil,       # Integer — loop count for wait_file
  webhook_url: nil,           # String
  required: nil,              # Array<String> — required parameter names
  is_typed_handler: false,    # Boolean
  swaig_fields: nil,          # Hash — additional SWAIG properties
  &block                      # canonical handler: |args, raw_data|
) # => AgentBase
```
Define a custom SWAIG function/tool.

**Parameters:**
- `name` (str): Function name
- `description` (str): Function description for AI
- `parameters` (Hash): REQUIRED. JSON schema for function parameters; state `{}` explicitly for a tool that takes none.
- `handler` (Callable): REQUIRED. The callable to execute when called. Ruby cannot let a block satisfy a required positional, so the canonical block form passes `handler: nil` and supplies the block (which wins).
- `secure` (Boolean): Require security token (default: `true`)
- `fillers` (Optional[Dict[str, List[str]]]): Language-specific filler phrases
- `webhook_url` (Optional[str]): Custom webhook URL
- `**swaig_fields`: Additional SWAIG function properties

**Usage:**
```ruby
agent.define_tool(
  name: "get_weather",
  description: "Get current weather for a location",
  parameters: {
    "location" => {
      "type" => "string",
      "description" => "City name"
    }
  },
  required: ["location"],
  fillers: { "en-US" => ["Checking weather...", "Looking up forecast..."] }, handler: nil
) do |args, raw_data|
  location = args["location"] || "Unknown"
  SignalWire::Swaig::FunctionResult.new("The weather in #{location} is sunny and 75°F")
end
```

##### `@AgentBase.tool(name=None, **kwargs)` (Class Decorator)
Decorator for defining tools as class methods.

**Parameters:**
- `name` (Optional[str]): Function name (defaults to method name)
- `**kwargs`: Same parameters as `define_tool()`

When `parameters` is omitted and the handler has type-hinted parameters (beyond `self`), the schema is inferred automatically from the type hints. The description is extracted from the docstring's first line, and per-parameter descriptions come from the `Args:` block.

**Usage (explicit schema):**
```ruby
class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: "my-agent", route: "/agent")

    # Ruby has no decorator; register the tool with a block handler.
    define_tool(
      name: "get_time",
      description: "Get current time",
      parameters: {}, handler: nil
    ) do |args, raw_data|
      SignalWire::Swaig::FunctionResult.new("Current time: #{Time.now}")
    end
  end
end
```

**Usage (type-hinted, schema inferred):**
```ruby
class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: "my-agent", route: "/agent")

    define_tool(
      name: "get_weather",
      description: "Get the weather forecast.",
      parameters: {
        "city"  => { "type" => "string", "description" => "Name of the city" },
        "units" => { "type" => "string", "description" => "Temperature units" }
      },
      required: ["city"], handler: nil
    ) do |args, raw_data|
      SignalWire::Swaig::FunctionResult.new("Weather in #{args['city']}")
    end
  end
end
```

##### `register_swaig_function`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def register_swaig_function(
  func_def                    # Hash — complete SWAIG function definition
) # => AgentBase
```
Register a pre-built SWAIG function dictionary.

**Parameters:**
- `function_dict` (Dict[str, Any]): Complete SWAIG function definition

**Usage:**
```ruby
# Register a DataMap tool
weather_tool = SignalWire::DataMap.new("get_weather").webhook("GET", "https://api.weather.com/...")
agent.register_swaig_function(weather_tool.to_swaig_function)
```

### Session Lifecycle Hooks

SignalWire AI agents support special SWAIG functions that are automatically called at specific points in the conversation lifecycle:

##### `startup_hook`
Called when a new conversation/call begins.

**Implementation:**
```ruby
agent.define_tool(
  name: "startup_hook",
  description: "Called when a new conversation starts to initialize state",
  parameters: {}, handler: nil
) do |args, raw_data|
  call_id = raw_data["call_id"]
  # Initialize session resources, load user data, etc.
  SignalWire::Swaig::FunctionResult.new("Session initialized")
end
```

##### `hangup_hook`
Called when a conversation/call ends.

**Implementation:**
```ruby
agent.define_tool(
  name: "hangup_hook",
  description: "Called when conversation ends to clean up resources",
  parameters: {}, handler: nil
) do |args, raw_data|
  call_id = raw_data["call_id"]
  # Clean up resources, save session data, etc.
  SignalWire::Swaig::FunctionResult.new("Session ended")
end
```

**Common Use Cases:**
- Loading user preferences at session start
- Initializing session-specific resources
- Logging conversation metrics
- Cleaning up temporary data
- Saving conversation summaries

### Skills System

##### `add_skill`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_skill(
  skill_name,                 # String
  params = {}                 # Hash — skill configuration
) # => AgentBase
```
Add a modular skill to the agent.

**Parameters:**
- `skill_name` (str): Name of the skill to add
- `params` (Optional[Dict[str, Any]]): Skill configuration parameters

**Available Skills:**
- `datetime`: Current date/time information
- `math`: Mathematical calculations
- `web_search`: Google Custom Search integration
- `datasphere`: SignalWire DataSphere search
- `native_vector_search`: Document search over a remote search server (the Ruby port does not ship the offline/embedded backend)

**Usage:**
```ruby
# Simple skill
agent.add_skill("datetime")
agent.add_skill("math")

# Skill with configuration
agent.add_skill("web_search", {
  "api_key" => "your-google-api-key",
  "search_engine_id" => "your-search-engine-id",
  "num_results" => 3
})

# Multiple instances with different names
agent.add_skill("web_search", {
  "api_key" => "your-api-key",
  "search_engine_id" => "general-engine",
  "tool_name" => "search_general"
})

agent.add_skill("web_search", {
  "api_key" => "your-api-key",
  "search_engine_id" => "news-engine",
  "tool_name" => "search_news"
})
```

##### `remove_skill(skill_name: str) -> AgentBase`
Remove a skill from the agent.

**Parameters:**
- `skill_name` (str): Name of skill to remove

**Usage:**
```ruby
agent.remove_skill("web_search")
```

##### `list_skills() -> List[str]`
Get list of currently added skills.

**Returns:**
- List[str]: Names of active skills

**Usage:**
```ruby
active_skills = agent.list_skills
puts "Active skills: #{active_skills}"
```

##### `has_skill?(skill_name) -> Boolean`
Check if a skill is currently added. Note the Ruby predicate `?` suffix.

**Parameters:**
- `skill_name` (String): Name of skill to check

**Returns:**
- Boolean: `true` if skill is active

**Usage:**
```ruby
if agent.has_skill?("web_search")
  puts "Web search is available"
end
```

### Native Functions

##### `native_functions=` (assignment) / `set_native_functions(function_names)` (chainable)

```ruby
agent.native_functions = function_names    # idiomatic assignment
agent.set_native_functions(function_names) # chainable, returns self
```
Enable specific native SWML functions. The `native_functions =` assignment is the
idiomatic Ruby form; the chainable `set_native_functions` (returns `self`) remains
for fluent building.

**Parameters:**
- `function_names` (Array<String>): List of native function names to enable

**Available Native Functions:**
- `transfer`: Transfer calls
- `hangup`: End calls
- `play`: Play audio files
- `record`: Record audio
- `send_sms`: Send SMS messages

**Usage:**
```ruby
agent.native_functions = ["transfer", "hangup", "send_sms"]
```

##### `internal_fillers=` (assignment) / `set_internal_fillers(internal_fillers)` (chainable)

```ruby
agent.internal_fillers = internal_fillers    # idiomatic assignment
agent.set_internal_fillers(internal_fillers) # chainable, returns self
```
Set custom filler phrases for internal/native SWAIG functions. The
`internal_fillers =` assignment is the idiomatic Ruby form; the chainable
`set_internal_fillers` (returns `self`) remains for fluent building.

**Parameters:**
- `internal_fillers` (Hash): Function name → language code → filler phrases

**Available Internal Functions:**
- `next_step`: Moving between workflow steps (contexts system)
- `change_context`: Switching contexts in workflows  
- `check_time`: Getting current time
- `wait_for_user`: Waiting for user input
- `wait_seconds`: Pausing for specified duration
- `get_visual_input`: Processing visual data

**Usage:**
```ruby
agent.internal_fillers = {
    "next_step" => {
        "en-US" => ["Moving to the next step...", "Let's continue..."],
        "es" => ["Pasando al siguiente paso...", "Continuemos..."]
    },
    "check_time" => {
        "en-US" => ["Let me check the time...", "Getting current time..."]
    }
}
```

##### `add_internal_filler`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_internal_filler(
  func_name,                  # String
  lang_code,                  # String
  fillers                     # Array<String>
) # => AgentBase
```
Add internal fillers for a specific function and language.

**Parameters:**
- `function_name` (str): Name of the internal function
- `language_code` (str): Language code (e.g., "en-US", "es", "fr")
- `fillers` (List[str]): List of filler phrases

**Usage:**
```ruby
agent.add_internal_filler("next_step", "en-US", [
  "Great! Let's move to the next step...",
  "Perfect! Moving forward..."
])
```

### Function Includes

##### `add_function_include`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def add_function_include(
  url,                        # String (positional)
  functions,                  # Array<String> (positional)
  meta_data: nil              # Hash
) # => AgentBase
```
Include external SWAIG functions from another service.

**Parameters:**
- `url` (str): URL of external SWAIG service
- `functions` (List[str]): List of function names to include
- `meta_data` (Optional[Dict[str, Any]]): Additional metadata

**Usage:**
```ruby
agent.add_function_include(
  "https://external-service.com/swaig",
  ["external_function1", "external_function2"],
  meta_data: { "service" => "external", "version" => "1.0" }
)
```

##### `function_includes=` (assignment) / `set_function_includes(includes)` (chainable)

```ruby
agent.function_includes = includes    # idiomatic assignment
agent.set_function_includes(includes) # chainable, returns self
```
Set multiple function includes at once. The `function_includes =` assignment is
the idiomatic Ruby form; the chainable `set_function_includes` (returns `self`)
remains for fluent building.

**Parameters:**
- `includes` (Array<Hash>): List of function include configurations

**Usage:**
```ruby
agent.function_includes = [
    {
        "url" => "https://service1.com/swaig",
        "functions" => ["func1", "func2"]
    },
    {
        "url" => "https://service2.com/swaig",
        "functions" => ["func3"],
        "meta_data" => { "priority" => "high" }
    }
]
```

### Webhook Configuration

##### `web_hook_url=` (assignment) / `set_web_hook_url(url)` (chainable)
Set default webhook URL for SWAIG functions. The `web_hook_url =` assignment is
the idiomatic Ruby form; the chainable `set_web_hook_url` (returns `self`) remains
for fluent building.

**Parameters:**
- `url` (String): Default webhook URL

**Usage:**
```ruby
agent.web_hook_url = "https://myserver.com/webhook"
```

##### `post_prompt_url=` (assignment) / `set_post_prompt_url(url)` (chainable)
Set URL for post-prompt processing. The `post_prompt_url =` assignment is the
idiomatic Ruby form; the chainable `set_post_prompt_url` (returns `self`) remains
for fluent building.

**Parameters:**
- `url` (String): Post-prompt webhook URL

**Usage:**
```ruby
agent.post_prompt_url = "https://myserver.com/post-prompt"
```

##### `add_swaig_query_params(params: dict) -> AgentBase`
Add query parameters to be included in all SWAIG webhook URLs.

This is useful for preserving dynamic configuration state across SWAIG callbacks. For example, if your dynamic config adds skills based on query parameters, you can pass those same parameters through to the SWAIG webhook so the same configuration is applied.

**Parameters:**
- `params` (dict): Dictionary of query parameter key-value pairs

**Usage:**
```ruby
# In dynamic config callback, preserve configuration parameters
agent.set_dynamic_config_callback(nil) do |query_params, body, headers, config|
  customer_id = query_params["customer_id"]
  if customer_id
    # Pass through to SWAIG callbacks
    config.add_swaig_query_params({ "customer_id" => customer_id })
    config.add_skill("customer_lookup", { "customer_id" => customer_id })
  end
end
```

##### `clear_swaig_query_params() -> AgentBase`
Clear all SWAIG query parameters.

**Usage:**
```ruby
agent.clear_swaig_query_params
```

### Debug Events

##### `enable_debug_events`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def enable_debug_events(level = 1) # => AgentBase
```
Enable the debug event webhook for this agent. When enabled, the AI module will POST real-time debug events to a `/debug_events` endpoint on this agent during calls. Events are automatically logged via the agent's structured logger and can optionally be handled with a custom callback via `on_debug_event()`.

**Parameters:**
- `level` (int): Debug event verbosity level. `1` = high-level events (barge, errors, session start/end, step changes). `2+` = adds high-volume events (every LLM request/response, conversation_add). Default: `1`

**Usage:**
```ruby
agent.enable_debug_events    # level 1 (default)
agent.enable_debug_events(2) # include high-volume events
```

**How it works:**
- Registers a `/debug_events` POST endpoint on the agent's HTTP server
- Auto-sets `debug_webhook_url` and `debug_webhook_level` in the SWML `params` during rendering
- The URL is built automatically using the same auth/proxy logic as other webhook URLs
- No manual URL configuration needed

**Event types at level 1:**

| Event label | Description |
|-------------|-------------|
| `session_start` | AI session started (model, TTS engine, voice, language) |
| `session_end` | AI session ended (reason, duration, token counts) |
| `barge` | User interrupted AI speech (barge type, elapsed ms) |
| `step_change` | Conversation step changed |
| `context_change` | Conversation context changed |
| `llm_error` | LLM error (fatal, retry, max_retries) |
| `voice_error` | TTS voice configuration or runtime error |
| `hold` | Call placed on hold or taken off hold |
| `filler` | Filler phrase spoken (thinking or function filler) |
| `consolidation` | Token consolidation triggered |
| `process_action` | Webhook action being processed |
| `gather_start` | Gather flow started |
| `gather_complete` | Gather flow completed |

**Additional events at level 2+:**

| Event label | Description |
|-------------|-------------|
| `llm_request` | LLM API request initiated (input tokens) |
| `llm_response` | LLM API response received (duration, output tokens) |
| `conversation_add` | Entry added to conversation history |

### Call Flow Verb Insertion

These methods allow you to customize the SWML call flow by inserting verbs at different stages of the call lifecycle.

##### `add_pre_answer_verb(verb_name: str, config: dict) -> AgentBase`
Add a verb to run before the call is answered (while still ringing).

**Safe pre-answer verbs:** `transfer`, `execute`, `return`, `label`, `goto`, `request`, `switch`, `cond`, `if`, `eval`, `set`, `unset`, `hangup`, `send_sms`, `sleep`, `stop_record_call`, `stop_denoise`, `stop_tap`

**Parameters:**
- `verb_name` (str): The SWML verb name
- `config` (dict): Verb configuration dictionary

**Usage:**
```ruby
# Send SMS before answering
agent.add_pre_answer_verb("send_sms", {
  "to" => "+15551234567",
  "from" => "+15559876543",
  "body" => "Incoming call from AI agent"
})

# Set variables before answer
agent.add_pre_answer_verb("set", { "call_start" => "${system.timestamp}" })
```

##### `add_answer_verb(config: dict = None) -> AgentBase`
Configure the answer verb that connects the call.

**Parameters:**
- `config` (dict, optional): Answer verb configuration (e.g., `{"max_duration": 3600}`)

**Usage:**
```ruby
# Set maximum call duration to 1 hour
agent.add_answer_verb({ "max_duration" => 3600 })
```

##### `add_post_answer_verb(verb_name: str, config: dict) -> AgentBase`
Add a verb to run after the call is answered but before the AI starts.

**Parameters:**
- `verb_name` (str): The SWML verb name (e.g., "play", "sleep")
- `config` (dict): Verb configuration dictionary

**Usage:**
```ruby
# Play welcome message before AI starts
agent.add_post_answer_verb("play", {
  "url" => "say:Welcome to our AI assistant. This call may be recorded."
})

# Add a brief pause
agent.add_post_answer_verb("sleep", { "duration" => 1 })
```

##### `add_post_ai_verb(verb_name: str, config: dict) -> AgentBase`
Add a verb to run after the AI conversation ends.

**Parameters:**
- `verb_name` (str): The SWML verb name (e.g., "hangup", "transfer", "request")
- `config` (dict): Verb configuration dictionary

**Usage:**
```ruby
# Clean hangup after AI ends
agent.add_post_ai_verb("hangup", {})

# Transfer to human after AI conversation
agent.add_post_ai_verb("transfer", { "to" => "+15551234567" })

# Log call completion
agent.add_post_ai_verb("request", {
  "url" => "https://myserver.com/call-complete",
  "method" => "POST"
})
```

##### `clear_pre_answer_verbs() -> AgentBase`
Remove all pre-answer verbs.

##### `clear_post_answer_verbs() -> AgentBase`
Remove all post-answer verbs.

##### `clear_post_ai_verbs() -> AgentBase`
Remove all post-AI verbs.

**Method Chaining Example:**
```ruby
agent.add_pre_answer_verb("set", { "source" => "ai_agent" })
     .add_answer_verb({ "max_duration" => 1800 })
     .add_post_answer_verb("play", { "url" => "say:Hello!" })
     .add_post_ai_verb("hangup", {})
```

### Dynamic Configuration

##### `set_dynamic_config_callback`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
# Pass a block (canonical) or a callable via the positional arg.
# The callback receives (query_params, body, headers, config).
def set_dynamic_config_callback(callable = nil, &block) # => AgentBase
```
Set callback for per-request dynamic configuration.

**Parameters:**
- `callback` (Callable): Function that receives (query_params, headers, body, config)

**Usage:**
```ruby
agent.set_dynamic_config_callback(nil) do |query_params, body, headers, config|
  # Configure based on request
  config.add_language("Spanish", "es-ES", "nova.luna") if query_params["language"] == "spanish"

  # Set customer-specific data
  customer_id = headers["X-Customer-ID"]
  config.set_global_data({ "customer_id" => customer_id }) if customer_id
end
```

### SIP Integration

##### `enable_sip_routing`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def enable_sip_routing(
  auto_map: true,             # Boolean
  path: "/sip"                # String
) # => AgentBase
```
Enable SIP-based routing for voice calls.

**Parameters:**
- `auto_map` (bool): Automatically map SIP usernames (default: True)
- `path` (str): SIP routing endpoint path (default: "/sip")

**Usage:**
```ruby
agent.enable_sip_routing
```

##### `register_sip_username(sip_username: str) -> AgentBase`
Register a specific SIP username for this agent.

**Parameters:**
- `sip_username` (str): SIP username to register

**Usage:**
```ruby
agent.register_sip_username("support")
agent.register_sip_username("sales")
```

##### `register_routing_callback`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
# `callback_fn` is a REQUIRED positional (reference parity): pass a callable, or
# pass `nil` and supply the block. The routing logic returns the agent route
# (or nil) for the request; `path` is the routing endpoint.
def register_routing_callback(callback_fn, path = '/sip', &block) # => nil
```
Register custom routing logic for SIP calls.

**Parameters:**
- `callback_fn` (Callable): Function that returns agent route based on request
- `path` (str): Routing endpoint path (default: "/sip")

**Usage:**
```ruby
agent.register_routing_callback(nil, "/sip") do |body, headers|
  case body["sip_username"]
  when "support" then "/support-agent"
  when "sales"   then "/sales-agent"
  end
end
```

### Utility Methods

##### `get_name() -> str`
Get the agent's name.

**Returns:**
- str: Agent name

##### `rack_app -> Rack application`
Return the agent as a Rack-compatible app (`call(env) → [status, headers, body]`)
so it can be mounted in any Rack or Sinatra application.

**Returns:**
- Rack application: The underlying Rack app (Sinatra-based).

**Usage:**
```ruby
# Embed agent in a larger Rack application:
require "rack"
require "rack/builder"

app = Rack::Builder.new do
  map "/agent" do
    run agent.rack_app
  end
end.to_app
```

### Event Handlers

##### `on_summary`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
# `summary` is a REQUIRED positional (reference parity). To REGISTER a handler,
# call `on_summary(nil) { |summary, raw_data| … }`; to DISPATCH one, pass the
# summary. You may also override this method in a subclass.
def on_summary(summary, raw_data = nil, &block) # => self / nil
```
Override to handle conversation summaries. This callback is triggered when the AI generates a summary based on your `post_prompt` configuration.

**Parameters:**
- `summary` (Optional[Dict[str, Any]]): Parsed summary data (from `post_prompt_data.parsed[0]`)
- `raw_data` (Optional[Dict[str, Any]]): Complete raw POST data including `post_prompt_data` with both `raw` and `parsed` fields

**Usage:**
```ruby
class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: "summary-agent", route: "/agent")

    # Configure post-prompt to request JSON summary
    self.post_prompt = <<~PROMPT
      Return a JSON summary of the conversation:
      {
          "topic": "MAIN_TOPIC",
          "satisfied": true/false,
          "follow_up_needed": true/false,
          "key_points": ["point1", "point2"]
      }
    PROMPT
  end

  # Handle conversation summaries after call ends
  def on_summary(summary = nil, raw_data = nil)
    if summary
      # Access parsed JSON fields directly
      topic = summary["topic"] || "Unknown"
      satisfied = summary["satisfied"] || false

      puts "Call about: #{topic}, Customer satisfied: #{satisfied}"

      # Save to database, send to CRM, trigger follow-up, etc.
      schedule_follow_up(summary) if summary["follow_up_needed"]
    end

    # Access raw summary text if needed
    if raw_data && raw_data.key?("post_prompt_data")
      raw_text = raw_data["post_prompt_data"]["raw"] || ""
      puts "Raw summary: #{raw_text}"
    end
  end
end
```

##### `on_debug_event`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
# `handler` is a REQUIRED positional (reference parity). Pass a callable, or
# pass `nil` and supply the block; the block receives |event_type, data|.
# Requires enable_debug_events first.
def on_debug_event(handler, &block) # => AgentBase
```
Register a handler for debug webhook events. Ruby has no decorator; pass the handler as a block (with `nil` in the required positional slot). Requires `enable_debug_events()` to be called first.

The handler receives:
- `event_type` (str): The event label (e.g. `"barge"`, `"llm_error"`, `"session_start"`)
- `data` (dict): The full event payload including `call_id`, `label`, and event-specific fields

The handler may be sync or async.

**Usage (block style):**
```ruby
agent = SignalWire::AgentBase.new(name: "my_agent")
agent.enable_debug_events

agent.on_debug_event(nil) do |event_type, data|
  call_id = data["call_id"]
  case event_type
  when "llm_error"
    puts "LLM error on call #{call_id}: #{data['event']}"
  when "barge"
    puts "Barge after #{data['barge_elapsed_ms']}ms"
  when "session_end"
    puts "Call ended: #{data['reason']}, duration: #{data['duration_ms']}ms"
  end
end
```

**Usage (subclass style):**
```ruby
class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: "debug-agent", route: "/agent")
    enable_debug_events(2)
    on_debug_event(nil) { |event_type, data| handle_debug(event_type, data) }
  end

  def handle_debug(event_type, data)
    alert_ops_team(data) if event_type == "llm_error"
  end
end
```

> **Note:** Even without registering a handler, all debug events are automatically logged via the agent's structured logger when `enable_debug_events()` is called.

##### `on_function_call`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def on_function_call(
  name,                       # String
  args,                       # Hash
  raw_data = nil              # Hash
) # => Object (typically FunctionResult)
```
Override to handle function calls with custom logic.

**Parameters:**
- `name` (str): Function name being called
- `args` (Dict[str, Any]): Function arguments
- `raw_data` (Optional[Dict[str, Any]]): Raw request data

**Returns:**
- Any: Function result (typically SwaigFunctionResult)

**Usage:**
```ruby
class MyAgent < SignalWire::AgentBase
  def on_function_call(name, args, raw_data = nil)
    if name == "get_weather"
      location = args["location"]
      # Custom weather logic
      return SignalWire::Swaig::FunctionResult.new("Weather in #{location}: Sunny")
    end
    super
  end
end
```

##### `on_request`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def on_request(
  request_data = nil,         # Hash (positional)
  callback_path = nil,        # String (positional)
  request: nil                # Rack request object
) # => Hash or nil
```
Override to handle general requests.

**Parameters:**
- `request_data` (Optional[dict]): Request data
- `callback_path` (Optional[str]): Callback path

**Returns:**
- Optional[dict]: Response modifications

##### `on_swml_request`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
def on_swml_request(
  request_data = nil,         # Hash (positional)
  callback_path = nil,        # String (positional)
  request: nil                # Rack request object
) # => Hash or nil
```
Override to handle SWML generation requests.

**Parameters:**
- `request_data` (Optional[dict]): Request data
- `callback_path` (Optional[str]): Callback path  
- `request` (Optional[Request]): FastAPI request object

**Returns:**
- Optional[dict]: SWML modifications

### Authentication

##### `validate_basic_auth(username: str, password: str) -> bool`
Override to implement custom basic authentication logic.

**Parameters:**
- `username` (str): Username from basic auth
- `password` (str): Password from basic auth

**Returns:**
- bool: True if credentials are valid

**Usage:**
```ruby
class MyAgent < SignalWire::AgentBase
  def validate_basic_auth(username, password)
    # Custom auth logic
    username == "admin" && password == "secret"
  end
end
```

##### `get_basic_auth_credentials`

<!-- snippet: no-compile ruby method-signature reference (def without body/end) -->
```ruby
# Returns [username, password], or [username, password, source]
# when include_source is true.
def get_basic_auth_credentials(include_source: false) # => Array<String>
```
Get basic auth credentials from environment or constructor.

**Parameters:**
- `include_source` (bool): Include source information (default: False)

**Returns:**
- Tuple: (username, password) or (username, password, source)

### Context System

##### `define_contexts() -> ContextBuilder`
Define structured workflow contexts for the agent.

**Returns:**
- ContextBuilder: Builder for creating contexts and steps

**Usage:**
```ruby
contexts = agent.define_contexts
contexts.add_context("greeting")
        .add_step("welcome")
        .set_text("Welcome! How can I help?")
        .set_valid_steps(["main_menu"])

contexts.add_context("main_menu")
        .add_step("menu")
        .set_text("Choose: 1) Support 2) Sales 3) Billing")
        .set_functions(["transfer_to_support", "transfer_to_sales"])
```

This concludes Part 1 of the API reference covering the AgentBase class. The document will continue with SwaigFunctionResult, DataMap, and other components in subsequent parts.

---

## SwaigFunctionResult Class

The `SwaigFunctionResult` class is used to create structured responses from SWAIG functions. It handles both natural language responses and structured actions that the agent should execute.

### Constructor

```ruby
SignalWire::Swaig::FunctionResult.new(response = nil, post_process: false)
```

**Parameters:**
- `response` (String, optional): Natural language response text for the AI to speak
- `post_process` (Boolean): Whether to let AI take another turn before executing actions (default: false)

**Post-processing Behavior:**
- `post_process: false` (default): Execute actions immediately after AI response
- `post_process: true`: Let AI respond to user one more time, then execute actions

**Usage:**
```ruby
# Simple response
result = SignalWire::Swaig::FunctionResult.new("The weather is sunny and 75°F")

# Response with post-processing enabled
result = SignalWire::Swaig::FunctionResult.new("I'll transfer you now", post_process: true)

# Empty response (actions only)
result = SignalWire::Swaig::FunctionResult.new
```

### Core Methods

#### Response Configuration

##### `response=` (assignment) / `set_response(response)` (chainable)
Set or update the natural language response text. The `response =` assignment is
the idiomatic Ruby form; the chainable `set_response` (returns `self`) remains for
fluent building.

**Parameters:**
- `response` (String): The text the AI should speak

**Usage:**
```ruby
result = SignalWire::Swaig::FunctionResult.new
result.response = "I found your order information"
```

##### `post_process=` (assignment) / `set_post_process(post_process)` (chainable)
Enable or disable post-processing for this result. The `post_process =` assignment
is the idiomatic Ruby form; the chainable `set_post_process` (returns `self`)
remains for fluent building.

**Parameters:**
- `post_process` (Boolean): `true` to let AI respond once more before executing actions

**Usage:**
```ruby
result = SignalWire::Swaig::FunctionResult.new("I'll help you with that")
result.post_process = true  # Let AI handle follow-up questions first
```

#### Action Management

##### `add_action(name, data) -> FunctionResult`
Add a structured action to execute.

**Parameters:**
- `name` (String): Action name/type (e.g., "play", "transfer", "set_global_data")
- `data` (Object): Action data - can be a string, boolean, hash, or array

**Usage:**
```ruby
# Simple action with boolean
result.add_action("hangup", true)

# Action with string data
result.add_action("play", "welcome.mp3")

# Action with object data
result.add_action("set_global_data", { "customer_id" => "12345", "status" => "verified" })

# Action with array data
result.add_action("send_sms", ["+15551234567", "Your order is ready!"])
```

##### `add_actions(actions) -> FunctionResult`
Add multiple actions at once.

**Parameters:**
- `actions` (Array<Hash>): List of action hashes

**Usage:**
```ruby
result.add_actions([
  { "play" => "hold_music.mp3" },
  { "set_global_data" => { "status" => "on_hold" } },
  { "wait" => 5000 }
])
```

### Call Control Actions

#### Call Transfer and Connection

##### `connect(destination, final: true, from_addr: nil) -> FunctionResult`
Transfer or connect the call to another destination.

**Parameters:**
- `destination` (String): Phone number, SIP address, or other destination
- `final` (Boolean): Permanent transfer (true) vs temporary transfer (false) (default: true)
- `from_addr` (String, optional): Override caller ID

**Transfer Types:**
- `final: true`: Permanent transfer - call exits agent completely
- `final: false`: Temporary transfer - call returns to agent if far end hangs up

**Usage:**
```ruby
# Permanent transfer to phone number
result.connect("+15551234567", final: true)

# Temporary transfer to SIP address with custom caller ID
result.connect("support@company.com", final: false, from_addr: "+15559876543")

# Transfer with response
result = SignalWire::Swaig::FunctionResult.new("Transferring you to our sales team")
result.connect("sales@company.com")
```

##### `swml_transfer(dest, ai_response, final: true) -> FunctionResult`
Create a SWML-based transfer with AI response setup.

**Parameters:**
- `dest` (String): Transfer destination
- `ai_response` (String): AI response when transfer completes

**Usage:**
```ruby
result.swml_transfer(
  "+15551234567",
  "You've been transferred back to me. How else can I help?"
)
```

##### `sip_refer(to_uri) -> FunctionResult`
Perform a SIP REFER transfer.

**Parameters:**
- `to_uri` (String): SIP URI to transfer to

**Usage:**
```ruby
result.sip_refer("sip:support@company.com")
```

#### Call Management

##### `hangup -> FunctionResult`
End the call immediately.

**Usage:**
```ruby
result = SignalWire::Swaig::FunctionResult.new("Thank you for calling. Goodbye!")
result.hangup
```

##### `hold(timeout = 300) -> FunctionResult`
Put the call on hold.

**Parameters:**
- `timeout` (Integer): Hold timeout in seconds (default: 300)

**Usage:**
```ruby
result = SignalWire::Swaig::FunctionResult.new("Please hold while I look that up")
result.hold(60)
```

##### `stop -> FunctionResult`
Stop current audio playback or recording.

**Usage:**
```ruby
result.stop
```

#### Audio Control

##### `say(text) -> FunctionResult`
Add text for the AI to speak.

**Parameters:**
- `text` (String): Text to speak

**Usage:**
```ruby
result.say("Please wait while I process your request")
```

##### `play_background_file(filename, wait: false) -> FunctionResult`
Play an audio file in the background.

**Parameters:**
- `filename` (String): Audio file path or URL
- `wait` (Boolean): Wait for file to finish before continuing (default: false)

**Usage:**
```ruby
# Play hold music in background
result.play_background_file("hold_music.mp3")

# Play announcement and wait for completion
result.play_background_file("important_announcement.wav", wait: true)
```

##### `stop_background_file -> FunctionResult`
Stop background audio playback.

**Usage:**
```ruby
result.stop_background_file
```

### Data Management Actions

##### `set_global_data(data) -> FunctionResult`
Set global data for the conversation.

**Parameters:**
- `data` (Hash): Global data to set

**Usage:**
```ruby
result.set_global_data({
  "customer_id" => "12345",
  "order_status" => "shipped",
  "tracking_number" => "1Z999AA1234567890"
})
```

##### `update_global_data(data) -> FunctionResult`
Update existing global data (merge with existing).

**Parameters:**
- `data` (Hash): Data to merge

**Usage:**
```ruby
result.update_global_data({
  "last_interaction" => "2024-01-15T10:30:00Z",
  "agent_notes" => "Customer satisfied with resolution"
})
```

##### `remove_global_data(keys) -> FunctionResult`
Remove specific keys from global data.

**Parameters:**
- `keys` (String or Array<String>): Key name or list of key names to remove

**Usage:**
```ruby
# Remove single key
result.remove_global_data("temporary_data")

# Remove multiple keys
result.remove_global_data(["temp1", "temp2", "cache_data"])
```

##### `metadata=` (assignment) / `set_metadata(data)` (chainable)
Set metadata for the conversation. The `metadata =` assignment is the idiomatic
Ruby form; the chainable `set_metadata` (returns `self`) remains for fluent
building (use it mid-chain, since `=` can't chain).

**Parameters:**
- `data` (Hash): Metadata to set

**Usage:**
```ruby
result.metadata = {
    "call_type" => "support",
    "priority" => "high",
    "department" => "technical"
}
```

##### `remove_metadata(keys) -> FunctionResult`
Remove specific metadata keys.

**Parameters:**
- `keys` (String or Array<String>): Key name or list of key names to remove

**Usage:**
```ruby
result.remove_metadata(["temporary_flag", "debug_info"])
```

### AI Behavior Control

##### `end_of_speech_timeout=` (assignment) / `set_end_of_speech_timeout(milliseconds)` (chainable)
Adjust how long to wait for speech to end. The `end_of_speech_timeout =`
assignment is the idiomatic Ruby form; the chainable `set_end_of_speech_timeout`
(returns `self`) remains for fluent building.

**Parameters:**
- `milliseconds` (Integer): Timeout in milliseconds

**Usage:**
```ruby
# Shorter timeout for quick responses
result.end_of_speech_timeout = 300

# Longer timeout for thoughtful responses
result.end_of_speech_timeout = 2000
```

##### `speech_event_timeout=` (assignment) / `set_speech_event_timeout(milliseconds)` (chainable)
Set timeout for speech events. The `speech_event_timeout =` assignment is the
idiomatic Ruby form; the chainable `set_speech_event_timeout` (returns `self`)
remains for fluent building.

**Parameters:**
- `milliseconds` (Integer): Timeout in milliseconds

**Usage:**
```ruby
result.speech_event_timeout = 5000
```

##### `wait_for_user(enabled: nil, timeout: nil, answer_first: false) -> FunctionResult`
Control whether to wait for user input.

**Parameters:**
- `enabled` (Boolean, optional): Enable/disable waiting for user
- `timeout` (Integer, optional): Timeout in milliseconds
- `answer_first` (Boolean): Answer call before waiting (default: false)

**Usage:**
```ruby
# Wait for user input with 10 second timeout
result.wait_for_user(enabled: true, timeout: 10000)

# Don't wait for user (immediate response)
result.wait_for_user(enabled: false)
```

##### `toggle_functions(function_toggles) -> FunctionResult`
Enable or disable specific functions.

**Parameters:**
- `function_toggles` (Array<Hash>): List of function toggle configurations

**Usage:**
```ruby
result.toggle_functions([
  { "name" => "transfer_to_sales", "enabled" => true },
  { "name" => "end_call", "enabled" => false },
  { "name" => "escalate", "enabled" => true, "timeout" => 30000 }
])
```

##### `enable_functions_on_timeout(enabled = true) -> FunctionResult`
Control whether functions are enabled when timeout occurs.

**Parameters:**
- `enabled` (Boolean): Enable functions on timeout (default: true)

**Usage:**
```ruby
result.enable_functions_on_timeout(false)  # Disable functions on timeout
```

##### `enable_extensive_data(enabled = true) -> FunctionResult`
Enable extensive data collection.

**Parameters:**
- `enabled` (Boolean): Enable extensive data (default: true)

**Usage:**
```ruby
result.enable_extensive_data(true)
```

##### `update_settings(settings) -> FunctionResult`
Update various AI settings.

**Parameters:**
- `settings` (Hash): Settings to update

**Usage:**
```ruby
result.update_settings({
  "temperature" => 0.8,
  "max_tokens" => 150,
  "end_of_speech_timeout" => 800
})
```

### Context and Conversation Control

##### `switch_context(system_prompt: nil, user_prompt: nil, consolidate: false, full_reset: false) -> FunctionResult`
Switch conversation context or reset the conversation.

**Parameters:**
- `system_prompt` (String, optional): New system prompt
- `user_prompt` (String, optional): New user prompt
- `consolidate` (Boolean): Consolidate conversation history (default: false)
- `full_reset` (Boolean): Completely reset conversation (default: false)

**Usage:**
```ruby
# Switch to technical support context
result.switch_context(
  system_prompt: "You are now a technical support specialist",
  user_prompt: "The customer needs technical help"
)

# Reset conversation completely
result.switch_context(full_reset: true)

# Consolidate conversation history
result.switch_context(consolidate: true)
```

##### `simulate_user_input(text) -> FunctionResult`
Simulate user input for testing or automation.

**Parameters:**
- `text` (String): Text to simulate as user input

**Usage:**
```ruby
result.simulate_user_input("I need help with my order")
```

### Communication Actions

##### `send_sms(to_number:, from_number:, body: nil, media: nil, tags: nil, region: nil) -> FunctionResult`
Send an SMS message.

**Parameters:**
- `to_number` (String): Recipient phone number
- `from_number` (String): Sender phone number
- `body` (String, optional): SMS message text
- `media` (Array<String>, optional): List of media URLs
- `tags` (Array<String>, optional): Message tags
- `region` (String, optional): SignalWire region

**Usage:**
```ruby
# Simple text message
result.send_sms(
  to_number: "+15551234567",
  from_number: "+15559876543",
  body: "Your order #12345 has shipped!"
)

# Message with media and tags
result.send_sms(
  to_number: "+15551234567",
  from_number: "+15559876543",
  body: "Here's your receipt",
  media: ["https://example.com/receipt.pdf"],
  tags: ["receipt", "order_12345"]
)
```

### Recording and Media

##### `record_call(control_id: nil, stereo: false, format: RecordFormat::WAV, direction: RecordDirection::BOTH, terminators: nil, beep: false, input_sensitivity: 44.0, initial_timeout: 0.0, end_silence_timeout: 0.0, max_length: nil, status_url: nil) -> FunctionResult`
Start call recording.

**Parameters:**
- `control_id` (String, optional): Unique identifier for this recording
- `stereo` (Boolean): Record in stereo (default: false)
- `format` (String): Recording format: "wav", "mp3", "mp4" (default: "wav")
- `direction` (String): Recording direction: "both", "inbound", "outbound" (default: "both")
- `terminators` (String, optional): DTMF keys to stop recording
- `beep` (Boolean): Play beep before recording (default: false)
- `input_sensitivity` (Float): Input sensitivity level (default: 44.0)
- `initial_timeout` (Float): Initial timeout in seconds (default: 0.0)
- `end_silence_timeout` (Float): End silence timeout in seconds (default: 0.0)
- `max_length` (Float, optional): Maximum recording length in seconds
- `status_url` (String, optional): Webhook URL for recording status

**Usage:**
```ruby
# Basic recording
result.record_call(format: "mp3", direction: "both")

# Recording with control ID and settings
result.record_call(
  control_id: "customer_call_001",
  stereo: true,
  format: "wav",
  beep: true,
  max_length: 300.0,
  terminators: "#*"
)
```

##### `stop_record_call(control_id: nil) -> FunctionResult`
Stop call recording.

**Parameters:**
- `control_id` (String, optional): Control ID of recording to stop

**Usage:**
```ruby
result.stop_record_call
result.stop_record_call(control_id: "customer_call_001")
```

### Conference and Room Management

##### `join_room(name) -> FunctionResult`
Join a SignalWire room.

**Parameters:**
- `name` (String): Room name to join

**Usage:**
```ruby
result.join_room("support_room_1")
```

##### `join_conference(name, muted: false, beep: "true", start_on_enter: true, end_on_exit: false, wait_url: nil, max_participants: 250, record: "do-not-record", region: nil, trim: "trim-silence", coach: nil, status_callback_event: nil, status_callback: nil, status_callback_method: "POST", recording_status_callback: nil, recording_status_callback_method: "POST", recording_status_callback_event: "completed", result: nil) -> FunctionResult`
Join a conference call.

**Parameters:**
- `name` (String): Conference name
- `muted` (Boolean): Join muted (default: false)
- `beep` (String): Beep setting: "true", "false", "onEnter", "onExit" (default: "true")
- `start_on_enter` (Boolean): Start conference when this participant enters (default: true)
- `end_on_exit` (Boolean): End conference when this participant exits (default: false)
- `wait_url` (String, optional): URL for hold music/content
- `max_participants` (Integer): Maximum participants (default: 250)
- `record` (String): Recording setting (default: "do-not-record")
- `region` (String, optional): SignalWire region
- `trim` (String): Trim setting for recordings (default: "trim-silence")
- `coach` (String, optional): Coach participant identifier
- `status_callback_event` (String, optional): Status callback events
- `status_callback` (String, optional): Status callback URL
- `status_callback_method` (String): Status callback HTTP method (default: "POST")
- `recording_status_callback` (String, optional): Recording status callback URL
- `recording_status_callback_method` (String): Recording status callback method (default: "POST")
- `recording_status_callback_event` (String): Recording status callback events (default: "completed")

**Usage:**
```ruby
# Basic conference join
result.join_conference("sales_meeting")

# Conference with recording and settings
result.join_conference(
  name: "support_conference",
  muted: false,
  beep: "onEnter",
  record: "record-from-start",
  max_participants: 10
)
```

### Payment Processing

##### `pay(payment_connector_url:, input_method: "dtmf", status_url: nil, payment_method: "credit-card", timeout: 5, max_attempts: 1, security_code: true, postal_code: true, min_postal_code_length: 0, token_type: "reusable", charge_amount: nil, currency: "usd", language: "en-US", voice: "woman", description: nil, valid_card_types: "visa mastercard amex", parameters: nil, prompts: nil) -> FunctionResult`
Process a payment through the call.

**Parameters:**
- `payment_connector_url` (String): Payment processor webhook URL
- `input_method` (String): Input method: "dtmf", "speech" (default: "dtmf")
- `status_url` (String, optional): Payment status webhook URL
- `payment_method` (String): Payment method: "credit-card" (default: "credit-card")
- `timeout` (Integer): Input timeout in seconds (default: 5)
- `max_attempts` (Integer): Maximum retry attempts (default: 1)
- `security_code` (Boolean): Require security code (default: true)
- `postal_code` (Boolean or String): Require postal code (default: true)
- `min_postal_code_length` (Integer): Minimum postal code length (default: 0)
- `token_type` (String): Token type: "reusable", "one-time" (default: "reusable")
- `charge_amount` (String, optional): Amount to charge
- `currency` (String): Currency code (default: "usd")
- `language` (String): Language for prompts (default: "en-US")
- `voice` (String): Voice for prompts (default: "woman")
- `description` (String, optional): Payment description
- `valid_card_types` (String): Accepted card types (default: "visa mastercard amex")
- `parameters` (Array<Hash>, optional): Additional parameters
- `prompts` (Array<Hash>, optional): Custom prompts

**Usage:**
```ruby
# Basic payment processing
result.pay(
  payment_connector_url: "https://payment-processor.com/webhook",
  charge_amount: "29.99",
  description: "Monthly subscription"
)

# Payment with custom settings
result.pay(
  payment_connector_url: "https://payment-processor.com/webhook",
  input_method: "speech",
  timeout: 10,
  max_attempts: 3,
  security_code: true,
  postal_code: true,
  charge_amount: "149.99",
  currency: "usd",
  description: "Premium service upgrade"
)
```

### Call Monitoring

##### `tap(uri, control_id: nil, direction: TapDirection::BOTH, codec: Codec::PCMU, rtp_ptime: 20, status_url: nil) -> FunctionResult`
Start call tapping/monitoring.

**Parameters:**
- `uri` (String): URI to send tapped audio to
- `control_id` (String, optional): Unique identifier for this tap
- `direction` (String): Tap direction: "both", "inbound", "outbound" (default: "both")
- `codec` (String): Audio codec: "PCMU", "PCMA", "G722" (default: "PCMU")
- `rtp_ptime` (Integer): RTP packet time in milliseconds (default: 20)
- `status_url` (String, optional): Status webhook URL

**Usage:**
```ruby
# Basic call tapping
result.tap("sip:monitor@company.com")

# Tap with specific settings
result.tap(
  "sip:quality@company.com",
  control_id: "quality_monitor_001",
  direction: "both",
  codec: "G722"
)
```

##### `stop_tap(control_id: nil) -> FunctionResult`
Stop call tapping.

**Parameters:**
- `control_id` (String, optional): Control ID of tap to stop

**Usage:**
```ruby
result.stop_tap
result.stop_tap(control_id: "quality_monitor_001")
```

### Advanced SWML Execution

##### `execute_swml(swml_content, transfer: false) -> FunctionResult`
Execute custom SWML content.

**Parameters:**
- `swml_content`: SWML document or content to execute
- `transfer` (Boolean): Whether this is a transfer operation (default: false)

**Usage:**
```ruby
# Execute custom SWML
custom_swml = {
  "version" => "1.0.0",
  "sections" => {
    "main" => [
      { "play" => { "url" => "https://example.com/custom.mp3" } },
      { "say" => { "text" => "Custom SWML execution" } }
    ]
  }
}
result.execute_swml(custom_swml)
```

### Utility Methods

##### `to_h -> Hash`
Convert the result to a Hash for serialization.

**Returns:**
- Hash: Hash representation of the result

**Usage:**
```ruby
result = SignalWire::Swaig::FunctionResult.new("Hello world")
result.add_action("play", "music.mp3")
result_hash = result.to_h
puts result_hash
# Output: {"response" => "Hello world", "action" => [{"play" => "music.mp3"}]}
```

### Static Helper Methods

##### `FunctionResult.create_payment_prompt(for_situation, actions, card_type: nil, error_type: nil) -> Hash`
Create a payment prompt configuration.

**Parameters:**
- `for_situation` (String): Situation identifier
- `actions` (Array<Hash>): List of action configurations
- `card_type` (String, optional): Card type for prompts
- `error_type` (String, optional): Error type for error prompts

**Usage:**
```ruby
prompt = SignalWire::Swaig::FunctionResult.create_payment_prompt(
  "card_number",
  [
    SignalWire::Swaig::FunctionResult.create_payment_action("say", "Please enter your card number")
  ]
)
```

##### `FunctionResult.create_payment_action(action_type, phrase) -> Hash`
Create a payment action configuration.

**Parameters:**
- `action_type` (String): Action type
- `phrase` (String): Action phrase

**Usage:**
```ruby
action = SignalWire::Swaig::FunctionResult.create_payment_action("say", "Enter your card number")
```

##### `FunctionResult.create_payment_parameter(name, value) -> Hash`
Create a payment parameter configuration.

**Parameters:**
- `name` (String): Parameter name
- `value` (String): Parameter value

**Usage:**
```ruby
param = SignalWire::Swaig::FunctionResult.create_payment_parameter("merchant_id", "12345")
```

### Method Chaining

All methods return `self`, enabling fluent method chaining:

```ruby
result = SignalWire::Swaig::FunctionResult.new("I'll help you with that")
  .set_post_process(true)
  .update_global_data({ "status" => "helping" })
  .set_end_of_speech_timeout(800)
  .add_action("play", "thinking.mp3")

# Complex workflow
result = SignalWire::Swaig::FunctionResult.new("Processing your payment")
  .set_post_process(true)
  .update_global_data({ "payment_status" => "processing" })
  .pay(
    payment_connector_url: "https://payments.com/webhook",
    charge_amount: "99.99",
    description: "Service payment"
  )
  .send_sms(
    to_number: "+15551234567",
    from_number: "+15559876543",
    body: "Payment confirmation will be sent shortly"
  )
```

This concludes Part 2 of the API reference covering the SwaigFunctionResult class. The document will continue with DataMap and other components in subsequent parts.

---

## DataMap Class

The `DataMap` class provides a declarative approach to creating SWAIG tools that integrate with REST APIs without requiring webhook infrastructure. DataMap tools execute on SignalWire's server infrastructure, eliminating the need to expose webhook endpoints.

### Constructor

<!-- snippet: no-run constructor/config signature illustration referencing assumed placeholder locals (name/function_name/contexts/MyAgent) -->
```ruby
SignalWire::DataMap.new(function_name)
```

**Parameters:**
- `function_name` (String): Name of the SWAIG function this DataMap will create

**Usage:**
```ruby
# Create a new DataMap tool
weather_map = SignalWire::DataMap.new('get_weather')
search_map = SignalWire::DataMap.new('search_docs')
```

### Core Configuration Methods

#### Function Metadata

##### `purpose(description) -> DataMap`
Set the function description/purpose.

**Parameters:**
- `description` (String): Human-readable description of what this function does

**Usage:**
```ruby
data_map = SignalWire::DataMap.new('get_weather').purpose('Get current weather information for any city')
```

##### `description(description) -> DataMap`
Alias for `purpose()` - set the function description.

**Parameters:**
- `description` (String): Function description

**Usage:**
```ruby
data_map = SignalWire::DataMap.new('search_api').description('Search our knowledge base for information')
```

#### Parameter Definition

##### `parameter(name, param_type, description, required: false, enum: nil) -> DataMap`
Add a function parameter with JSON schema validation.

**Parameters:**
- `name` (String): Parameter name
- `param_type` (String): JSON schema type: "string", "number", "boolean", "array", "object"
- `description` (String): Parameter description for the AI
- `required` (Boolean): Whether parameter is required (default: false)
- `enum` (Array<String>, optional): List of allowed values for validation

**Usage:**
```ruby
# Required string parameter
data_map.parameter('location', 'string', 'City name or ZIP code', required: true)

# Optional number parameter
data_map.parameter('days', 'number', 'Number of forecast days', required: false)

# Enum parameter with allowed values
data_map.parameter('units', 'string', 'Temperature units',
                   enum: ['celsius', 'fahrenheit'], required: false)

# Boolean parameter
data_map.parameter('include_alerts', 'boolean', 'Include weather alerts', required: false)

# Array parameter
data_map.parameter('categories', 'array', 'Search categories to include')
```

### API Integration Methods

#### HTTP Webhook Configuration

##### `webhook(method, url, headers: nil, form_param: nil, input_args_as_params: false, require_args: nil) -> DataMap`
Configure an HTTP API call.

**Parameters:**
- `method` (String): HTTP method: "GET", "POST", "PUT", "DELETE", "PATCH"
- `url` (String): API endpoint URL (supports `${variable}` substitution)
- `headers` (Hash, optional): HTTP headers to send
- `form_param` (String, optional): Send JSON body as single form parameter with this name
- `input_args_as_params` (Boolean): Merge function arguments into URL parameters (default: false)
- `require_args` (Array<String>, optional): Only execute if these arguments are present

**Variable Substitution in URLs:**
- `${args.parameter_name}`: Function argument values
- `${global_data.key}`: Call-wide data store (user info, call state - NOT credentials)
- `${meta_data.call_id}`: Call and function metadata

**Usage:**
```ruby
# Simple GET request with parameter substitution
data_map.webhook('GET', 'https://api.weather.com/v1/current?key=API_KEY&q=${args.location}')

# POST request with authentication headers
data_map.webhook(
  'POST',
  'https://api.company.com/search',
  headers: {
    'Authorization' => 'Bearer YOUR_TOKEN',
    'Content-Type' => 'application/json'
  }
)

# Webhook that requires specific arguments
data_map.webhook(
  'GET',
  'https://api.service.com/data?id=${args.customer_id}',
  require_args: ['customer_id']
)

# Use global data for call-related info (NOT credentials)
data_map.webhook(
  'GET',
  'https://api.service.com/customer/${global_data.customer_id}/orders',
  headers: { 'Authorization' => 'Bearer YOUR_API_TOKEN' }  # Use static credentials
)
```

##### `body(data) -> DataMap`
Set the JSON body for POST/PUT requests.

**Parameters:**
- `data` (Hash): JSON body data (supports `${variable}` substitution)

**Usage:**
```ruby
# Static body with parameter substitution
data_map.body({
  'query' => '${args.search_term}',
  'limit' => 5,
  'filters' => {
    'category' => '${args.category}',
    'active' => true
  }
})

# Body with call-related data (NOT sensitive info)
data_map.body({
  'customer_id' => '${global_data.customer_id}',
  'request_id' => '${meta_data.call_id}',
  'search' => '${args.query}'
})
```

##### `params(data) -> DataMap`
Set URL query parameters.

**Parameters:**
- `data` (Hash): Query parameters (supports `${variable}` substitution)

**Usage:**
```ruby
# URL parameters with substitution
data_map.params({
  'api_key' => 'YOUR_API_KEY',
  'q' => '${args.location}',
  'units' => '${args.units}',
  'lang' => 'en'
})
```

#### Multiple Webhooks and Fallbacks

DataMap supports multiple webhook configurations for fallback scenarios:

```ruby
# Primary API with fallback
data_map = SignalWire::DataMap.new('search_with_fallback')
  .purpose('Search with multiple API fallbacks')
  .parameter('query', 'string', 'Search query', required: true)
  # Primary API
  .webhook('GET', 'https://api.primary.com/search?q=${args.query}')
  .output(SignalWire::Swaig::FunctionResult.new('Primary result: ${response.title}'))
  # Fallback API
  .webhook('GET', 'https://api.fallback.com/search?q=${args.query}')
  .output(SignalWire::Swaig::FunctionResult.new('Fallback result: ${response.title}'))
  # Final fallback if all APIs fail
  .fallback_output(SignalWire::Swaig::FunctionResult.new('Sorry, all search services are currently unavailable'))
```

### Response Processing

#### Basic Output

##### `output(result) -> DataMap`
Set the response template for successful API calls.

**Parameters:**
- `result` (FunctionResult): Response template with variable substitution

**Variable Substitution in Outputs:**
- `${response.field}`: API response fields
- `${response.nested.field}`: Nested response fields
- `${response.array[0].field}`: Array element fields
- `${args.parameter}`: Original function arguments
- `${global_data.key}`: Call-wide data store (user info, call state)

**Usage:**
```ruby
# Simple response template
data_map.output(SignalWire::Swaig::FunctionResult.new('Weather in ${args.location}: ${response.current.condition.text}, ${response.current.temp_f}°F'))

# Response with actions
data_map.output(
  SignalWire::Swaig::FunctionResult.new('Found ${response.total_results} results')
    .update_global_data({ 'last_search' => '${args.query}' })
    .add_action('play', 'search_complete.mp3')
)

# Complex response with nested data
data_map.output(
  SignalWire::Swaig::FunctionResult.new('Order ${response.order.id} status: ${response.order.status}. Estimated delivery: ${response.order.delivery.estimated_date}')
)
```

##### `fallback_output(result) -> DataMap`
Set the response when all webhooks fail.

**Parameters:**
- `result` (FunctionResult): Fallback response

**Usage:**
```ruby
data_map.fallback_output(
  SignalWire::Swaig::FunctionResult.new('Sorry, the service is temporarily unavailable. Please try again later.')
    .add_action('play', 'service_unavailable.mp3')
)
```

#### Array Processing

##### `foreach(foreach_config) -> DataMap`
Process array responses by iterating over elements.

**Parameters:**
- `foreach_config` (String or Hash): Array path or configuration object

**Simple Array Processing:**
```ruby
# Process array of search results
data_map = SignalWire::DataMap.new('search_docs')
  .webhook('GET', 'https://api.docs.com/search?q=${args.query}')
  .foreach(
    'input_key'  => 'results',            # array key in the webhook response
    'output_key' => 'formatted_results',  # variable holding the built string
    'append'     => 'Found: ${this.title} - ${this.summary}\n'
  )
  .output(SignalWire::Swaig::FunctionResult.new('${formatted_results}'))
```

**Advanced Array Processing:**
```ruby
# Complex foreach configuration
data_map.foreach({
  'input_key'  => 'items',                    # array key in the webhook response
  'output_key' => 'formatted_items',          # variable holding the built string
  'max'        => 3,                          # process only the first 3 items
  'append'     => 'Item: ${this.name} (${this.status})\n'
})
```

**Foreach Variable Access:**
- `${foreach.field}`: Current array element field
- `${foreach.nested.field}`: Nested fields in current element
- `${foreach_index}`: Current iteration index (0-based)
- `${foreach_count}`: Total number of items being processed

### Pattern-Based Processing

#### Expression Matching

##### `expression(test_value, pattern, output, nomatch_output: nil) -> DataMap`
Add pattern-based responses without API calls.

**Parameters:**
- `test_value` (String): Template string to test against pattern
- `pattern` (String or Regexp): Regex pattern or compiled Regexp object
- `output` (FunctionResult): Response when pattern matches
- `nomatch_output` (FunctionResult, optional): Response when pattern doesn't match

**Usage:**
```ruby
# Command-based responses
control_map = SignalWire::DataMap.new('file_control')
  .purpose('Control file playback')
  .parameter('command', 'string', 'Playback command', required: true)
  .parameter('filename', 'string', 'File to control')
  # Start commands
  .expression(
    '${args.command}',
    /start|play|begin/,
    SignalWire::Swaig::FunctionResult.new('Starting playback')
      .add_action('start_playback', { 'file' => '${args.filename}' })
  )
  # Stop commands
  .expression(
    '${args.command}',
    /stop|pause|halt/,
    SignalWire::Swaig::FunctionResult.new('Stopping playback')
      .add_action('stop_playback', true)
  )
  # Volume commands
  .expression(
    '${args.command}',
    /volume (\d+)/,
    SignalWire::Swaig::FunctionResult.new('Setting volume to ${match.1}')
      .add_action('set_volume', '${match.1}')
  )
```

**Pattern Matching Variables:**
- `${match.0}`: Full match
- `${match.1}`, `${match.2}`, etc.: Capture groups
- `${match.group_name}`: Named capture groups

### Error Handling

##### `error_keys(keys) -> DataMap`
Specify response fields that indicate errors.

**Parameters:**
- `keys` (Array<String>): List of field names that indicate API errors

**Usage:**
```ruby
# Treat these response fields as errors
data_map.error_keys(['error', 'error_message', 'status_code'])

# If API returns {"error" => "Not found"}, DataMap will treat this as an error
```

##### `global_error_keys(keys) -> DataMap`
Set global error keys for all webhooks in this DataMap.

**Parameters:**
- `keys` (Array<String>): Global error field names

**Usage:**
```ruby
data_map.global_error_keys(['error', 'message', 'code'])
```

### Advanced Configuration

##### `webhook_expressions(expressions) -> DataMap`
Add expression-based webhook selection.

**Parameters:**
- `expressions` (Array<Hash>): List of expression configurations

**Usage:**
```ruby
# Different APIs based on input
data_map.webhook_expressions([
  {
    'test' => '${args.type}',
    'pattern' => 'weather',
    'webhook' => {
      'method' => 'GET',
      'url' => 'https://weather-api.com/current?q=${args.location}'
    }
  },
  {
    'test' => '${args.type}',
    'pattern' => 'news',
    'webhook' => {
      'method' => 'GET',
      'url' => 'https://news-api.com/search?q=${args.query}'
    }
  }
])
```

### Complete DataMap Examples

#### Simple Weather API

```ruby
weather_tool = SignalWire::DataMap.new('get_weather')
  .purpose('Get current weather information')
  .parameter('location', 'string', 'City name or ZIP code', required: true)
  .parameter('units', 'string', 'Temperature units', enum: ['celsius', 'fahrenheit'])
  .webhook('GET', 'https://api.weather.com/v1/current?key=API_KEY&q=${args.location}&units=${args.units}')
  .output(SignalWire::Swaig::FunctionResult.new('Weather in ${args.location}: ${response.current.condition.text}, ${response.current.temp_f}°F'))
  .error_keys(['error'])

# Register with agent
agent.register_swaig_function(weather_tool.to_swaig_function)
```

#### Search with Array Processing

```ruby
search_tool = SignalWire::DataMap.new('search_knowledge')
  .purpose('Search company knowledge base')
  .parameter('query', 'string', 'Search query', required: true)
  .parameter('category', 'string', 'Search category', enum: ['docs', 'faq', 'policies'])
  .webhook(
    'POST',
    'https://api.company.com/search',
    headers: { 'Authorization' => 'Bearer TOKEN' }
  )
  .params({
    'query' => '${args.query}',
    'category' => '${args.category}',
    'limit' => 5
  })
  .foreach(
    'input_key'  => 'results',
    'output_key' => 'formatted_results',
    'append'     => 'Found: ${this.title} - ${this.summary}\n'
  )
  .output(SignalWire::Swaig::FunctionResult.new('${formatted_results}'))
  .fallback_output(SignalWire::Swaig::FunctionResult.new('Search service is temporarily unavailable'))
```

#### Command Processing (No API)

```ruby
control_tool = SignalWire::DataMap.new('system_control')
  .purpose('Control system functions')
  .parameter('action', 'string', 'Action to perform', required: true)
  .parameter('target', 'string', 'Target for the action')
  # Restart commands
  .expression(
    '${args.action}',
    /restart|reboot/,
    SignalWire::Swaig::FunctionResult.new('Restarting ${args.target}')
      .add_action('restart_service', { 'service' => '${args.target}' })
  )
  # Status commands
  .expression(
    '${args.action}',
    /status|check/,
    SignalWire::Swaig::FunctionResult.new('Checking status of ${args.target}')
      .add_action('check_status', { 'service' => '${args.target}' })
  )
  # Default for unrecognized commands
  .expression(
    '${args.action}',
    /.*/,
    SignalWire::Swaig::FunctionResult.new('Unknown command: ${args.action}'),
    nomatch_output: SignalWire::Swaig::FunctionResult.new('Please specify a valid action')
  )
```

### Conversion and Registration

##### `to_swaig_function -> Hash`
Convert the DataMap to a SWAIG function hash for registration.

**Returns:**
- Hash: Complete SWAIG function definition

**Usage:**
```ruby
# Build DataMap
weather_map = SignalWire::DataMap.new('get_weather').purpose('Get weather').parameter('location', 'string', 'City', required: true)

# Convert to SWAIG function and register
swaig_function = weather_map.to_swaig_function
agent.register_swaig_function(swaig_function)
```

### Convenience Functions

The SDK provides helper class methods for common DataMap patterns:

##### `DataMap.create_simple_api_tool(name:, url:, response_template:, parameters: nil, method: "GET", headers: nil, error_keys: nil) -> DataMap`

Create a simple API integration tool.

**Parameters:**
- `name` (String): Function name
- `url` (String): API endpoint URL
- `response_template` (String): Response template string
- `parameters` (Hash, optional): Parameter definitions
- `method` (String): HTTP method (default: "GET")
- `headers` (Hash, optional): HTTP headers
- `error_keys` (Array<String>, optional): Error field names

**Usage:**
```ruby
weather = SignalWire::DataMap.create_simple_api_tool(
  name: 'get_weather',
  url: 'https://api.weather.com/v1/current?key=API_KEY&q=${location}',
  response_template: 'Weather in ${location}: ${response.current.condition.text}',
  parameters: {
    'location' => {
      'type' => 'string',
      'description' => 'City name',
      'required' => true
    }
  }
)

agent.register_swaig_function(weather.to_swaig_function)
```

##### `DataMap.create_expression_tool(name:, patterns:, parameters: nil) -> DataMap`

Create a pattern-based tool without API calls.

**Parameters:**
- `name` (String): Function name
- `patterns` (Hash): Pattern mappings
- `parameters` (Hash, optional): Parameter definitions

**Usage:**
```ruby
file_control = SignalWire::DataMap.create_expression_tool(
  name: 'file_control',
  patterns: {
    /start.*/ => ['${args.command}', SignalWire::Swaig::FunctionResult.new.add_action('start_playback', true)],
    /stop.*/  => ['${args.command}', SignalWire::Swaig::FunctionResult.new.add_action('stop_playback', true)]
  },
  parameters: {
    'command' => {
      'type' => 'string',
      'description' => 'Playback command',
      'required' => true
    }
  }
)

agent.register_swaig_function(file_control.to_swaig_function)
```

### Method Chaining

All DataMap methods return `self`, enabling fluent method chaining:

```ruby
complete_tool = SignalWire::DataMap.new('comprehensive_search')
  .purpose('Comprehensive search with fallbacks')
  .parameter('query', 'string', 'Search query', required: true)
  .parameter('category', 'string', 'Search category', enum: ['all', 'docs', 'faq'])
  .webhook('GET', 'https://primary-api.com/search?q=${args.query}&cat=${args.category}')
  .output(SignalWire::Swaig::FunctionResult.new('Primary: ${response.title}'))
  .webhook('GET', 'https://backup-api.com/search?q=${args.query}')
  .output(SignalWire::Swaig::FunctionResult.new('Backup: ${response.title}'))
  .fallback_output(SignalWire::Swaig::FunctionResult.new('All search services unavailable'))
  .error_keys(['error', 'message'])
```

This concludes Part 3 of the API reference covering the DataMap class. The document will continue with Context System and other components in subsequent parts. 

---

## Context System

The Context System enhances traditional prompt-based agents by adding structured workflows with sequential steps on top of a base prompt. Each step contains its own guidance, completion criteria, and function restrictions while building upon the agent's foundational prompt.

### ContextBuilder Class

The `ContextBuilder` is accessed via `agent.define_contexts` and provides the main interface for creating structured workflows.

#### Getting Started

```ruby
# Access the context builder
contexts = agent.define_contexts

# Create contexts and steps
contexts.add_context("greeting")
        .add_step("welcome")
        .set_text("Welcome! How can I help you today?")
        .set_step_criteria("User has stated their need")
        .set_valid_steps(["next"])
```

##### `add_context(name) -> Context`
Create a new context in the workflow.

**Parameters:**
- `name` (String): Unique context name

**Returns:**
- Context: Context object for method chaining

**Usage:**
<!-- snippet: no-run constructor/config signature illustration referencing assumed placeholder locals (name/function_name/contexts/MyAgent) -->
```ruby
# Create multiple contexts
greeting_context = contexts.add_context("greeting")
main_menu_context = contexts.add_context("main_menu")
support_context = contexts.add_context("support")
```

### Context Class

The Context class represents a conversation context containing multiple steps with enhanced features.

Each single-value `set_*` writer below also has an idiomatic `X =` assignment
alias — `context.system_prompt = "..."`, `context.prompt = "..."`,
`context.post_prompt = "..."`, `context.user_prompt = "..."`,
`context.consolidate = true`, `context.full_reset = true`,
`context.valid_contexts = [...]`, `context.valid_steps = [...]`,
`context.initial_step = "..."`, `context.isolated = true`,
`context.enter_fillers = [...]`, `context.exit_fillers = [...]`. Use the `X =`
form for standalone config; the chainable `set_*` form (returns `self`) is what
the fluent builder examples chain with. (`add_step` / `add_section` /
`add_bullets` are builders, not single-value setters, so they keep their names.)

```ruby
class Context
  # Create a new step in this context
  def add_step(name); end

  # Set which contexts can be accessed from this context
  def set_valid_contexts(contexts); end

  # Context entry parameters (for context switching behavior)

  # Override agent's post prompt when this context is active
  def set_post_prompt(post_prompt); end

  # Trigger context switch with new system instructions (makes this a Context Switch Context)
  def set_system_prompt(system_prompt); end

  # Whether to consolidate conversation history when entering this context
  def set_consolidate(consolidate); end

  # Whether to do complete system prompt replacement vs injection
  def set_full_reset(full_reset); end

  # User message to inject when entering this context for AI context
  def set_user_prompt(user_prompt); end

  # Context prompts (guidance for all steps in context)

  # Set simple string prompt that applies to all steps in this context
  def set_prompt(prompt); end

  # Add POM-style section to context prompt
  def add_section(title, body); end

  # Add POM-style bullet section to context prompt
  def add_bullets(title, bullets); end
end
```

**Context Types:**

1. **Workflow Container Context** (no `system_prompt`): Organizes steps without conversation state changes
2. **Context Switch Context** (has `system_prompt`): Triggers conversation state changes when entered, processing entry parameters like a `context_switch` SWAIG action

**Prompt Hierarchy:** Base Agent Prompt → Context Prompt → Step Prompt

#### Usage Examples

<!-- snippet: no-run constructor/config signature illustration referencing assumed placeholder locals (name/function_name/contexts/MyAgent) -->
```ruby
# Workflow container context (just organizes steps)
main_context = contexts.add_context("main")
main_context.set_prompt("Follow standard customer service protocols")

# Context switch context (changes AI behavior)
billing_context = contexts.add_context("billing")
billing_context.set_system_prompt("You are now a billing specialist")
               .set_consolidate(true)
               .set_user_prompt("Customer needs billing assistance")
               .add_section("Department", "Billing Department")
               .add_bullets("Services", ["Account inquiries", "Payments", "Refunds"])

# Full reset context (complete conversation reset)
manager_context = contexts.add_context("manager")
manager_context.set_system_prompt("You are a senior manager")
               .set_full_reset(true)
               .set_consolidate(true)
```

---

## Skills System

The Skills System provides modular, reusable capabilities that can be easily added to any agent.

### Available Built-in Skills

#### `datetime` Skill
Provides current date and time information.

**Parameters:**
- `timezone` (String, optional): Timezone for date/time (default: system timezone)
- `format` (String, optional): Custom date/time format string

**Usage:**
```ruby
# Basic datetime skill
agent.add_skill("datetime")

# With timezone
agent.add_skill("datetime", { "timezone" => "America/New_York" })

# With custom format
agent.add_skill("datetime", {
  "timezone" => "UTC",
  "format" => "%Y-%m-%d %H:%M:%S %Z"
})
```

#### `math` Skill
Safe mathematical expression evaluation.

**Parameters:**
- `precision` (Integer, optional): Decimal precision for results (default: 2)
- `max_expression_length` (Integer, optional): Maximum expression length (default: 100)

**Usage:**
```ruby
# Basic math skill
agent.add_skill("math")

# With custom precision
agent.add_skill("math", { "precision" => 4 })
```

#### `web_search` Skill
Google Custom Search API integration with web scraping.

**Parameters:**
- `api_key` (String): Google Custom Search API key (required)
- `search_engine_id` (String): Google Custom Search Engine ID (required)
- `num_results` (Integer, optional): Number of results to return (default: 3)
- `tool_name` (String, optional): Custom tool name for multiple instances
- `delay` (Float, optional): Delay between requests in seconds
- `no_results_message` (String, optional): Custom message when no results found

**Usage:**
```ruby
# Basic web search
agent.add_skill("web_search", {
  "api_key" => "your-google-api-key",
  "search_engine_id" => "your-search-engine-id"
})

# Multiple search instances
agent.add_skill("web_search", {
  "api_key" => "your-api-key",
  "search_engine_id" => "general-engine-id",
  "tool_name" => "search_general",
  "num_results" => 5
})

agent.add_skill("web_search", {
  "api_key" => "your-api-key",
  "search_engine_id" => "news-engine-id",
  "tool_name" => "search_news",
  "num_results" => 3,
  "delay" => 0.5
})
```

#### `datasphere` Skill
SignalWire DataSphere knowledge search integration.

**Parameters:**
- `space_name` (String): DataSphere space name (required)
- `project_id` (String): DataSphere project ID (required)
- `token` (String): DataSphere access token (required)
- `document_id` (String, optional): Specific document to search
- `tool_name` (String, optional): Custom tool name for multiple instances
- `count` (Integer, optional): Number of results to return (default: 3)
- `tags` (Array<String>, optional): Filter by document tags

**Usage:**
```ruby
# Basic DataSphere search
agent.add_skill("datasphere", {
  "space_name" => "my-space",
  "project_id" => "my-project",
  "token" => "my-token"
})

# Multiple DataSphere instances
agent.add_skill("datasphere", {
  "space_name" => "my-space",
  "project_id" => "my-project",
  "token" => "my-token",
  "document_id" => "drinks-menu",
  "tool_name" => "search_drinks",
  "count" => 5
})

agent.add_skill("datasphere", {
  "space_name" => "my-space",
  "project_id" => "my-project",
  "token" => "my-token",
  "tool_name" => "search_policies",
  "tags" => ["HR", "Policies"]
})
```

#### `native_vector_search` Skill
Document search against a remote search server using vector similarity and keyword
search. The Ruby port supports **remote (network) mode only** -- it POSTs queries to
the server at `remote_url`. Local `.swsearch` index files are not supported.

**Parameters:**
- `remote_url` (String): URL of the remote search server (required)
- `index_name` (String, optional): Index name on the remote server
- `tool_name` (String, optional): Custom tool name (default: "search_knowledge")
- `description` (String, optional): Tool description
- `count` (Integer, optional): Number of results to return (default: 3)
- `similarity_threshold` (Float, optional): Minimum similarity score (default: 0.5)
- `hints` (Array, optional): Extra speech hints to merge into the agent's hint list

**Usage:**
```ruby
# Connect to a remote search server
agent.add_skill('native_vector_search', {
  'remote_url' => 'http://localhost:8001'
})

# With custom settings
agent.add_skill('native_vector_search', {
  'remote_url'           => 'http://localhost:8001',
  'index_name'          => 'docs',
  'tool_name'           => 'search_docs',
  'count'               => 10,
  'similarity_threshold' => 0.25
})
```

### Creating Custom Skills

#### Skill Structure

Create a new skill by extending `SkillBase`:

```ruby
require 'signalwire'

class CustomSkill < SignalWire::Skills::SkillBase
  def name = "custom_skill"
  def description = "Description of what this skill does"
  def version = "1.0.0"
  def required_env_vars = ["API_KEY"]  # Environment variables needed

  # Validate and store configuration. Return true if the skill is ready.
  def setup
    unless @params["api_key"]
      @logger.error("api_key parameter is required")
      return false
    end

    @api_key = @params["api_key"]
    true
  end

  # Register skill functions
  def register_tools
    # DataMap-based tool
    tool = SignalWire::DataMap.new("custom_function")
      .description("Custom API integration")
      .parameter("query", "string", "Search query", required: true)
      .webhook("GET", "https://api.example.com/search?key=#{@api_key}&q=${args.query}")
      .output(SignalWire::Swaig::FunctionResult.new("Found: ${response.title}"))

    @agent.register_swaig_function(tool.to_swaig_function)
  end

  # Speech recognition hints
  def get_hints = ["custom search", "find information"]

  # Global data for DataMap
  def get_global_data = { "skill_version" => version }

  # Prompt sections to add
  def get_prompt_sections
    [{
      "title" => "Custom Search Capability",
      "body" => "You can search our custom database for information.",
      "bullets" => ["Use the custom_function to search", "Results are real-time"]
    }]
  end
end
```

#### Skill Registration

Built-in skills are automatically discovered from the `lib/signalwire/skills/builtin/` directory. To register a custom skill, subclass `SignalWire::Skills::SkillBase` and register it with the skill registry, then load it on the agent via `add_skill`.

---

## Utility Classes

### SWAIG Functions

The Ruby port does not ship a dedicated `SWAIGFunction` wrapper class (see
[PORT_OMISSIONS.md](../PORT_OMISSIONS.md)); SWAIG functions are registered as
plain Hashes directly with the agent. Use `AgentBase#define_tool` for the
conventional case, or `AgentBase#register_swaig_function` for manual hashes:

```ruby
agent.register_swaig_function(
  "function"    => "get_weather",
  "description" => "Get current weather",
  "parameters"  => {
    "type"       => "object",
    "properties" => {
      "location" => { "type" => "string", "description" => "City name" }
    },
    "required"   => ["location"]
  },
  "secure"  => true,
  "fillers" => { "en-US" => ["Checking weather..."] }
)
```

### SWMLService Class

Base class providing SWML document generation and HTTP service capabilities. `AgentBase` extends this class.

#### Key Methods

##### `get_swml_document -> Hash`
Generate the complete SWML document for the service.

##### `handle_request(request_data) -> Hash`
Handle incoming HTTP requests and generate appropriate responses.

### Dynamic Configuration

The dynamic configuration callback receives the agent instance directly, allowing you to configure it based on request data.

**Usage:**
```ruby
dynamic_config = lambda do |query_params, body_params, headers, agent|
  # Configure based on request
  if query_params["lang"] == "es"
    agent.add_language("Spanish", "es-ES", "nova.luna")
  end

  # Customer-specific configuration
  customer_id = headers["X-Customer-ID"]
  if customer_id
    agent.set_global_data({ "customer_id" => customer_id })
    agent.prompt_add_section("Customer Context", "You are helping customer #{customer_id}")
  end

  # Add skills dynamically
  if query_params["enable_search"] == "true"
    agent.add_skill("web_search", { "provider" => "google" })
  end
end

agent.set_dynamic_config_callback(dynamic_config)
```

---

## Environment Variables

The SDK supports various environment variables for configuration:

### Authentication
- `SWML_BASIC_AUTH_USER`: Basic auth username
- `SWML_BASIC_AUTH_PASSWORD`: Basic auth password

### SSL/HTTPS
- `SWML_SSL_ENABLED`: Enable SSL (true/false)
- `SWML_SSL_CERT_PATH`: Path to SSL certificate
- `SWML_SSL_KEY_PATH`: Path to SSL private key
- `SWML_DOMAIN`: Domain name for SSL

### Proxy Support
- `SWML_PROXY_URL_BASE`: Base URL for proxy server

### Skills Configuration
- `GOOGLE_SEARCH_API_KEY`: Google Custom Search API key
- `GOOGLE_SEARCH_ENGINE_ID`: Google Custom Search Engine ID
- `DATASPHERE_SPACE_NAME`: DataSphere space name
- `DATASPHERE_PROJECT_ID`: DataSphere project ID
- `DATASPHERE_TOKEN`: DataSphere access token

### Usage

<!-- snippet: no-run constructor/config signature illustration referencing assumed placeholder locals (name/function_name/contexts/MyAgent) -->
```ruby
# Set environment variables
ENV["SWML_BASIC_AUTH_USER"] = "admin"
ENV["SWML_BASIC_AUTH_PASSWORD"] = "secret"
ENV["GOOGLE_SEARCH_API_KEY"] = "your-api-key"

# Agent will automatically use these
agent = MyAgent.new
agent.add_skill("web_search", {
  "search_engine_id" => "your-engine-id"
  # api_key will be read from environment
})
```

---

## Complete Example

Here's a comprehensive example using multiple SDK components:

<!-- snippet: no-run ends by starting a blocking server (agent.run/serve) -->
```ruby
require 'signalwire'

class ComprehensiveAgent < SignalWire::AgentBase
  def initialize
    super(
      name: "Comprehensive Agent",
      auto_answer: true,
      record_call: true
    )

    # Configure voice and language
    add_language("English", "en-US", "rime.spore",
                 speech_fillers: ["Let me check...", "One moment..."])

    # Add speech recognition hints
    add_hints(["SignalWire", "customer service", "technical support"])

    # Configure AI parameters
    set_params({
      "ai_model" => "gpt-4.1-nano",
      "end_of_speech_timeout" => 800,
      "temperature" => 0.7
    })

    # Add skills
    add_skill("datetime")
    add_skill("math")
    add_skill("web_search", {
      "api_key" => "your-google-api-key",
      "search_engine_id" => "your-engine-id",
      "num_results" => 3
    })

    # Set up structured workflow
    setup_contexts

    # Add custom tools
    register_custom_tools

    # Set global data
    set_global_data({
      "company_name" => "Acme Corp",
      "support_hours" => "9 AM - 5 PM EST",
      "version" => "2.0"
    })
  end

  # Set up structured workflow contexts
  def setup_contexts
    contexts = define_contexts

    # Greeting context
    greeting = contexts.add_context("greeting")
    greeting.add_step("welcome")
            .set_text("Hello! Welcome to Acme Corp support. How can I help you today?")
            .set_step_criteria("Customer has explained their issue")
            .set_valid_steps(["next"])

    greeting.add_step("categorize")
            .add_section("Current Task", "Categorize the customer's request")
            .add_bullets("Categories", [
              "Technical issue - use diagnostic tools",
              "Billing question - transfer to billing",
              "General inquiry - handle directly"
            ])
            .set_functions(["transfer_to_billing", "run_diagnostics"])
            .set_step_criteria("Request categorized and action taken")

    # Technical support context
    tech = contexts.add_context("technical_support")
    tech.add_step("diagnose")
        .set_text("Let me run some diagnostics to identify the issue.")
        .set_functions(["run_diagnostics", "check_system_status"])
        .set_step_criteria("Diagnostics completed")
        .set_valid_steps(["resolve"])

    tech.add_step("resolve")
        .set_text("Based on the diagnostics, here's how we'll fix this.")
        .set_functions(["apply_fix", "schedule_technician"])
        .set_step_criteria("Issue resolved or escalated")
  end

  # Register custom DataMap tools
  def register_custom_tools
    # Customer lookup tool
    lookup_tool = SignalWire::DataMap.new("lookup_customer")
      .description("Look up customer information")
      .parameter("customer_id", "string", "Customer ID", required: true)
      .webhook("GET", "https://api.company.com/customers/${args.customer_id}",
               headers: { "Authorization" => "Bearer YOUR_TOKEN" })
      .output(SignalWire::Swaig::FunctionResult.new("Customer: ${response.name}, Status: ${response.status}"))
      .error_keys(["error"])

    register_swaig_function(lookup_tool.to_swaig_function)

    # System control tool
    control_tool = SignalWire::DataMap.new("system_control")
      .description("Control system functions")
      .parameter("action", "string", "Action to perform", required: true)
      .parameter("target", "string", "Target system")
      .expression("${args.action}", /restart|reboot/,
                  SignalWire::Swaig::FunctionResult.new("Restarting ${args.target}")
                    .add_action("restart_system", { "target" => "${args.target}" }))
      .expression("${args.action}", /status|check/,
                  SignalWire::Swaig::FunctionResult.new("Checking ${args.target} status")
                    .add_action("check_status", { "target" => "${args.target}" }))

    register_swaig_function(control_tool.to_swaig_function)

    # Transfer-to-billing tool
    define_tool(
      name: "transfer_to_billing",
      description: "Transfer call to billing department",
      parameters: { "type" => "object", "properties" => {} }, handler: nil
    ) do |args, raw_data|
      SignalWire::Swaig::FunctionResult.new("Transferring you to our billing department")
        .update_global_data({ "last_action" => "transfer_to_billing" })
        .connect("billing@company.com", final: false)
    end
  end

  # Handle conversation summaries
  def on_summary(summary = nil, raw_data = nil)
    puts "Conversation completed: #{summary}"
    # Could save to database, send notifications, etc.
  end
end

# Run the agent
if __FILE__ == $PROGRAM_NAME
  agent = ComprehensiveAgent.new
  agent.run
end
```

This concludes the complete API reference for the SignalWire AI Agents SDK. The SDK provides a comprehensive framework for building sophisticated AI agents with modular capabilities, structured workflows, persistent state, and deployment across multiple environments.
