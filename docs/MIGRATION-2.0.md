# Migrating to SignalWire SDK 2.0

## Gem Rename

Update your `Gemfile`:
```ruby
# Before
gem 'signalwire_agents'

# After
gem 'signalwire'
```

Then run:
```bash
bundle install
```

## Require and Module Changes

```ruby
# Before
require 'signalwire_agents'

class MyAgent < SignalWireAgents::AgentBase
  def initialize
    super
    client = SignalWireAgents::Rest::SignalWireClient.new(project_id, token, space_url)
  end
end

# After
require 'signalwire'

class MyAgent < SignalWire::AgentBase
  def initialize
    super
    client = SignalWire::Rest::RestClient.new(project_id, token, space_url)
  end
end
```

## Class Renames

| Before | After |
|--------|-------|
| `SignalWireAgents::AgentBase` | `SignalWire::AgentBase` |
| `SignalWireAgents::Rest::SignalWireClient` | `SignalWire::Rest::RestClient` |
| `SignalWireAgents::` (all modules) | `SignalWire::` |

## Quick Migration

Find and replace in your project:
```bash
# Update require statements
find . -name '*.rb' -exec sed -i "s/require 'signalwire_agents'/require 'signalwire'/g" {} +

# Update module namespace
find . -name '*.rb' -exec sed -i 's/SignalWireAgents/SignalWire/g' {} +

# Rename client class
find . -name '*.rb' -exec sed -i 's/SignalWireClient/RestClient/g' {} +

# Update Gemfile
sed -i "s/gem 'signalwire_agents'/gem 'signalwire'/g" Gemfile
bundle install
```

## What Didn't Change

- All method names (set_prompt_text, define_tool, add_skill, etc.)
- All parameter shapes
- SWML output format
- RELAY protocol
- REST API paths
- Skills, contexts, DataMap -- all the same
