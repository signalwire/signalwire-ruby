# frozen_string_literal: true

# Example: Skills integration -- datetime, math, and joke skills.
#
# Skills are self-contained capability modules that register tools,
# hints, and prompt sections automatically when added to an agent.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'skills_agent', route: '/')

agent.prompt_add_section(
  'Role',
  'You are a versatile assistant that can tell the time, do math, ' \
  'and tell jokes. Use the available tools to help the caller.'
)

# --- Add skills ---

# DateTime skill: provides current date/time lookup
agent.add_skill('datetime', 'timezone' => 'America/Chicago')

# Math skill: provides basic arithmetic
agent.add_skill('math')

# Joke skill: tells random jokes
agent.add_skill('joke')

# --- Additional hints ---

agent.add_hints(%w[time date clock math calculate joke funny])

# --- LLM config ---

agent.set_prompt_llm_params(temperature: 0.5)

# --- List what was loaded ---

puts "Loaded skills: #{agent.list_skills.join(', ')}"
puts "Starting skills agent on port #{agent.port}..."
agent.run
