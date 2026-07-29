# SignalWire Agents Skills System

<!-- snippet-setup: every ruby example on this page assumes the SDK is required; the web_search skill's setup requires Google Custom Search credentials to be present -->
```ruby
require 'signalwire'
ENV['GOOGLE_SEARCH_API_KEY']   ||= 'demo-key'
ENV['GOOGLE_SEARCH_ENGINE_ID'] ||= 'demo-engine-id'
```

The SignalWire Agents SDK now includes a modular skills system that lets you add capabilities to your agents with simple one-liner calls and configurable parameters.

## What's New

Instead of manually implementing every agent capability, you can now:

<!-- snippet: no-run overview fragment: illustrates the default AND custom-parameter forms of the same skill together; adding web_search twice collides on its instance key at runtime -->
```ruby
require 'signalwire'

# Create an agent
agent = SignalWire::AgentBase.new(name: 'My Assistant')

# Add skills with one-liners!
agent.add_skill('web_search')   # Web search capability with default settings
agent.add_skill('datetime')     # Current date/time info
agent.add_skill('math')         # Mathematical calculations

# Add skills with custom parameters!
agent.add_skill('web_search', {
  'num_results' => 3,  # Get 3 search results instead of default 1
  'delay' => 0.5       # Add 0.5s delay between requests instead of default 0
})

# Your agent now has all these capabilities automatically
```

## Architecture

The skills system consists of:

### Core Infrastructure
- **`SkillBase`** - Abstract base class for all skills with parameter support
- **`SkillManager`** - Handles loading/unloading and lifecycle management with parameters
- **`AgentBase.add_skill()`** - Simple method to add skills to agents with optional parameters

### Discovery & Registry  
- **`SkillRegistry`** - Auto-discovers skills from the `skills/` directory
- **Auto-discovery** - Skills are found automatically on import
- **Validation** - Checks dependencies and environment variables

### Built-in Skills
- **`web_search`** - Google Custom Search API integration with web scraping
- **`datetime`** - Current date/time information with timezone support
- **`math`** - Basic mathematical calculations

## Available Skills

### Web Search (`web_search`)
Search the internet and extract content from web pages.

**Requirements:**
- Environment variables: `GOOGLE_SEARCH_API_KEY`, `GOOGLE_SEARCH_ENGINE_ID`
- Packages: `beautifulsoup4`, `requests`

**Parameters:**
- `num_results` (default: 1) - Number of search results to retrieve (1-10)
- `delay` (default: 0) - Delay in seconds between web requests

**Tools provided:**
- `web_search(query, num_results)` - Search and scrape web content

**Usage examples:**
```ruby
# Default: fast single result
agent.add_skill('web_search')

# Custom: multiple results with delay
agent.add_skill('web_search', {
  'num_results' => 3,
  'delay' => 0.5
})

# Speed optimized: single result, no delay
agent.add_skill('web_search', {
  'num_results' => 1,
  'delay' => 0
})
```

### Date/Time (`datetime`)  
Get current date and time information.

**Requirements:**
- Packages: `pytz`

**Parameters:** None (no configurable parameters)

**Tools provided:**
- `get_current_time(timezone)` - Current time in any timezone
- `get_current_date(timezone)` - Current date in any timezone

### Math (`math`)
Perform mathematical calculations.

**Requirements:** None

**Parameters:** None (no configurable parameters)

**Tools provided:**
- `calculate(expression)` - Evaluate mathematical expressions safely

### Native Vector Search (`native_vector_search`)
Search document indexes via a remote search server using vector similarity and
keyword search. The Ruby port implements **remote (network) mode only**: it POSTs
queries to a search server over HTTP using the Ruby standard library (`net/http`).
The Python reference's local/offline `.swsearch` index mode and the `sw-search`
index-building CLI are not part of the Ruby gem.

**Requirements:**
- A reachable search server URL (`remote_url`). No extra gems are required --
  the skill uses `net/http` from the standard library.

**Parameters:**
- `remote_url` (required) - URL of the remote search server
- `index_name` (optional) - Index name on the remote server
- `tool_name` (default: "search_knowledge") - Custom name for the search tool
- `description` (optional) - Tool description
- `count` (default: 3) - Number of search results to return
- `similarity_threshold` (default: 0.5) - Minimum similarity score
- `hints` (optional) - Extra speech hints to merge into the agent's hint list

**Tools provided:**
- `search_knowledge(query, count)` - Search documents on the remote server

