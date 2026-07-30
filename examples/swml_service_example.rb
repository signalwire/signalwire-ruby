#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: SWML service patterns -- three approaches to building SWML.
#
# Demonstrates the same documented contract as Python's
# examples/swml_service_example.py, adapted to Ruby idiom:
#
#   1. Direct verb manipulation on a SWMLService instance
#   2. Sequential calls to the auto-vivified verb methods (Ruby's
#      equivalent of the Python SWMLBuilder fluent surface)
#   3. Using the AI verb for conversational experiences
#
# Each approach renders a standalone SWML document and starts an HTTP
# server. Run with PORT=NNNN to override the listening port; the
# inherited Service constructor reads PORT from ENV by default.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'signalwire'

# ---------------------------------------------------------------------
# 1. Direct verb manipulation on SWMLService
# ---------------------------------------------------------------------

def example_using_service
  puts '=== Example using SWMLService directly ==='

  service = SignalWire::SWML::Service.new(
    name: 'simple-swml-service',
    route: '/simple',
    host: '0.0.0.0',
    port: 3001
  )

  # Build the SWML document by calling auto-vivified verb methods.
  # Each method appends a verb to the active section of the document.
  service.add_verb('answer', {})
  service.add_verb('play',   { 'url' => 'say:Hello, world!' })
  service.add_verb('hangup', {})

  puts JSON.pretty_generate(service.render_document)
  puts

  service
end

# ---------------------------------------------------------------------
# 2. Auto-vivified verb method API (Ruby's fluent surface)
# ---------------------------------------------------------------------

def example_using_builder
  puts '=== Example using auto-vivified verb methods ==='

  service = SignalWire::SWML::Service.new(
    name: 'fluent-swml-service',
    route: '/fluent',
    host: '0.0.0.0',
    port: 3002
  )

  # Each verb method appends to the document. The 38 verbs from the
  # SWML schema are available as methods on every Service instance.
  service.answer
  service.play(url: 'say:Welcome to our service!')
  service.record(format: 'mp3', stereo: true, beep: true, max_length: 60)
  service.play(url: 'say:Thank you for your message. Goodbye!')
  service.hangup

  puts JSON.pretty_generate(service.render_document)
  puts

  service
end

# ---------------------------------------------------------------------
# 3. AI verb for conversational experiences
# ---------------------------------------------------------------------

def example_using_ai
  puts '=== Example using AI verb ==='

  service = SignalWire::SWML::Service.new(
    name: 'ai-swml-service',
    route: '/ai',
    host: '0.0.0.0',
    port: 3003
  )

  service.answer
  service.ai(
    'prompt' => {
      'text' => 'You are a friendly receptionist. Greet the caller, ask how ' \
                'you can help, and answer questions about our company.'
    },
    'params' => { 'temperature' => 0.7 },
    'languages' => [
      { 'name' => 'English', 'code' => 'en-US', 'voice' => 'rachel' }
    ]
  )

  puts JSON.pretty_generate(service.render_document)
  puts

  service
end

if __FILE__ == $PROGRAM_NAME
  # Render each example to stdout for inspection. Uncomment any
  # serve() call to actually start an HTTP server on its route.
  example_using_service
  example_using_builder
  example_using_ai

  puts
  puts 'To start a server, edit this file and call .serve on one of the'
  puts 'returned services. Each runs on its own port (3001/3002/3003).'
end
