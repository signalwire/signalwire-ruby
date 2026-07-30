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

# The per-request knobs this agent reads off the query string.
def request_profile(query_params)
  {
    vip: query_params['vip'].to_s.downcase == 'true',
    department: (query_params['department'] || 'general').downcase,
    customer_id: query_params['customer_id'] || '',
    language: (query_params['language'] || 'en').downcase
  }
end

def apply_voice_and_params(clone, profile)
  voice = profile[:vip] ? 'elevenlabs.nova' : 'elevenlabs.rachel'
  if profile[:language] == 'es'
    clone.add_language('Spanish', 'es-ES', voice)
  else
    clone.add_language('English', 'en-US', voice)
  end
  clone.set_params(
    'end_of_speech_timeout' => profile[:vip] ? 300 : 500,
    'attention_timeout' => profile[:vip] ? 20_000 : 15_000
  )
end

DEPARTMENT_HINTS = {
  'sales' => %w[pricing enterprise upgrade],
  'billing' => %w[invoice payment charges]
}.freeze
DEFAULT_HINTS = %w[support troubleshoot help].freeze

def apply_hints_and_data(clone, profile)
  clone.add_hints(%w[SignalWire SWML API webhook SIP] +
                  DEPARTMENT_HINTS.fetch(profile[:department], DEFAULT_HINTS))

  global = { 'department' => profile[:department],
             'service_level' => profile[:vip] ? 'vip' : 'standard' }
  global['customer_id'] = profile[:customer_id] unless profile[:customer_id].empty?
  clone.global_data = global
end

def apply_role_prompt(clone, profile)
  role = if profile[:customer_id].empty?
           'You are a professional customer service representative.'
         else
           "You are a customer service rep helping customer #{profile[:customer_id]}."
         end
  role += ' This is a VIP customer who receives priority service.' if profile[:vip]
  clone.prompt_add_section('Role and Purpose', role)
end

# department -> [section title, body, bullets]. 'general' is the fallback.
DEPARTMENT_SECTIONS = {
  'sales' => ['Sales Expertise', 'You specialize in sales:',
              ['Present product features and benefits', 'Handle pricing questions',
               'Process orders and upgrades']],
  'billing' => ['Billing Expertise', 'You specialize in billing:',
                ['Explain statements and charges', 'Process payment arrangements',
                 'Handle dispute resolution']]
}.freeze
DEFAULT_SECTION = ['Support Guidelines', 'Follow these principles:',
                   ['Listen carefully to customer needs', 'Provide accurate information',
                    'Escalate complex issues when appropriate']].freeze
VIP_SECTION = ['VIP Standards', 'Premium service:',
               ['Provide immediate attention', 'Offer exclusive options',
                'Ensure complete satisfaction']].freeze

def apply_expertise_sections(clone, profile)
  title, body, bullets = DEPARTMENT_SECTIONS.fetch(profile[:department], DEFAULT_SECTION)
  clone.prompt_add_section(title, body, bullets: bullets)
  return unless profile[:vip]

  vip_title, vip_body, vip_bullets = VIP_SECTION
  clone.prompt_add_section(vip_title, vip_body, bullets: vip_bullets)
end

agent.set_dynamic_config_callback(nil) do |query_params, _body_params, _headers, clone|
  profile = request_profile(query_params)
  apply_voice_and_params(clone, profile)
  apply_hints_and_data(clone, profile)
  apply_role_prompt(clone, profile)
  apply_expertise_sections(clone, profile)
end

puts 'Starting Enhanced Dynamic Agent'
puts '  ?vip=true          Premium voice + faster response'
puts '  ?department=sales  Sales expertise'
puts '  ?customer_id=X     Personalized experience'
puts '  ?language=es       Spanish'
agent.run
