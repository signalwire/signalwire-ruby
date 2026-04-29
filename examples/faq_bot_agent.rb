# frozen_string_literal: true

# Example: FAQBotAgent prefab.
#
# Demonstrates a specialised FAQ agent that answers questions from a
# pre-defined knowledge base and logs conversation summaries.

require 'signalwire'

faqs = [
  {
    'question' => 'What is SignalWire?',
    'answer'   => 'SignalWire is a communications platform providing APIs for voice, video, and messaging.'
  },
  {
    'question' => 'How do I create an AI Agent?',
    'answer'   => 'Use the SignalWire AI Agent SDK to build and deploy conversational AI agents.'
  },
  {
    'question' => 'What is SWML?',
    'answer'   => 'SWML (SignalWire Markup Language) is a markup language for defining communications workflows.'
  }
]

faq_bot = SignalWire::Prefabs::FaqBot.new(
  faqs:    faqs,
  name:    'signalwire_faq',
  route:   '/faq',
  persona: 'You are a helpful FAQ assistant for SignalWire.'
)

agent = SignalWire::AgentBase.new(name: faq_bot.name, route: faq_bot.route)

# Apply prompt sections
faq_bot.prompt_sections.each do |section|
  agent.prompt_add_section(section['title'], section['body'], bullets: section['bullets'])
end

agent.prompt_add_section('Instructions', nil, bullets: [
  'Only answer questions if the information is in the FAQ knowledge base.',
  'If you do not know the answer, politely say so and offer to help with something else.',
  'Be concise and direct in your responses.'
])

agent.set_global_data(faq_bot.global_data)

agent.define_tool(
  name:        'search_faq',
  description: 'Search the FAQ knowledge base',
  parameters:  {
    'query' => { 'type' => 'string', 'description' => 'Search query' }
  }
) do |args, raw_data|
  faq_bot.handle_search(args, raw_data)
end

# Post-prompt for conversation summary
agent.set_post_prompt(
  'Provide a JSON summary: {"question_type": "CATEGORY", "answered_from_kb": true/false, "follow_up_needed": true/false}'
)

agent.on_summary do |summary, _raw_data|
  puts "FAQ Bot summary: #{summary.inspect}"
end

agent.add_hints(%w[SignalWire SWML agent SDK API])

puts "Starting FAQ Bot on port #{agent.port}..."
agent.run