**Usage examples:**
```ruby
# Remote mode (the only supported mode in the Ruby port)
agent.add_skill('native_vector_search', {
  'remote_url' => 'http://localhost:8001',
  'index_name' => 'knowledge'
})

# Custom tool name and result count
agent.add_skill('native_vector_search', {
  'remote_url' => 'http://localhost:8001',
  'tool_name'  => 'search_docs',
  'count'      => 5
})

# Multiple instances pointing at different servers/indexes
agent.add_skill('native_vector_search', {
  'remote_url' => 'http://localhost:8001',
  'index_name' => 'examples',
  'tool_name'  => 'search_examples'
})
```

### SWML Transfer (`swml_transfer`)
Transfer calls between agents using pattern matching.

**Requirements:** None (no additional packages or environment variables required)

**Parameters:**
- `tool_name` (default: "transfer_call") - Custom name for the transfer function
- `description` (default: "Transfer call based on pattern matching") - Tool description
- `parameter_name` (default: "transfer_type") - Name of the parameter for the transfer function
- `parameter_description` (default: "The type of transfer to perform") - Parameter description
- `transfers` (required) - Dictionary mapping regex patterns to transfer configurations:
  - Pattern (key): Regex pattern to match (e.g., "/sales/i")
  - Configuration (value): Dictionary with:
    - `url` (required): Transfer destination URL
    - `message` (optional): Pre-transfer message
    - `return_message` (optional): Post-transfer message
    - `post_process` (optional, default: True): Enable post-processing
- `default_message` (default: "Please specify a valid transfer type.") - Message when no pattern matches
- `default_post_process` (default: False) - Post-processing flag for default case
- `required_fields` (default: {}) - Object mapping field names to descriptions for data collection before transfer

**Tools provided:**
- `transfer_call(transfer_type, ...required_fields)` (or custom tool_name) - Transfer based on pattern matching with optional required fields

**Usage examples:**
```ruby
# Simple transfer between departments
agent.add_skill('swml_transfer', {
  'tool_name' => 'transfer_to_department',
  'transfers' => {
    '/sales/i' => {
      'url' => 'https://example.com/sales',
      'message' => 'Transferring to sales...',
      'return_message' => 'Sales transfer complete.'
    },
    '/support/i' => {
      'url' => 'https://example.com/support',
      'message' => 'Transferring to support...',
      'return_message' => 'Support transfer complete.'
    }
  }
})

# Multiple instances for different transfer types
agent.add_skill('swml_transfer', {
  'tool_name' => 'route_call',
  'parameter_name' => 'department',
  'transfers' => {
    '/sales|billing/i' => {
      'url' => 'https://api.company.com/sales',
      'message' => 'Connecting to sales team...',
      'post_process' => true
    },
    '/technical|support/i' => {
      'url' => 'https://api.company.com/support',
      'message' => 'Connecting to support team...',
      'post_process' => true
    }
  },
  'default_message' => 'Would you like sales or support?'
})
```

## Usage Examples

### Basic Usage
<!-- snippet: no-run ends with agent.run, which starts a blocking WEBrick server -->
```ruby
require 'signalwire'

# Create agent and add skills
agent = SignalWire::AgentBase.new(name: 'Assistant', route: '/assistant')
agent.add_skill('datetime')
agent.add_skill('math')
agent.add_skill('web_search')  # Uses defaults: 1 result, no delay

# Start the agent
agent.run
```

### Skills with Custom Parameters
<!-- snippet: no-run ends with agent.run, which starts a blocking WEBrick server -->
```ruby
require 'signalwire'

# Create agent
agent = SignalWire::AgentBase.new(name: 'Research Assistant', route: '/research')

# Add web search optimized for research (more results)
agent.add_skill('web_search', {
  'num_results' => 5,   # Get more comprehensive results
  'delay' => 1.0        # Be respectful to websites
})

# Add other skills without parameters
agent.add_skill('datetime')
agent.add_skill('math')

# Start the agent
agent.run
```

### Different Parameter Configurations
```ruby
# Speed-optimized for quick responses
agent.add_skill('web_search', {
  'num_results' => 1,
  'delay' => 0
})

# Comprehensive research mode
agent.add_skill('web_search', {
  'num_results' => 5,
  'delay' => 1.0
})

# Balanced approach
agent.add_skill('web_search', {
  'num_results' => 3,
  'delay' => 0.5
})
```

### Check Available Skills
```ruby
require 'signalwire'

# List all discovered skills (name + description per registered skill)
SignalWire.list_skills_with_params.each do |name, info|
  puts "- #{name}: #{info['description']}"
end
```

### Runtime Skill Management
```ruby
agent = SignalWire::AgentBase.new(name: 'Dynamic Agent')

# Add skills with different configurations
agent.add_skill('math')
agent.add_skill('datetime')
agent.add_skill('web_search', { 'num_results' => 2, 'delay' => 0.3 })

# Check what's loaded
puts "Loaded skills: #{agent.list_skills}"

# Remove a skill
agent.remove_skill('math')

# Check if a specific skill is loaded (note the Ruby predicate `?`)
if agent.has_skill?('datetime')
  puts 'Date/time capabilities available'
end
```

