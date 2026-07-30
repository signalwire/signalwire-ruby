# frozen_string_literal: true

# Example: Tier-based dynamic configuration.
#
# Demonstrates comprehensive per-request agent customization including
# tier-based parameters, industry-specific prompts, voice/language
# selection, A/B testing, and global data setup.

require 'signalwire'

VOICE_OPTIONS = {
  'standard' => %w[elevenlabs.rachel elevenlabs.adam],
  'premium' => %w[elevenlabs.rachel elevenlabs.adam elevenlabs.josh],
  'enterprise' => %w[elevenlabs.rachel elevenlabs.adam elevenlabs.josh elevenlabs.bella]
}.freeze

INDUSTRY_CONFIGS = {
  'healthcare' => { 'compliance' => 'high', 'style' => 'professional' },
  'finance' => { 'compliance' => 'high', 'style' => 'formal' },
  'retail' => { 'compliance' => 'medium', 'style' => 'friendly' },
  'general' => { 'compliance' => 'standard', 'style' => 'conversational' }
}.freeze

agent = SignalWire::AgentBase.new(
  name: 'comprehensive_dynamic',
  route: '/dynamic',
  record_call: true
)

PREMIUM_TIERS = %w[premium enterprise].freeze

# The per-request knobs this agent reads off the query string.
def request_profile(query_params)
  {
    tier: (query_params['tier'] || 'standard').downcase,
    industry: (query_params['industry']   || 'general').downcase,
    language: (query_params['language']   || 'en').downcase,
    locale: (query_params['locale'] || 'us').downcase,
    test_group: (query_params['test_group'] || 'A').upcase,
    debug: query_params['debug'] == 'true'
  }
end

def apply_language(ephemeral, profile)
  voice = VOICE_OPTIONS.fetch(profile[:tier], VOICE_OPTIONS['standard']).first
  case profile[:language]
  when 'en' then ephemeral.add_language('English', profile[:locale] == 'ca' ? 'en-CA' : 'en-US', voice)
  when 'es' then ephemeral.add_language('Spanish', profile[:locale] == 'mx' ? 'es-MX' : 'es-ES', voice)
  else ephemeral.add_language('English', 'en-US', voice)
  end
end

TIER_PARAMS = {
  'enterprise' => { 'end_of_speech_timeout' => 800, 'attention_timeout' => 25_000 },
  'premium' => { 'end_of_speech_timeout' => 600, 'attention_timeout' => 20_000 }
}.freeze
DEFAULT_TIER_PARAMS = { 'end_of_speech_timeout' => 400, 'attention_timeout' => 15_000 }.freeze

def apply_tier_params(ephemeral, profile)
  params = TIER_PARAMS.fetch(profile[:tier], DEFAULT_TIER_PARAMS).dup
  # Test group B gets a 20% longer end-of-speech window.
  params['end_of_speech_timeout'] = (params['end_of_speech_timeout'] * 1.2).to_i if profile[:test_group] == 'B'
  ephemeral.params = params
end

# industry -> [section title, body, bullets]. Industries without an entry get
# only the generic Role and Purpose section.
INDUSTRY_SECTIONS = {
  'healthcare' => ['Healthcare Guidelines',
                   'Follow HIPAA compliance standards. Never provide medical diagnoses.',
                   ['Protect patient privacy', 'Direct medical questions to providers']],
  'finance' => ['Financial Guidelines',
                'Adhere to financial regulations and maintain strict confidentiality.',
                ['Never provide investment advice', 'Protect financial information']],
  'retail' => ['Customer Service', 'Focus on customer satisfaction and sales support.',
               ['Maintain friendly demeanor', 'Handle complaints with empathy']]
}.freeze

ENHANCED_BULLETS = ['Extended memory', 'Priority processing',
                    'Specialised knowledge bases'].freeze

def apply_role_prompt(ephemeral, profile, config)
  ephemeral.prompt_add_section(
    'Role and Purpose',
    "You are a professional AI assistant specialised in #{profile[:industry]} services. " \
    "Maintain #{config['style']} communication standards."
  )
end

def apply_industry_prompts(ephemeral, profile, config)
  apply_role_prompt(ephemeral, profile, config)
  section = INDUSTRY_SECTIONS[profile[:industry]]
  ephemeral.prompt_add_section(section[0], section[1], bullets: section[2]) if section
  return unless PREMIUM_TIERS.include?(profile[:tier])

  ephemeral.prompt_add_section('Enhanced Capabilities',
                               "As a #{profile[:tier]} service, you have access to advanced features:",
                               bullets: ENHANCED_BULLETS)
end

def apply_global_data(ephemeral, profile, config)
  features = %w[basic_conversation function_calling]
  features += %w[extended_memory priority_processing] if PREMIUM_TIERS.include?(profile[:tier])
  features += %w[custom_integration dedicated_support] if profile[:tier] == 'enterprise'

  ephemeral.set_global_data(
    'service_tier' => profile[:tier], 'industry_focus' => profile[:industry],
    'test_group' => profile[:test_group], 'features_enabled' => features,
    'compliance_level' => config['compliance']
  )
end

DEBUG_BULLETS = ['Include global data references', 'Explain tier-based features'].freeze
AB_BULLETS = ['Ask clarifying questions', 'Offer proactive suggestions'].freeze

def apply_debug_prompt(ephemeral)
  ephemeral.prompt_add_section('Debug Mode',
                               'Debug mode is enabled. Show reasoning and feature availability.',
                               bullets: DEBUG_BULLETS)
  ephemeral.add_hints(%w[debug verbose reasoning tier])
end

def apply_debug_and_ab(ephemeral, profile)
  apply_debug_prompt(ephemeral) if profile[:debug]
  return unless profile[:test_group] == 'B'

  ephemeral.add_hints(%w[enhanced personalised proactive])
  ephemeral.prompt_add_section('Enhanced Style', 'Use an enhanced conversation style:',
                               bullets: AB_BULLETS)
end

agent.set_dynamic_config_callback(nil) do |query_params, _body, _headers, ephemeral|
  profile = request_profile(query_params)
  config = INDUSTRY_CONFIGS.fetch(profile[:industry], INDUSTRY_CONFIGS['general'])

  apply_language(ephemeral, profile)
  apply_tier_params(ephemeral, profile)
  apply_industry_prompts(ephemeral, profile, config)
  apply_global_data(ephemeral, profile, config)
  apply_debug_and_ab(ephemeral, profile)
end

puts "Starting comprehensive dynamic agent on port #{agent.port}..."
puts 'Try: curl http://localhost:3000/dynamic?tier=premium&industry=healthcare'
agent.run
