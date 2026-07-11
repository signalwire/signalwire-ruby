# Third-Party Skills Integration Guide

This guide explains how to create and integrate third-party skills with the SignalWire AI Agents SDK. The SDK supports multiple methods for loading external skills, making it easy to extend agent capabilities without modifying the core SDK.

## Overview

Third-party skills can be integrated using four different methods:

1. **Direct Registration** - Register skill classes programmatically
2. **Directory Registration** - Add directories containing skill collections
3. **Distribute as a Gem** - Package and install skills as a Ruby gem
4. **Environment Variables** - Configure skill paths via environment

All third-party skills are discovered and indexed the same way as built-in skills, appearing in `list_skills_with_params` output with their parameter schemas.

## Creating a Third-Party Skill

Third-party skills follow the same structure as built-in skills. Here's a minimal example:

```ruby
# my_weather_skill/skill.rb
require 'signalwire'

# Custom weather information skill.
class WeatherSkill < SignalWire::Skills::SkillBase
  def name = 'weather'
  def description = 'Get weather information for any location'
  def version = '1.0.0'
  def required_packages = ['httparty']

  # Define configuration parameters.
  def get_parameter_schema
    schema = super

    schema.merge(
      'api_key' => {
        'type' => 'string',
        'description' => 'Weather API key',
        'required' => true,
        'hidden' => true,
        'env_var' => 'WEATHER_API_KEY'
      },
      'units' => {
        'type' => 'string',
        'description' => 'Temperature units',
        'default' => 'celsius',
        'required' => false,
        'enum' => ['celsius', 'fahrenheit', 'kelvin']
      },
      'cache_timeout' => {
        'type' => 'integer',
        'description' => 'Cache timeout in seconds',
        'default' => 300,
        'required' => false,
        'min' => 0,
        'max' => 3600
      }
    )
  end

  # Initialize the skill.
  def setup
    return false unless validate_packages

    @api_key = get_param('api_key', env_var: 'WEATHER_API_KEY')
    unless @api_key
      logger.error('Weather API key is required')
      return false
    end

    @units = get_param('units', default: 'celsius')
    @cache_timeout = get_param('cache_timeout', default: 300)

    true
  end

  # Register weather tools with the agent.
  def register_tools
    define_tool(
      name: 'get_weather',
      description: 'Get current weather for a location',
      parameters: {
        'location' => {
          'type' => 'string',
          'description' => 'City name or coordinates'
        }
      }
    ) do |args, raw_data|
      handle_get_weather(args, raw_data)
    end
  end

  # Handle weather requests.
  def handle_get_weather(args, _raw_data)
    location = (args['location'] || '').strip

    return SignalWire::Swaig::FunctionResult.new('Please provide a location') if location.empty?

    # Implementation would call weather API here.
    # This is just an example.
    SignalWire::Swaig::FunctionResult.new(
      "The weather in #{location} is sunny and 22°#{@units[0].upcase}"
    )
  end
end
```

## Integration Methods

### Method 1: Direct Registration

Register individual skill classes programmatically:

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
require 'signalwire'
require_relative 'my_weather_skill/skill'

# Register the skill globally
SignalWire.register_skill(WeatherSkill)

# Now use it in any agent
class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent')

    # Add the registered skill
    add_skill('weather', {
      'api_key' => 'your-api-key',
      'units' => 'fahrenheit'
    })
  end
end
```

### Method 2: Directory Registration

Register directories containing multiple skills:

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
require 'signalwire'

# Add a directory of custom skills
SignalWire.add_skill_directory('/opt/custom_skills')

# Directory structure should be:
# /opt/custom_skills/
#   weather/
#     skill.rb      # Contains WeatherSkill class
#   stock_market/
#     skill.rb      # Contains StockMarketSkill class
#   translation/
#     skill.rb      # Contains TranslationSkill class

# Now use any skill from the directory
agent.add_skill('weather', { 'api_key' => '...' })
agent.add_skill('stock_market', { 'api_key' => '...' })
```

### Method 3: Distribute as a Gem

Package your skills as a gem. Each skill file calls
`SignalWire::Skills::SkillRegistry.register` when it is `require`d, so
requiring the gem registers every skill it ships:

```ruby
# my_signalwire_skills.gemspec
Gem::Specification.new do |spec|
  spec.name    = 'my-signalwire-skills'
  spec.version = '1.0.0'
  spec.files   = Dir['lib/**/*.rb']

  spec.add_dependency 'signalwire-sdk'
  spec.add_dependency 'httparty'
end
```

Each skill file registers itself on load:

