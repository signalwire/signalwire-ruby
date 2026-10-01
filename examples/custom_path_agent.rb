# frozen_string_literal: true

# Example: Agent with a custom HTTP path.
#
# Instead of the default "/" route, this agent serves at "/chat".
# Dynamic config personalises the prompt based on query parameters.
#
# Try: curl "http://localhost:3000/chat?user_name=Alice&topic=AI&mood=casual"

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name: 'Chat Assistant',
  route: '/chat',
  record_call: true
)

agent.prompt_add_section(
  'Role',
  'You are a friendly chat assistant ready to help with any questions or conversations.'
)

agent.set_dynamic_config_callback(nil) do |query_params, _body, _headers, ephemeral|
  user_name = query_params['user_name'] || 'friend'
  topic     = query_params['topic']     || 'general conversation'
  mood      = (query_params['mood']     || 'friendly').downcase

  ephemeral.prompt_add_section(
    'Personalisation',
    "The user's name is #{user_name}. They are interested in discussing #{topic}."
  )

  ephemeral.add_language('English', 'en-US', 'elevenlabs.rachel')

  style = case mood
          when 'professional' then 'Maintain a professional, business-appropriate tone.'
          when 'casual'       then 'Use a casual, relaxed conversational style.'
          else                     'Be warm, friendly, and approachable.'
          end
  ephemeral.prompt_add_section('Communication Style', style)

  ephemeral.set_global_data(
    'user_name' => user_name,
    'topic' => topic,
    'mood' => mood,
    'session_type' => 'chat'
  )

  ephemeral.add_hints(%w[chat assistant help conversation question])
end

puts "Starting chat agent at /chat on port #{agent.port}..."
agent.run
