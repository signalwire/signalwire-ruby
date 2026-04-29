# frozen_string_literal: true

# Example: Web search skill with multiple instances and custom tool names.
#
# Loads the web search skill three times (general, news, quick) plus
# Wikipedia search.
#
# Required: GOOGLE_SEARCH_API_KEY, GOOGLE_SEARCH_ENGINE_ID

require 'signalwire'

api_key   = ENV['GOOGLE_SEARCH_API_KEY']
engine_id = ENV['GOOGLE_SEARCH_ENGINE_ID']

agent = SignalWire::AgentBase.new(name: 'multi-search', route: '/multi-search')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a research assistant with access to multiple search tools. ' \
  'Use the most appropriate tool for each query.'
)

begin
  agent.add_skill('datetime')
  agent.add_skill('math')
rescue => e
  puts "Skill warning: #{e.message}"
end

# Wikipedia search
begin
  agent.add_skill('wikipedia_search', 'num_results' => 2)
  puts 'Added Wikipedia search (tool: search_wiki)'
rescue => e
  puts "Wikipedia: #{e.message}"
end

if api_key.nil? || engine_id.nil? || api_key.empty? || engine_id.empty?
  puts 'Warning: Missing GOOGLE_SEARCH_API_KEY or GOOGLE_SEARCH_ENGINE_ID.'
  puts 'Web search instances will not be available.'
else
  # General web search (default tool name)
  begin
    agent.add_skill('web_search',
      'api_key'          => api_key,
      'search_engine_id' => engine_id,
      'num_results'      => 3)
    puts 'Added general web search (tool: web_search)'
  rescue => e
    puts "General search: #{e.message}"
  end

  # News search
  begin
    agent.add_skill('web_search',
      'api_key'          => api_key,
      'search_engine_id' => engine_id,
      'tool_name'        => 'search_news',
      'num_results'      => 5,
      'delay'            => 0.5)
    puts 'Added news search (tool: search_news)'
  rescue => e
    puts "News search: #{e.message}"
  end

  # Quick single-result search
  begin
    agent.add_skill('web_search',
      'api_key'          => api_key,
      'search_engine_id' => engine_id,
      'tool_name'        => 'quick_search',
      'num_results'      => 1,
      'delay'            => 0)
    puts 'Added quick search (tool: quick_search)'
  rescue => e
    puts "Quick search: #{e.message}"
  end
end

puts "\nTools: web_search, search_news, quick_search, search_wiki"
puts "Starting multi-search agent on port #{agent.port}..."
agent.run