```ruby
# lib/my_signalwire_skills/weather.rb
require 'signalwire'

class WeatherSkill < SignalWire::Skills::SkillBase
  def name = 'weather'
  # ... rest of the skill ...
end

SignalWire::Skills::SkillRegistry.register('weather') do |params|
  WeatherSkill.new(params)
end
```

After installing the gem, require it and the skills are available:

```bash
gem install my-signalwire-skills
```

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
# Requiring the gem registers its skills
require 'my_signalwire_skills'

agent.add_skill('weather', { 'api_key' => '...' })
```

### Method 4: Environment Variable

The SDK auto-consumes the `SIGNALWIRE_SKILL_PATHS` environment variable: every
directory it names is folded into the skill registry's external search path
automatically — no startup wiring required. This mirrors the Python reference,
which reads the same variable and adds those directories to skill discovery.

```bash
# Single directory
export SIGNALWIRE_SKILL_PATHS=/opt/my_skills

# Multiple directories (path-separator-delimited, ":" on Unix)
export SIGNALWIRE_SKILL_PATHS=/opt/my_skills:/home/user/custom_skills
```

```ruby
require 'signalwire'

# No wiring needed — directories in SIGNALWIRE_SKILL_PATHS are already on the
# registry's external search path, so the skill resolves.
agent.add_skill('weather', { 'api_key' => '...' })
```

The variable is read at skill-search time, so it takes effect even if set after
the process starts. Directories registered explicitly via `add_skill_directory`
take precedence (they appear first in the search order); env-var directories are
appended and deduplicated.

## Directory Structure

Skills loaded from directories must follow this structure:

```
my_skills_directory/
├── weather/                 # Skill directory (matches the skill name)
│   ├── skill.rb            # Required: Contains skill class
│   └── README.md           # Optional: Documentation
├── translation/
│   ├── skill.rb
│   └── resources/          # Optional: Additional files
│       └── languages.json
└── stock_market/
    └── skill.rb
```

## Skill Discovery and Schema

Third-party skills are fully integrated with the SDK's discovery system:

```ruby
require 'signalwire'

# Get all skills including third-party ones
all_skills = SignalWire.list_skills_with_params

# Third-party skills include source information
puts all_skills['weather']
# Output:
{
  'name' => 'weather',
  'description' => 'Get weather information for any location',
  'version' => '1.0.0',
  'supports_multiple_instances' => false,
  'required_packages' => ['httparty'],
  'required_env_vars' => [],
  'parameters' => {
    'api_key' => {
      'type' => 'string',
      'description' => 'Weather API key',
      'required' => true,
      'hidden' => true,
      'env_var' => 'WEATHER_API_KEY'
    },
    'units' => {
      'type' => 'string',
      'description' => 'Temperature units',
      'default' => 'celsius',
      'required' => false,
      'enum' => ['celsius', 'fahrenheit', 'kelvin']
    }
  },
  'source' => 'external'  # Shows it's a third-party skill
}
```

## Best Practices

### 1. Skill Naming

- Use lowercase, underscore-separated names
- Choose unique names to avoid conflicts with built-in skills
- Match directory name to the skill's `name` for directory-based loading

### 2. Parameter Design

- Always implement `get_parameter_schema` for GUI compatibility
- Mark sensitive parameters as `hidden`
- Provide sensible defaults
- Use `env_var` for parameters that can come from environment

### 3. Error Handling

```ruby
# Proper setup with error handling.
def setup
  # Validate packages
  return false unless validate_packages

  # Validate required parameters
  unless params['api_key']
    logger.error('API key is required')
    return false
  end

  # Test connectivity
  begin
    test_api_connection
  rescue StandardError => e
    logger.error("Failed to connect to API: #{e}")
    return false
  end

  true
end
```

### 4. Documentation

Include a README.md in your skill directory:

```markdown
# Weather Skill

Provides weather information for any location.

## Configuration

- `api_key` (required): Your weather API key
- `units` (optional): Temperature units (celsius, fahrenheit, kelvin)
- `cache_timeout` (optional): Cache timeout in seconds

## Usage

```ruby
agent.add_skill('weather', {
  'api_key' => 'your-api-key',
  'units' => 'fahrenheit'
})
```
```

## Advanced Features

### Multiple Instances

Support multiple instances of your skill:

```ruby
class WeatherSkill < SignalWire::Skills::SkillBase
  def name = 'weather'
  def supports_multiple_instances? = true # Enable multiple instances

  # Create a unique key for this instance.
  def instance_key
    service = get_param('service', default: 'default')
    "#{name}_#{service}"
  end
