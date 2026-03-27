# frozen_string_literal: true

# Example: Web search skill.
#
# Demonstrates the Google Custom Search integration via the web_search
# skill. Requires GOOGLE_SEARCH_API_KEY and GOOGLE_SEARCH_ENGINE_ID
# environment variables.

require 'signalwire'

api_key   = ENV['GOOGLE_SEARCH_API_KEY']
engine_id = ENV['GOOGLE_SEARCH_ENGINE_ID']

unless api_key && engine_id
  puts 'Missing required environment variables:'
  puts '  GOOGLE_SEARCH_API_KEY'
  puts '  GOOGLE_SEARCH_ENGINE_ID'
  puts
  puts 'Get credentials at: https://developers.google.com/custom-search/v1/introduction'
  exit 1
end

agent = SignalWire::AgentBase.new(name: 'Web Search Assistant', route: '/search')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Personality',
  'You are Franklin, a friendly and knowledgeable search bot. ' \
  'You are enthusiastic about helping people find information online.'
)

agent.prompt_add_section('Instructions', nil, bullets: [
  'Always introduce yourself as Franklin.',
  'Use web search to find current information.',
  'Present results clearly with source URLs.'
])

agent.add_skill('web_search', {
  'api_key'          => api_key,
  'search_engine_id' => engine_id,
  'num_results'      => 1,
  'delay'            => 0,
  'max_content_length' => 3000,
  'no_results_message' => "I couldn't find anything about '{query}'. Try rephrasing?"
})

puts "Loaded skills: #{agent.list_skills.join(', ')}"
puts "Starting Web Search agent on port #{agent.port}..."
agent.run
