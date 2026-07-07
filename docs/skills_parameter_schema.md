# Skills Parameter Schema System

This guide explains the parameter schema system for SignalWire AI Agents SDK skills, which enables GUI configuration tools and programmatic skill discovery.

## Overview

The parameter schema system allows skills to declare their configurable parameters with metadata including types, descriptions, default values, and security hints. This enables:

- **GUI Configuration Tools** - Automatically generate configuration forms
- **API Documentation** - Document all available parameters
- **Validation** - Type checking and constraint validation
- **Security** - Mark sensitive parameters as hidden
- **Environment Variables** - Indicate which parameters can be sourced from environment

## Using the Schema System

### Getting All Skills Schema

Use the `list_skills_with_params` method to get a complete schema of all available skills:

```ruby
require 'signalwire'

# Get complete schema for all skills
schema = SignalWire.list_skills_with_params

# Example output structure (a Hash keyed by skill name):
{
  'web_search' => {
    'name' => 'web_search',
    'description' => 'Search the web for information using Google Custom Search API',
    'version' => '1.0.0',
    'supports_multiple_instances' => true,
    'required_packages' => ['bs4', 'requests'],
    'required_env_vars' => [],
    'parameters' => {
      'api_key' => {
        'type' => 'string',
        'description' => 'Google Custom Search API key',
        'required' => true,
        'hidden' => true,
        'env_var' => 'GOOGLE_SEARCH_API_KEY'
      },
      'search_engine_id' => {
        'type' => 'string',
        'description' => 'Google Custom Search Engine ID',
        'required' => true,
        'hidden' => true,
        'env_var' => 'GOOGLE_SEARCH_ENGINE_ID'
      },
      'num_results' => {
        'type' => 'integer',
        'description' => 'Default number of search results to return',
        'default' => 1,
        'required' => false,
        'min' => 1,
        'max' => 10
      }
      # ...
    }
  },
  'datetime' => {
    'name' => 'datetime',
    'description' => 'Get current date, time, and timezone information',
    'version' => '1.0.0',
    'supports_multiple_instances' => false,
    'required_packages' => ['pytz'],
    'required_env_vars' => [],
    'parameters' => {
      'swaig_fields' => {
        'type' => 'object',
        'description' => 'Additional SWAIG function metadata to merge into tool definitions',
        'default' => {},
        'required' => false
      }
    }
  }
  # ...
}
```

### Using Schema for GUI Configuration

Here's an example of how to use the schema to generate a configuration form:

```ruby
require 'signalwire'

# Get skills schema
schema = SignalWire.list_skills_with_params

# Example: Generate HTML form for web_search skill
web_search_schema = schema['web_search']

# Generate an HTML form field based on a parameter schema entry.
def generate_form_field(param_name, param_info)
  field_html = +"<div class=\"form-group\">\n"
  field_html << "  <label for=\"#{param_name}\">#{param_info['description']}</label>\n"

  # Mark required fields
  required = param_info['required'] ? 'required' : ''

  # Hide sensitive fields
  input_type = param_info['hidden'] ? 'password' : 'text'

  # Handle different types
  case param_info['type']
  when 'string'
    default = param_info.fetch('default', '')
    field_html << "  <input type=\"#{input_type}\" id=\"#{param_name}\" name=\"#{param_name}\" "
    field_html << "value=\"#{default}\" #{required}>\n"
  when 'integer'
    default = param_info.fetch('default', 0)
    min_val = param_info.key?('min') ? "min=\"#{param_info['min']}\"" : ''
    max_val = param_info.key?('max') ? "max=\"#{param_info['max']}\"" : ''
    field_html << "  <input type=\"number\" id=\"#{param_name}\" name=\"#{param_name}\" "
    field_html << "value=\"#{default}\" #{min_val} #{max_val} #{required}>\n"
  when 'boolean'
    checked = param_info.fetch('default', false) ? 'checked' : ''
    field_html << "  <input type=\"checkbox\" id=\"#{param_name}\" name=\"#{param_name}\" #{checked}>\n"
  end

  # Show environment variable hint
  if param_info.key?('env_var')
    field_html << "  <small>Can also be set via #{param_info['env_var']} environment variable</small>\n"
  end

  field_html << "</div>\n"
  field_html
end

# Generate form fields for web_search skill
puts '<form>'
web_search_schema['parameters'].each do |param_name, param_info|
  puts generate_form_field(param_name, param_info)
end
puts '</form>'
```

### Programmatic Skill Configuration

Use the schema to validate and configure skills programmatically:

```ruby
require 'signalwire'

class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent')

    # Get schema to validate configuration
    schema = SignalWire.list_skills_with_params

    # Configure web_search skill with validation
    web_search_params = {
      'api_key' => 'your-api-key',
      'search_engine_id' => 'your-engine-id',
      'num_results' => 3,
      'max_content_length' => 3000
    }

    # Validate required parameters
    web_search_schema = schema['web_search']['parameters']
    web_search_schema.each do |param, info|
      if info['required'] && !web_search_params.key?(param)
        raise ArgumentError, "Missing required parameter: #{param}"
      end
    end

    # Add skill with validated parameters
    add_skill('web_search', web_search_params)
  end
end
```

## Parameter Schema Reference

Each parameter in the schema can have the following properties:

