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
    # Python parity:
    # - ``logger`` — agent-specific structured logger (Python: ``self.log``).
    # - ``skill_manager`` — owning SkillManager (Python's ``self.skill_manager``).
    # - ``agent_id`` — UUID identifier from constructor or auto-generated.
    # - ``default_webhook_url`` — base URL for SWAIG webhook fallbacks.
    # - ``native_functions`` — names of built-in SWAIG functions to advertise.
    # - ``use_pom`` — whether prompt-object-model rendering is enabled.
    attr_reader :logger, :skill_manager, :agent_id, :default_webhook_url,
                :native_functions, :use_pom, :signing_key

    # Maximum request body size (1 MB)
    MAX_BODY_SIZE = 1_048_576

    # _create_ephemeral_copy: ivars whose value is an array of dup-able
    # elements (deep-copied via map(&:dup)).
    EPHEMERAL_ARRAY_OF_DUPS = %i[
      @pom_sections @languages @pronounce @function_includes
      @pre_answer_verbs @post_answer_verbs @post_ai_verbs @mcp_servers
    ].freeze

    # _create_ephemeral_copy: ivars deep-copied with a shallow #dup.
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
      @logger.info "Agent '#{@name}' initialised (route=#{@route}, port=#{@port})"
    end

    def init_call_settings(auto_answer:, record_call:, record_format:, record_stereo:)
      @auto_answer   = auto_answer
      @record_call   = record_call
      @record_format = record_format
      @record_stereo = record_stereo
    end

    # Python parity: use_pom toggles POM-vs-raw rendering; agent_id is an
    # optional explicit UUID; default_webhook_url is used when SWAIG functions
    # carry no explicit URL; native_functions lists native SWAIG callables; the
    # *_override flags are wired through the endpoint dispatcher.
    def init_identity(**opts)
      @use_pom = opts[:use_pom]
      @agent_id            = opts[:agent_id] || SecureRandom.uuid
      @default_webhook_url = opts[:default_webhook_url]
      @native_functions    = opts[:native_functions] || []
      @enable_post_prompt_override = opts[:enable_post_prompt_override]
      @check_for_input_override    = opts[:check_for_input_override]
    end

    # Webhook signature validation (porting-sdk/webhooks.md). Resolution:
    # explicit arg → SIGNALWIRE_SIGNING_KEY env. When set, _build_rack_app
    # mounts WebhookMiddleware on the signed routes; when unset, warn so
    # production users notice unsigned traffic is being accepted.
    def init_signing_key(signing_key, trust_proxy_for_signature)
      @signing_key = signing_key || ENV.fetch('SIGNALWIRE_SIGNING_KEY', nil)
      @trust_proxy_for_signature = trust_proxy_for_signature
      log_signing_key_status unless @suppress_logs
    end

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

    def init_prompt_and_ai_state
      @prompt_text      = nil    # raw text mode
      @prompt_pom       = nil    # direct POM array
      @pom_sections     = []     # built via prompt_add_section
      @post_prompt_text = nil
      init_ai_config_state
    end

    def init_ai_config_state
      @hints               = []
      @languages           = []
      @pronounce           = []
      @params              = {}
      @global_data         = {}
      @function_includes   = []
      @internal_fillers    = {}
      @prompt_llm_params   = {}
      @post_prompt_llm_params = {}
    end

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

    def init_web_and_integration_state
      @dynamic_config_callback = nil
      @proxy_url_base          = ENV.fetch('SWML_PROXY_URL_BASE', nil)
      @web_hook_url_override   = nil
      @post_prompt_url_override = nil
      @swaig_query_params      = {}
      @debug_routes_enabled    = false
      @summary_callback        = nil
      init_sip_and_mcp_state
    end

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
    # Python parity:
    # ``prompt_add_section(title, body="", bullets=None,
    # numbered=False, numbered_bullets=False, subsections=None)``.
    #
    # @param title [String] section title
    # @param body  [String, nil] optional body text
    # @param bullets [Array<String>, nil] optional bullet items
    # @param numbered [Boolean] render as a numbered top-level entry
    # @param numbered_bullets [Boolean] render bullets as numbered
    # @param subsections [Array<Hash>, nil] optional pre-rendered
    #   subsection hashes (each ``{title:, body:, bullets:}``)
    def prompt_add_section(title, body = nil, bullets: nil,
                           numbered: false, numbered_bullets: false,
                           subsections: nil)
      @prompt_text = nil
      @prompt_pom  = nil
      @pom_sections << build_section(title, body, bullets: bullets, numbered: numbered,
                                                  numbered_bullets: numbered_bullets, subsections: subsections)
      self
    end

    def build_section(title, body, **opts)
      section = { 'title' => title }
      section['body']             = body              if body
      section['bullets']          = opts[:bullets]    if opts[:bullets]
      section['numbered']         = true              if opts[:numbered]
      section['numbered_bullets'] = true              if opts[:numbered_bullets]
      subs = build_subsections(opts[:subsections])
      section['subsections'] = subs if subs
      section
    end

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
    # Python parity:
    # ``prompt_add_to_section(title, body=None, bullet=None,
    # bullets=None)``. Supports appending body text, a single bullet,
    # or a list of bullets.
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

    def find_or_create_section(title)
      sec = @pom_sections.find { |s| s['title'] == title }
      return sec if sec

      sec = { 'title' => title }
      @pom_sections << sec
      sec
    end

    def append_section_bullets(sec, bullet, bullets)
      to_add = []
      to_add << bullet if bullet
      to_add.concat(bullets) if bullets.is_a?(Array)
      sec['bullets'] = (sec['bullets'] || []) + to_add unless to_add.empty?
    end

    # Add a subsection under a parent section.
    def prompt_add_subsection(parent_title, title, body = nil, bullets: nil)
      parent = @pom_sections.find { |s| s['title'] == parent_title }
      if parent
        parent['subsections'] ||= []
        sub = { 'title' => title }
        sub['body']    = body    if body
        sub['bullets'] = bullets if bullets
        parent['subsections'] << sub
      end
      self
    end

    # Check whether a POM section with the given title exists.
    def prompt_has_section?(title)
      @pom_sections.any? { |s| s['title'] == title }
    end

    # Return the current prompt: either a string (text mode) or an array (POM).
    # @!visibility private  (idiomatic alias: #prompt; original kept for
    #   cross-port audit parity + back-compat)
    def get_prompt
      return @prompt_text if @prompt_text
      return @prompt_pom  if @prompt_pom
      return @pom_sections.dup unless @pom_sections.empty?

      nil
    end

    # Read-only snapshot of the agent's POM as a typed
    # {SignalWire::POM::PromptObjectModel} instance.
    #
    # Python parity: ``agent.pom`` instance attribute (agent_base.py
    # line 209) is a ``PromptObjectModel`` instance. Returns ``nil`` when
    # raw-text prompt mode is in effect (``set_prompt_text`` was called)
    # — mirrors Python's ``self.pom = None when use_pom=False``.
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

    def section_pom_kwargs(sec)
      {
        body: sec.fetch('body', ''),
        bullets: sec['bullets'] || [],
        numbered: sec['numbered'] || false,
        numbered_bullets: sec['numbered_bullets'] || sec['numberedBullets'] || false
      }
    end

    # Returns the post-prompt text whatever set_post_prompt stored, or
    # nil when no post-prompt has been set.
    #
    # Mirrors Python's PromptManager#get_post_prompt /
    # PromptMixin#get_post_prompt — used by SWML rendering when a
    # post-prompt is configured.
    # @!visibility private  (idiomatic alias: #post_prompt; original kept for
    #   cross-port audit parity + back-compat)
    def get_post_prompt
      @post_prompt_text
    end

    # Returns the raw prompt text whatever set_prompt_text stored, or
    # nil when no raw prompt has been set. Distinct from #get_prompt
    # which may return the POM array when use_pom is true.
    #
    # Mirrors Python's PromptManager#get_raw_prompt.
    # @!visibility private  (idiomatic alias: #prompt_text; original kept for
    #   cross-port audit parity + back-compat)
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

    def global_data=(data)
      set_global_data(data)
    end

    def internal_fillers=(fillers)
      set_internal_fillers(fillers)
    end

    def languages=(languages)
      set_languages(languages)
    end

    def native_functions=(names)
      set_native_functions(names)
    end

    def params=(params)
      set_params(params)
    end

    def post_prompt_url=(url)
      set_post_prompt_url(url)
    end

    def prompt_pom=(pom)
      set_prompt_pom(pom)
    end

    def pronunciations=(pronunciations)
      set_pronunciations(pronunciations)
    end

    def web_hook_url=(url)
      set_web_hook_url(url)
    end

    # Returns the contexts dictionary as a serialised hash, or nil when
    # no contexts have been defined yet.
    #
    # Mirrors Python's PromptManager#get_contexts which returns the
    # contexts dict or None.
    # @!visibility private  (idiomatic alias: #contexts; original kept for
    #   cross-port audit parity + back-compat)
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
    # Python parity:
    # ``define_tool(name, description, parameters, handler,
    # secure=True, fillers=None, wait_file=None, wait_file_loops=None,
    # webhook_url=None, required=None, is_typed_handler=False,
    # **swaig_fields)``.
    #
    # @param name [String] tool name
    # @param description [String] LLM-facing description
    # @param parameters [Hash] JSON-Schema parameters
    # @param handler [Proc, nil] explicit handler (alternative to a
    #   block); kept for backward compat
    # @param secure [Boolean] require token validation. Ruby defaults
    #   to ``false`` (kept for backward compat); Python defaults to
    #   ``True``. Pass ``secure: true`` to match Python.
    # @param fillers [Hash, nil] language-keyed filler phrases
    # @param wait_file [String, nil] URL of audio file to play while
    #   the tool runs server-side
    # @param wait_file_loops [Integer, nil] loop count for ``wait_file``
    # @param webhook_url [String, nil] external endpoint to use
    #   instead of dispatching to the local handler
    # @param required [Array<String>, nil] required parameter names
    # @param is_typed_handler [Boolean] handler accepts type-coerced
    #   keyword args (parity flag; Ruby uses dynamic typing so this
    #   is a no-op at runtime but is preserved for surface parity)
    # @param swaig_fields [Hash, nil] additional fields merged into
    #   the SWAIG function definition
    # @yield [args, raw_data] tool handler body (alternative to
    #   passing ``handler:``)
    def define_tool(name:, description:, parameters: {}, handler: nil,
                    secure: false, fillers: nil,
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
    # `required:` list (Python parity) onto an object schema.
    def build_tool_param_schema(parameters, required)
      param_schema = _normalise_parameters(parameters)
      if required.is_a?(Array) && !required.empty? && param_schema.is_a?(Hash) && param_schema['type'] == 'object'
        existing = param_schema['required'] || []
        param_schema['required'] = (existing + required).uniq
      end
      param_schema
    end

    def build_tool_definition(name, description, param_schema, **opts)
      tool_def = { 'function' => name, 'description' => description, 'parameters' => param_schema }
      optional_tool_fields(opts).each { |k, v| tool_def[k] = v if v }
      swaig_fields = opts[:swaig_fields]
      swaig_fields.each { |k, v| tool_def[k.to_s] = v } if swaig_fields.is_a?(Hash)
      tool_def
    end

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
    # Python parity: state_mixin.StateMixin#_create_tool_token —
    # delegates to SessionManager#create_token and returns "" on any
    # raised error (Python rescues all exceptions and returns "").
    def create_tool_token(tool_name, call_id)
      @session_manager.create_token(tool_name, call_id)
    rescue StandardError
      ''
    end

    # Validate a per-call SWAIG-function token. Returns false when the
    # function is not registered, when the SessionManager rejects the
    # token, or on any underlying exception.
    #
    # Python parity: state_mixin.StateMixin#validate_tool_token —
    # rejects unknown function names up-front and rescues exceptions.
    def validate_tool_token(function_name, token, call_id)
      return false unless has_function(function_name)

      @session_manager.validate_token(function_name, token, call_id)
    rescue StandardError
      false
    end

    # Dispatch a function call to the registered handler.
    def on_function_call(name, args, raw_data)
      tool = @tools[name]
      return { 'response' => "Function '#{name}' not found" } unless tool
      return { 'response' => 'Invalid or expired token' } unless secure_token_ok?(name, tool, raw_data)

      coerce_function_result(name, tool[:handler].call(args, raw_data))
    rescue StandardError => e
      @logger.error "Tool '#{name}' error: #{e.message}"
      { 'response' => "Error executing '#{name}': #{e.message}" }
    end

    # True unless this is a secure tool with a present-but-invalid token.
    def secure_token_ok?(name, tool, raw_data)
      return true unless tool[:secure]

      call_id = raw_data && (raw_data['call_id'] || raw_data.dig('call', 'call_id'))
      token   = raw_data && raw_data['meta_data_token']
      return true unless call_id && token

      @session_manager.validate_token(name, token, call_id)
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

    def add_hints(hints)
      hints.each { |h| add_hint(h) } if hints.is_a?(Array)
      self
    end

    # Add a complex (pattern-matched) hint.
    #
    # Python parity:
    # ``add_pattern_hint(hint, pattern, replace, ignore_case=False)``.
    # Ruby supports both the Python-style positional form and the
    # legacy keyword form (``add_pattern_hint(pattern, hint:, language:)``)
    # for backward compat.
    #
    # @overload add_pattern_hint(hint, pattern, replace, ignore_case: false)
    #   @param hint [String] hint to match
    #   @param pattern [String] regex pattern
    #   @param replace [String] replacement text
    #   @param ignore_case [Boolean] match without regard to case
    # @overload add_pattern_hint(pattern, hint:, language: 'en-US')
    #   Legacy Ruby form — pattern + optional hint string and language.
    def add_pattern_hint(*args, hint: nil, pattern: nil, replace: nil,
                         ignore_case: false, language: 'en-US')
      @hints << build_pattern_hint(args, hint: hint, pattern: pattern, replace: replace,
                                         ignore_case: ignore_case, language: language)
      self
    end

    def build_pattern_hint(args, **opts)
      # Three positional args = Python positional shape.
      return replace_hint(*args, opts[:ignore_case]) if args.length == 3
      # Single positional ≡ legacy add_pattern_hint(pattern, hint:, language:).
      return legacy_pattern_hint(args.first, opts[:hint], opts[:language]) if legacy_hint_form?(args, opts)
      # Pure-keyword form (Python-named keywords).
      return replace_hint(opts[:hint], opts[:pattern], opts[:replace], opts[:ignore_case]) if keyword_hint_form?(opts)

      raise ArgumentError,
            'add_pattern_hint: pass either (hint, pattern, replace) or use legacy (pattern, hint:, language:) form'
    end

    def legacy_hint_form?(args, opts)
      args.length == 1 && opts[:pattern].nil? && opts[:replace].nil?
    end

    def keyword_hint_form?(opts)
      opts[:pattern] && opts[:hint] && opts[:replace]
    end

    def replace_hint(hint, pattern, replace, ignore_case)
      { 'hint' => hint, 'pattern' => pattern, 'replace' => replace, 'ignore_case' => ignore_case }
    end

    def legacy_pattern_hint(pattern, hint, language)
      entry = { 'pattern' => pattern }
      entry['hint']     = hint     if hint
      entry['language'] = language if language
      entry
    end

    # Add a language configuration.
    #
    # Python parity: ``add_language(name, code, voice, speech_fillers=None,
    # function_fillers=None, engine=None, model=None)``. Ruby supports
    # both the Python-style positional shape AND the original
    # ``add_language(config)`` hash form.
    #
    # Voice argument can be either a simple voice id (``"en-US-Neural2-F"``)
    # or a combined ``"engine.voice:model"`` string
    # (``"elevenlabs.josh:eleven_turbo_v2_5"``); the combined form is
    # parsed into ``engine``/``voice``/``model`` keys when ``engine``
    # and ``model`` aren't supplied explicitly.
    #
    # @overload add_language(config)
    #   @param config [Hash] preformed language config
    # @overload add_language(name, code, voice, speech_fillers: nil,
    #   function_fillers: nil, engine: nil, model: nil, params: nil)
    #   @param name [String] language name (e.g. ``"English"``)
    #   @param code [String] BCP47 language code (e.g. ``"en-US"``)
    #   @param voice [String] voice id or ``engine.voice:model`` string
    #   @param speech_fillers [Array<String>, nil] filler phrases for
    #     natural speech
    #   @param function_fillers [Array<String>, nil] filler phrases
    #     during function calls
    #   @param engine [String, nil] explicit engine override
    #   @param model [String, nil] explicit model override
    #   @param params [Hash, nil] optional per-language params (engine-
    #     specific tuning, voice settings, etc.). Emitted as the language
    #     object's ``params`` key in SWML; the key is only emitted when
    #     non-empty so existing entries stay byte-identical.
    def add_language(name_or_config, code = nil, voice = nil,
                     speech_fillers: nil, function_fillers: nil,
                     engine: nil, model: nil, params: nil)
      # Hash form (legacy / direct config)
      return (@languages << name_or_config) && self if hash_language_form?(name_or_config, code, voice)

      raise ArgumentError, 'add_language: name, code, voice are required (or pass a Hash)' if code.nil? || voice.nil?

      lang = { 'name' => name_or_config, 'code' => code }
      apply_language_voice(lang, voice, engine, model)
      apply_language_fillers(lang, speech_fillers, function_fillers)
      # Only emit params when non-empty so SWML isn't polluted with empty objects.
      lang['params'] = params if params.is_a?(Hash) && !params.empty?
      @languages << lang
      self
    end

    def hash_language_form?(name_or_config, code, voice)
      name_or_config.is_a?(Hash) && code.nil? && voice.nil?
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

    def set_languages(languages)
      @languages = languages.dup if languages.is_a?(Array)
      self
    end

    # language_code: is part of the Python-parity signature; the current rule
    # shape doesn't carry it, but the kwarg must stay for surface parity (renaming
    # to _language_code would change the public kwarg name). rubocop:disable below.
    def add_pronunciation(phrase, pronunciation, language_code: 'en-US') # rubocop:disable Lint/UnusedMethodArgument
      rule = { 'replace' => phrase, 'with' => pronunciation }
      rule['ignore_case'] = false
      @pronounce << rule
      self
    end

    def set_pronunciations(pronunciations)
      @pronounce = pronunciations.dup if pronunciations.is_a?(Array)
      self
    end

    def set_param(key, value)
      @params[key.to_s] = value
      self
    end

    def set_params(params)
      params.each { |k, v| @params[k.to_s] = v } if params.is_a?(Hash)
      self
    end

    def set_global_data(data)
      @global_data.merge!(data) if data.is_a?(Hash)
      self
    end

    def update_global_data(data)
      set_global_data(data)
    end

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

    def warn_unknown_filler_name(func_name)
      @logger.warn(
        "unknown_internal_filler_name: #{func_name.inspect}. " \
        'add_internal_filler received a function name the SWML ' \
        'schema does not recognize. The entry will be stored but ' \
        'the runtime will not play these fillers. Supported ' \
        "names: #{SUPPORTED_INTERNAL_FILLER_NAMES.sort.inspect}."
      )
    end

    def enable_debug_events(level = 1)
      @debug_events_enabled = true
      @debug_events_level   = level
      self
    end

    def add_function_include(url, functions, meta_data: nil)
      include = { 'url' => url, 'functions' => functions }
      include['meta_data'] = meta_data if meta_data.is_a?(Hash)
      @function_includes << include
      self
    end

    def set_function_includes(includes)
      @function_includes = includes.dup if includes.is_a?(Array)
      self
    end

    def set_prompt_llm_params(**params)
      @prompt_llm_params.merge!(params.transform_keys(&:to_s))
      self
    end

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

    def clear_pre_answer_verbs
      @pre_answer_verbs = []
      self
    end

    def add_answer_verb(config)
      @answer_config = config
      self
    end

    def add_post_answer_verb(verb_name, config)
      @post_answer_verbs << [verb_name.to_s, config]
      self
    end

    def clear_post_answer_verbs
      @post_answer_verbs = []
      self
    end

    def add_post_ai_verb(verb_name, config)
      @post_ai_verbs << [verb_name.to_s, config]
      self
    end

    def clear_post_ai_verbs
      @post_ai_verbs = []
      self
    end

    # ==================================================================
    # Contexts
    # ==================================================================

    # Define / retrieve the ContextBuilder for this agent.
    #
    # Python parity: ``define_contexts(contexts)`` accepts either a
    # ``ContextBuilder`` (calls ``.to_dict()`` to materialise) or a
    # raw ``dict`` and stores it on the agent. Ruby supports both
    # forms PLUS the original lazy-getter idiom:
    #
    # 1. **Lazy getter** (Ruby idiom) — ``agent.define_contexts``
    #    returns the existing builder, creating one if needed.
    # 2. **Override with builder** — ``agent.define_contexts(other_cb)``
    #    replaces the current builder with the supplied one (Python
    #    parity).
    # 3. **Override with hash** — ``agent.define_contexts({...})``
    #    builds a fresh builder using the provided contexts hash
    #    (Python parity for raw-dict input).
    #
    # @param contexts [SignalWire::Contexts::ContextBuilder, Hash, nil]
    #   optional override
    # @return [SignalWire::Contexts::ContextBuilder] the active builder
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

    def attach_context_builder(builder)
      builder.attach_agent(self) if builder.respond_to?(:attach_agent)
      builder
    end

    # Build a ContextBuilder from a raw contexts Hash (Python-parity dict input).
    def build_context_builder_from_hash(contexts)
      cb = Contexts::ContextBuilder.new(self)
      contexts.each do |name, body|
        ctx = cb.add_context(name.to_s)
        steps = (body.is_a?(Hash) ? body['steps'] : nil) || []
        steps.each { |step_h| add_context_step(ctx, step_h) }
      end
      cb
    end

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
    def add_skill(skill_name, params = {})
      # Ensure builtins are registered
      Skills::SkillRegistry.register_builtins!

      factory = Skills::SkillRegistry.get_factory(skill_name)
      raise ArgumentError, "Unknown skill: '#{skill_name}'" unless factory

      skill = factory.call(params)
      @skill_manager.load(skill.instance_key, skill)
      @loaded_skills[skill_name] = skill

      register_skill_tools(skill)
      merge_skill_hints_and_data(skill)
      merge_skill_prompt_sections(skill)
      self
    end

    def register_skill_tools(skill)
      tool_defs = skill.register_tools
      return unless tool_defs.is_a?(Array)

      tool_defs.each { |td| define_skill_tool(td) }
    end

    def define_skill_tool(tool_def)
      td_name    = sym_or_str(tool_def, :name)
      td_handler = sym_or_str(tool_def, :handler)
      return unless td_name && td_handler

      define_tool(name: td_name, description: sym_or_str(tool_def, :description) || '',
                  parameters: sym_or_str(tool_def, :parameters) || {}, &td_handler)
    end

    # Read a key from a hash that may use symbol or string keys.
    def sym_or_str(hash, key)
      hash[key] || hash[key.to_s]
    end

    def merge_skill_hints_and_data(skill)
      skill_hints = skill.get_hints
      @hints.concat(skill_hints) if skill_hints.is_a?(Array) && !skill_hints.empty?

      skill_data = skill.get_global_data
      @global_data.merge!(skill_data) if skill_data.is_a?(Hash) && !skill_data.empty?
    end

    def merge_skill_prompt_sections(skill)
      skill_sections = skill.get_prompt_sections
      return unless skill_sections.is_a?(Array) && !skill_sections.empty?

      @prompt_text = nil # switch to POM mode
      @prompt_pom  = nil
      skill_sections.each { |sec| @pom_sections << sec }
    end

    def remove_skill(skill_name)
      skill = @loaded_skills.delete(skill_name)
      @skill_manager.unload(skill.instance_key) if skill
      self
    end

    def list_skills
      @loaded_skills.keys
    end

    def has_skill?(skill_name)
      @loaded_skills.key?(skill_name)
    end

    # ==================================================================
    # Web / HTTP configuration
    # ==================================================================

    def set_dynamic_config_callback(callable = nil, &block)
      @dynamic_config_callback = callable || block
      self
    end

    def manual_set_proxy_url(url)
      @proxy_url_base = url
      self
    end

    def set_web_hook_url(url)
      @web_hook_url_override = url
      self
    end

    def set_post_prompt_url(url)
      @post_prompt_url_override = url
      self
    end

    def add_swaig_query_params(params)
      @swaig_query_params.merge!(params) if params.is_a?(Hash)
      self
    end

    def clear_swaig_query_params
      @swaig_query_params = {}
      self
    end

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
      self
    end

    def register_sip_username(username)
      @sip_usernames << username
      self
    end

    # Automatically register common SIP usernames based on this agent's
    # name and route.
    #
    # Python parity: ``AgentBase.auto_map_sip_usernames`` derives SIP
    # usernames from the agent name and route (lower-cased, stripped to
    # ``[a-z0-9_]``) plus a no-vowels variant of the name, registering
    # each via {#register_sip_username}. Duplicates are skipped so the
    # registered set matches Python's set-backed dedup.
    #
    # @return [self] for method chaining
    def auto_map_sip_usernames
      register = lambda do |candidate|
        register_sip_username(candidate) unless candidate.empty? || @sip_usernames.include?(candidate)
      end

      clean_name = sanitize_sip_username(@name)
      register.call(clean_name) unless clean_name.empty?

      clean_route = sanitize_sip_username(@route)
      register.call(clean_route) if !clean_route.empty? && clean_route != clean_name

      register_no_vowels_variation(clean_name, register)
      self
    end

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

    def mcp_tool_entry(name, tool)
      params = tool[:definition]['parameters']
      {
        'name' => name,
        'description' => tool[:definition]['description'] || name,
        'inputSchema' => mcp_input_schema(params)
      }
    end

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

      return _mcp_error(req_id, -32_600, 'Invalid JSON-RPC version') unless body['jsonrpc'] == '2.0'

      # Each branch is a distinct JSON-RPC method; the no-op ack arms
      # (notifications/initialized, ping) share an empty-result body but stay
      # documented by name in _mcp_empty_result_method?.
      case method
      when 'initialize'   then _mcp_initialize_response(req_id)
      when 'tools/list'   then _mcp_result(req_id, { 'tools' => _build_mcp_tool_list })
      when 'tools/call'   then _mcp_tools_call(req_id, params)
      else _mcp_default_response(method, req_id)
      end
    end

    def _mcp_default_response(method, req_id)
      return _mcp_result(req_id, {}) if _mcp_empty_result_method?(method)

      _mcp_error(req_id, -32_601, "Method not found: #{method}")
    end

    def _mcp_empty_result_method?(method)
      %w[notifications/initialized ping].include?(method)
    end

    def _mcp_result(req_id, result)
      { 'jsonrpc' => '2.0', 'id' => req_id, 'result' => result }
    end

    def _mcp_initialize_response(req_id)
      {
        'jsonrpc' => '2.0', 'id' => req_id,
        'result' => {
          'protocolVersion' => '2025-06-18',
          'capabilities' => { 'tools' => {} },
          'serverInfo' => { 'name' => @name, 'version' => '1.0.0' }
        }
      }
    end

    def _mcp_tools_call(req_id, params)
      tool_name = params['name'] || ''
      arguments = params['arguments'] || {}
      tool = @tools[tool_name]
      return _mcp_error(req_id, -32_602, "Unknown tool: #{tool_name}") unless tool

      raw_data = { 'function' => tool_name, 'argument' => { 'parsed' => [arguments] } }
      result = tool[:handler].call(arguments, raw_data)
      _mcp_tool_result(req_id, _mcp_response_text(result), is_error: false)
    rescue StandardError => e
      @logger.error "MCP tool call error: #{tool_name}: #{e.message}"
      _mcp_tool_result(req_id, "Error: #{e.message}", is_error: true)
    end

    def _mcp_response_text(result)
      return result.to_h['response'] || '' if result.respond_to?(:to_h)
      return result['response'] || result.to_s if result.is_a?(Hash)
      return result if result.is_a?(String)

      ''
    end

    def _mcp_tool_result(req_id, text, is_error:)
      {
        'jsonrpc' => '2.0', 'id' => req_id,
        'result' => {
          'content' => [{ 'type' => 'text', 'text' => text }],
          'isError' => is_error
        }
      }
    end

    # @api private
    def _mcp_error(req_id, code, message)
      {
        'jsonrpc' => '2.0',
        'id' => req_id,
        'error' => { 'code' => code, 'message' => message }
      }
    end

    # ==================================================================
    # Lifecycle
    # ==================================================================

    # Python parity: ``on_summary(self, summary, raw_data=None)`` is a
    # virtual hook called when a post-prompt summary is received.
    # Ruby supports two equivalent shapes:
    #
    # 1. **Registration** (Ruby idiom) — pass a block to install a
    #    callback. The block receives ``(summary, raw_data)`` when a
    #    summary is delivered. ``on_summary { |sum, raw| ... }``
    # 2. **Override** (Python idiom) — subclass and override
    #    ``on_summary(summary, raw_data = nil)``. Default
    #    implementation calls the registered block (if any) and
    #    otherwise no-ops.
    #
    # @param summary [Hash, nil] the post-prompt summary
    # @param raw_data [Hash, nil] the complete raw POST data
    # @yield [summary, raw_data] optional callback registration
    def on_summary(summary = nil, raw_data = nil, &block)
      if block
        @summary_callback = block
        return self
      end

      @summary_callback&.call(summary, raw_data)
      nil
    end

    def on_debug_event(&block)
      @debug_event_callback = block
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

      case mode
      when 'lambda'
        _run_lambda(event, context)
      when 'cgi'
        _run_cgi
      else
        serve(host: host, port: port)
      end
    end

    # @api private
    def _detect_run_mode
      return 'lambda' if ENV['AWS_LAMBDA_FUNCTION_NAME'] && !ENV['AWS_LAMBDA_FUNCTION_NAME'].empty?
      return 'cgi'    if ENV['GATEWAY_INTERFACE']

      'server'
    end

    # @api private
    def _run_lambda(event, _context)
      require 'stringio'
      event ||= {}
      path = event['path'] || event['rawPath'] || '/'
      method = event['httpMethod'] || event.dig('requestContext', 'http', 'method') || 'GET'
      env = rack_env(path: path, method: method, query: '', body: event['body'] || '')
      status, headers, response_body = rack_app.call(env)
      { 'statusCode' => Integer(status), 'headers' => headers, 'body' => join_rack_body(response_body) }
    end

    # Build a minimal Rack env hash for serverless/CGI invocation.
    def rack_env(path:, method:, query:, body:)
      {
        'PATH_INFO' => path,
        'REQUEST_METHOD' => method,
        'QUERY_STRING' => query,
        'rack.input' => StringIO.new(body),
        'rack.errors' => $stderr
      }
    end

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
    # Python parity: ``serve(host=None, port=None)``. ``host`` /
    # ``port`` overrides default to constructor-supplied values.
    def serve(host: nil, port: nil)
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

    def log_server_startup(bind_host, bind_port)
      @logger.info "Starting server on #{bind_host}:#{bind_port} ..."
      user, _pass = @basic_auth
      @logger.info "Basic-auth credentials — user: #{user}  password: [REDACTED]"
    end

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
      @rack_app ||= _build_rack_app
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

    def apply_dynamic_config(request_data, request)
      agent = _create_ephemeral_copy
      query_params = request ? _parse_query_string(request) : {}
      body_params  = request_data || {}
      headers      = request ? _extract_headers(request) : {}
      @dynamic_config_callback.call(query_params, body_params, headers, agent)
      agent
    rescue StandardError => e
      @logger.error "Dynamic config error: #{e.message}"
      agent
    end

    # @api private
    def _render_swml_internal
      sections_main = []
      sections_main.concat(verb_entries(@pre_answer_verbs))   # PHASE 1: pre-answer verbs
      sections_main << answer_entry if @auto_answer           # PHASE 2: answer verb
      sections_main << record_call_entry if @record_call      # PHASE 3a: record_call
      sections_main.concat(verb_entries(@post_answer_verbs))  # PHASE 3b: post-answer verbs
      sections_main << { 'ai' => _build_ai_config }           # PHASE 4: AI verb
      sections_main.concat(verb_entries(@post_ai_verbs))      # PHASE 5: post-AI verbs

      { 'version' => '1.0.0', 'sections' => { 'main' => sections_main } }
    end

    # Map a [[verb_name, config], ...] list into [{verb_name => config}, ...].
    def verb_entries(verbs)
      verbs.map { |verb_name, config| { verb_name => config } }
    end

    def answer_entry
      { 'answer' => @answer_config.empty? ? {} : @answer_config }
    end

    def record_call_entry
      { 'record_call' => { 'format' => @record_format, 'stereo' => @record_stereo } }
    end

    # Get the configured basic-auth credentials.
    #
    # Python parity: ``get_basic_auth_credentials(include_source=False)``.
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

    def matches_env_auth?(user, pass, env_user, env_pass)
      env_user && !env_user.empty? && env_pass && !env_pass.empty? && user == env_user && pass == env_pass
    end

    # ==================================================================
    # Private helpers
    # ==================================================================

    private

    # Build the AI verb configuration hash.
    def _build_ai_config
      ai = {}
      add_ai_prompt(ai)
      add_ai_post_prompt(ai)
      add_ai_swaig(ai)
      add_ai_collections(ai)
      add_ai_params(ai)
      ai['global_data'] = @global_data.dup unless @global_data.empty?
      add_ai_contexts(ai)
      ai['mcp_servers'] = @mcp_servers.map(&:dup) unless @mcp_servers.empty?
      ai
    end

    def add_ai_prompt(config)
      prompt = get_prompt
      key = prompt.is_a?(Array) ? 'pom' : 'text'
      return if prompt.nil? || prompt.empty?

      prompt_obj = { key => prompt }
      prompt_obj.merge!(@prompt_llm_params) unless @prompt_llm_params.empty?
      config['prompt'] = prompt_obj
    end

    def add_ai_post_prompt(config)
      return unless @post_prompt_text && !@post_prompt_text.empty?

      pp_obj = { 'text' => @post_prompt_text }
      pp_obj.merge!(@post_prompt_llm_params) unless @post_prompt_llm_params.empty?
      config['post_prompt'] = pp_obj
      config['post_prompt_url'] = (@post_prompt_url_override || _build_webhook_url('post_prompt'))
    end

    def add_ai_swaig(config)
      functions = _build_functions_array
      swaig = { 'defaults' => { 'web_hook_url' => swaig_default_url } }
      swaig['functions']        = functions          unless functions.empty?
      swaig['native_functions'] = @native_functions  unless @native_functions.empty?
      swaig['includes']         = @function_includes unless @function_includes.empty?
      swaig['internal_fillers'] = @internal_fillers  unless @internal_fillers.empty?
      config['SWAIG'] = swaig unless swaig.keys == ['defaults'] && functions.empty?
    end

    def swaig_default_url
      @web_hook_url_override ||
        _build_webhook_url('swaig', @swaig_query_params.empty? ? nil : @swaig_query_params)
    end

    def add_ai_collections(config)
      config['hints']     = @hints.dup     unless @hints.empty?
      config['languages'] = @languages.dup unless @languages.empty?
      config['pronounce'] = @pronounce.dup unless @pronounce.empty?
    end

    def add_ai_params(config)
      merged_params = @params.dup
      if @debug_events_enabled
        merged_params['debug_webhook_url']   = _build_webhook_url('debug_events')
        merged_params['debug_webhook_level'] = @debug_events_level
      end
      config['params'] = merged_params unless merged_params.empty?
    end

    def add_ai_contexts(config)
      return unless @context_builder

      config['contexts'] = @context_builder.to_h
    rescue ArgumentError
      # invalid context config — skip silently
    end

    # Build the functions array for the SWAIG section.
    def _build_functions_array
      functions = @tools.values.map { |tool| tool_function_entry(tool) }
      @swaig_functions.each_value { |func_def| functions << func_def.dup }
      functions
    end

    def tool_function_entry(tool)
      func_entry = tool[:definition].dup
      # Add a per-function webhook URL when there are query params. (Secure
      # tools get per-call URLs at request time — token isn't known yet at
      # render — so the default webhook URL handles their dispatch here.)
      if tool[:secure] || !@swaig_query_params.empty?
        qp = @swaig_query_params.dup
        func_entry['web_hook_url'] = _build_webhook_url('swaig', qp) unless qp.empty?
      end
      func_entry
    end

    # Build a webhook URL with optional query params.
    def _build_webhook_url(endpoint, query_params = nil)
      base = _base_url
      path = @route == '/' ? "/#{endpoint}" : "#{@route}/#{endpoint}"

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
    # +@route+ is appended by {#_build_webhook_url}. Never bake the
    # route into the base here, or a non-root agent deployed behind a
    # proxy will have its mount point silently dropped from webhook
    # URLs.
    def _base_url
      return @proxy_url_base.chomp('/') if @proxy_url_base && !@proxy_url_base.empty?

      if Runtime.lambda?
        lambda_base = Runtime.lambda_base_url
        if lambda_base
          user, pass = @basic_auth
          return _embed_auth(lambda_base, user, pass)
        end
      end

      user, pass = @basic_auth
      "http://#{user}:#{pass}@#{@host}:#{@port}"
    end

    # Embed basic-auth credentials into +base+ immediately after the
    # scheme. Returns +base+ untouched when either credential is blank
    # or the URL already contains an @-delimited userinfo component.
    def _embed_auth(base, user, pass)
      return base if blank?(user) || blank?(pass)

      uri = URI.parse(base)
      return base if uri.userinfo && !uri.userinfo.empty?

      uri.userinfo = "#{URI.encode_www_form_component(user)}:#{URI.encode_www_form_component(pass)}"
      uri.to_s
    rescue URI::InvalidURIError
      base
    end

    def blank?(str)
      str.nil? || str.empty?
    end

    # Normalise tool parameters into JSON-Schema form.
    def _normalise_parameters(params)
      return params if object_schema?(params)
      return { 'type' => 'object', 'properties' => {} } if params.nil? || params.empty?

      # If the hash looks like {name => {type, description}}, wrap it.
      return params unless params.is_a?(Hash) && !params.key?('type')

      { 'type' => 'object', 'properties' => params.transform_keys(&:to_s) }
    end

    def object_schema?(params)
      params.is_a?(Hash) && params['type'] == 'object'
    end

    # Create an ephemeral deep copy for dynamic config.
    def _create_ephemeral_copy
      copy = dup
      ephemeral_copy_values.each { |ivar, value| copy.instance_variable_set(ivar, value) }
      copy
    end

    # The deep-copied ivar => value pairs for {#_create_ephemeral_copy}. The
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
        :@internal_fillers => _deep_dup_hash(@internal_fillers),
        :@mcp_server_enabled => @mcp_server_enabled,
        :@dynamic_config_callback => nil
      }
    end

    # Deep-dup a hash of hashes
    def _deep_dup_hash(hash)
      hash.each_with_object({}) do |(k, v), result|
        result[k] = v.is_a?(Hash) ? v.dup : v
      end
    end

    # Parse query string from Rack request
    def _parse_query_string(request)
      return {} unless request.respond_to?(:env)

      qs = request.env['QUERY_STRING'] || ''
      URI.decode_www_form(qs).to_h
    rescue StandardError
      {}
    end

    # Extract headers from Rack request
    def _extract_headers(request)
      return {} unless request.respond_to?(:env)

      request.env.select { |k, _| k.start_with?('HTTP_') }
                 .transform_keys { |k| k.sub('HTTP_', '').downcase.tr('_', '-') }
    rescue StandardError
      {}
    end

    # ==================================================================
    # Rack app
    # ==================================================================

    def _build_rack_app
      agent = self
      main_route = @route
      authenticated = _build_authenticated_app
      Rack::Builder.new do
        # --- public endpoints (no auth) --------------------------------
        map('/health') { run ->(_env) { agent.send(:_static_status_response, 'healthy') } }
        map('/ready')  { run ->(_env) { agent.send(:_static_status_response, 'ready') } }
        # --- authenticated endpoints -----------------------------------
        map(main_route) { run authenticated }
      end
    end

    # The middleware stack + handler for the authenticated main route, as its
    # own Rack app so _build_rack_app stays a thin router.
    def _build_authenticated_app
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
        run ->(env) { agent.send(:_handle_main_request, env) }
      end
    end

    # Keyword args for the WebhookMiddleware `use`, or nil when no signing key.
    def webhook_middleware_args
      return nil if @signing_key.nil? || @signing_key.empty?

      { signing_key: @signing_key, trust_proxy: @trust_proxy_for_signature,
        paths: ['/', '/swaig', '/post_prompt'], methods: ['POST'] }
    end

    def _static_status_response(status)
      [200, { 'content-type' => 'application/json' }, [JSON.generate({ status: status })]]
    end

    # The authenticated main-route Rack handler: parse the body, then dispatch
    # to /swaig, the extra routes (/post_prompt, /debug_events, /mcp), or SWML.
    def _handle_main_request(env)
      request  = Rack::Request.new(env)
      sub_path = env['PATH_INFO'] || '/'
      sub_path = '/' if sub_path.empty?
      request_data = parse_request_body(request, env)

      # /swaig — handled by Service; dispatch uses on_function_call (which
      # AgentBase overrides for token validation).
      return _handle_swaig_endpoint(request, request_data, env) if sub_path == '/swaig'

      extra = handle_additional_route(sub_path, request_data, env)
      return extra if extra

      body = JSON.generate(render_swml(request_data, request: request))
      [200, { 'content-type' => 'application/json' }, [body]]
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

    def handle_additional_route(sub_path, request_data, env)
      case sub_path
      when '/post_prompt'  then _handle_post_prompt(request_data, env)
      when '/debug_events' then _handle_debug_events(request_data, env)
      when '/mcp'          then _handle_mcp_endpoint(request_data, env)
      end
    end

    # These methods must be accessible from the Rack lambda

    # _handle_swaig is now provided by Service (lifted as _handle_swaig_endpoint).
    # AgentBase still hooks the dispatch path via the on_function_call override
    # below, which adds session-token validation on top of Service's plain
    # registry lookup.

    # Handle post_prompt callback.
    # @api private
    def _handle_post_prompt(request_data, _env)
      invoke_summary_callback(request_data) if @summary_callback && request_data
      json_response(200, { 'status' => 'ok' })
    end

    def invoke_summary_callback(request_data)
      post_prompt_data = request_data['post_prompt_data']
      summary = nil
      summary = post_prompt_data['parsed'] || post_prompt_data['raw'] if post_prompt_data.is_a?(Hash)
      @summary_callback.call(summary, request_data)
    rescue StandardError => e
      @logger.error "Post-prompt callback error: #{e.message}"
    end

    # Handle debug events.
    # @api private
    def _handle_debug_events(request_data, _env)
      invoke_debug_event_callback(request_data) if @debug_event_callback && request_data
      json_response(200, { 'status' => 'ok' })
    end

    def invoke_debug_event_callback(request_data)
      event_type = request_data['event_type'] || 'unknown'
      @debug_event_callback.call(event_type, request_data)
    rescue StandardError => e
      @logger.error "Debug event callback error: #{e.message}"
    end

    # Handle MCP JSON-RPC 2.0 endpoint.
    # @api private
    def _handle_mcp_endpoint(request_data, _env)
      return json_response(404, { 'error' => 'MCP server not enabled' }) unless @mcp_server_enabled
      return json_response(400, _mcp_error(nil, -32_700, 'Parse error')) unless request_data

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

      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        HEADERS.each { |k, v| headers[k] = v }
        [status, headers, body]
      end
    end

    class AgentBodyLimitMiddleware
      def initialize(app, max_size)
        @app      = app
        @max_size = max_size
      end

      def call(env)
        if env['CONTENT_LENGTH'] && env['CONTENT_LENGTH'].to_i > @max_size
          body = JSON.generate({ 'error' => 'Request body too large' })
          return [413, { 'content-type' => 'application/json' }, [body]]
        end
        @app.call(env)
      end
    end

    class AgentTimingSafeBasicAuth
      def initialize(app, agent)
        @app   = app
        @agent = agent
      end

      def call(env)
        auth = Rack::Auth::Basic::Request.new(env)
        return _unauthorized unless auth.provided? && auth.basic?

        credentials_valid?(auth.credentials) ? @app.call(env) : _unauthorized
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

      def _unauthorized
        [
          401,
          {
            'content-type' => 'text/plain',
            'www-authenticate' => 'Basic realm="SignalWire Agent"'
          },
          ['Unauthorized']
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
    private :basic_auth_source, :build_context_builder_from_hash, :build_pattern_hint, :build_section
    private :build_subsection, :build_subsections, :build_tool_definition, :build_tool_param_schema
    private :coerce_function_result, :compound_voice?, :define_skill_tool, :find_or_create_section
    private :hash_language_form?, :invoke_debug_event_callback, :invoke_summary_callback, :join_rack_body
    private :keyword_hint_form?, :legacy_hint_form?, :legacy_pattern_hint, :log_server_startup
    private :matches_env_auth?, :mcp_input_schema, :mcp_tool_entry, :merge_skill_hints_and_data
    private :merge_skill_prompt_sections, :optional_tool_fields, :rack_env, :register_no_vowels_variation
    private :register_skill_tools, :replace_hint, :sanitize_sip_username, :section_pom_kwargs
    private :secure_token_ok?, :sym_or_str, :verb_entries, :warn_unexpected_function_result
    private :warn_unknown_filler_name, :warn_unknown_filler_names, :webrick_opts
    private :answer_entry, :record_call_entry, :webrick_handler
  end
end