end
```

Usage:

```ruby
# Add multiple weather services
agent.add_skill('weather', {
  'tool_name' => 'openweather',
  'service' => 'openweathermap',
  'api_key' => 'key1'
})

agent.add_skill('weather', {
  'tool_name' => 'weatherapi',
  'service' => 'weatherapi',
  'api_key' => 'key2'
})
```

### Dynamic Tool Names

Customize tool names for better agent prompts:

```ruby
def register_tools
  tool_name = get_param('tool_name', default: 'get_weather')
  service   = get_param('service', default: 'default')

  define_tool(
    name: tool_name,
    description: "Get weather using #{service}",
    parameters: { } # ...
  ) do |args, raw_data|
    handle_get_weather(args, raw_data)
  end
end
```

### Skill Dependencies

Load skills that depend on other skills. Call through `has_skill?` on the
agent (note the Ruby predicate `?`):

```ruby
def setup
  unless agent.has_skill?("translation")
    # Logger tag suppressed for brevity; plug in your own logger as needed.
    return false
  end

  true
end
```

## Testing Third-Party Skills

Test your skills before distribution:

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
# test_weather_skill.rb
require 'minitest/autorun'
require 'signalwire'
require_relative 'my_weather_skill/skill'

class TestWeatherSkill < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new(name: 'test-agent')
  end

  def test_skill_registration
    # Test direct registration
    SignalWire.register_skill(WeatherSkill)

    # add_skill returns the agent (raises ArgumentError on an unknown skill)
    assert_equal @agent, @agent.add_skill('weather', { 'api_key' => 'test-key' })
    assert @agent.has_skill?('weather')
  end

  def test_parameter_schema
    schema = WeatherSkill.new({}).get_parameter_schema
    assert schema.key?('api_key')
    assert schema['api_key']['required']
    assert schema['api_key']['hidden']
  end
end
```

## Troubleshooting

### Skill Not Found

If your skill isn't being discovered:

1. Check the skill directory structure
2. Verify the skill's `name` matches the directory name
3. Ensure `skill.rb` exists and contains a valid skill class
4. Check logs for loading errors

### Require Errors

For skills that pull in helper files, require them relative to the skill file:

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
# Require helpers relative to skill.rb
require_relative 'utils'

# Or handle load errors gracefully
begin
  require_relative 'utils'
rescue LoadError
  require 'utils'
end

parse_temperature(raw)
```

### Environment Variables

Debug environment variable loading:

```ruby
require 'signalwire'

puts "Skill paths: #{ENV.fetch('SIGNALWIRE_SKILL_PATHS', 'Not set')}"

registry = SignalWire::Skills::SkillRegistry.new
sources = registry.list_all_skill_sources
puts "External skills: #{sources['external_paths']}"
```

## Example: Complete Third-Party Skill Package

Here's a complete example of a distributable skill package:

```
my-signalwire-skills/
├── my-signalwire-skills.gemspec
├── README.md
├── Gemfile
├── lib/
│   ├── my_signalwire_skills.rb
│   └── my_signalwire_skills/
│       ├── weather/
│       │   ├── skill.rb
│       │   └── utils.rb
│       └── translation/
│           └── skill.rb
└── test/
    ├── test_weather.rb
    └── test_translation.rb
```

```ruby
# my-signalwire-skills.gemspec
Gem::Specification.new do |spec|
  spec.name        = 'my-signalwire-skills'
  spec.version     = '1.0.0'
  spec.author      = 'Your Name'
  spec.summary     = 'Custom skills for SignalWire AI Agents'
  spec.files       = Dir['lib/**/*.rb']

  spec.add_dependency 'signalwire-sdk', '>= 1.0.12'
  spec.add_dependency 'httparty', '>= 0.21'
  spec.required_ruby_version = '>= 3.0'
end
```

The top-level `lib/my_signalwire_skills.rb` requires each skill file, and
each skill file calls `SkillRegistry.register` on load:

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
# lib/my_signalwire_skills.rb
require 'my_signalwire_skills/weather/skill'
require 'my_signalwire_skills/translation/skill'
```

Install and use:

```bash
gem install specific_install
gem specific_install https://github.com/yourname/my-signalwire-skills.git
```

<!-- snippet: no-run references user-supplied external skill files/directories not present in the SDK repo -->
```ruby
require 'signalwire'
require 'my_signalwire_skills'

agent = SignalWire::AgentBase.new(name: 'my-agent')
agent.add_skill('weather', { 'api_key' => '...' })
agent.add_skill('translate', { 'api_key' => '...' })
agent.run
```
