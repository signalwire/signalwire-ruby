# frozen_string_literal: true

# Example: Enhanced dynamic agent that adapts based on request parameters.
#
# - vip=true/false (premium voice, faster response)
# - department=sales/support/billing (specialized expertise)
# - customer_id=<string> (personalized experience)
# - language=en/es (language and voice selection)
#
# Test:
#   curl "http://localhost:3000/?vip=true&department=sales"
#   curl "http://localhost:3000/?department=billing&language=es"

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name: 'Enhanced Dynamic Agent',
  auto_answer: true,
  record_call: true
)

agent.set_dynamic_config_callback(nil) do |query_params, _body_params, _headers, clone|
  is_vip      = query_params['vip'].to_s.downcase == 'true'
  department  = (query_params['department'] || 'general').downcase
  customer_id = query_params['customer_id'] || ''
  language    = (query_params['language'] || 'en').downcase

  # Voice and language
  voice = is_vip ? 'elevenlabs.nova' : 'elevenlabs.rachel'
  if language == 'es'
    clone.add_language('Spanish', 'es-ES', voice)
  else
    clone.add_language('English', 'en-US', voice)
  end

  # AI parameters
  clone.set_params(
    'end_of_speech_timeout' => is_vip ? 300 : 500,
    'attention_timeout' => is_vip ? 20_000 : 15_000
  )

  # Hints
  hints = %w[SignalWire SWML API webhook SIP]
  hints += case department
           when 'sales'   then %w[pricing enterprise upgrade]
           when 'billing' then %w[invoice payment charges]
           else %w[support troubleshoot help]
           end
  clone.add_hints(hints)

  # Global data
  global = { 'department' => department, 'service_level' => is_vip ? 'vip' : 'standard' }
  global['customer_id'] = customer_id unless customer_id.empty?
  clone.global_data = global

  # Role prompt
  role = if customer_id.empty?
           'You are a professional customer service representative.'
         else
           "You are a customer service rep helping customer #{customer_id}."
         end
  role += ' This is a VIP customer who receives priority service.' if is_vip
  clone.prompt_add_section('Role and Purpose', role)

  # Department expertise
  case department
  when 'sales'
    clone.prompt_add_section('Sales Expertise', 'You specialize in sales:', bullets: [
                               'Present product features and benefits',
                               'Handle pricing questions',
                               'Process orders and upgrades'
                             ])
  when 'billing'
    clone.prompt_add_section('Billing Expertise', 'You specialize in billing:', bullets: [
                               'Explain statements and charges',
                               'Process payment arrangements',
                               'Handle dispute resolution'
                             ])
  else
    clone.prompt_add_section('Support Guidelines', 'Follow these principles:', bullets: [
                               'Listen carefully to customer needs',
                               'Provide accurate information',
                               'Escalate complex issues when appropriate'
                             ])
  end

  if is_vip
    clone.prompt_add_section('VIP Standards', 'Premium service:', bullets: [
                               'Provide immediate attention',
                               'Offer exclusive options',
                               'Ensure complete satisfaction'
                             ])
  end
end

puts 'Starting Enhanced Dynamic Agent'
puts '  ?vip=true          Premium voice + faster response'
puts '  ?department=sales  Sales expertise'
puts '  ?customer_id=X     Personalized experience'
puts '  ?language=es       Spanish'
agent.run