| Property | Type | Description |
|----------|------|-------------|
| `type` | string | Parameter type: "string", "integer", "number", "boolean", "object", "array" |
| `description` | string | Human-readable description of the parameter |
| `default` | any | Default value if not provided |
| `required` | boolean | Whether the parameter is required (default: false) |
| `hidden` | boolean | Whether to hide this field in UIs (for secrets/API keys) |
| `env_var` | string | Environment variable that can provide this value |
| `enum` | array | List of allowed values (for string types) |
| `min` | number | Minimum value (for numeric types) |
| `max` | number | Maximum value (for numeric types) |

## Implementing Parameter Schema in Skills

To add parameter schema support to a skill, override the `get_parameter_schema` method:

```ruby
require 'signalwire'

class MyCustomSkill < SignalWire::Skills::SkillBase
  def name = 'my_custom_skill'
  def description = 'My custom skill'
  def version = '1.0.0'

  # Get parameter schema for this skill.
  def get_parameter_schema
    # Get base schema from parent (includes common parameters)
    schema = super

    # Add skill-specific parameters
    schema.merge(
      'api_endpoint' => {
        'type' => 'string',
        'description' => 'API endpoint URL',
        'required' => true,
        'default' => 'https://api.example.com'
      },
      'api_key' => {
        'type' => 'string',
        'description' => 'API authentication key',
        'required' => true,
        'hidden' => true,           # Mark as sensitive
        'env_var' => 'MY_API_KEY'   # Can be set via environment
      },
      'timeout' => {
        'type' => 'integer',
        'description' => 'Request timeout in seconds',
        'default' => 30,
        'required' => false,
        'min' => 1,
        'max' => 300
      },
      'retry_count' => {
        'type' => 'integer',
        'description' => 'Number of retries on failure',
        'default' => 3,
        'required' => false,
        'min' => 0,
        'max' => 10
      },
      'output_format' => {
        'type' => 'string',
        'description' => 'Output format for results',
        'default' => 'json',
        'required' => false,
        'enum' => ['json', 'xml', 'text']   # Allowed values
      },
      'enable_cache' => {
        'type' => 'boolean',
        'description' => 'Enable response caching',
        'default' => true,
        'required' => false
      }
    )
  end

  # Setup the skill using parameters.
  def setup
    # Access parameters via params (string keys)
    @api_endpoint = params['api_endpoint']
    @api_key      = params['api_key']
    @timeout      = params.fetch('timeout', 30)
    # ... etc
    true
  end
end
```

## Common Parameter Patterns

### API Keys and Secrets

Always mark sensitive parameters as `hidden` and provide an `env_var` option:

```ruby
'api_key' => {
  'type' => 'string',
  'description' => 'API key for authentication',
  'required' => true,
  'hidden' => true,
  'env_var' => 'SERVICE_API_KEY'
}
```

### Numeric Parameters with Constraints

Use `min` and `max` to enforce valid ranges:

```ruby
'port' => {
  'type' => 'integer',
  'description' => 'Server port number',
  'default' => 8080,
  'required' => false,
  'min' => 1,
  'max' => 65535
}
```

### Enumerated Values

Use `enum` to restrict to specific values:

```ruby
'log_level' => {
  'type' => 'string',
  'description' => 'Logging level',
  'default' => 'info',
  'required' => false,
  'enum' => ['debug', 'info', 'warning', 'error']
}
```

### Optional Features

Use boolean parameters for optional features:

```ruby
'enable_analytics' => {
  'type' => 'boolean',
  'description' => 'Enable analytics tracking',
  'default' => false,
  'required' => false
}
```

## Base Parameters

All skills automatically inherit these base parameters from `SkillBase`:

- **`swaig_fields`** (object) - Additional SWAIG function metadata to merge into tool definitions
- **`tool_name`** (string) - Custom name for skill instances (only for skills whose `supports_multiple_instances?` returns `true`)

## Examples

### Simple Skill (No Parameters)

Skills like `datetime` and `math` that don't need configuration:

```ruby
def get_parameter_schema
  # Just return base schema
  super
end
```

### Complex Skill (Many Parameters)

Skills like `web_search` with multiple configuration options:

```ruby
def get_parameter_schema
  schema = super

  schema.merge(
    # API credentials (hidden)
    'api_key' => { }, # ...
    'api_secret' => { }, # ...

    # Configuration options
    'timeout' => { }, # ...
    'retry_count' => { }, # ...

    # Feature flags
    'enable_cache' => { }, # ...
    'debug_mode' => { }, # ...

    # Customization
    'response_template' => { }, # ...
    'error_messages' => { } # ...
  )
end
```

## Best Practices

1. **Always provide descriptions** - Make parameters self-documenting
2. **Set sensible defaults** - Allow skills to work with minimal configuration
3. **Mark secrets as hidden** - Protect sensitive information in UIs
4. **Use appropriate types** - Enable proper validation and UI controls
5. **Document environment variables** - Show alternative configuration methods
6. **Validate in setup()** - Ensure all required parameters are present
7. **Support backward compatibility** - Handle deprecated parameters gracefully

## Future Enhancements

The parameter schema system is designed to be extensible. Future enhancements may include:

- **Conditional parameters** - Show/hide based on other parameter values
- **Complex validation** - Cross-parameter validation rules
- **Nested schemas** - Support for complex object parameters
- **Internationalization** - Localized descriptions and error messages
- **Runtime parameter updates** - Modify configuration without restart