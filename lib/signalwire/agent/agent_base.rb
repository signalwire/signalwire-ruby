# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
require 'securerandom'
require 'openssl'
require 'rack'
require 'uri'
require_relative '../logging'
require_relative '../runtime'
require_relative '../swml/document'
require_relative '../swml/schema'
require_relative '../swml/service'
require_relative '../swaig/function_result'
require_relative '../swaig/parameter_schema'
require_relative '../security/session_manager'
require_relative '../security/webhook_validator'
require_relative '../security/webhook_middleware'
require_relative '../contexts/context_builder'
require_relative '../skills/skill_base'
require_relative '../skills/skill_manager'
require_relative '../skills/skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Central agent class that composes SWML rendering, tool dispatch,
  # prompt management, AI config, and HTTP serving.
  #
  # AgentBase extends SWMLService with agent-specific capabilities:
  #  - Prompt management (POM sections and raw text)
  #  - Tool (SWAIG function) registration & dispatch
  #  - AI configuration (hints, languages, pronunciations, params)
  #  - Verb management (pre/post answer, post-AI)
  #  - Context & step workflows
  #  - Skill integration
  #  - Dynamic configuration via per-request ephemeral copies
  #
  # All configuration methods return +self+ for method chaining.
  class AgentBase < SWML::Service
    # Attributes:
    # - ``logger`` — agent-specific structured logger.
    # - ``skill_manager`` — owning SkillManager.
    # - ``agent_id`` — UUID identifier from constructor or auto-generated.
    # - ``default_webhook_url`` — base URL for SWAIG webhook fallbacks.
    # - ``native_functions`` — names of built-in SWAIG functions to advertise.
    # - ``use_pom`` — whether prompt-object-model rendering is enabled.
    attr_reader :logger, :skill_manager, :agent_id, :default_webhook_url,
                :native_functions, :use_pom, :signing_key

    # Maximum request body size (1 MB)
    MAX_BODY_SIZE = 1_048_576

    # create_ephemeral_copy: ivars whose value is an array of dup-able
    # elements (deep-copied via map(&:dup)).
    EPHEMERAL_ARRAY_OF_DUPS = %i[
      @pom_sections @languages @pronounce @function_includes
      @pre_answer_verbs @post_answer_verbs @post_ai_verbs @mcp_servers
    ].freeze

    # create_ephemeral_copy: ivars deep-copied with a shallow #dup.
    EPHEMERAL_SHALLOW_DUPS = %i[
      @hints @params @global_data @native_functions @prompt_llm_params
      @post_prompt_llm_params @answer_config @swaig_query_params @loaded_skills
    ].freeze

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------

    def initialize(name: 'agent', route: '/', host: '0.0.0.0', port: nil,
                   basic_auth: nil,
                   use_pom: true,
                   token_expiry_secs: 3600,
                   auto_answer: true, record_call: false,
                   record_format: 'mp4', record_stereo: true,
                   default_webhook_url: nil,
                   agent_id: nil,
                   native_functions: nil,
                   schema_path: nil,
                   suppress_logs: false,
                   enable_post_prompt_override: false,
                   check_for_input_override: false,
                   config_file: nil,
                   schema_validation: true,
                   signing_key: nil,
                   trust_proxy_for_signature: false)
      # Resolve auth before super so we can warn about auto-generated
      # passwords. Service's built-in auth fallback uses a fresh UUID per
      # process, which is fine, but we want the agent-specific warning.
      resolved_auth, password_auto_generated = resolve_basic_auth(basic_auth)
      super(name: name, route: route, host: host, port: port, basic_auth: resolved_auth,
            schema_path: schema_path, config_file: config_file, schema_validation: schema_validation)
      init_logger(name, suppress_logs, password_auto_generated)
      configure_agent(
        auto_answer:, record_call:, record_format:, record_stereo:, use_pom:, agent_id:,
        default_webhook_url:, native_functions:, enable_post_prompt_override:,
        check_for_input_override:, token_expiry_secs:, signing_key:, trust_proxy_for_signature:
      )
    end

    private

    # Read-only agent configuration, set during construction / one-time config
    # calls (enable_sip_routing, enable_debug_events, etc.) and only read after.
    attr_reader :auto_answer, :record_call, :record_format, :record_stereo,
                :suppress_logs, :trust_proxy_for_signature, :proxy_url_base,
                :sip_routing_enabled, :sip_path, :sip_auto_map, :debug_events_level,
                :debug_events_enabled, :debug_routes_enabled, :mcp_server_enabled

    # Resolve basic auth. Returns [auth_pair, password_auto_generated?].
    # Resolution: explicit arg → SWML_BASIC_AUTH_* env → random UUIDs.
    def resolve_basic_auth(basic_auth)
      return [basic_auth, false] if basic_auth

      if ENV['SWML_BASIC_AUTH_USER'] && ENV['SWML_BASIC_AUTH_PASSWORD']
        return [[ENV['SWML_BASIC_AUTH_USER'], ENV['SWML_BASIC_AUTH_PASSWORD']], false]
      end

      [[ENV['SWML_BASIC_AUTH_USER'] || SecureRandom.uuid, SecureRandom.uuid], true]
    end

    # Warn loudly so external callers (tests, RPC clients, MCP) know why they
    # are getting HTTP 401 — the auto-generated password lives only in this
    # process and changes on every restart.
    def warn_autogenerated_password
      @logger.warn(
        "basic_auth_password_autogenerated: username=#{@basic_auth[0].inspect}. " \
        'No SWML_BASIC_AUTH_PASSWORD found in environment and no basic_auth ' \
        'passed to the agent constructor. The SDK generated a random ' \
        'password that exists only in this process; external callers will ' \
        "get HTTP 401 unless they read the value from this process's env. " \
        'To fix, set SWML_BASIC_AUTH_USER and SWML_BASIC_AUTH_PASSWORD in ' \
        'your environment, or pass basic_auth: [user, pass] to ' \
        'AgentBase.new.'
      )
    end

    # @api private — build the agent's structured logger and, when the
    # constructor had to invent a basic-auth password, warn that external callers
    # will get 401 unless they read it out of this process.
    def init_logger(name, suppress_logs, password_auto_generated)
      @logger = Logging.logger("AgentBase[#{name}]")
      @suppress_logs = suppress_logs
      warn_autogenerated_password if password_auto_generated
    end

    # Apply the constructor options: call settings, agent identity/flags, the
    # session manager, signing key, and all default-valued state.
    def configure_agent(**opts)
      init_call_settings(**opts.slice(:auto_answer, :record_call, :record_format, :record_stereo))
      init_identity(**opts.slice(:use_pom, :agent_id, :default_webhook_url, :native_functions,
                                 :enable_post_prompt_override, :check_for_input_override))
      @session_manager = Security::SessionManager.new(token_expiry_secs: opts[:token_expiry_secs])
      init_signing_key(opts[:signing_key], opts[:trust_proxy_for_signature])
      init_default_state
      @logger.info "Agent '#{name}' initialised (route=#{route}, port=#{port})"
    end

    # @api private — store the four call-handling constructor options that drive
    # the SWML `answer` / `record_call` verbs emitted ahead of the AI verb.
    def init_call_settings(auto_answer:, record_call:, record_format:, record_stereo:)
      @auto_answer   = auto_answer
      @record_call   = record_call
      @record_format = record_format
      @record_stereo = record_stereo
    end

    # use_pom toggles POM-vs-raw rendering; agent_id is an optional explicit
    # UUID; default_webhook_url is used when SWAIG functions carry no explicit
    # URL; native_functions lists native SWAIG callables; the *_override flags
    # are wired through the endpoint dispatcher.
    def init_identity(**opts)
      @use_pom = opts[:use_pom]
      @agent_id            = opts[:agent_id] || SecureRandom.uuid
      @default_webhook_url = opts[:default_webhook_url]
      @native_functions    = opts[:native_functions] || []
      @enable_post_prompt_override = opts[:enable_post_prompt_override]
      @check_for_input_override    = opts[:check_for_input_override]
    end

    # Webhook signature validation (per the SignalWire webhook signing spec).
    # Resolution:
    # explicit arg → SIGNALWIRE_SIGNING_KEY env. When set, build_rack_app
    # mounts WebhookMiddleware on the signed routes; when unset, warn so
    # production users notice unsigned traffic is being accepted.
    def init_signing_key(signing_key, trust_proxy_for_signature)
      @signing_key = signing_key || ENV.fetch('SIGNALWIRE_SIGNING_KEY', nil)
      @trust_proxy_for_signature = trust_proxy_for_signature
      log_signing_key_status unless suppress_logs
    end

    # @api private — log whether inbound webhook signature validation is armed. A
    # missing signing key is a WARN, not an error: the agent still serves, but it
    # accepts unsigned traffic.
    def log_signing_key_status
      if @signing_key && !@signing_key.empty?
        @logger.info('webhook_signature_validation_enabled')
      else
        @logger.warn(
          '[signalwire] webhook signature validation is disabled — ' \
          'set signing_key or SIGNALWIRE_SIGNING_KEY to enable'
        )
      end
    end

    # Initialise all the plain default-valued instance variables (prompt state,
    # AI config, debug, verbs, contexts, skills, web, SIP, MCP). Service
    # (parent) already initialised @tools / @swaig_functions.
    def init_default_state
      init_prompt_and_ai_state
      init_verb_and_context_state
      init_web_and_integration_state
    end

    # @api private — reset the prompt state (raw text, direct POM, POM sections,
    # post-prompt text) and the AI-config state.
    def init_prompt_and_ai_state
      @prompt_text      = nil    # raw text mode
      @prompt_pom       = nil    # direct POM array
      @pom_sections     = []     # built via prompt_add_section
      @post_prompt_text = nil
      init_ai_config_state
    end

    # @api private — reset the AI-verb collections (hints, languages, pronounce,
    # params, global_data, function includes, internal fillers and the two LLM
    # param maps) to their empty defaults.
    def init_ai_config_state
      @hints               = []
      @languages           = []
      @multilingual_config = nil
      @pronounce           = []
      @params              = {}
      @global_data         = {}
      @function_includes   = []
      @internal_fillers    = {}
      @prompt_llm_params   = {}
      @post_prompt_llm_params = {}
    end

    # @api private — reset the verb lists (pre-answer / answer / post-answer /
    # post-AI), the debug-event flags, the context builder, and the skill manager
    # and its loaded-skill map.
    def init_verb_and_context_state
      @debug_events_enabled = false
      @debug_events_level   = 1
      @debug_event_callback = nil

      @pre_answer_verbs  = [] # [[verb_name, config], ...]
      @answer_config     = {}
      @post_answer_verbs = []
      @post_ai_verbs     = []

      @context_builder   = nil

      # Python parity: SkillManager(agent) keeps a back-pointer so loaded
      # skills can attach SWAIG tools and prompt sections via the manager.
      @skill_manager     = Skills::SkillManager.new(self)
      @loaded_skills     = {} # skill_name => SkillBase
    end

    # @api private — reset the web/serving state: the dynamic-config callback, the
    # proxy URL base (seeded from SWML_PROXY_URL_BASE), the webhook URL overrides,
    # the SWAIG query params, and the debug-route/summary hooks.
    def init_web_and_integration_state
      @dynamic_config_callback = nil
      @proxy_url_base          = ENV.fetch('SWML_PROXY_URL_BASE', nil)
      @web_hook_url_override   = nil
      @post_prompt_url_override = nil
      @swaig_query_params      = {}
      @render_call_id          = nil
      @debug_routes_enabled    = false
      @summary_callback        = nil
      init_sip_and_mcp_state
    end

    # @api private — reset SIP routing (disabled, `/sip`, no registered usernames)
    # and MCP state (no external servers, `/mcp` endpoint not exposed).
    def init_sip_and_mcp_state
      @sip_routing_enabled = false
      @sip_auto_map        = false
      @sip_path            = '/sip'
      @sip_usernames       = []

      @mcp_servers         = []     # external MCP server configs
      @mcp_server_enabled  = false  # expose /mcp endpoint
    end

    public

    # ==================================================================
    # Identity / URL
    # ==================================================================

    # Return the agent's name.
    #
    # The name is stored on the parent {SWML::Service} as ``@name`` (also
    # exposed via the ``name`` reader); this getter exposes it under the
    # ``get_name`` method name.
    #
    # @return [String] the agent name
    def get_name
      name
    end

    # Build the full URL for this agent.
    #
    # {SWML::Service} already defines ``get_full_url``; AgentBase inherits
    # it. This explicit override (delegating to +super+) exposes the method
    # as an own-method of AgentBase while preserving identical behaviour.
    #
    # @param include_auth [Boolean] embed basic-auth credentials in the URL
    # @return [String] the full URL
    def get_full_url(include_auth: false)
      super
    end

    # ==================================================================
    # Prompt methods
    # ==================================================================

    # Set prompt as raw text. Clears any POM state.
    def set_prompt_text(text)
      @prompt_text  = text
      @pom_sections = []
      @prompt_pom   = nil
      self
    end

    # Set post-prompt text.
    def set_post_prompt(text)
      @post_prompt_text = text
      self
    end

    # Set POM array directly.
    def set_prompt_pom(pom)
      @prompt_pom   = pom
      @prompt_text  = nil
      @pom_sections = []
      self
    end

    # Add a POM section.
    #
    # @param title [String] section title
    # @param body  [String, nil] optional body text
    # @param bullets [Array<String>, nil] optional bullet items
    # @param numbered [Boolean] render as a numbered top-level entry
    # @param numbered_bullets [Boolean] render bullets as numbered
    # @param subsections [Array<Hash>, nil] optional pre-rendered
    #   subsection hashes (each ``{title:, body:, bullets:}``)
    def prompt_add_section(title, body = '', bullets: nil,
                           numbered: false, numbered_bullets: false,
                           subsections: nil)
      @prompt_text = nil
      @prompt_pom  = nil
      @pom_sections << build_section(title, body, bullets: bullets, numbered: numbered,
                                                  numbered_bullets: numbered_bullets, subsections: subsections)
      self
    end

    # @api private — build one POM section hash from the {#prompt_add_section}
    # arguments. `body` is omitted when nil or empty (Ruby's `''` is truthy where
    # the reference's is falsy, so a bare truth test would emit `"body": ""`);
    # the flags are emitted only when true.
    def build_section(title, body, **opts)
      section = { 'title' => title }
      # See prompt_add_subsection: `''` is truthy in Ruby, falsy in python.
      section['body']             = body              unless body.nil? || body.empty?
      section['bullets']          = opts[:bullets]    if opts[:bullets]
      section['numbered']         = true              if opts[:numbered]
      section['numbered_bullets'] = true              if opts[:numbered_bullets]
      subs = build_subsections(opts[:subsections])
      section['subsections'] = subs if subs
      section
    end

    # @api private — normalise a list of subsection hashes to the wire shape, or
    # nil when the caller passed no subsections.
    def build_subsections(subsections)
      return nil unless subsections.is_a?(Array) && !subsections.empty?

      subsections.map { |sub| build_subsection(sub) }
    end

    # Normalise a subsection hash (string or symbol keys) into the wire shape.
    def build_subsection(sub)
      h = { 'title' => sub['title'] || sub[:title] }
      body = sub['body'] || sub[:body]
      bullets = sub['bullets'] || sub[:bullets]
      h['body']    = body    if body
      h['bullets'] = bullets if bullets
      h
    end

    # Append content to an existing POM section, creating it if absent.
    #
    # Supports appending body text, a single bullet, or a list of bullets.
    #
    # @param title [String] section title
    # @param body  [String, nil] body text to append
    # @param bullet [String, nil] single bullet to append
    # @param bullets [Array<String>, nil] bullets to append
    #
    # **Backwards compat:** the original Ruby signature was
    # ``prompt_add_to_section(title, text)``. When called with two
    # positional arguments the second becomes ``body``; this preserves
    # existing call sites while still supporting Python's keyword form.
    def prompt_add_to_section(title, body_arg = nil, body: nil, bullet: nil, bullets: nil)
      effective_body = body || body_arg
      sec = find_or_create_section(title)

      sec['body'] = (sec['body'] || '') + effective_body.to_s if effective_body
      append_section_bullets(sec, bullet, bullets)
      self
    end

    # @api private — the existing POM section with this title, or a freshly
    # appended one. Never returns nil, so callers can append unconditionally.
    def find_or_create_section(title)
      sec = @pom_sections.find { |s| s['title'] == title }
      return sec if sec

      sec = { 'title' => title }
      @pom_sections << sec
      sec
    end

    # @api private — append a single `bullet` and/or a `bullets` array to a
    # section, creating its `bullets` key on first use. A nil/non-Array pair is a
    # no-op, leaving the section untouched.
    def append_section_bullets(sec, bullet, bullets)
      to_add = []
      to_add << bullet if bullet
      to_add.concat(bullets) if bullets.is_a?(Array)
      sec['bullets'] = (sec['bullets'] || []) + to_add unless to_add.empty?
    end

    # Add a subsection under a parent section.
    def prompt_add_subsection(parent_title, title, body = '', bullets: nil)
      parent = find_or_create_section(parent_title)
      parent['subsections'] ||= []
      sub = { 'title' => title }
      # An EMPTY body is omitted, not emitted as "". Ruby's `''` is truthy where
      # python's is falsy, so a bare `if body` would emit `"body": ""` for the
      # default where the reference (`if self.body:` in pom.Section.to_dict)
      # omits the key entirely.
      sub['body']    = body    unless body.nil? || body.empty?
      sub['bullets'] = bullets if bullets
      parent['subsections'] << sub
      self
    end

    # Check whether a POM section with the given title exists.
    def prompt_has_section?(title)
      @pom_sections.any? { |s| s['title'] == title }
    end

    # Return the current prompt: either a string (text mode) or an array (POM).
    # @!visibility private  (idiomatic alias: #prompt; the original
    #   ``get_prompt`` name is kept for back-compat)
    def get_prompt
      return @prompt_text if @prompt_text
      return @prompt_pom  if @prompt_pom
      return @pom_sections.dup unless @pom_sections.empty?

      nil
    end

    # Read-only snapshot of the agent's POM as a typed
    # {SignalWire::POM::PromptObjectModel} instance.
    #
    # Returns ``nil`` when raw-text prompt mode is in effect
    # (``set_prompt_text`` was called); the POM is only available when
    # ``use_pom`` is enabled.
    #
    # The returned PromptObjectModel is a fresh build of the agent's
    # current section state, so caller mutations do not leak into agent
    # state. Use ``agent.pom.to_h`` to retrieve the legacy
    # array-of-hashes representation.
    def pom
      return nil if @prompt_text

      sections = @prompt_pom || @pom_sections
      pom = SignalWire::POM::PromptObjectModel.new
      sections.each { |sec| add_pom_section(pom, sec) }
      pom
    end

    # Convert one section Hash (String/Symbol keys) into a POM section plus
    # its subsections, appended to `pom`.
    def add_pom_section(pom, sec)
      h = sec.transform_keys(&:to_s)
      section = pom.add_section(h['title'], **section_pom_kwargs(h))
      (h['subsections'] || []).each do |sub|
        sh = sub.transform_keys(&:to_s)
        section.add_subsection(sh['title'], **section_pom_kwargs(sh))
      end
    end

    # @api private — the {SignalWire::POM::PromptObjectModel} keyword args for one
    # section hash, defaulting each key and accepting both the `numbered_bullets`
    # and legacy `numberedBullets` spellings.
    def section_pom_kwargs(sec)
      {
        body: sec.fetch('body', ''),
        bullets: sec['bullets'] || [],
        numbered: sec['numbered'] || false,
        numbered_bullets: sec['numbered_bullets'] || sec['numberedBullets'] || false
      }
    end

    # Returns the post-prompt text whatever set_post_prompt stored, or
    # nil when no post-prompt has been set. Used by SWML rendering when a
    # post-prompt is configured.
    # @!visibility private  (idiomatic alias: #post_prompt; the original
    #   ``get_post_prompt`` name is kept for back-compat)
    def get_post_prompt
      @post_prompt_text
    end

    # Returns the raw prompt text whatever set_prompt_text stored, or
    # nil when no raw prompt has been set. Distinct from #get_prompt
    # which may return the POM array when use_pom is true.
    # @!visibility private  (idiomatic alias: #prompt_text; the original
    #   ``get_raw_prompt`` name is kept for back-compat)
    def get_raw_prompt
      @prompt_text
    end

    # ==================================================================
    #  Idiomatic Ruby accessors (PROTOTYPE — see RUBY_ERGONOMICS_MIGRATION.md)
    # ==================================================================
    # Additive aliases layered over the Python-named originals above. The
    # `get_`/`set_` methods stay (the cross-port audit matches them 1:1);
    # these give Ruby callers the native shape: `agent.post_prompt = "..."`
    # and `agent.prompt`. Every alias is recorded in PORT_ADDITIONS.md as a
    # port-only symbol. This block prototypes the pattern on the prompt
    # accessors only; the full rollout is described in the migration doc.

    # Reader: the effective prompt (string in text mode, POM array otherwise).
    # Alias of #get_prompt. Reader-only — `get_prompt` is a *computed* getter
    # (raw text vs POM), so there is no symmetric writer; set the raw text via
    # #prompt_text= or build a POM. This raw-vs-rendered asymmetry is the main
    # edge case the migration doc calls out.
    alias prompt get_prompt

    # Raw prompt text (whatever #set_prompt_text stored). Symmetric pair.
    alias prompt_text get_raw_prompt
    # Writer returns the assigned value (Ruby `=` semantics), not self, so it
    # can't chain — but `=` writers are never chained anyway.
    def prompt_text=(text)
      set_prompt_text(text)
    end

    # Post-prompt text. Clean symmetric reader/writer pair — the showcase case.
    alias post_prompt get_post_prompt
    # Set the post-prompt text — the instruction run after the conversation ends.
    # Writer half of the {#post_prompt} pair; returns the assigned value, not self.
    #
    # @param text [String]
    def post_prompt=(text)
      set_post_prompt(text)
    end

    # ------------------------------------------------------------------
    # Remaining single-class config accessors on AgentBase. Same additive
    # pattern: `get_<name>` zero-arg readers become bare-noun
    # `alias_method`s; single-value `set_<name>` setters become `X=`
    # writers (block form so the writer yields the RHS, not self).
    # Multi-arg / keyword setters (e.g. #set_language_params) stay as
    # methods — a `=` writer takes exactly one value — and are not aliased.
    # ------------------------------------------------------------------

    def function_includes=(includes)
      set_function_includes(includes)
    end

    # Merge a Hash into the agent's `global_data`, the variable bag every prompt
    # and DataMap expression can reference. Writer form of {#set_global_data}.
    #
    # @param data [Hash]
    def global_data=(data)
      set_global_data(data)
    end

    # Merge internal-function filler phrases. Writer form of
    # {#set_internal_fillers} — see it for the supported function names.
    #
    # @param fillers [Hash{String => Hash{String => Array<String>}}]
    def internal_fillers=(fillers)
      set_internal_fillers(fillers)
    end

    # Replace the language list wholesale. Writer form of {#set_languages}.
    #
    # @param languages [Array<Hash>] language config hashes as built by {#add_language}
    def languages=(languages)
      set_languages(languages)
    end

    # Replace the list of native SWAIG function names advertised on the AI verb.
    # Writer form of {#set_native_functions}.
    #
    # @param names [Array<String>]
    def native_functions=(names)
      set_native_functions(names)
    end

    # Merge AI-verb params (keys stringified). Writer form of {#set_params}.
    #
    # @param params [Hash]
    def params=(params)
      set_params(params)
    end

    # Override the URL the platform POSTs the post-prompt summary to, instead of
    # the URL derived from the agent's base URL and route. Writer form of
    # {#set_post_prompt_url}.
    #
    # @param url [String]
    def post_prompt_url=(url)
      set_post_prompt_url(url)
    end

    # Set the prompt directly as a POM array, clearing raw-text mode and any
    # sections built with {#prompt_add_section}. Writer form of {#set_prompt_pom}.
    #
    # @param pom [Array<Hash>]
    def prompt_pom=(pom)
      set_prompt_pom(pom)
    end

    # Replace the pronunciation rule list wholesale. Writer form of
    # {#set_pronunciations}.
    #
    # @param pronunciations [Array<Hash>] rules as built by {#add_pronunciation}
    def pronunciations=(pronunciations)
      set_pronunciations(pronunciations)
    end

    # Override the URL the platform POSTs SWAIG function calls to, instead of the
    # URL derived from the agent's base URL and route. Writer form of
    # {#set_web_hook_url}.
    #
    # @param url [String]
    def web_hook_url=(url)
      set_web_hook_url(url)
    end

    # D9: additional bare-noun readers over the zero-/default-arg `get_<name>`
    # accessors (the get_ names stay as the deprecating aliases). Multi-arg
    # readers (#get_language_params(code)) are NOT aliased — a bare noun can't
    # carry an argument idiomatically. Defined as method wrappers (not `alias`)
    # because some targets (#get_app) are declared later in the class body and
    # `alias` binds at definition time.
    # (`name` is already a bare-noun reader inherited from SWML::Service's
    # attr_reader — get_name delegates to it — so it is NOT re-wrapped here.)
    def app
      get_app
    end

    # Single-value `set_<name>` config setter → `X=` writer.
    def multilingual=(config)
      set_multilingual(config)
    end

    # Predicate form of #has_skill? (idiomatic Ruby `?`-reader; takes the skill
    # name like the original).
    def skill?(skill_name)
      has_skill?(skill_name)
    end

    # Bare-noun readers over the kwarg-defaulted getters (the default path is
    # the common case; the get_ form remains for the explicit-flag call).
    def full_url(include_auth: false)
      get_full_url(include_auth: include_auth)
    end

    # The agent's basic-auth credentials. Bare-noun form of
    # {#get_basic_auth_credentials}.
    #
    # @param include_source [Boolean] also return where the credentials came from
    # @return [Array(String, String), Array(String, String, String)] `[user, pass]`,
    #   or `[user, pass, source]` when +include_source+ is true
    def basic_auth_credentials(include_source: false)
      get_basic_auth_credentials(include_source: include_source)
    end

    # Returns the contexts dictionary as a serialised hash, or nil when
    # no contexts have been defined yet.
    # @!visibility private  (idiomatic alias: #contexts; the original
    #   ``get_contexts`` name is kept for back-compat)
    def get_contexts
      return nil if @context_builder.nil?

      @context_builder.to_h
    end

    # ==================================================================
    # Tool methods
    # ==================================================================

    # Register a SWAIG tool (function) that the AI can invoke during a
    # call.
    #
    # == How this becomes a tool the model sees
    #
    # A SWAIG function is *exactly the same concept* as a "tool" in
    # native OpenAI / Anthropic tool calling. On every LLM turn, the
    # SDK renders each registered SWAIG function into the OpenAI tool
    # schema:
    #
    #     {
    #       "type": "function",
    #       "function": {
    #         "name":        "your_name_here",
    #         "description": "your description text",
    #         "parameters":  { ... your JSON schema ... }
    #       }
    #     }
    #
    # That schema is sent to the model as part of the same API call
    # that produces the next assistant message. The model reads:
    #
    #   - the function +description+ to decide WHEN to call this tool
    #   - each parameter +description+ (inside +parameters+) to decide
    #     HOW to fill in that argument from the user's utterance
    #
    # This means *descriptions are prompt engineering*, not developer
    # comments. A vague description is the #1 cause of "the model has
    # the right tool but doesn't call it" failures.
    #
    # == Bad vs good descriptions
    #
    #   BAD : description: "Lookup function"
    #   GOOD: description: "Look up a customer's account details by " \
    #                      "account number. Use this BEFORE quoting "  \
    #                      "any account-specific info (balance, plan, " \
    #                      "status). Do not use for general product "  \
    #                      "questions."
    #
    #   BAD : parameters: { id: { type: 'string', description: 'the id' } }
    #   GOOD: parameters: { account_number: { type: 'string',
    #             description: "The customer's 8-digit account " \
    #             "number, no dashes or spaces. Ask the user if they " \
    #             "don't provide it." } }
    #
    # == Tool count matters
    #
    # LLM tool selection accuracy degrades past ~7-8
    # simultaneously-active tools per call. Use
    # Contexts::Step#set_functions to partition tools across steps so
    # only the relevant subset is active at any moment.
    #
    # @param name [String] function name (snake_case verb recommended)
    # @param description [String] LLM-facing description of when to
    #   call this tool
    # @param parameters [Hash] JSON-Schema properties with LLM-facing
    #   descriptions for each parameter
    # @param secure [Boolean]
    # @param fillers [Hash, nil] language_code => [phrases]
    # @param swaig_fields [Hash, nil] extra fields merged into definition
    # @yield [args, raw_data] the tool handler
    # Define a SWAIG tool.
    #
    # @param name [String] tool name
    # @param description [String] LLM-facing description
    # @param parameters [Hash] JSON-Schema parameters
    # @param handler [Proc, nil] explicit handler (alternative to a
    #   block); kept for backward compat
    # @param secure [Boolean] require token validation. Defaults to
    #   ``true`` (fleet-wide, matching Python): a tool defined without an
    #   explicit ``secure:`` requires SWAIG token validation. Pass
    #   ``secure: false`` to opt a tool out.
    # @param fillers [Hash, nil] language-keyed filler phrases
    # @param wait_file [String, nil] URL of audio file to play while
    #   the tool runs server-side
    # @param wait_file_loops [Integer, nil] loop count for ``wait_file``
    # @param webhook_url [String, nil] external endpoint to use
    #   instead of dispatching to the local handler
    # @param required [Array<String>, nil] required parameter names
    # @param is_typed_handler [Boolean] handler accepts type-coerced
    #   keyword args (Ruby uses dynamic typing so this is a no-op at
    #   runtime but is accepted for signature compatibility)
    # @param swaig_fields [Hash, nil] additional fields merged into
    #   the SWAIG function definition
    # @yield [args, raw_data] tool handler body (takes precedence over an
    #   explicit ``handler:``, which must still be supplied — pass ``nil``)
    #
    # ``parameters:`` and ``handler:`` are REQUIRED, matching the reference
    # (``define_tool(name, description, parameters, handler, ...)``). They
    # previously defaulted to ``{}`` / ``nil``, so a call that named no
    # parameters and registered no handler was silently accepted here while every
    # other port rejected it. A tool with no parameters states ``parameters: {}``
    # explicitly; a block-bodied tool states ``handler: nil`` and passes the block.
    def define_tool(name:, description:, parameters:, handler:,
                    secure: true, fillers: nil,
                    wait_file: nil, wait_file_loops: nil,
                    webhook_url: nil, required: nil,
                    is_typed_handler: false,
                    swaig_fields: nil, &block)
      # Block is canonical — falls back to explicit handler kwarg.
      effective_handler = block || handler
      param_schema = build_tool_param_schema(parameters, required)
      tool_def = build_tool_definition(name, description, param_schema,
                                       fillers: fillers, wait_file: wait_file,
                                       wait_file_loops: wait_file_loops, webhook_url: webhook_url,
                                       is_typed_handler: is_typed_handler, swaig_fields: swaig_fields)

      @tools[name] = { definition: tool_def, handler: effective_handler, secure: secure }
      self
    end

    # Normalise parameters into JSON-Schema form and inject the caller's
    # `required:` list onto an object schema.
    def build_tool_param_schema(parameters, required)
      param_schema = normalise_parameters(parameters)
      if required.is_a?(Array) && !required.empty? && param_schema.is_a?(Hash) && param_schema['type'] == 'object'
        existing = param_schema['required'] || []
        param_schema['required'] = (existing + required).uniq
      end
      param_schema
    end

    # @api private — assemble the SWAIG function definition: the required
    # `function` / `description` / `parameters` triple, then the optional fields
    # that were supplied, then any caller-supplied `swaig_fields` merged over the
    # top (keys stringified).
    def build_tool_definition(name, description, param_schema, **opts)
      tool_def = { 'function' => name, 'description' => description, 'parameters' => param_schema }
      optional_tool_fields(opts).each { |k, v| tool_def[k] = v if v }
      swaig_fields = opts[:swaig_fields]
      swaig_fields.each { |k, v| tool_def[k.to_s] = v } if swaig_fields.is_a?(Hash)
      tool_def
    end

    # @api private — the optional SWAIG function-definition fields, keyed by their
    # wire names. A nil (or empty `fillers`) value means the caller did not set it
    # and the key is dropped by {#build_tool_definition}.
    def optional_tool_fields(opts)
      {
        'fillers' => (opts[:fillers] unless opts[:fillers].nil? || opts[:fillers].empty?),
        'wait_file' => opts[:wait_file],
        'wait_file_loops' => opts[:wait_file_loops],
        'webhook_url' => opts[:webhook_url],
        'is_typed_handler' => (true if opts[:is_typed_handler])
      }
    end

    # Register a raw SWAIG function definition (e.g. from DataMap#to_swaig_function).
    def register_swaig_function(func_def)
      fname = func_def['function'] || func_def[:function]
      return self unless fname

      @swaig_functions[fname] = func_def.transform_keys(&:to_s)
      self
    end

    # Return an array of all tool definitions (for SWML rendering).
    def define_tools
      defs = @tools.values.map { |t| t[:definition].dup }
      defs + @swaig_functions.values.map(&:dup)
    end

    # Mint a per-call SWAIG-function token via the agent's SessionManager.
    #
    # Delegates to SessionManager#create_token and returns "" on any
    # raised error.
    def create_tool_token(tool_name, call_id)
      @session_manager.create_token(tool_name, call_id)
    rescue StandardError
      ''
    end

    # Validate a per-call SWAIG-function token. Returns false when the
    # function is not registered, when the SessionManager rejects the
    # token, or on any underlying exception. Unknown function names are
    # rejected up-front.
    def validate_tool_token(function_name, token, call_id)
      return false unless has_function(function_name)

      @session_manager.validate_token(function_name, token, call_id)
    rescue StandardError
      false
    end

    # Dispatch a function call to the registered handler.
    #
    # `secure` enforcement does NOT live here — it lives in
    # {#swaig_validate_token}, invoked from {#swaig_pre_dispatch} before dispatch
    # ever reaches this method, so every transport shares one decision.
    def on_function_call(name, args, raw_data = nil)
      tool = @tools[name]
      return { 'response' => "Function '#{name}' not found" } unless tool

      coerce_function_result(name, tool[:handler].call(args, raw_data))
    rescue StandardError => e
      @logger.error "Tool '#{name}' error: #{e.message}"
      { 'response' => "Error executing '#{name}': #{e.message}" }
    end

    # The refusal a `secure` SWAIG tool returns when its `__token` is absent,
    # forged, or unvalidatable. A 200 + FunctionResult body, never an HTTP error
    # status: the engine has no handling for a SWAIG refusal status, so the tool
    # reports that it cannot execute and the model relays it.
    SECURE_REFUSAL_RESPONSE = 'I\'m sorry, the security token for this function is invalid ' \
                              'or expired. I cannot execute this action.'

    # Enforce `secure: true` for one SWAIG call, independent of transport.
    #
    # A tool registered with `secure: true` (define_tool's default) REQUIRES a
    # valid `__token`. An ABSENT token is refused exactly like a forged one --
    # omitting the credential must never be weaker than presenting a wrong one,
    # or `secure` would be a flag that permits anonymous calls. A token can only
    # be validated against a call_id, so a missing call_id is likewise treated as
    # unvalidated rather than as a bypass.
    #
    # Three nullable strings in, a nullable Hash out: no framework types, so the
    # HTTP handler and every serverless adapter share one decision.
    #
    # @param function_name [String] the SWAIG function being invoked
    # @param token [String, nil] the `__token` credential from the query string
    # @param call_id [String, nil] the call id from the POST body
    # @return [Hash, nil] nil to proceed, or the refusal body to return instead
    def swaig_validate_token(function_name, token, call_id)
      tool = @tools[function_name]
      return nil unless tool && tool[:secure]

      return nil if token && call_id && validate_tool_token(function_name, token, call_id)

      @logger.warn "secure_function_refused: function=#{function_name.inspect} token_present=#{!token.nil?}"
      SignalWire::Swaig::FunctionResult.new(SECURE_REFUSAL_RESPONSE).to_h
    end

    # Extension-point override: validate the per-call `__token` and apply
    # ephemeral dynamic config before POST /swaig dispatch.
    #
    # The credential rides the QUERY STRING (`__token`) and the call_id rides the
    # POST BODY (`call_id`) -- the same split on every transport, because the
    # serverless adapters translate their invocation event into the same Rack env
    # this hook reads.
    #
    # @return [Array(Object, Hash), Array(Object, nil)] `[target, short_circuit]`
    def swaig_pre_dispatch(request_data, func_name, env)
      call_id = swaig_call_id(request_data)
      refusal = swaig_validate_token(func_name, swaig_request_token(env), call_id)
      return [self, refusal] if refusal

      target = @dynamic_config_callback ? apply_dynamic_config(request_data, Rack::Request.new(env)) : self
      [target, nil]
    end

    # @api private — the `__token` credential from a Rack env's query string.
    # `token` is accepted as a legacy alias, matching the reference.
    def swaig_request_token(env)
      qs = env.is_a?(Hash) ? (env['QUERY_STRING'] || '') : ''
      params = URI.decode_www_form(qs).to_h
      t = params['__token'] || params['token']
      t unless t.nil? || t.empty?
    rescue StandardError
      nil
    end

    # @api private — the call id a SWAIG POST body carries, accepting both the
    # flat `call_id` and the nested `call.call_id` shape.
    def swaig_call_id(request_data)
      return nil unless request_data.is_a?(Hash)

      cid = request_data['call_id'] || request_data.dig('call', 'call_id')
      cid unless cid.nil? || cid.to_s.empty?
    end

    # Coerce a handler return into a wire Hash: Hash passes through, a
    # FunctionResult-like object is to_h'd, anything else is wrapped (with a
    # warning) — matching Python's web/serverless/tool mixin behaviour.
    def coerce_function_result(name, result)
      return result if result.is_a?(Hash)
      return result.to_h if !result.nil? && result.respond_to?(:to_h)

      warn_unexpected_function_result(name, result)
      { 'response' => result.to_s }
    end

    # @api private — warn that a SWAIG handler returned neither a Hash nor a
    # FunctionResult. The stringified value is still sent to the model as the
    # tool response, so this is a silent-degradation warning, not a failure.
    def warn_unexpected_function_result(name, result)
      @logger.warn(
        "unexpected_function_result_type: function=#{name.inspect} " \
        "result_type=#{result.class.name.inspect}. SWAIG function " \
        'returned a value that is neither a FunctionResult (responds ' \
        'to to_h) nor a Hash; falling back to wrapping the ' \
        'stringified value. The AI will see the stringified value as ' \
        'its tool response. Return a ' \
        'SignalWire::SWAIG::FunctionResult object or a Hash with at ' \
        "least a 'response' key."
      )
    end

    # ==================================================================
    # AI Config methods
    # ==================================================================

    def add_hint(hint)
      @hints << hint if hint.is_a?(String) && !hint.empty?
      self
    end

    # Add several speech-recognition hints at once. A non-Array is ignored; each
    # element goes through {#add_hint}, which drops non-String and empty entries.
    #
    # @param hints [Array<String>]
    # @return [self] for chaining
    def add_hints(hints)
      hints.each { |h| add_hint(h) } if hints.is_a?(Array)
      self
    end

    # Add a complex (pattern-matched) hint.
    #
    # ``hint``, ``pattern`` and ``replace`` are REQUIRED, matching the reference
    # (``add_pattern_hint(hint, pattern, replace, ignore_case=False)``). The
    # legacy ``add_pattern_hint(pattern, hint:, language:)`` overload was removed:
    # it had no reference counterpart AND emitted a different wire shape
    # (``{pattern, hint, language}`` instead of
    # ``{hint, pattern, replace, ignore_case}``), so it was port-invented surface
    # rather than an idiomatic spelling of the reference call.
    #
    # @param hint [String] hint to match
    # @param pattern [String] regex pattern
    # @param replace [String] replacement text
    # @param ignore_case [Boolean] match without regard to case
    def add_pattern_hint(hint, pattern, replace, ignore_case: false)
      @hints << { 'hint' => hint, 'pattern' => pattern,
                  'replace' => replace, 'ignore_case' => ignore_case }
      self
    end

    # Add a language configuration.
    #
    # ``name``, ``code`` and ``voice`` are REQUIRED, matching the reference
    # (``add_language(name, code, voice, ...)``). The preformed-hash shapes this
    # method used to also accept (``add_language(config_hash)`` and the braceless
    # ``add_language('name' => …, 'code' => …)``) had no reference counterpart —
    # the reference spells that capability #set_languages, which takes the list of
    # config hashes — so they were removed rather than kept as port-only surface.
    #
    # Voice argument can be either a simple voice id (``"en-US-Neural2-F"``)
    # or a combined ``"engine.voice:model"`` string
    # (``"elevenlabs.josh:eleven_turbo_v2_5"``); the combined form is
    # parsed into ``engine``/``voice``/``model`` keys when ``engine``
    # and ``model`` aren't supplied explicitly.
    #
    # @param name [String] language name (e.g. ``"English"``)
    # @param code [String] BCP47 language code (e.g. ``"en-US"``)
    # @param voice [String] voice id or ``engine.voice:model`` string
    # @param speech_fillers [Array<String>, nil] filler phrases for
    #   natural speech
    # @param function_fillers [Array<String>, nil] filler phrases
    #   during function calls
    # @param engine [String, nil] explicit engine override
    # @param model [String, nil] explicit model override
    # @param params [Hash, nil] optional per-language params (engine-
    #   specific tuning, voice settings, etc.). Emitted as the language
    #   object's ``params`` key in SWML; the key is only emitted when
    #   non-empty so existing entries stay byte-identical.
    def add_language(name, code, voice,
                     speech_fillers: nil, function_fillers: nil,
                     engine: nil, model: nil, params: nil)
      lang = { 'name' => name, 'code' => code }
      apply_language_voice(lang, voice, engine, model)
      apply_language_fillers(lang, speech_fillers, function_fillers)
      # Only emit params when non-empty so SWML isn't polluted with empty objects.
      lang['params'] = params if params.is_a?(Hash) && !params.empty?
      @languages << lang
      self
    end

    # Resolve the voice/engine/model triple onto `lang`. Explicit engine/model
    # win; otherwise an "engine.voice:model" string is split; else bare voice.
    def apply_language_voice(lang, voice, engine, model)
      if engine || model
        lang['voice']  = voice
        lang['engine'] = engine if engine
        lang['model']  = model  if model
      elsif compound_voice?(voice)
        apply_compound_voice(lang, voice)
      else
        lang['voice'] = voice
      end
    end

    # @api private — true when +voice+ is the combined `"engine.voice:model"`
    # form, which {#apply_compound_voice} splits into three keys.
    def compound_voice?(voice)
      voice.is_a?(String) && voice.include?('.') && voice.include?(':')
    end

    # Split an "engine.voice:model" string onto lang's voice/engine/model.
    def apply_compound_voice(lang, voice)
      engine_voice, model_part = voice.split(':', 2)
      engine_part, voice_part  = engine_voice.split('.', 2)
      lang['voice']  = voice_part
      lang['engine'] = engine_part
      lang['model']  = model_part
    end

    # @api private — attach filler phrases to a language entry. Both kinds present
    # emit the distinct `speech_fillers` / `function_fillers` keys; exactly one
    # present emits the combined `fillers` key the runtime also accepts.
    def apply_language_fillers(lang, speech_fillers, function_fillers)
      if speech_fillers && function_fillers
        lang['speech_fillers']   = speech_fillers
        lang['function_fillers'] = function_fillers
      elsif speech_fillers || function_fillers
        lang['fillers'] = speech_fillers || function_fillers
      end
    end

    # Set (or replace) the per-language ``params`` dict on an
    # already-added language. Useful when language entries are built up
    # via add_language first and engine-specific tuning is added later
    # (e.g. from a config loader). Returns self for chaining.
    #
    # @param code [String] language code as previously passed to
    #   ``add_language`` (e.g. ``"en-US"``).
    # @param params [Hash] engine-specific params hash to attach.
    #   Empty hash removes the key.
    # @return [self] No-op if the code isn't found.
    def set_language_params(code, params)
      @languages.each do |lang|
        next unless lang.is_a?(Hash) && lang['code'] == code

        if params.is_a?(Hash) && !params.empty?
          lang['params'] = params
        else
          lang.delete('params')
        end
        break
      end
      self
    end

    # Read the per-language ``params`` hash for a previously-added
    # language.
    #
    # @param code [String] language code as previously passed to ``add_language``.
    # @return [Hash, nil] the params hash if set, ``nil`` otherwise
    #   (including when the code is unknown).
    def get_language_params(code)
      @languages.each do |lang|
        return lang['params'] if lang.is_a?(Hash) && lang['code'] == code
      end
      nil
    end

    # Replace the language list wholesale, discarding anything added via
    # {#add_language}. A non-Array is ignored.
    #
    # @param languages [Array<Hash>] language config hashes
    # @return [self] for chaining
    def set_languages(languages)
      @languages = languages.dup if languages.is_a?(Array)
      self
    end

    # +language_code+ is accepted for Ruby back-compat but the current rule
    # shape doesn't carry it; the kwarg must stay because renaming to
    # _language_code would change the public kwarg name (hence the # ).
    # The +ignore_case+ key is only emitted when true; +language_code+ is
    # accepted for Ruby back-compat but is not part of the wire shape.
    def add_pronunciation(replace, with_text, ignore_case: false, language_code: 'en-US') # rubocop:disable Lint/UnusedMethodArgument
      return self unless replace && with_text

      rule = { 'replace' => replace, 'with' => with_text }
      rule['ignore_case'] = true if ignore_case
      @pronounce << rule
      self
    end

    # Replace the pronunciation rule list wholesale, discarding anything added via
    # {#add_pronunciation}. A non-Array is ignored.
    #
    # @param pronunciations [Array<Hash>] `{'replace', 'with', 'ignore_case'?}` rules
    # @return [self] for chaining
    def set_pronunciations(pronunciations)
      @pronounce = pronunciations.dup if pronunciations.is_a?(Array)
      self
    end

    # Set one AI-verb param. The key is stringified, so a Symbol and its String
    # spelling address the same param.
    #
    # @param key [String, Symbol]
    # @param value [Object]
    # @return [self] for chaining
    def set_param(key, value)
      @params[key.to_s] = value
      self
    end

    # Merge several AI-verb params at once (keys stringified). Merges rather than
    # replaces, so earlier params survive. A non-Hash is ignored.
    #
    # @param params [Hash]
    # @return [self] for chaining
    def set_params(params)
      params.each { |k, v| @params[k.to_s] = v } if params.is_a?(Hash)
      self
    end

    # Merge a Hash into `global_data`, the variable bag prompts and DataMap
    # expressions reference as `${global_data.*}`. Merges rather than replaces. A
    # non-Hash is ignored.
    #
    # @param data [Hash]
    # @return [self] for chaining
    def set_global_data(data)
      @global_data.merge!(data) if data.is_a?(Hash)
      self
    end

    # Alias for {#set_global_data} — merges into `global_data` rather than
    # replacing it, matching the name's "update" reading.
    #
    # @param data [Hash]
    # @return [self] for chaining
    def update_global_data(data)
      set_global_data(data)
    end

    # Replace the list of native SWAIG function names advertised to the runtime on
    # the AI verb's `SWAIG.native_functions`. A non-Array is ignored.
    #
    # @param names [Array<String>]
    # @return [self] for chaining
    def set_native_functions(names)
      @native_functions = names.dup if names.is_a?(Array)
      self
    end

    # The complete set of internal SWAIG function names that accept
    # fillers, matching the SWAIGInternalFiller schema definition.
    #
    # Any name outside this set is silently ignored by the runtime —
    # +set_internal_fillers+ and +add_internal_filler+ warn if you pass
    # an unknown name.
    #
    # Notable absences: +change_step+, +gather_submit+, or arbitrary
    # user-defined SWAIG function names are NOT supported.
    SUPPORTED_INTERNAL_FILLER_NAMES = %w[
      hangup
      check_time
      wait_for_user
      wait_seconds
      adjust_response_latency
      next_step
      change_context
      get_visual_input
      get_ideal_strategy
    ].freeze

    # Set internal fillers for native SWAIG functions.
    #
    # Internal fillers are short phrases the AI agent speaks (via TTS)
    # while an internal/native function is running, so the caller
    # doesn't hear dead air during transitions or background work.
    #
    # Supported function names (match the SWAIGInternalFiller schema):
    # +hangup+, +check_time+, +wait_for_user+, +wait_seconds+,
    # +adjust_response_latency+, +next_step+, +change_context+,
    # +get_visual_input+, +get_ideal_strategy+. See
    # SUPPORTED_INTERNAL_FILLER_NAMES.
    #
    # Notably NOT supported: +change_step+, +gather_submit+, or
    # arbitrary user-defined SWAIG function names. The runtime only
    # honors fillers for the names listed above; everything else is
    # silently ignored at the SWML level. This method warns at
    # registration time if you pass an unknown name so you catch the
    # typo early.
    #
    # Expected format: +{ function_name => { language_code => [phrases] } }+
    def set_internal_fillers(fillers)
      if fillers.is_a?(Hash)
        unknown = (fillers.keys.map(&:to_s) - SUPPORTED_INTERNAL_FILLER_NAMES).sort
        warn_unknown_filler_names(unknown) if unknown.any?
        @internal_fillers.merge!(fillers)
      end
      self
    end

    # @api private — warn that {#set_internal_fillers} was given names outside
    # SUPPORTED_INTERNAL_FILLER_NAMES. They are stored but the runtime will ignore
    # them, so the warning is the only signal of the typo.
    def warn_unknown_filler_names(unknown)
      @logger.warn(
        "unknown_internal_filler_names: #{unknown.inspect}. " \
        'set_internal_fillers received names that the SWML schema ' \
        'does not recognize. Those entries will be ignored by the ' \
        "runtime. Supported names: #{SUPPORTED_INTERNAL_FILLER_NAMES.sort.inspect}."
      )
    end

    # Add internal fillers for a single internal function and language.
    #
    # See +set_internal_fillers+ for the complete list of supported
    # +func_name+ values (SUPPORTED_INTERNAL_FILLER_NAMES) and what
    # fillers do. Names outside the supported set log a warning and are
    # stored but the runtime will not play them.
    def add_internal_filler(func_name, lang_code, fillers)
      if func_name && lang_code && fillers.is_a?(Array) && !fillers.empty?
        warn_unknown_filler_name(func_name) unless SUPPORTED_INTERNAL_FILLER_NAMES.include?(func_name.to_s)
        @internal_fillers[func_name] ||= {}
        @internal_fillers[func_name][lang_code] = fillers
      end
      self
    end

    # @api private — the single-name counterpart of {#warn_unknown_filler_names},
    # emitted by {#add_internal_filler}.
    def warn_unknown_filler_name(func_name)
      @logger.warn(
        "unknown_internal_filler_name: #{func_name.inspect}. " \
        'add_internal_filler received a function name the SWML ' \
        'schema does not recognize. The entry will be stored but ' \
        'the runtime will not play these fillers. Supported ' \
        "names: #{SUPPORTED_INTERNAL_FILLER_NAMES.sort.inspect}."
      )
    end

    # Enable debug events: the AI verb gains a `debug_webhook_url` pointing at
    # this agent's `/debug_events` route plus a `debug_webhook_level`, and the
    # runtime POSTs debug events there. Register a handler with {#on_debug_event}.
    #
    # @param level [Integer] verbosity, emitted as `params.debug_webhook_level`
    # @return [self] for chaining
    def enable_debug_events(level = 1)
      @debug_events_enabled = true
      @debug_events_level   = level
      self
    end

    # Include SWAIG functions hosted at another URL, so the model can call tools
    # this agent does not implement. Emitted in the AI verb's `SWAIG.includes`.
    #
    # @param url [String] the remote SWAIG endpoint
    # @param functions [Array<String>] the function names to import from it
    # @param meta_data [Hash, nil] optional metadata passed through to the remote endpoint
    # @return [self] for chaining
    def add_function_include(url, functions, meta_data: nil)
      include = { 'url' => url, 'functions' => functions }
      include['meta_data'] = meta_data if meta_data.is_a?(Hash)
      @function_includes << include
      self
    end

    # Replace the whole function-include list. Entries that are not a Hash with a
    # truthy `url` and a `functions` Array are DROPPED with a warning rather than
    # emitted — a malformed include would be silently ignored by the runtime.
    #
    # @param includes [Array<Hash>] `{'url', 'functions', 'meta_data'?}` entries
    # @return [self] for chaining
    def set_function_includes(includes)
      return self unless includes.is_a?(Array)

      valid, dropped = includes.partition { |inc| valid_function_include?(inc) }
      dropped.each { |inc| warn_dropped_function_include(inc) }
      @function_includes = valid
      self
    end

    # An include is valid when it is a Hash carrying a truthy +url+ and a
    # +functions+ array (mirrors TS setFunctionIncludes' per-entry filter).
    def valid_function_include?(inc)
      inc.is_a?(Hash) && inc['url'] && inc['functions'].is_a?(Array)
    end

    # @api private — warn that {#set_function_includes} dropped an entry that was
    # not a Hash with a `url` and a `functions` array.
    def warn_dropped_function_include(inc)
      @logger.warn(
        "invalid_function_include_dropped: #{inc.inspect}. " \
        'set_function_includes entries must be a Hash with a "url" ' \
        'and a "functions" array; this entry was dropped.'
      )
    end

    # Merge LLM tuning params (temperature, top_p, …) into the AI verb's `prompt`
    # object alongside the prompt text/POM. Keys are stringified.
    #
    # @param params [Hash] LLM parameters merged into the rendered `prompt` object
    # @return [self] for chaining
    def set_prompt_llm_params(**params)
      @prompt_llm_params.merge!(params.transform_keys(&:to_s))
      self
    end

    # Merge LLM tuning params into the AI verb's `post_prompt` object, letting the
    # summarization pass use different settings from the conversation itself.
    #
    # @param params [Hash] LLM parameters merged into the rendered `post_prompt` object
    # @return [self] for chaining
    def set_post_prompt_llm_params(**params)
      @post_prompt_llm_params.merge!(params.transform_keys(&:to_s))
      self
    end

    # ==================================================================
    # Verb management
    # ==================================================================

    def add_pre_answer_verb(verb_name, config)
      @pre_answer_verbs << [verb_name.to_s, config]
      self
    end

    # Drop every verb queued ahead of the `answer` verb.
    #
    # @return [self] for chaining
    def clear_pre_answer_verbs
      @pre_answer_verbs = []
      self
    end

    # Configure the SWML `answer` verb emitted when `auto_answer` is on. A nil or
    # empty config renders as a bare `{"answer": {}}`.
    #
    # @param config [Hash, nil] the answer verb's config object
    # @return [self] for chaining
    def add_answer_verb(config = nil)
      @answer_config = config
      self
    end

    # Queue a SWML verb to run after `answer` (and `record_call`) but before the
    # AI verb, in call order.
    #
    # @param verb_name [String, Symbol] the SWML verb name, stringified
    # @param config [Object] the verb's config value
    # @return [self] for chaining
    def add_post_answer_verb(verb_name, config)
      @post_answer_verbs << [verb_name.to_s, config]
      self
    end

    # Drop every verb queued between `answer` and the AI verb.
    #
    # @return [self] for chaining
    def clear_post_answer_verbs
      @post_answer_verbs = []
      self
    end

    # Queue a SWML verb to run after the AI verb returns — what the call does once
    # the agent is done.
    #
    # @param verb_name [String, Symbol] the SWML verb name, stringified
    # @param config [Object] the verb's config value
    # @return [self] for chaining
    def add_post_ai_verb(verb_name, config)
      @post_ai_verbs << [verb_name.to_s, config]
      self
    end

    # Drop every verb queued after the AI verb.
    #
    # @return [self] for chaining
    def clear_post_ai_verbs
      @post_ai_verbs = []
      self
    end

    # ==================================================================
    # Contexts
    # ==================================================================

    # Define / retrieve the ContextBuilder for this agent.
    #
    # ``define_contexts(contexts)`` accepts either a ``ContextBuilder`` or a
    # raw contexts Hash and stores it on the agent, and also supports the
    # lazy-getter idiom:
    #
    # 1. **Lazy getter** — ``agent.define_contexts`` returns the existing
    #    builder, creating one if needed.
    # 2. **Override with builder** — ``agent.define_contexts(other_cb)``
    #    replaces the current builder with the supplied one.
    # 3. **Override with hash** — ``agent.define_contexts({...})``
    #    builds a fresh builder using the provided contexts hash.
    #
    # @param contexts [SignalWire::Contexts::ContextBuilder, Hash, nil]
    #   optional override
    # @return [SignalWire::Contexts::ContextBuilder] the active builder
    # ``contexts`` is OPTIONAL here, matching the reference's AgentBase-facing
    # ``PromptMixin.define_contexts(contexts=None)`` — the no-argument call is the
    # documented "get or create the builder" shape. The reference's OTHER
    # ``define_contexts``, on PromptManager, does require it; Ruby's
    # PromptManager#define_contexts matches that separately.
    def define_contexts(contexts = nil)
      return (@context_builder = attach_context_builder(contexts)) if contexts.is_a?(Contexts::ContextBuilder)
      return (@context_builder = build_context_builder_from_hash(contexts)) if contexts.is_a?(Hash)

      raise ArgumentError, 'contexts must be a ContextBuilder, Hash, or nil' unless contexts.nil?

      # @context_builder is a genuine shared instance variable (assigned in the
      # branches above and read across the class: getters, render, reset), not a
      # per-method memo — its name must NOT track this method's name.
      # rubocop:disable Naming/MemoizedInstanceVariableName
      @context_builder ||= attach_context_builder(Contexts::ContextBuilder.new(self))
      # rubocop:enable Naming/MemoizedInstanceVariableName
    end

    # @api private — give a ContextBuilder a back-pointer to this agent so its
    # `validate!` can check step function whitelists and reserved tool names
    # against the agent's real tool registry. Returns the builder.
    def attach_context_builder(builder)
      builder.attach_agent(self) if builder.respond_to?(:attach_agent)
      builder
    end

    # Build a ContextBuilder from a raw contexts Hash.
    def build_context_builder_from_hash(contexts)
      cb = Contexts::ContextBuilder.new(self)
      contexts.each do |name, body|
        ctx = cb.add_context(name.to_s)
        steps = (body.is_a?(Hash) ? body['steps'] : nil) || []
        steps.each { |step_h| add_context_step(ctx, step_h) }
      end
      cb
    end

    # @api private — add one step from a raw contexts Hash to +ctx+, taking the
    # name from either the String or Symbol key.
    #
    # @raise [ArgumentError] if the step hash carries no name
    def add_context_step(ctx, step_h)
      step_name = step_h['name'] || step_h[:name] || raise(ArgumentError, 'step missing name')
      step = ctx.add_step(step_name)
      step.set_text(step_h['text']) if step_h['text']
    end

    alias contexts define_contexts

    # Remove all contexts, returning the agent to a no-contexts state.
    # This is a convenience wrapper around +define_contexts.reset+.
    # Use it in a dynamic config callback when you need to rebuild
    # contexts from scratch for a specific request.
    def reset_contexts
      @context_builder&.reset
      self
    end

    # Return the names of all registered SWAIG tools in insertion
    # order. Used by ContextBuilder#validate! to detect collisions with
    # reserved native tool names.
    def list_tool_names
      (@tools.keys + @swaig_functions.keys).uniq
    end

    # ==================================================================
    # Skill integration
    # ==================================================================

    # Load and register a skill by name.
    def add_skill(skill_name, params = nil)
      # Ensure builtins are registered
      Skills::SkillRegistry.register_builtins!

      factory = Skills::SkillRegistry.get_factory(skill_name)
      raise ArgumentError, "Unknown skill: '#{skill_name}'" unless factory

      # The default is `nil` to match the reference (`params: dict | None = None`),
      # but every registered factory is a block that INDEXES the params hash, so
      # the nil is normalised here rather than pushed onto each factory.
      skill = factory.call(params || {})
      @skill_manager.load(skill.instance_key, skill)
      @loaded_skills[skill_name] = skill

      register_skill_tools(skill)
      merge_skill_hints_and_data(skill)
      merge_skill_prompt_sections(skill)
      self
    end

    # @api private — register every tool a loaded skill declares via its
    # `register_tools`. A skill returning something other than an Array
    # contributes no tools.
    def register_skill_tools(skill)
      tool_defs = skill.register_tools
      return unless tool_defs.is_a?(Array)

      tool_defs.each { |td| define_skill_tool(td) }
    end

    # @api private — register one skill-declared tool. Entries missing a name or a
    # handler are skipped; the handler is passed as the block, so `define_tool`'s
    # required `handler:` slot is nil.
    def define_skill_tool(tool_def)
      td_name    = sym_or_str(tool_def, :name)
      td_handler = sym_or_str(tool_def, :handler)
      return unless td_name && td_handler

      # `handler:` is a required keyword; the skill's handler is passed as the
      # block, so the explicit slot is nil.
      define_tool(name: td_name, description: sym_or_str(tool_def, :description) || '',
                  parameters: sym_or_str(tool_def, :parameters) || {}, handler: nil, &td_handler)
    end

    # Read a key from a hash that may use symbol or string keys.
    def sym_or_str(hash, key)
      hash[key] || hash[key.to_s]
    end

    # @api private — fold a loaded skill's hints into the agent's hint list and
    # its global data into the agent's `global_data`.
    def merge_skill_hints_and_data(skill)
      skill_hints = skill.get_hints
      @hints.concat(skill_hints) if skill_hints.is_a?(Array) && !skill_hints.empty?

      skill_data = skill.get_global_data
      @global_data.merge!(skill_data) if skill_data.is_a?(Hash) && !skill_data.empty?
    end

    # @api private — append a loaded skill's prompt sections to the agent's POM,
    # switching out of raw-text mode so the sections actually render.
    def merge_skill_prompt_sections(skill)
      skill_sections = skill.get_prompt_sections
      return unless skill_sections.is_a?(Array) && !skill_sections.empty?

      @prompt_text = nil # switch to POM mode
      @prompt_pom  = nil
      skill_sections.each { |sec| @pom_sections << sec }
    end

    # Unload a previously added skill, removing it from the skill manager. Tools
    # and prompt sections the skill already contributed stay registered.
    #
    # @param skill_name [String] the name it was added under
    # @return [self] for chaining
    def remove_skill(skill_name)
      skill = @loaded_skills.delete(skill_name)
      @skill_manager.unload(skill.instance_key) if skill
      self
    end

    # The names of the skills currently loaded on this agent, in load order.
    #
    # @return [Array<String>]
    def list_skills
      @loaded_skills.keys
    end

    # Whether a skill is loaded under this name.
    #
    # @param skill_name [String]
    # @return [Boolean]
    def has_skill?(skill_name)
      @loaded_skills.key?(skill_name)
    end

    # ==================================================================
    # Web / HTTP configuration
    # ==================================================================

    # The callback is REQUIRED, matching the reference
    # (``set_dynamic_config_callback(self, callback)``); the block is the
    # idiomatic spelling of the same slot and passing neither raises.
    def set_dynamic_config_callback(callable, &block)
      callback = callable || block
      raise ArgumentError, 'set_dynamic_config_callback requires a callback (block or callable)' if callback.nil?

      @dynamic_config_callback = callback
      self
    end

    # Override the base URL used to build webhook URLs, for when the agent is
    # reached through a proxy or tunnel at a different address than it binds. Takes
    # precedence over the SWML_PROXY_URL_BASE environment variable.
    #
    # @param url [String] the externally-reachable base URL, e.g. "https://agent.example.com"
    # @return [self] for chaining
    def manual_set_proxy_url(url)
      @proxy_url_base = url
      self
    end

    # ------------------------------------------------------------------
    # Web / routing surface (Python WebMixin parity — item I). Several of
    # these delegate to the inherited SWMLService implementation; explicit
    # overrides make them part of AgentBase's own public surface (Python
    # composes them via mixins, so the reference records them on AgentBase).
    # ------------------------------------------------------------------

    # The Rack application for this agent (deployment adapters mount this).
    # Mirrors Python WebMixin.get_app (which returns the FastAPI app).
    def get_app
      rack_app
    end

    # A Rack-mountable router/app for this agent. Mirrors WebMixin.as_router
    # (Python returns a FastAPI APIRouter; Ruby returns the Rack app).
    def as_router
      rack_app
    end

    # NOTE: register_routing_callback / on_request / on_swml_request /
    # validate_basic_auth are inherited from SWMLService. The reference records
    # them on WebMixin/AuthMixin (which Python's AgentBase composes); the Ruby
    # surface enumerator projects them onto those mixins from the base
    # SWML::Service via SURFACE_METHOD_DONORS, so no useless super-only
    # override is defined here.

    # Install SIGTERM/SIGINT handlers for graceful shutdown (Kubernetes).
    # Mirrors WebMixin.setup_graceful_shutdown.
    def setup_graceful_shutdown
      %w[TERM INT].each do |sig|
        Signal.trap(sig) do
          @log&.info("shutdown_signal_received signal=#{sig}")
          stop
        end
      end
      self
    rescue ArgumentError
      # Some platforms/threads can't trap a given signal; ignore quietly.
      self
    end

    # Handle a serverless-environment request (CGI / Lambda / Cloud Functions).
    # Mirrors ServerlessMixin.handle_serverless_request — routes to the normal
    # run() entry point with the serverless event/context/mode.
    def handle_serverless_request(event: nil, context: nil, mode: nil)
      run(event: event, context: context, force_mode: mode)
    end

    # Configure ASR-driven multilingual mode (Mode B). Emits a top-level
    # ``multilingual`` object on the AI verb. Mirrors
    # AIConfigMixin.set_multilingual — mutually exclusive with set_languages.
    def set_multilingual(config)
      @multilingual_config = config
      self
    end

    # Override the URL the platform POSTs SWAIG function calls to, replacing the
    # URL derived from the agent's base URL and route. Rendered as the AI verb's
    # `SWAIG.defaults.web_hook_url`.
    #
    # @param url [String]
    # @return [self] for chaining
    def set_web_hook_url(url)
      @web_hook_url_override = url
      self
    end

    # Override the URL the platform POSTs the post-prompt summary to, replacing
    # the URL derived from the agent's base URL and route. Rendered as the AI
    # verb's `post_prompt_url`.
    #
    # @param url [String]
    # @return [self] for chaining
    def set_post_prompt_url(url)
      @post_prompt_url_override = url
      self
    end

    # Merge query parameters onto every rendered SWAIG webhook URL — how an agent
    # carries its own correlation data through the platform's callback.
    #
    # @param params [Hash] merged into the existing query params; a non-Hash is ignored
    # @return [self] for chaining
    def add_swaig_query_params(params)
      @swaig_query_params.merge!(params) if params.is_a?(Hash)
      self
    end

    # Drop every SWAIG webhook query parameter added via {#add_swaig_query_params}.
    #
    # @return [self] for chaining
    def clear_swaig_query_params
      @swaig_query_params = {}
      self
    end

    # Expose the agent's debug routes. Off by default — these routes reveal
    # internal agent state, so they are opt-in.
    #
    # @return [self] for chaining
    def enable_debug_routes
      @debug_routes_enabled = true
      self
    end

    # ==================================================================
    # SIP
    # ==================================================================

    def enable_sip_routing(auto_map: true, path: '/sip')
      @sip_routing_enabled = true
      @sip_auto_map        = auto_map
      @sip_path            = path

      # Python parity (AgentBase.enable_sip_routing): register a routing
      # callback at +path+ so the served +/sip+ endpoint actually CONSULTS the
      # SIP mapping. Previously the mapping was stored but never wired into
      # dispatch (a stored-but-unconsulted mapping). The callback extracts the
      # SIP username from the request body and returns nil (matched → this agent
      # handles the call so dispatch renders SWML; unmatched → routing
      # continues) — exactly Python's sip_routing_callback.
      register_routing_callback(nil, path) { |body, _headers| sip_routing_callback(body) }

      auto_map_sip_usernames if auto_map
      self
    end

    # @api private
    # SIP routing callback. Extracts the SIP username from the body and logs
    # whether it matched a registered username. Always returns nil: a matched
    # username is handled by this agent (dispatch renders SWML), an unmatched
    # one lets routing continue.
    def sip_routing_callback(body)
      username = self.class.extract_sip_username_from_request(body)
      return nil if username.nil?

      @logger&.info("sip_username_extracted: #{username}")
      matched = @sip_usernames.map(&:downcase).include?(username.downcase)
      @logger&.info("sip_username_#{matched ? 'matched' : 'not_matched'}: #{username}")
      nil
    end

    # Register a SIP username routed to this agent. The username is
    # lower-cased and stored with case-insensitive dedup, so
    # "Bob"/"BOB"/"bob" collapse to a single "bob" entry.
    def register_sip_username(username)
      normalized = username.to_s.downcase
      @sip_usernames << normalized unless @sip_usernames.include?(normalized)
      self
    end

    # Automatically register common SIP usernames based on this agent's
    # name and route.
    #
    # Derives SIP usernames from the agent name and route (lower-cased,
    # stripped to ``[a-z0-9_]``) plus a no-vowels variant of the name,
    # registering each via {#register_sip_username}. Duplicates are skipped.
    #
    # @return [self] for method chaining
    def auto_map_sip_usernames
      register = lambda do |candidate|
        register_sip_username(candidate) unless candidate.empty? || @sip_usernames.include?(candidate)
      end

      clean_name = sanitize_sip_username(name)
      register.call(clean_name) unless clean_name.empty?

      clean_route = sanitize_sip_username(route)
      register.call(clean_route) if !clean_route.empty? && clean_route != clean_name

      register_no_vowels_variation(clean_name, register)
      self
    end

    # @api private — reduce a name or route to a legal SIP username by
    # lower-casing and stripping everything outside `[a-z0-9_]`.
    def sanitize_sip_username(value)
      value.to_s.downcase.gsub(/[^a-z0-9_]/, '')
    end

    # Register a no-vowels variation when the name is long enough.
    def register_no_vowels_variation(clean_name, register)
      return unless clean_name.length > 3

      no_vowels = clean_name.gsub(/[aeiou]/, '')
      register.call(no_vowels) if no_vowels != clean_name && no_vowels.length > 2
    end

    # Extract a SIP username from a SIP URI string.
    #
    # Parses URIs of the form "sip:user@domain" and returns the user part.
    # Handles optional "sip:" or "sips:" scheme prefixes.
    #
    # @param sip_uri [String] a SIP URI, e.g. "sip:alice@example.com"
    # @return [String, nil] the username, or nil if the URI cannot be parsed
    def self.extract_sip_username(sip_uri)
      return nil if sip_uri.nil? || sip_uri.empty?

      # Strip optional sip:/sips: scheme
      uri = sip_uri.to_s.strip
      uri = uri.sub(/\Asips?:/, '')

      # Extract user part before @
      return unless uri.include?('@')

      user = uri.split('@', 2).first
      user && !user.empty? ? user : nil
    end

    # Extract the SIP username from request body data.
    #
    # Looks for SIP URI in common request body fields
    # (e.g., "to", "from", "sip_uri", "call.to", "call.from").
    #
    # @param request_data [Hash] the parsed request body
    # @return [String, nil] the extracted SIP username, or nil
    def self.extract_sip_username_from_request(request_data)
      return nil unless request_data.is_a?(Hash)

      # Check common SIP URI fields.
      candidates = [request_data['to'], request_data['from'], request_data['sip_uri'],
                    request_data.dig('call', 'to'), request_data.dig('call', 'from')].compact
      candidates.each do |uri|
        username = extract_sip_username(uri.to_s)
        return username if username
      end
      nil
    end

    # ==================================================================
    # MCP integration
    # ==================================================================

    # Add an external MCP server for tool discovery and invocation.
    #
    # @param url [String] MCP server HTTP endpoint URL
    # @param headers [Hash, nil] optional HTTP headers
    # @param resources [Boolean] whether to fetch resources into global_data
    # @param resource_vars [Hash, nil] variables for URI template substitution
    # @return [self]
    def add_mcp_server(url, headers: nil, resources: false, resource_vars: nil)
      server = { 'url' => url }
      server['headers']       = headers       if headers && !headers.empty?
      server['resources']     = true          if resources
      server['resource_vars'] = resource_vars if resource_vars && !resource_vars.empty?
      @mcp_servers << server
      self
    end

    # Expose this agent's tools as an MCP server endpoint at /mcp.
    #
    # @return [self]
    def enable_mcp_server
      @mcp_server_enabled = true
      self
    end

    # @api private
    # Build MCP tool list from registered tools.
    def _build_mcp_tool_list
      @tools.map { |name, tool| mcp_tool_entry(name, tool) }
    end

    # @api private — one MCP `tools/list` entry for a registered SWAIG tool: its
    # name, its description (falling back to the name), and its JSON-Schema
    # `inputSchema`.
    def mcp_tool_entry(name, tool)
      params = tool[:definition]['parameters']
      {
        'name' => name,
        'description' => tool[:definition]['description'] || name,
        'inputSchema' => mcp_input_schema(params)
      }
    end

    # @api private — normalise a tool's `parameters` into an MCP `inputSchema`. An
    # absent/empty schema becomes an empty object schema; a bare property map is
    # wrapped as `{type: object, properties: …}`; a schema that already declares
    # `type` passes through.
    def mcp_input_schema(params)
      return { 'type' => 'object', 'properties' => {} } if params.nil? || params.empty?

      params.key?('type') ? params : { 'type' => 'object', 'properties' => params }
    end

    # @api private
    # Handle a single MCP JSON-RPC 2.0 request and return the response hash.
    def _handle_mcp_request(body)
      method  = body['method'] || ''
      req_id  = body['id']
      params  = body['params'] || {}

      return mcp_error(req_id, -32_600, 'Invalid JSON-RPC version') unless body['jsonrpc'] == '2.0'

      # Each branch is a distinct JSON-RPC method; the no-op ack arms
      # (notifications/initialized, ping) share an empty-result body but stay
      # documented by name in mcp_empty_result_method?.
      case method
      when 'initialize'   then mcp_initialize_response(req_id)
      when 'tools/list'   then mcp_result(req_id, { 'tools' => _build_mcp_tool_list })
      when 'tools/call'   then mcp_tools_call(req_id, params)
      else mcp_default_response(method, req_id)
      end
    end

    # @api private — the response for a JSON-RPC method not handled by name: an
    # empty result for the acknowledged no-ops, else JSON-RPC -32601 Method not found.
    def mcp_default_response(method, req_id)
      return mcp_result(req_id, {}) if mcp_empty_result_method?(method)

      mcp_error(req_id, -32_601, "Method not found: #{method}")
    end

    # @api private — true for the MCP methods that are acknowledged with an empty
    # result and no work: `notifications/initialized` and `ping`.
    def mcp_empty_result_method?(method)
      %w[notifications/initialized ping].include?(method)
    end

    # @api private — wrap +result+ in a JSON-RPC 2.0 success envelope for +req_id+.
    def mcp_result(req_id, result)
      { 'jsonrpc' => '2.0', 'id' => req_id, 'result' => result }
    end

    # @api private — the MCP `initialize` reply: protocol version 2025-06-18, the
    # `tools` capability, and this agent's name as the server name.
    def mcp_initialize_response(req_id)
      {
        'jsonrpc' => '2.0', 'id' => req_id,
        'result' => {
          'protocolVersion' => '2025-06-18',
          'capabilities' => { 'tools' => {} },
          'serverInfo' => { 'name' => name, 'version' => '1.0.0' }
        }
      }
    end

    # @api private — execute an MCP `tools/call`. An unregistered tool name is
    # JSON-RPC -32602; a raising handler is reported as an MCP tool result with
    # `isError` true rather than a JSON-RPC error, which is what the MCP spec asks
    # for so the model can see and recover from the failure.
    def mcp_tools_call(req_id, params)
      tool_name = params['name'] || ''
      arguments = params['arguments'] || {}
      tool = @tools[tool_name]
      return mcp_error(req_id, -32_602, "Unknown tool: #{tool_name}") unless tool

      raw_data = { 'function' => tool_name, 'argument' => { 'parsed' => [arguments] } }
      result = tool[:handler].call(arguments, raw_data)
      mcp_tool_result(req_id, mcp_response_text(result), is_error: false)
    rescue StandardError => e
      @logger.error "MCP tool call error: #{tool_name}: #{e.message}"
      mcp_tool_result(req_id, "Error: #{e.message}", is_error: true)
    end

    # @api private — extract the text an MCP client should see from a SWAIG
    # handler's return: a FunctionResult's or Hash's `response`, a bare String as
    # itself, anything else as empty.
    def mcp_response_text(result)
      return result.to_h['response'] || '' if result.respond_to?(:to_h)
      return result['response'] || result.to_s if result.is_a?(Hash)
      return result if result.is_a?(String)

      ''
    end

    # @api private — wrap +text+ in the MCP `tools/call` result shape: a
    # single-element `content` array plus the `isError` flag.
    def mcp_tool_result(req_id, text, is_error:)
      {
        'jsonrpc' => '2.0', 'id' => req_id,
        'result' => {
          'content' => [{ 'type' => 'text', 'text' => text }],
          'isError' => is_error
        }
      }
    end

    # @api private
    def mcp_error(req_id, code, message)
      {
        'jsonrpc' => '2.0',
        'id' => req_id,
        'error' => { 'code' => code, 'message' => message }
      }
    end

    # ==================================================================
    # Lifecycle
    # ==================================================================

    # A virtual hook called when a post-prompt summary is received.
    # Two equivalent shapes are supported:
    #
    # 1. **Registration** — pass a block to install a callback. The block
    #    receives ``(summary, raw_data)`` when a summary is delivered.
    #    ``on_summary(nil) { |sum, raw| ... }``
    # 2. **Override** — subclass and override
    #    ``on_summary(summary, raw_data = nil)``. Default implementation
    #    calls the registered block (if any) and otherwise no-ops.
    #
    # ``summary`` is REQUIRED, matching the reference
    # (``on_summary(self, summary: PostPromptData | None, raw_data=None)``): the
    # slot is nullABLE, not omittABLE, so a caller states `nil` explicitly rather
    # than relying on a port-invented default the other nine ports do not have.
    #
    # @param summary [Hash, nil] the post-prompt summary
    # @param raw_data [Hash, nil] the complete raw POST data
    # @yield [summary, raw_data] optional callback registration
    def on_summary(summary, raw_data = nil, &block)
      if block
        @summary_callback = block
        return self
      end

      @summary_callback&.call(summary, raw_data)
      nil
    end

    # Register the debug-event handler. REQUIRED, matching the reference
    # (``on_debug_event(self, handler)``); the block is the idiomatic spelling of
    # the same slot and passing neither raises.
    def on_debug_event(handler, &block)
      callback = block || handler
      raise ArgumentError, 'on_debug_event requires a handler (block or callable)' if callback.nil?

      @debug_event_callback = callback
      self
    end

    # Universal run method — mirrors Python's
    # ``WebMixin.run(event=None, context=None, force_mode=None,
    # host=None, port=None)``.
    #
    # Detects execution mode (server / lambda / cgi) and routes
    # accordingly. ``force_mode`` overrides auto-detection.
    #
    # @param event [Object, nil] serverless event
    # @param context [Object, nil] serverless context
    # @param force_mode [String, nil] one of ``"server"``, ``"lambda"``,
    #   ``"cgi"``
    # @param host [String, nil] override bind host (server mode)
    # @param port [Integer, nil] override bind port (server mode)
    def run(event: nil, context: nil, force_mode: nil, host: nil, port: nil)
      mode = force_mode || _detect_run_mode
      handler = SERVERLESS_DISPATCH[mode]
      return handler.call(self, event, context) if handler

      # In :server mode this calls serve, which honors the SIGNALWIRE_SUPPRESS_RUN
      # guard (ruby_R5 N1) — so tooling loading an example ending in a bare
      # `agent.run` gets a no-op instead of a blocking WEBrick boot, while a
      # serverless-simulation dispatch above still runs.
      serve(host: host, port: port)
    end

    # Serverless run-mode dispatch table: mode string → a lambda that invokes
    # the matching per-platform handler. A mode absent here falls through to
    # serve() (the long-running HTTP server).
    SERVERLESS_DISPATCH = {
      'lambda' => ->(a, event, context) { a._run_lambda(event, context) },
      'cgi' => ->(a, _event, _context) { a._run_cgi },
      'google_cloud_function' => ->(a, event, _context) { a._run_gcf(event) },
      'gcf' => ->(a, event, _context) { a._run_gcf(event) },
      'azure_function' => ->(a, event, _context) { a._run_azure(event) },
      'azure' => ->(a, event, _context) { a._run_azure(event) }
    }.freeze

    # @api private
    # Detect the serverless execution mode via the canonical
    # {SignalWire::Runtime.execution_mode} detector (cgi / lambda /
    # google_cloud_function / azure_function / server), returning the string
    # form used by +run+.
    def _detect_run_mode
      SignalWire::Runtime.execution_mode.to_s
    end

    # @api private
    # Dispatch a Lambda invocation through the full RequestTranslation env
    # builder so the request HEADERS (Authorization, Content-Type, …) and the
    # base64/body handling reach the Rack app — a hand-rolled env that dropped
    # headers made every authenticated serverless request 401.
    def _run_lambda(event, context)
      require_relative '../serverless/lambda_handler'
      SignalWire::Serverless::LambdaHandler.for(self).call(event, context)
    end

    # @api private
    # Handle a Google Cloud Functions / Cloud Run invocation. GCF hands the
    # function an HTTP-request-shaped object; we accept either a Hash
    # (+{ 'method', 'path', 'query', 'body', 'headers' }+ — the framework-free
    # idiom) or a Rack-request-like object, translate it into a Rack env,
    # and return a +{ 'status', 'headers', 'body' }+ response.
    def _run_gcf(request)
      run_http_serverless(request)
    end

    # @api private
    # Handle an Azure Functions invocation. Azure passes an HTTP request
    # object/dict (method / url / headers / body); translate to a Rack env and
    # return a +{ 'status', 'headers', 'body' }+ response.
    def _run_azure(request)
      run_http_serverless(request)
    end

    # @api private
    # Shared GCF/Azure request pump: normalise the HTTP-request-shaped input
    # into a Rack env, invoke the app, and return a +{status,headers,body}+
    # response hash.
    def run_http_serverless(request)
      require 'stringio'
      method, path, query, body, headers = extract_http_request(request)
      env = rack_env(path: path, method: method, query: query, body: body)
      apply_env_headers(env, headers)
      status, resp_headers, resp_body = rack_app.call(env)
      { 'status' => Integer(status), 'headers' => resp_headers, 'body' => join_rack_body(resp_body) }
    end

    # @api private
    # Normalise a serverless HTTP request (Hash with string/symbol keys, or a
    # Rack-request-like object) into +[method, path, query, body, headers]+.
    # For Azure, a full +url+ is split into path + query string.
    def extract_http_request(request)
      req = request || {}
      method = (req_field(req, :method, :request_method, :httpMethod) || 'GET').to_s.upcase
      path, query = extract_path_and_query(req)
      [method, path, query, (req_field(req, :body) || '').to_s, req_field(req, :headers) || {}]
    end

    # Resolve [path, query] from a request: the target may be a bare path or a
    # full URL (Azure); the query may come from a dedicated field or the URL.
    def extract_path_and_query(req)
      path, url_query = split_url_path((req_field(req, :path, :url, :rawPath, :request_uri) || '/').to_s)
      query = (req_field(req, :query, :query_string, :rawQueryString) || url_query || '').to_s
      [path, query]
    end

    # Split a request target into [path, query]. Accepts a bare path
    # ("/health?x=1") or a full URL ("https://host/health?x=1", as Azure sends)
    # and returns just the path component + query string.
    def split_url_path(raw)
      if raw.include?('://')
        require 'uri'
        parsed = URI.parse(raw)
        [parsed.path.empty? ? '/' : parsed.path, parsed.query]
      else
        raw.split('?', 2)
      end
    rescue URI::InvalidURIError
      raw.split('?', 2)
    end

    # Look up the first present key (string or symbol) from a Hash, or call the
    # first matching reader on a request-like object.
    def req_field(req, *names)
      if req.is_a?(Hash)
        names.each do |n|
          return req[n.to_s] if req.key?(n.to_s)
          return req[n] if req.key?(n)
        end
      else
        names.each { |n| return req.public_send(n) if req.respond_to?(n) }
      end
      nil
    end

    # Rack env keys for headers Rack expects unprefixed (not HTTP_*).
    UNPREFIXED_HEADER_ENV = {
      'content-type' => 'CONTENT_TYPE', 'content-length' => 'CONTENT_LENGTH'
    }.freeze

    # Merge request headers (a Hash) into a Rack env as HTTP_* keys, pulling out
    # CONTENT_TYPE / CONTENT_LENGTH which Rack expects unprefixed.
    def apply_env_headers(env, headers)
      return unless headers.is_a?(Hash)

      headers.each do |name, value|
        key = name.to_s.downcase
        env_key = UNPREFIXED_HEADER_ENV[key] || "HTTP_#{key.tr('-', '_').upcase}"
        env[env_key] = value.to_s
      end
    end

    # Build a minimal Rack env hash for serverless/CGI invocation. Includes the
    # keys Rack::URLMap (used by the mounted rack_app) requires — notably
    # SCRIPT_NAME, which it string-concatenates, and SERVER_NAME/PORT +
    # rack.url_scheme for URL construction.
    # Static Rack env keys that don't depend on the request (Rack::URLMap needs
    # SCRIPT_NAME; SERVER_* + rack.url_scheme drive URL construction).
    STATIC_RACK_ENV = {
      'SCRIPT_NAME' => '', 'SERVER_NAME' => 'serverless', 'SERVER_PORT' => '443',
      'SERVER_PROTOCOL' => 'HTTP/1.1', 'rack.url_scheme' => 'https'
    }.freeze

    # @api private — build the minimal Rack env for a serverless invocation:
    # STATIC_RACK_ENV plus the request's path, method, query string and body. The
    # body is wrapped in a StringIO because Rack requires `rack.input` to be readable.
    def rack_env(path:, method:, query:, body:)
      STATIC_RACK_ENV.merge(
        'PATH_INFO' => path, 'REQUEST_METHOD' => method, 'QUERY_STRING' => query,
        'rack.input' => StringIO.new(body), 'rack.errors' => $stderr
      )
    end

    # @api private — collapse a Rack body (an Array of strings, or any object
    # responding to `join`) into a single String for the serverless response.
    def join_rack_body(body)
      body.respond_to?(:join) ? body.join : body.to_s
    end

    # @api private
    def _run_cgi
      require 'stringio'
      env = rack_env(path: ENV['PATH_INFO'] || '/', method: ENV['REQUEST_METHOD'] || 'GET',
                     query: ENV['QUERY_STRING'] || '', body: '')
      status, headers, body = rack_app.call(env)
      out = "Status: #{status}\r\n"
      headers.each { |k, v| out << "#{k}: #{v}\r\n" }
      out << "\r\n"
      out << join_rack_body(body)
      out
    end

    # Start the HTTP server (blocking).
    #
    # ``host`` / ``port`` overrides default to the constructor-supplied
    # values.
    def serve(host: nil, port: nil)
      # Suppress-run guard (ruby_R5 N1): tooling loading an example whose last
      # line calls serve must not block on a booted WEBrick server.
      return nil if SignalWire::Runtime.suppress_run?

      require 'webrick'
      bind_host = host || @host
      bind_port = port || @port
      log_server_startup(bind_host, bind_port)

      @server = ::WEBrick::HTTPServer.new(**webrick_opts(bind_host, bind_port))
      @server.mount '/', webrick_handler, rack_app
      trap('INT')  { @server.shutdown }
      trap('TERM') { @server.shutdown }
      @server.start
    end

    # @api private — log the bind address and the basic-auth USERNAME at startup.
    # The password is deliberately printed as `[REDACTED]` — it is often
    # auto-generated and the log is not a safe place for it.
    def log_server_startup(bind_host, bind_port)
      @logger.info "Starting server on #{bind_host}:#{bind_port} ..."
      user, _pass = @basic_auth
      @logger.info "Basic-auth credentials — user: #{user}  password: [REDACTED]"
    end

    # @api private — the WEBrick options for {#serve}: bind host/port, a WARN-level
    # logger, access logging off, plus TLS when SSL is configured (SWML_SSL_* or
    # the config file). A no-op SSL config leaves this plain HTTP.
    def webrick_opts(bind_host, bind_port)
      opts = {
        Host: bind_host,
        Port: bind_port,
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        AccessLog: []
      }
      # WebMixin parity: serve HTTPS when SSL is configured (via the SWML_SSL_*
      # env vars read in SWMLService#initialize, or a config file). Shares the
      # helper with SWMLService#serve. No-op when SSL is off → plain HTTP.
      _apply_webrick_ssl!(opts)
      opts
    end

    # Rack 3+ moved Handler to the rackup gem; fall back to the rack gem.
    def webrick_handler
      require 'rackup/handler/webrick'
      Rackup::Handler::WEBrick
    rescue LoadError
      require 'rack/handler/webrick'
      Rack::Handler::WEBrick
    end

    # Return a Rack-compatible application for mounting.
    def rack_app
      return @rack_app if defined?(@rack_app)

      @rack_app = build_rack_app
    end

    alias as_rack_app rack_app

    # ==================================================================
    # SWML Rendering
    # ==================================================================

    # Build the complete SWML document hash.
    #
    # @param request_data [Hash, nil] parsed request body
    # @param request [Rack::Request, nil] the HTTP request
    # @return [Hash]
    def render_swml(request_data = nil, request: nil)
      # Dynamic config: clone into an ephemeral copy and run the callback.
      agent = @dynamic_config_callback ? apply_dynamic_config(request_data, request) : self
      agent._render_swml_internal
    end

    # Framework-free request-dispatch core for AgentBase — overrides
    # {SWMLService#handle_request} so the primitive dispatch surface renders SWML
    # via the agent's {#render_swml} (mirroring the Rack +handle_main_request+
    # path) instead of the base +render_document+. Performs proxy detection,
    # basic-auth, the routing-callback check, and the +on_swml_request+
    # modification hook over plain primitives, returning a
    # +[status, headers, body_string]+ triple with the 401-auth and 307-redirect
    # behavior preserved.
    #
    # @param method [String] HTTP method, e.g. "GET" / "POST".
    # @param url [String] the full request URL.
    # @param headers [Hash{String=>String}] request headers as a plain Hash.
    # @param body [Hash, nil] the already-parsed JSON body for POST, or nil.
    # @param request [Rack::Request, nil] the live Rack request when dispatched
    #   from the served path, so dynamic config sees the request's query string
    #   and headers; nil for the framework-free primitive path.
    # @param skip_auth [Boolean] true when the served-path middleware already
    #   validated basic auth (avoids a redundant re-check; the 307/render
    #   decision still flows through here).
    # @return [Array(Integer, Hash{String=>String}, String)]
    def handle_request(method, url, headers, body = nil, request: nil, skip_auth: false)
      body ||= {}
      callback_path = callback_path_for_url(url)

      detect_proxy_from_primitives(url, headers)
      return unauthorized_triple unless skip_auth || check_basic_auth_headers(headers)

      redirect = routing_redirect(method, body, headers, callback_path)
      return redirect if redirect

      agent_render_triple(body, callback_path, request:)
    end

    # 200 triple rendering agent SWML with any on_swml_request modifications
    # shallow-merged in. Split out of {#handle_request} for clarity.
    def agent_render_triple(body, callback_path, request: nil)
      modifications = agent_on_swml_request(body, callback_path, request)
      swml = render_swml(body, request:)
      swml = swml.merge(modifications) if modifications.is_a?(Hash)
      [200, {}, JSON.generate(swml)]
    end

    # Call +on_swml_request+ (a raising modifier does not 500 the
    # request), returning its modifications or nil. +request+ is the live Rack
    # request on the served path, or nil for the framework-free primitive path.
    def agent_on_swml_request(body, callback_path, request = nil)
      on_swml_request(body, callback_path, request:)
    rescue StandardError => e
      @log&.error("error_in_request_modifier: #{e.message}")
      nil
    end

    # @api private — run the dynamic-config callback against an ephemeral copy of
    # the agent, so per-request mutations never touch the shared agent. The
    # callback receives the query params, the parsed body, the request headers and
    # the copy. A raising callback is logged and the (partially configured) copy is
    # still returned, so one bad callback does not 500 the request.
    def apply_dynamic_config(request_data, request)
      agent = create_ephemeral_copy
      query_params = request ? parse_query_string(request) : {}
      body_params  = request_data || {}
      headers      = request ? extract_headers(request) : {}
      @dynamic_config_callback.call(query_params, body_params, headers, agent)
      agent
    rescue StandardError => e
      @logger.error "Dynamic config error: #{e.message}"
      agent
    end

    # @api private
    #
    # +call_id+ (optional) is the active call's id. When present, each SECURE
    # tool's rendered SWAIG webhook carries a per-tool ``__token`` (minted via
    # the SessionManager) so the platform can validate the callback — the wire
    # manifestation of ``secure`` (mirrors python agent_base.py:1040/1096-1100).
    def _render_swml_internal(call_id: nil)
      @render_call_id = call_id
      { 'version' => '1.0.0', 'sections' => { 'main' => build_main_section } }
    ensure
      @render_call_id = nil
    end

    # Assemble the ordered SWML "main" section entries.
    #
    # The reference routes every one of these through the validating
    # ``SWMLService.add_verb`` (python core/agent_base.py:1194-1216, 1367-1418).
    # This assembly builds the section directly, so each entry is put through
    # the same schema validation here — otherwise the caller-supplied configs
    # of #add_pre_answer_verb / #add_post_answer_verb / #add_post_ai_verb reach
    # the wire completely unchecked.
    def build_main_section
      sections_main = []
      sections_main.concat(verb_entries(@pre_answer_verbs)) # PHASE 1: pre-answer verbs
      sections_main << answer_entry if auto_answer           # PHASE 2: answer verb
      sections_main << record_call_entry if record_call      # PHASE 3a: record_call
      sections_main.concat(verb_entries(@post_answer_verbs)) # PHASE 3b: post-answer verbs
      sections_main << { 'ai' => build_ai_config } # PHASE 4: AI verb
      sections_main.concat(verb_entries(@post_ai_verbs)) # PHASE 5: post-AI verbs
      sections_main.each { |entry| validate_section_entry(entry) }
    end

    # Validate one assembled {verb_name => config} entry against the SWML
    # schema, exactly as Service#add_verb would. Raises SchemaValidationError
    # on an invalid config; a bare Integer +sleep+ is a valid direct value and
    # is passed through, matching Service#add_verb's sleep handling.
    #
    # Private: this is internal render plumbing, not agent-author surface. A
    # subclass that rewrites the rendered document (BedrockAgent) reaches it via
    # __send__ to re-validate what it substitutes.
    #
    # The `ai` verb is EXEMPT for now. The bundled schema's AIObject declares
    # nine properties and is closed; the engine accepts fifteen
    # (agent, prompt, post_prompt, engine, voice, post_prompt_url,
    # post_prompt_auth_user, post_prompt_auth_password, languages, multilingual,
    # pronounce, global_data, SWAIG, params, hints). The bundled copy is a
    # strict subset with no extras, so validating `ai` against it would reject
    # six keys the platform accepts — `multilingual` among them, which this SDK
    # emits. Re-enable once the schema is regenerated from the engine.
    def validate_section_entry(entry)
      verb_name, config = entry.first
      return entry if verb_name == 'sleep' && config.is_a?(Integer)
      return entry if verb_name == 'ai'

      __send__(:verb_config_valid!, verb_name, config)
      entry
    end
    private :validate_section_entry

    # Map a [[verb_name, config], ...] list into [{verb_name => config}, ...].
    def verb_entries(verbs)
      verbs.map { |verb_name, config| { verb_name => config } }
    end

    # @api private — the SWML `answer` verb entry. An unset answer config renders
    # as an empty object rather than being omitted.
    def answer_entry
      { 'answer' => @answer_config.empty? ? {} : @answer_config }
    end

    # @api private — the SWML `record_call` verb entry, carrying the constructor's
    # `record_format` and `record_stereo`.
    def record_call_entry
      { 'record_call' => { 'format' => record_format, 'stereo' => record_stereo } }
    end

    # Get the configured basic-auth credentials.
    #
    # When ``include_source`` is true, returns a 3-tuple ``[user,
    # pass, source]`` (``"environment"`` / ``"auto-generated"`` /
    # ``"provided"``). Otherwise returns ``[user, pass]``.
    def get_basic_auth_credentials(include_source: false)
      user, pass = @basic_auth
      return [user, pass] unless include_source

      [user, pass, basic_auth_source(user, pass)]
    end

    # Classify where the active basic-auth credentials came from.
    def basic_auth_source(user, pass)
      env_user = ENV.fetch('SWML_BASIC_AUTH_USER', nil)
      env_pass = ENV.fetch('SWML_BASIC_AUTH_PASSWORD', nil)
      return 'environment' if matches_env_auth?(user, pass, env_user, env_pass)
      return 'auto-generated' if user&.start_with?('user_') && pass && pass.length > 20

      'provided'
    end

    # @api private — true when the active credentials came from
    # SWML_BASIC_AUTH_USER / SWML_BASIC_AUTH_PASSWORD: both env vars must be set,
    # non-empty, and equal to what the agent is using.
    def matches_env_auth?(user, pass, env_user, env_pass)
      env_user && !env_user.empty? && env_pass && !env_pass.empty? && user == env_user && pass == env_pass
    end

    # ==================================================================
    # Private helpers
    # ==================================================================

    private

    # Build the AI verb configuration hash.
    def build_ai_config
      ai = {}
      add_ai_prompt(ai)
      add_ai_post_prompt(ai)
      add_ai_swaig(ai)
      add_ai_collections(ai)
      add_ai_params(ai)
      ai['global_data'] = @global_data.dup unless @global_data.empty?
      add_ai_contexts(ai)
      ai
    end

    # @api private — render the AI verb's `prompt` object. An unset or empty
    # prompt falls back to "You are <name>, a helpful AI assistant." rather than
    # being omitted. A POM array renders under `pom`, raw text under `text`; the
    # prompt LLM params are merged alongside.
    def add_ai_prompt(config)
      prompt = get_prompt
      if prompt.nil? || (prompt.respond_to?(:empty?) && prompt.empty?)
        # Match TS: emit the default fallback prompt rather than omitting it.
        prompt = "You are #{name}, a helpful AI assistant."
      end
      key = prompt.is_a?(Array) ? 'pom' : 'text'

      prompt_obj = { key => prompt }
      prompt_obj.merge!(@prompt_llm_params) unless @prompt_llm_params.empty?
      config['prompt'] = prompt_obj
    end

    # @api private — render the AI verb's `post_prompt` object and its
    # `post_prompt_url`. Emits nothing when no post-prompt text is set — the
    # summarization pass is opt-in.
    def add_ai_post_prompt(config)
      return unless @post_prompt_text && !@post_prompt_text.empty?

      pp_obj = { 'text' => @post_prompt_text }
      pp_obj.merge!(@post_prompt_llm_params) unless @post_prompt_llm_params.empty?
      config['post_prompt'] = pp_obj
      config['post_prompt_url'] = (@post_prompt_url_override || build_webhook_url('post_prompt'))
    end

    # @api private — render the AI verb's `SWAIG` object: the default webhook URL,
    # plus `functions` / `native_functions` / `includes` / `internal_fillers` when
    # non-empty. The whole key is dropped when there is nothing but the defaults.
    # `mcp_servers` lives INSIDE this SWAIG object, not at the ai verb's top
    # level (reference core/agent_base.py:1150-1153 — `swaig_obj["mcp_servers"]`).
    # The ai verb's schema is closed, so a top-level `mcp_servers` is a key the
    # platform rejects; it only ever shipped because this assembly bypassed the
    # validating add_verb.
    def add_ai_swaig(config)
      functions = build_functions_array
      swaig = { 'defaults' => { 'web_hook_url' => swaig_default_url } }
      { 'functions' => functions, 'native_functions' => @native_functions,
        'includes' => @function_includes, 'internal_fillers' => @internal_fillers,
        'mcp_servers' => @mcp_servers.map(&:dup) }.each do |key, value|
        swaig[key] = value unless value.empty?
      end
      config['SWAIG'] = swaig unless swaig.keys == ['defaults'] && functions.empty?
    end

    # @api private — the URL for `SWAIG.defaults.web_hook_url`: the
    # {#set_web_hook_url} override when set, else this agent's `/swaig` route with
    # the configured SWAIG query params attached.
    def swaig_default_url
      @web_hook_url_override ||
        build_webhook_url('swaig', @swaig_query_params.empty? ? nil : @swaig_query_params)
    end

    # @api private — render the AI verb's list-valued config (`hints`,
    # `languages`, `pronounce`) plus `multilingual`, each only when non-empty.
    # `multilingual` and `languages` are mutually exclusive on the wire — the
    # server prefers `multilingual` when both are present.
    def add_ai_collections(config)
      config['hints']     = @hints.dup     unless @hints.empty?
      config['languages'] = @languages.dup unless @languages.empty?
      config['pronounce'] = @pronounce.dup unless @pronounce.empty?
      # ASR-driven multilingual mode (set_multilingual): emit the top-level
      # `multilingual` object on the AI verb. Mutually exclusive with
      # `languages` — the server prefers `multilingual` when both are present.
      config['multilingual'] = @multilingual_config if @multilingual_config && !@multilingual_config.empty?
    end

    # @api private — render the AI verb's `params`, adding the debug webhook URL
    # and level when debug events are enabled. Emits nothing when the merged map
    # is empty.
    def add_ai_params(config)
      merged_params = @params.dup
      if debug_events_enabled
        merged_params['debug_webhook_url']   = build_webhook_url('debug_events')
        merged_params['debug_webhook_level'] = debug_events_level
      end
      config['params'] = merged_params unless merged_params.empty?
    end

    # @api private — render the AI verb's `contexts` from the context builder. An
    # invalid context configuration is skipped rather than raised, so a broken
    # contexts block degrades to a context-free agent instead of failing the render.
    #
    # `contexts` belongs INSIDE the prompt object (`ai.prompt.contexts`), not at
    # the ai verb's top level — the reference builds it that way
    # (core/swml_handler.py:191 `prompt_config["contexts"]`) and this port's own
    # AiVerbHandler#build_prompt_config already agrees. The ai verb's schema is
    # closed, so a top-level `contexts` is a key the platform rejects; it only
    # ever shipped because this assembly bypassed the validating add_verb.
    def add_ai_contexts(config)
      return unless @context_builder

      prompt = config['prompt']
      return unless prompt.is_a?(Hash)

      prompt['contexts'] = @context_builder.to_h
    rescue ArgumentError
      # invalid context config — skip silently
    end

    # Build the functions array for the SWAIG section.
    def build_functions_array
      functions = @tools.values.map { |tool| tool_function_entry(tool) }
      @swaig_functions.each_value { |func_def| functions << func_def.dup }
      functions
    end

    # @api private — one SWAIG `functions` entry for a registered tool. When the
    # tool is `secure` and a call_id is in scope, a per-tool `__token` (minted via
    # the SessionManager) is appended to its webhook URL so the platform can
    # validate the callback — the wire manifestation of `secure`.
    def tool_function_entry(tool)
      func_entry = tool[:definition].dup
      # A SECURE tool rendered with an active call_id gets a per-tool ``__token``
      # appended to its webhook URL (minted via the SessionManager) so the
      # platform validates the callback — the wire manifestation of ``secure``
      # (mirrors python agent_base.py:1040/1096-1100). Absent a call_id (or for
      # an insecure tool) it falls back to the query-param webhook, if any.
      qp = @swaig_query_params.dup
      if tool[:secure] && @render_call_id && !@render_call_id.to_s.empty?
        qp['__token'] = create_tool_token(func_entry['function'], @render_call_id)
      end
      func_entry['web_hook_url'] = build_webhook_url('swaig', qp) unless qp.empty?
      func_entry
    end

    # Build a webhook URL with optional query params.
    def build_webhook_url(endpoint, query_params = nil)
      base = base_url
      path = route == '/' ? "/#{endpoint}" : "#{route}/#{endpoint}"

      url = "#{base}#{path}"

      if query_params && !query_params.empty?
        qs = URI.encode_www_form(query_params)
        url = "#{url}?#{qs}"
      end

      url
    end

    # Compute the base URL for webhook construction.
    #
    # Precedence (matches the Python SDK):
    #   1. +SWML_PROXY_URL_BASE+ or a call to +manual_set_proxy_url+
    #      (an explicit override always wins)
    #   2. AWS Lambda-derived URL when execution mode is +:lambda+
    #      (either +AWS_LAMBDA_FUNCTION_URL+ or the Function URL built
    #      from +AWS_LAMBDA_FUNCTION_NAME+ + +AWS_REGION+)
    #   3. +http://user:pass@host:port+ for local server mode
    #
    # This method intentionally returns only the *base* — the agent's
    # +@route+ is appended by {#build_webhook_url}. Never bake the
    # route into the base here, or a non-root agent deployed behind a
    # proxy will have its mount point silently dropped from webhook
    # URLs.
    def base_url
      return proxy_url_base.chomp('/') if proxy_url_base && !proxy_url_base.empty?

      if Runtime.lambda?
        lambda_base = Runtime.lambda_base_url
        if lambda_base
          user, pass = @basic_auth
          return embed_auth(lambda_base, user, pass)
        end
      end

      user, pass = @basic_auth
      "http://#{user}:#{pass}@#{host}:#{port}"
    end

    # Embed basic-auth credentials into +base+ immediately after the
    # scheme. Returns +base+ untouched when either credential is blank
    # or the URL already contains an @-delimited userinfo component.
    def embed_auth(base, user, pass)
      return base if blank?(user) || blank?(pass)

      uri = URI.parse(base)
      return base if uri.userinfo && !uri.userinfo.empty?

      uri.userinfo = "#{URI.encode_www_form_component(user)}:#{URI.encode_www_form_component(pass)}"
      uri.to_s
    rescue URI::InvalidURIError
      base
    end

    # @api private — true for nil or an empty String. Used by {#embed_auth} so a
    # blank credential is never embedded in a URL.
    def blank?(str)
      str.nil? || str.empty?
    end

    # Normalise tool parameters into JSON-Schema form.
    def normalise_parameters(params)
      return params if object_schema?(params)
      return { 'type' => 'object', 'properties' => {} } if params.nil? || params.empty?

      # If the hash looks like {name => {type, description}}, wrap it.
      return params unless params.is_a?(Hash) && !params.key?('type')

      { 'type' => 'object', 'properties' => params.transform_keys(&:to_s) }
    end

    # @api private — true when +params+ is already a JSON Schema object (a Hash
    # whose `type` is `"object"`), so {#normalise_parameters} leaves it alone.
    def object_schema?(params)
      params.is_a?(Hash) && params['type'] == 'object'
    end

    # Create an ephemeral deep copy for dynamic config.
    def create_ephemeral_copy
      copy = dup
      ephemeral_copy_values.each { |ivar, value| copy.instance_variable_set(ivar, value) }
      copy
    end

    # The deep-copied ivar => value pairs for {#create_ephemeral_copy}. The
    # dynamic-config callback is intentionally nil'd to prevent infinite
    # recursion; @mcp_server_enabled is a scalar so it's copied as-is.
    def ephemeral_copy_values
      values = {}
      EPHEMERAL_ARRAY_OF_DUPS.each { |iv| values[iv] = instance_variable_get(iv).map(&:dup) }
      EPHEMERAL_SHALLOW_DUPS.each { |iv| values[iv] = instance_variable_get(iv).dup }
      values.merge(ephemeral_special_copies)
    end

    # ivars that need a bespoke deep-copy strategy (or are scalar / nil'd).
    def ephemeral_special_copies
      {
        :@tools => @tools.transform_values(&:dup),
        :@swaig_functions => @swaig_functions.transform_values(&:dup),
        :@internal_fillers => deep_dup_hash(@internal_fillers),
        :@mcp_server_enabled => @mcp_server_enabled,
        :@dynamic_config_callback => nil
      }
    end

    # Deep-dup a hash of hashes
    def deep_dup_hash(hash)
      hash.each_with_object({}) do |(k, v), result|
        result[k] = v.is_a?(Hash) ? v.dup : v
      end
    end

    # Parse query string from Rack request
    def parse_query_string(request)
      return {} unless request.respond_to?(:env)

      qs = request.env['QUERY_STRING'] || ''
      URI.decode_www_form(qs).to_h
    rescue StandardError
      {}
    end

    # Extract headers from Rack request
    def extract_headers(request)
      return {} unless request.respond_to?(:env)

      request.env.select { |k, _| k.start_with?('HTTP_') }
                 .transform_keys { |k| k.sub('HTTP_', '').downcase.tr('_', '-') }
    rescue StandardError
      {}
    end

    # ==================================================================
    # Rack app
    # ==================================================================

    def build_rack_app
      agent = self
      main_route = route
      authenticated = build_authenticated_app
      Rack::Builder.new do
        # --- public endpoints (no auth) --------------------------------
        map('/health') { run ->(_env) { agent.send(:static_status_response, 'healthy') } }
        map('/ready')  { run ->(_env) { agent.send(:static_status_response, 'ready') } }
        # --- authenticated endpoints -----------------------------------
        map(main_route) { run authenticated }
      end
    end

    # The middleware stack + handler for the authenticated main route, as its
    # own Rack app so build_rack_app stays a thin router.
    def build_authenticated_app
      agent = self
      # Webhook signature validation runs BEFORE basic auth so a spoofed but
      # unsigned request is rejected with 403 (the spec) rather than 401 (which
      # would expose that the key is missing). Only POSTs to the signed routes
      # go through. webhook_mw_args is nil when no signing key is configured.
      webhook_args = webhook_middleware_args

      Rack::Builder.new do
        use AgentSecurityHeadersMiddleware
        use AgentBodyLimitMiddleware, AgentBase::MAX_BODY_SIZE
        use(SignalWire::Security::WebhookMiddleware, **webhook_args) if webhook_args
        use AgentTimingSafeBasicAuth, agent
        run ->(env) { agent.send(:handle_main_request, env) }
      end
    end

    # Keyword args for the WebhookMiddleware `use`, or nil when no signing key.
    def webhook_middleware_args
      return nil if @signing_key.nil? || @signing_key.empty?

      { signing_key: @signing_key, trust_proxy: trust_proxy_for_signature,
        paths: ['/', '/swaig', '/post_prompt'], methods: ['POST'] }
    end

    # @api private — the unauthenticated `/health` and `/ready` response: 200 with
    # a `{"status": …}` JSON body. Deliberately reveals nothing about the agent.
    def static_status_response(status)
      [200, { 'content-type' => 'application/json' }, [JSON.generate({ status: status })]]
    end

    # The authenticated main-route Rack handler: parse the body, then dispatch
    # to /swaig, the extra routes (/post_prompt, /debug_events, /mcp), or SWML.
    def handle_main_request(env)
      request  = Rack::Request.new(env)
      sub_path = env['PATH_INFO'] || '/'
      sub_path = '/' if sub_path.empty?
      request_data = parse_request_body(request, env)

      # /swaig — handled by Service; dispatch uses on_function_call (which
      # AgentBase overrides for token validation).
      return handle_swaig_endpoint(request, request_data, env) if sub_path == '/swaig'

      extra = handle_additional_route(sub_path, request_data, env)
      return extra if extra

      # SWML fall-through: route through the decomposed handle_request core so the
      # served path honors the routing-callback 307 redirect (#61) instead of
      # unconditionally rendering SWML. Basic auth already ran in the Rack
      # middleware, so skip the redundant re-check; the request is threaded
      # through for dynamic config's query/header access.
      dispatch_via_handle_request(request, env, sub_path, request_data)
    end

    # Marshal the served Rack request into the (method, url, headers, body)
    # primitives, call {#handle_request}, and turn its
    # +[status, headers, body_string]+ triple back into a Rack response array.
    def dispatch_via_handle_request(request, env, sub_path, request_data)
      method  = env['REQUEST_METHOD'] || 'GET'
      url     = served_request_url(env, sub_path)
      headers = extract_headers(request)
      status, headers_out, body = handle_request(
        method, url, headers, request_data, request:, skip_auth: true
      )
      resp_headers = { 'content-type' => 'application/json' }.merge(headers_out || {})
      [status, resp_headers, [body.to_s]]
    end

    # Build the request URL (path + query string) that handle_request's
    # callback-path matcher and proxy detection consume.
    def served_request_url(env, sub_path)
      qs = env['QUERY_STRING']
      qs && !qs.empty? ? "#{sub_path}?#{qs}" : sub_path
    end

    # Parse a POST/PUT JSON body. Prefers the raw body stashed by
    # WebhookMiddleware (already read+rewound); else reads rack input directly.
    def parse_request_body(request, env)
      return nil unless request.post? || request.put?

      body = env['signalwire.raw_body']
      if body.nil?
        body = request.body.read
        request.body.rewind if request.body.respond_to?(:rewind)
      end
      safe_json_parse(body)
    end

    # @api private — parse a JSON request body, returning nil on any parse
    # failure. Callers treat nil as "no usable body" rather than erroring, so a
    # malformed POST does not 500.
    def safe_json_parse(body)
      JSON.parse(body)
    rescue StandardError
      nil
    end

    # Build a [status, headers, [body]] Rack triple for a JSON object.
    def json_response(status, obj)
      [status, { 'content-type' => 'application/json' }, [JSON.generate(obj)]]
    end

    # Override Service's hook to add agent-specific routes.
    public

    # Dispatch the agent-specific routes mounted under the main route:
    # `/post_prompt`, `/debug_events` and `/mcp`. Returns nil for any other path
    # so the caller falls through to SWML rendering.
    #
    # @param sub_path [String] the path below the agent's route
    # @param request_data [Hash, nil] the parsed JSON body
    # @param env [Hash] the Rack env
    # @return [Array, nil] a Rack response triple, or nil when the path is not one of these
    def handle_additional_route(sub_path, request_data, env)
      case sub_path
      when '/post_prompt'  then handle_post_prompt(request_data, env)
      when '/debug_events' then handle_debug_events(request_data, env)
      when '/mcp'          then handle_mcp_endpoint(request_data, env)
      end
    end

    # These methods must be accessible from the Rack lambda

    # _handle_swaig is now provided by Service (lifted as handle_swaig_endpoint).
    # AgentBase still hooks the dispatch path via the on_function_call override
    # below, which adds session-token validation on top of Service's plain
    # registry lookup.

    # Handle post_prompt callback.
    # @api private
    def handle_post_prompt(request_data, _env)
      invoke_summary_callback(request_data) if @summary_callback && request_data
      json_response(200, { 'status' => 'ok' })
    end

    # @api private — extract the summary from a post-prompt payload and hand it to
    # the registered {#on_summary} callback. A raising callback is logged, not
    # propagated: the platform still gets its 200 ack.
    def invoke_summary_callback(request_data)
      summary = find_summary_in_post_data(request_data)
      @summary_callback.call(summary, request_data)
    rescue StandardError => e
      @logger.error "Post-prompt callback error: #{e.message}"
    end

    # Locate the summary in the post-prompt payload. Mirrors the extraction
    # order used by the Python and TS ports:
    #   1. top-level "summary" key
    #   2. post_prompt_data["parsed"][0] (when parsed is a non-empty array)
    #   3. post_prompt_data["raw"] (JSON-parsed when possible, else raw)
    def find_summary_in_post_data(body)
      return nil unless body.is_a?(Hash)
      return body['summary'] if body['summary']

      ppd = body['post_prompt_data']
      ppd.is_a?(Hash) ? summary_from_post_prompt_data(ppd) : nil
    end

    # Second/third tiers of the summary lookup: parsed[0] then raw
    # (JSON-parsed when possible, else the raw string).
    def summary_from_post_prompt_data(ppd)
      parsed = ppd['parsed']
      return parsed[0] if parsed.is_a?(Array) && !parsed.empty?

      raw = ppd['raw']
      return nil unless raw

      begin
        JSON.parse(raw)
      rescue StandardError
        raw
      end
    end

    # Handle debug events.
    # @api private
    def handle_debug_events(request_data, _env)
      invoke_debug_event_callback(request_data) if @debug_event_callback && request_data
      json_response(200, { 'status' => 'ok' })
    end

    # @api private — hand a debug-event payload to the registered
    # {#on_debug_event} callback, keyed by its `event_type` (defaulting to
    # "unknown"). A raising callback is logged, not propagated.
    def invoke_debug_event_callback(request_data)
      event_type = request_data['event_type'] || 'unknown'
      @debug_event_callback.call(event_type, request_data)
    rescue StandardError => e
      @logger.error "Debug event callback error: #{e.message}"
    end

    # Handle MCP JSON-RPC 2.0 endpoint.
    # @api private
    def handle_mcp_endpoint(request_data, _env)
      return json_response(404, { 'error' => 'MCP server not enabled' }) unless mcp_server_enabled
      return json_response(400, mcp_error(nil, -32_700, 'Parse error')) unless request_data

      json_response(200, _handle_mcp_request(request_data))
    end

    # ==================================================================
    # Rack Middleware
    # ==================================================================

    class AgentSecurityHeadersMiddleware
      HEADERS = {
        'x-content-type-options' => 'nosniff',
        'x-frame-options' => 'DENY',
        'cache-control' => 'no-store, no-cache, must-revalidate'
      }.freeze

      # @param app [#call] the next Rack app in the stack
      def initialize(app)
        @app = app
      end

      # Call the wrapped app and stamp the fixed security headers onto its response.
      #
      # @param env [Hash] the Rack env
      # @return [Array] the Rack response triple, with HEADERS applied
      def call(env)
        status, headers, body = app.call(env)
        HEADERS.each { |k, v| headers[k] = v }
        [status, headers, body]
      end

      private

      attr_reader :app
    end

    # Rack middleware rejecting a request whose declared body length exceeds the
    # agent's limit, before the body is ever read into memory.
    class AgentBodyLimitMiddleware
      # @param app [#call] the next Rack app in the stack
      # @param max_size [Integer] the largest CONTENT_LENGTH accepted, in bytes
      def initialize(app, max_size)
        @app      = app
        @max_size = max_size
      end

      # Reject an over-sized request with 413 and a JSON error body; otherwise pass
      # it to the wrapped app. Only the declared CONTENT_LENGTH is checked — a
      # request that lies about its length is caught downstream by the server.
      #
      # @param env [Hash] the Rack env
      # @return [Array] the Rack response triple
      def call(env)
        if env['CONTENT_LENGTH'] && env['CONTENT_LENGTH'].to_i > max_size
          body = JSON.generate({ 'error' => 'Request body too large' })
          return [413, { 'content-type' => 'application/json' }, [body]]
        end
        app.call(env)
      end

      private

      attr_reader :app, :max_size
    end

    # Rack middleware enforcing the agent's basic auth with a constant-time
    # credential comparison, so a wrong password cannot be recovered by timing the
    # response.
    class AgentTimingSafeBasicAuth
      # @param app [#call] the next Rack app in the stack
      # @param agent [AgentBase] the agent whose credentials are the expected pair
      def initialize(app, agent)
        @app   = app
        @agent = agent
      end

      # Require valid basic auth before passing the request on. A missing or
      # non-Basic Authorization header, or a credential mismatch, gets the same 401
      # challenge — the response does not distinguish the two.
      #
      # @param env [Hash] the Rack env
      # @return [Array] the Rack response triple
      def call(env)
        auth = Rack::Auth::Basic::Request.new(env)
        return unauthorized unless auth.provided? && auth.basic?

        credentials_valid?(auth.credentials) ? @app.call(env) : unauthorized
      end

      private

      # Constant-time comparison of supplied [user, pass] against the agent's.
      def credentials_valid?(input)
        user, pass = @agent.get_basic_auth_credentials
        input_user, input_pass = input
        user_ok = Rack::Utils.secure_compare(user.to_s, input_user.to_s)
        pass_ok = Rack::Utils.secure_compare(pass.to_s, input_pass.to_s)
        user_ok && pass_ok
      end

      # @api private — the 401 challenge: a `Basic realm="SignalWire Agent"`
      # www-authenticate header and a JSON `{"error":"Unauthorized"}` body (not
      # plain text), matching the reference's auth challenges.
      def unauthorized
        # Python parity (AuthMixin._send_lambda_auth_challenge / the CGI + server
        # challenges): a JSON {"error":"Unauthorized"} body with a JSON
        # content-type, not a plain-text "Unauthorized".
        [
          401,
          {
            'content-type' => 'application/json',
            'www-authenticate' => 'Basic realm="SignalWire Agent"'
          },
          [JSON.generate('error' => 'Unauthorized')]
        ]
      end
    end

    # Internal helpers extracted during the lint burndown (Metrics cops) for
    # locality, but they are implementation details with no Python-reference
    # counterpart. Declared private here at the end of the class — after every
    # one is defined — so they stay off the audited public surface (restoring the
    # encapsulation the pre-extraction inline code had). Placed last because the
    # methods span multiple public/private regions above.
    private :add_context_step, :add_pom_section, :append_section_bullets, :apply_compound_voice
    private :apply_dynamic_config, :apply_language_fillers, :apply_language_voice, :attach_context_builder
    private :basic_auth_source, :build_context_builder_from_hash, :build_section
    private :build_subsection, :build_subsections, :build_tool_definition, :build_tool_param_schema
    private :coerce_function_result, :compound_voice?, :define_skill_tool, :find_or_create_section
    private :invoke_debug_event_callback, :invoke_summary_callback, :join_rack_body
    private :log_server_startup
    private :matches_env_auth?, :mcp_input_schema, :mcp_tool_entry, :merge_skill_hints_and_data
    private :merge_skill_prompt_sections, :optional_tool_fields, :rack_env, :register_no_vowels_variation
    private :register_skill_tools, :sanitize_sip_username, :section_pom_kwargs
    # swaig_pre_dispatch / swaig_validate_token are PRIVATE, mirroring the
    # reference's `_swaig_pre_dispatch` / `_swaig_validate_token` (both
    # underscore-private). Service invokes the hook with an implicit receiver, so
    # private visibility is sufficient and the override adds no public surface.
    private :swaig_pre_dispatch, :swaig_validate_token, :swaig_request_token, :swaig_call_id
    private :sym_or_str, :verb_entries, :warn_unexpected_function_result
    private :warn_unknown_filler_name, :warn_unknown_filler_names, :webrick_opts
    private :answer_entry, :record_call_entry, :webrick_handler
    private :valid_function_include?, :warn_dropped_function_include, :find_summary_in_post_data
    private :summary_from_post_prompt_data
    # Formerly leading-underscore-by-convention internals; underscore dropped in
    # the idiom pass. Declared private so the cross-port surface enumerator keeps
    # excluding them (unchanged public surface).
    private :agent_on_swml_request, :agent_render_triple, :apply_env_headers,
            :extract_http_request, :extract_path_and_query, :handle_debug_events,
            :handle_mcp_endpoint, :handle_post_prompt, :mcp_default_response,
            :mcp_empty_result_method?, :mcp_error, :mcp_initialize_response,
            :mcp_response_text, :mcp_result, :mcp_tool_result, :mcp_tools_call,
            :req_field, :run_http_serverless, :sip_routing_callback, :split_url_path
  end
end
