# frozen_string_literal: true

# Example: Tier-based dynamic configuration.
#
# Demonstrates comprehensive per-request agent customization including
# tier-based parameters, industry-specific prompts, voice/language
# selection, A/B testing, and global data setup.

require 'signalwire'

VOICE_OPTIONS = {
  'standard'   => %w[elevenlabs.rachel elevenlabs.adam],
  'premium'    => %w[elevenlabs.rachel elevenlabs.adam elevenlabs.josh],
  'enterprise' => %w[elevenlabs.rachel elevenlabs.adam elevenlabs.josh elevenlabs.bella]
}.freeze

INDUSTRY_CONFIGS = {
  'healthcare' => { 'compliance' => 'high',   'style' => 'professional' },
  'finance'    => { 'compliance' => 'high',   'style' => 'formal' },
  'retail'     => { 'compliance' => 'medium', 'style' => 'friendly' },
  'general'    => { 'compliance' => 'standard', 'style' => 'conversational' }
}.freeze

agent = SignalWire::AgentBase.new(
  name:        'comprehensive_dynamic',
  route:       '/dynamic',
  record_call: true
)

agent.set_dynamic_config_callback do |query_params, _body, _headers, ephemeral|
  tier       = (query_params['tier']       || 'standard').downcase
  industry   = (query_params['industry']   || 'general').downcase
  language   = (query_params['language']   || 'en').downcase
  locale     = (query_params['locale']     || 'us').downcase
  test_group = (query_params['test_group'] || 'A').upcase
  debug_mode = query_params['debug'] == 'true'

  # --- Voice & language ---
  voices = VOICE_OPTIONS.fetch(tier, VOICE_OPTIONS['standard'])
  voice  = voices.first

  case language
  when 'en'
    code = locale == 'ca' ? 'en-CA' : 'en-US'
    ephemeral.add_language('name' => 'English', 'code' => code, 'voice' => voice)
  when 'es'
    code = locale == 'mx' ? 'es-MX' : 'es-ES'
    ephemeral.add_language('name' => 'Spanish', 'code' => code, 'voice' => voice)
  else
    ephemeral.add_language('name' => 'English', 'code' => 'en-US', 'voice' => voice)
  end

  # --- Tier-based AI params ---
  params = case tier
           when 'enterprise'
             { 'end_of_speech_timeout' => 800, 'attention_timeout' => 25_000 }
           when 'premium'
             { 'end_of_speech_timeout' => 600, 'attention_timeout' => 20_000 }
           else
             { 'end_of_speech_timeout' => 400, 'attention_timeout' => 15_000 }
           end

  params['end_of_speech_timeout'] = (params['end_of_speech_timeout'] * 1.2).to_i if test_group == 'B'
  ephemeral.params = params

  # --- Industry-specific prompts ---
  config = INDUSTRY_CONFIGS.fetch(industry, INDUSTRY_CONFIGS['general'])
  ephemeral.prompt_add_section(
    'Role and Purpose',
    "You are a professional AI assistant specialised in #{industry} services. " \
    "Maintain #{config['style']} communication standards."
  )

  case industry
  when 'healthcare'
    ephemeral.prompt_add_section('Healthcare Guidelines',
      'Follow HIPAA compliance standards. Never provide medical diagnoses.',
      bullets: ['Protect patient privacy', 'Direct medical questions to providers'])
  when 'finance'
    ephemeral.prompt_add_section('Financial Guidelines',
      'Adhere to financial regulations and maintain strict confidentiality.',
      bullets: ['Never provide investment advice', 'Protect financial information'])
  when 'retail'
    ephemeral.prompt_add_section('Customer Service',
      'Focus on customer satisfaction and sales support.',
      bullets: ['Maintain friendly demeanor', 'Handle complaints with empathy'])
  end

  if %w[premium enterprise].include?(tier)
    ephemeral.prompt_add_section('Enhanced Capabilities',
      "As a #{tier} service, you have access to advanced features:",
      bullets: ['Extended memory', 'Priority processing', 'Specialised knowledge bases'])
  end

  # --- Global data ---
  features = %w[basic_conversation function_calling]
  features += %w[extended_memory priority_processing] if %w[premium enterprise].include?(tier)
  features += %w[custom_integration dedicated_support] if tier == 'enterprise'

  ephemeral.set_global_data(
    'service_tier'     => tier,
    'industry_focus'   => industry,
    'test_group'       => test_group,
    'features_enabled' => features,
    'compliance_level' => config['compliance']
  )

  # --- Debug ---
  if debug_mode
    ephemeral.prompt_add_section('Debug Mode',
      'Debug mode is enabled. Show reasoning and feature availability.',
      bullets: ['Include global data references', 'Explain tier-based features'])
    ephemeral.add_hints(%w[debug verbose reasoning tier])
  end

  # --- A/B testing ---
  if test_group == 'B'
    ephemeral.add_hints(%w[enhanced personalised proactive])
    ephemeral.prompt_add_section('Enhanced Style',
      'Use an enhanced conversation style:',
      bullets: ['Ask clarifying questions', 'Offer proactive suggestions'])
  end
end

puts "Starting comprehensive dynamic agent on port #{agent.port}..."
puts 'Try: curl http://localhost:3000/dynamic?tier=premium&industry=healthcare'
agent.run
