# SignalWire SWML Service Guide

## Table of Contents
- [Introduction](#introduction)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Centralized Logging System](#centralized-logging-system)
- [SWML Document Creation](#swml-document-creation)
- [Verb Handling](#verb-handling)
- [Web Service Features](#web-service-features)
- [Custom Routing Callbacks](#custom-routing-callbacks)
- [Advanced Usage](#advanced-usage)
- [API Reference](#api-reference)
- [Examples](#examples)

## Introduction

The `SWMLService` class provides a foundation for creating and serving SignalWire Markup Language (SWML) documents. It serves as the base class for all SignalWire services, including AI Agents, and handles common tasks such as:

- SWML document creation and manipulation
- Schema validation
- Web service functionality
- Authentication
- Centralized logging

The class is designed to be extended for specific use cases, while providing a full set of capabilities out of the box.

## Installation

The `SWMLService` class is part of the SignalWire AI Agent SDK. Install it as a gem:

```bash
gem install signalwire-sdk
```

## Basic Usage

Here's a simple example of creating an SWML service:

```ruby
require "signalwire/swml"

class SimpleVoiceService < Signalwire::SWML::Service
  def initialize(host: "0.0.0.0", port: 3000)
    super(name: "voice-service", route: "/voice", host: host, port: port)

    build_document
  end

  def build_document
    # Add answer verb
    document.add_verb("answer", {})

    # Add play verb for greeting
    document.add_verb("play", {
      "url" => "say:Hello, thank you for calling our service."
    })

    # Add hangup verb
    document.add_verb("hangup", {})
  end
end

# Create and start the service
service = SimpleVoiceService.new
service.serve
```

## Centralized Logging System

The SignalWire Ruby SDK ships its own lightweight logger
(`Signalwire::Logging::Logger`) that every `SWMLService` and agent uses
automatically. Each logger is tagged with the service name so messages are easy
to trace.

### Using the Logger

Inside a `Signalwire::SWML::Service` or `Signalwire::Agent::AgentBase`
subclass, grab a logger via the `Signalwire::Logging.logger` factory:

```ruby
log = Signalwire::Logging.logger("SWML::Service[my-service]")

# Basic logging
log.info("service_started")

# Debug information
log.debug("document_created size=#{document.to_h.size}")

# Error logging
begin
  # Some operation
rescue => e
  log.error("operation_failed error=#{e.message}")
end
```

### Log Levels

Available log levels, in increasing severity:

- `debug`: Detailed information for debugging
- `info`:  General information about operation
- `warn`:  Warning about potential issues
- `error`: Error information when operations fail

### Suppressing Logs

To suppress logs globally, set `SIGNALWIRE_LOG_MODE=off`, or raise the
threshold with `SIGNALWIRE_LOG_LEVEL=warn`:

```bash
export SIGNALWIRE_LOG_LEVEL=warn   # only warnings and above
# or
export SIGNALWIRE_LOG_MODE=off     # suppress everything
```

At runtime:

```ruby
Signalwire::Logging.global_level = :warn
```

## SWML Document Creation

The `SWMLService` class provides methods for creating and manipulating SWML documents.

### Document Structure

SWML documents have the following basic structure:

```json
{
  "version": "1.0.0",
  "sections": {
    "main": [
      { "verb1": { /* configuration */ } },
      { "verb2": { /* configuration */ } }
    ],
    "section1": [
      { "verb3": { /* configuration */ } }
    ]
  }
}
```

### Document Methods

On `Signalwire::SWML::Document`:

- `add_section(name)`: Add a new named section
- `add_verb(verb_name, config)`: Add a verb to the `main` section
- `add_verb_to_section(section_name, verb_name, config)`: Add a verb to a specific section
- `to_h`: Get the current document as a hash
- `to_json`: Get the current document as a JSON string

On `Signalwire::SWML::Service`:

- `document`: The underlying `Document` instance — use `service.document.add_verb(...)`
- `render`: Render the document as JSON (compact)
- `render_pretty`: Render the document as pretty-printed JSON

## Verb Handling

The `SWMLService` class provides validation for SWML verbs using the SignalWire schema.

### Verb Validation

When adding a verb, the service validates it against the schema to ensure it has the correct structure and parameters.

```ruby
# Validated against the bundled SWML schema
document.add_verb("play", {
  "url"    => "say:Hello, world!",
  "volume" => 5
})

# This raises Signalwire::SWML::Schema::ValidationError at document render time
document.add_verb("play", { "invalid_param" => "value" })
```

### Custom Verb Handlers

In the Ruby port, verb validation is handled uniformly by
`Signalwire::SWML::Schema`. Per-verb custom handlers are not exposed — if you
need custom behavior for a specific verb, subclass `Signalwire::SWML::Service`
and override `execute_verb` (or call `add_verb`/`add_verb_to_section` directly
with a pre-built hash that bypasses the schema check).

## Web Service Features

The `SWMLService` class includes built-in web service capabilities for serving SWML documents.

### Endpoints

By default, a service provides the following endpoints:

- `GET /route`: Return the SWML document
- `POST /route`: Process request data and return the SWML document
- `GET /route/`: Same as above but with trailing slash
- `POST /route/`: Same as above but with trailing slash

Where `route` is the route path specified when creating the service.

### Authentication

Basic authentication is automatically set up for all endpoints. Credentials are generated if not provided, or can be specified:

```ruby
service = Signalwire::SWML::Service.new(
  name:       "my-service",
  basic_auth: ["username", "password"]
)
```

You can also set credentials using environment variables:
- `SWML_BASIC_AUTH_USER`
- `SWML_BASIC_AUTH_PASSWORD`

### Dynamic SWML Generation

You can override the `on_swml_request` method to customize SWML documents based on request data:

```ruby
def on_swml_request(request_data = nil)
  return nil unless request_data

  document.add_verb("answer", {})

  if request_data["caller_type"] == "vip"
    document.add_verb("play", { "url" => "say:Welcome VIP caller!" })
  else
    document.add_verb("play", { "url" => "say:Welcome caller!" })
  end

  nil # use the document we've built as-is
end
```

## Custom Routing Callbacks

The `SWMLService` class allows you to register custom routing callbacks that can examine incoming requests and determine where they should be routed.

### Registering a Routing Callback

You can use the `register_routing_callback` method to register a function that will be called to process requests to a specific path:

```ruby
# Example: Route based on a field in the request body. If the block returns a
# string, the request is redirected to that URL with HTTP 307. Returning nil
# causes the request to be processed normally by `on_request`.
service.register_routing_callback("/customer") do |request_data|
  if request_data["customer_id"]
    next "/customer/#{request_data['customer_id']}"
  end

  nil
end
```

### How Routing Works

1. When a request is received at the registered path, the routing callback is executed
2. The callback inspects the request and can decide whether to redirect it
3. If the callback returns a URL string, the request is redirected with HTTP 307 (temporary redirect)
4. If the callback returns `None`, the request is processed normally by the `on_request` method

### Serving Different Content for Different Paths

You can use the `callback_path` parameter passed to `on_request` to serve different content for different paths:

```ruby
def on_request(request_data = nil, callback_path: nil)
  case callback_path
  when "/customer"
    {
      "sections" => {
        "main" => [
          { "answer" => {} },
          { "play" => { "url" => "say:Welcome to customer service!" } }
        ]
      }
    }
  when "/product"
    {
      "sections" => {
        "main" => [
          { "answer" => {} },
          { "play" => { "url" => "say:Welcome to product support!" } }
        ]
      }
    }
  end
end
```

### Example: Multi-Section Service

Here's an example of a service that uses routing callbacks to handle different types of requests:

```ruby
require "signalwire/swml"

class MultiSectionService < Signalwire::SWML::Service
  def initialize
    super(name: "multi-section", route: "/main")

    # Main document
    document.add_verb("answer", {})
    document.add_verb("play", { "url" => "say:Hello from the main service!" })
    document.add_verb("hangup", {})

    # Customer section
    document.add_section("customer_section")
    document.add_verb_to_section("customer_section", "answer", {})
    document.add_verb_to_section("customer_section", "play",
                                 { "url" => "say:Welcome to customer service!" })
    document.add_verb_to_section("customer_section", "hangup", {})

    register_routing_callback("/customer") do |body|
      puts "Processing request for customer ID: #{body['customer_id']}" if body["customer_id"]
      nil
    end

    # Product section
    document.add_section("product_section")
    document.add_verb_to_section("product_section", "answer", {})
    document.add_verb_to_section("product_section", "play",
                                 { "url" => "say:Welcome to product support!" })
    document.add_verb_to_section("product_section", "hangup", {})

    register_routing_callback("/product") do |body|
      puts "Processing request for product ID: #{body['product_id']}" if body["product_id"]
      nil
    end
  end

  def on_request(_request_data = nil, callback_path: nil)
    case callback_path
    when "/customer"
      { "sections" => { "main" => document.to_h["sections"]["customer_section"] } }
    when "/product"
      { "sections" => { "main" => document.to_h["sections"]["product_section"] } }
    end
  end
end
```

In this example:
1. The service registers two custom route paths: `/customer` and `/product`
2. Each path has its own callback function to handle routing decisions
3. The `on_request` method uses the `callback_path` to determine which content to serve
4. Different SWML sections are served for different paths

## Advanced Usage

### Creating a FastAPI Router

You can get a Rack-compatible app for the service to include in a larger
application:

```ruby
require "rack/builder"
require "signalwire/swml"

service = Signalwire::SWML::Service.new(name: "my-service")

app = Rack::Builder.new do
  map "/voice" do
    run service.rack_app
  end
end.to_app
```

### Schema Path Customization

You can specify a custom path to the schema file:

```ruby
service = Signalwire::SWML::Service.new(
  name: "my-service",
  schema_path: "/path/to/schema.json"
)
```

## API Reference

### Constructor Parameters

- `name`: Service name/identifier (required)
- `route`: HTTP route path (default: "/")
- `host`: Host to bind to (default: "0.0.0.0")
- `port`: Port to bind to (default: 3000)
- `basic_auth`: Optional tuple of (username, password)
- `schema_path`: Optional path to schema.json
- `suppress_logs`: Whether to suppress structured logs (default: False)

### Document Methods

- `reset_document()`
- `add_verb(verb_name, config)`
- `add_section(section_name)`
- `add_verb_to_section(section_name, verb_name, config)`
- `get_document()`
- `render_document()`

### Service Methods

- `as_router()`: Get a FastAPI router for the service
- `run()`: Start the service
- `stop()`: Stop the service
- `get_basic_auth_credentials(include_source=False)`: Get the basic auth credentials
- `on_swml_request(request_data=None)`: Called when SWML is requested
- `register_routing_callback(callback_fn, path="/sip")`: Register a callback for request routing

### Verb Helper Methods

- `add_verb(verb_name, config)`: Add any SWML verb with configuration

## Examples

### Basic Voicemail Service

```ruby
require "signalwire/swml"

class VoicemailService < Signalwire::SWML::Service
  def initialize(host: "0.0.0.0", port: 3000)
    super(name: "voicemail", route: "/voicemail", host: host, port: port)

    build_voicemail_document
  end

  def build_voicemail_document
    # Add answer verb
    document.add_verb("answer", {})

    # Play greeting
    document.add_verb("play", {
      "url" => "say:Hello, you've reached the voicemail service. Please leave a message after the beep."
    })

    # Play a beep
    document.add_verb("play", { "url" => "https://example.com/beep.wav" })

    # Record the message
    document.add_verb("record", {
      "format"      => "mp3",
      "stereo"      => false,
      "max_length"  => 120,   # 2 minutes max
      "terminators" => "#"
    })

    # Thank the caller
    document.add_verb("play", {
      "url" => "say:Thank you for your message. Goodbye!"
    })

    # Hang up
    document.add_verb("hangup", {})
  end
end
```

### Dynamic Call Routing Service

```ruby
class CallRouterService < Signalwire::SWML::Service
  def on_swml_request(request_data = nil)
    # If there's no request data, use the default document.
    return nil unless request_data

    document.add_verb("answer", {})

    # Get routing parameters
    department = (request_data["department"] || "").downcase

    # Play greeting
    document.add_verb("play", {
      "url" => "say:Thank you for calling our #{department} department. Please hold."
    })

    # Route based on department
    phone_numbers = {
      "sales"   => "+15551112222",
      "support" => "+15553334444",
      "billing" => "+15555556666"
    }

    # Get the appropriate number or use the default.
    to_number = phone_numbers[department] || "+15559990000"

    # Connect to the department
    document.add_verb("connect", {
      "to"                => to_number,
      "timeout"           => 30,
      "answer_on_bridge"  => true
    })

    # Fallback message and hangup
    document.add_verb("play", {
      "url" => "say:We're sorry, but all of our agents are currently busy. Please try again later."
    })
    document.add_verb("hangup", {})

    nil # Use the document we've built
  end
end
```

For more examples, see the `examples` directory in the SignalWire AI Agent SDK repository. 