## Creating Custom Skills

Create a new skill by extending `SignalWire::Skills::SkillBase` with
parameter support:

```ruby
# lib/signalwire/skills/builtin/my_skill.rb
require 'signalwire'

class MyCustomSkill < SignalWire::Skills::SkillBase
  REQUIRED_ENV_VARS = ['API_KEY'].freeze

  def name = 'my_skill'
  def description = 'Does something awesome with configurable parameters'
  def version = '1.0.0'

  def setup
    # Explicit env-var checks (or return false from validate_env_vars).
    REQUIRED_ENV_VARS.each do |var|
      return false if ENV[var].nil? || ENV[var].empty?
    end

    # Use parameters with defaults (params has string keys).
    @max_items   = params.fetch('max_items', 10)
    @timeout     = params.fetch('timeout', 30)
    @retry_count = params.fetch('retry_count', 3)

    true
  end

  def register_tools
    define_tool(
      name: 'my_function',
      description: "Does something cool (max #{@max_items} items)",
      parameters: {
        'input' => {
          'type' => 'string',
          'description' => 'Input parameter'
        }
      }, handler: nil
    ) do |args, raw_data|
      handle_my_function(args, raw_data)
    end
  end

  # Handle the tool call using configured parameters.
  def handle_my_function(args, _raw_data)
    # Use @max_items, @timeout, @retry_count in your logic
    SignalWire::Swaig::FunctionResult.new("Processed with max_items=#{@max_items}")
  end

  # Speech recognition hints.
  def get_hints = ['custom', 'skill', 'awesome']

  # Prompt sections to add to the agent.
  def get_prompt_sections
    [{
      'title' => 'Custom Capability',
      'body' => "You can do custom things with my_skill (configured for #{@max_items} items)."
    }]
  end
end

# Register the skill so agents can load it by name.
SignalWire::Skills::SkillRegistry.register('my_skill') do |params|
  MyCustomSkill.new(params)
end
```

The skill will be available once registered as:
```ruby
# Use defaults
agent.add_skill('my_skill')

# Use custom parameters
agent.add_skill('my_skill', {
  'max_items' => 20,
  'timeout' => 60,
  'retry_count' => 5
})
```

## Quick Start

1. **Install dependencies:**
   ```bash
   gem install signalwire-sdk
   ```

2. **Run the demo:**
   ```bash
   ruby examples/skills_demo.rb
   ```

3. **For web search, set environment variables:**
   ```bash
   export GOOGLE_SEARCH_API_KEY="your_api_key"
   export GOOGLE_SEARCH_ENGINE_ID="your_engine_id"
   ```

## Testing

Test the skills system with parameters:

```ruby
require 'signalwire'

# Show discovered skills
puts "Available skills: #{SignalWire.list_skills_with_params.keys}"

# Create agent and load skills with parameters
agent = SignalWire::AgentBase.new(name: 'Test', route: '/test')
agent.add_skill('datetime')
agent.add_skill('math')
agent.add_skill('web_search', { 'num_results' => 2, 'delay' => 0.5 })

puts "Loaded skills: #{agent.list_skills}"
puts 'Skills system with parameters working!'
```

## Benefits

- **One-liner integration** - `agent.add_skill('skill_name')`
- **Configurable parameters** - `agent.add_skill('skill_name', { 'param' => 'value' })`
- **Automatic discovery** - Drop skills in the directory and they're available
- **Dependency validation** - Checks packages and environment variables
- **Modular architecture** - Skills are self-contained and reusable
- **Extensible** - Easy to create custom skills with parameters
- **Clean separation** - Skills don't interfere with each other
- **Performance tuning** - Configure skills for speed vs. comprehensiveness

## Migration Guide

**Before (manual implementation):**
```ruby
# Had to manually implement every capability
class WebSearchAgent < SignalWire::AgentBase
  def initialize
    super(name: "WebSearchAgent")
    # ... application-specific search setup ...
    define_tool(name: "web_search", description: "...", parameters: {}, handler: nil) do |args, _raw|
      # Lots of manual code...
    end
  end
end
```

**After (skills system with parameters):**
```ruby
# Simple one-liner with custom configuration
agent = SignalWire::AgentBase.new(name: "WebSearchAgent")
agent.add_skill("web_search", {
  "num_results" => 3,    # Get more results
  "delay"       => 0.5   # Be respectful to servers
})
# Done! Full web search capability with custom settings.
```

The skills system makes SignalWire agents more modular, maintainable, and configurable. 