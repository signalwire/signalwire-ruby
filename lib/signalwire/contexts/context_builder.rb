# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

module SignalWire
  module Contexts
    MAX_CONTEXTS = 50
    MAX_STEPS_PER_CONTEXT = 100

    # Reserved tool names auto-injected by the runtime when contexts/steps
    # are present. User-defined SWAIG tools must not collide with these
    # names.
    #
    #   - next_step / change_context are injected when valid_steps or
    #     valid_contexts is set so the model can navigate the flow.
    #   - gather_submit is injected while a step's gather_info is
    #     collecting answers.
    #
    # ContextBuilder#validate! rejects any agent that registers a user
    # tool sharing one of these names — the runtime would never call the
    # user tool because the native one wins.
    RESERVED_NATIVE_TOOL_NAMES = %w[next_step change_context gather_submit].freeze

    # Represents a single question in a gather_info configuration.
    class GatherQuestion
      attr_accessor :key, :question, :type, :confirm, :prompt, :functions

      def initialize(key:, question:, type: 'string', confirm: false, prompt: nil, functions: nil)
        @key       = key
        @question  = question
        @type      = type
        @confirm   = confirm
        @prompt    = prompt
        @functions = functions
      end

      def to_h
        h = { "key" => @key, "question" => @question }
        h["type"]      = @type      if @type != 'string'
        h["confirm"]   = true       if @confirm
        h["prompt"]    = @prompt    if @prompt
        h["functions"] = @functions if @functions
        h
      end
    end

    # Configuration for gathering information in a step via the C-side gather_info system.
    class GatherInfo
      attr_accessor :output_key, :completion_action, :prompt
      attr_reader   :questions

      def initialize(output_key: nil, completion_action: nil, prompt: nil)
        @output_key        = output_key
        @completion_action = completion_action
        @prompt            = prompt
        @questions         = []
      end

      # Add a question. Returns +self+ for chaining.
      def add_question(key:, question:, **opts)
        @questions << GatherQuestion.new(
          key:       key,
          question:  question,
          type:      opts.fetch(:type, 'string'),
          confirm:   opts.fetch(:confirm, false),
          prompt:    opts[:prompt],
          functions: opts[:functions]
        )
        self
      end

      def to_h
        raise ArgumentError, "gather_info must have at least one question" if @questions.empty?

        h = { "questions" => @questions.map(&:to_h) }
        h["prompt"]            = @prompt            if @prompt
        h["output_key"]        = @output_key        if @output_key
        h["completion_action"] = @completion_action if @completion_action
        h
      end
    end

    # Represents a single step within a context.
    #
    # All mutator methods return +self+ for fluent chaining.
    class Step
      attr_reader :name

      def initialize(name)
        @name = name
        @text = nil
        @step_criteria   = nil
        @functions       = nil  # nil | "none" | Array<String>
        @valid_steps     = nil
        @valid_contexts  = nil
        @sections        = []
        @gather_info     = nil

        # Behavior flags
        @end              = false
        @skip_user_turn   = false
        @skip_to_next_step = false

        # Reset object for context-switching from steps
        @reset_system_prompt = nil
        @reset_user_prompt   = nil
        @reset_consolidate   = false
        @reset_full_reset    = false
      end

      # Set the step's prompt text directly. Mutually exclusive with POM sections.
      def set_text(text)
        raise ArgumentError, "Cannot use set_text when POM sections have been added" if @sections.any?

        @text = text
        self
      end

      # Add a POM section (title + body). Mutually exclusive with +set_text+.
      def add_section(title, body)
        raise ArgumentError, "Cannot add POM sections when set_text has been used" unless @text.nil?

        @sections << { "title" => title, "body" => body }
        self
      end

      # Add a POM section with bullet points. Mutually exclusive with +set_text+.
      def add_bullets(title, bullets)
        raise ArgumentError, "Cannot add POM sections when set_text has been used" unless @text.nil?

        @sections << { "title" => title, "bullets" => bullets }
        self
      end

      def set_step_criteria(criteria)
        @step_criteria = criteria
        self
      end

      # Set which non-internal functions are callable while this step is
      # active.
      #
      # IMPORTANT — inheritance behavior:
      #   If you do NOT call this method, the step inherits whichever
      #   function set was active on the previous step (or the previous
      #   context's last step). The server-side runtime only resets the
      #   active set when a step explicitly declares its +functions+
      #   field. This is the most common source of bugs in multi-step
      #   agents: forgetting +set_functions+ on a later step lets the
      #   previous step's tools leak through. Best practice is to call
      #   +set_functions+ explicitly on every step that should differ
      #   from the previous one.
      #
      # Keep the per-step active set small: LLM tool selection accuracy
      # degrades noticeably past ~7-8 simultaneously-active tools per
      # call. Use per-step whitelisting to partition large tool
      # collections.
      #
      # Internal functions (e.g. +gather_submit+, hangup hook) are
      # ALWAYS protected and cannot be deactivated by this whitelist.
      # The native navigation tools +next_step+ and +change_context+ are
      # injected automatically when +set_valid_steps+/+set_valid_contexts+
      # is used; they are not affected by this list and do not need to
      # appear in it.
      #
      # @param functions [String, Array<String>] one of:
      #   - Array<String> — whitelist of function names allowed in this
      #     step. Functions not in the list become inactive.
      #   - [] — explicit disable-all (no user functions callable).
      #   - "none" — synonym for [], same effect.
      def set_functions(functions)
        @functions = functions
        self
      end

      def set_valid_steps(steps)
        @valid_steps = steps
        self
      end

      def set_valid_contexts(contexts)
        @valid_contexts = contexts
        self
      end

      # Mark this step as terminal for the step flow.
      #
      # IMPORTANT: +is_end+ = true does NOT end the conversation or hang
      # up the call. It exits step mode entirely after this step
      # executes — clearing the steps list, current step index,
      # valid_steps, and valid_contexts. The agent keeps running, but
      # operates only under the base system prompt and the
      # context-level prompt; no more step instructions are injected
      # and no more +next_step+ tool is offered.
      #
      # To actually end the call, call a hangup tool or define a
      # hangup hook.
      def set_end(is_end)
        @end = is_end
        self
      end

      def set_skip_user_turn(skip)
        @skip_user_turn = skip
        self
      end

      def set_skip_to_next_step(skip)
        @skip_to_next_step = skip
        self
      end

      # Enable info gathering for this step. Returns +self+.
      # After calling this, use +add_gather_question+ to define questions.
      def set_gather_info(output_key: nil, completion_action: nil, prompt: nil)
        @gather_info = GatherInfo.new(
          output_key:        output_key,
          completion_action: completion_action,
          prompt:            prompt
        )
        self
      end

      # Add a question to this step's gather_info configuration.
      # +set_gather_info+ must be called first.
      #
      # IMPORTANT — gather mode locks function access:
      #   While the model is asking gather questions, the runtime
      #   forcibly deactivates ALL of the step's other functions. The
      #   only callable tools during a gather question are:
      #
      #     - +gather_submit+ (the native answer-submission tool)
      #     - Whatever names you pass in this question's +functions:+
      #       option
      #
      #   +next_step+ and +change_context+ are also filtered out — the
      #   model cannot navigate away until the gather completes. This
      #   is by design: it forces a tight ask → submit → next-question
      #   loop.
      #
      #   If a question needs to call out to a tool (e.g. validate an
      #   email, geocode a ZIP), pass that tool name in this question's
      #   +functions:+ option. Functions listed here are active ONLY for
      #   this question.
      # Python parity: ``add_gather_question(key, question, type='string',
      # confirm=False, prompt=None, functions=None)``. Ruby exposes the
      # same parameter set as keyword args.
      def add_gather_question(key:, question:, type: 'string', confirm: false,
                              prompt: nil, functions: nil)
        raise ArgumentError, "Must call set_gather_info before add_gather_question" if @gather_info.nil?

        @gather_info.add_question(
          key:       key,
          question:  question,
          type:      type,
          confirm:   confirm,
          prompt:    prompt,
          functions: functions
        )
        self
      end

      # Remove all POM sections and direct text.
      def clear_sections
        @sections = []
        @text = nil
        self
      end

      def set_reset_system_prompt(prompt)
        @reset_system_prompt = prompt
        self
      end

      def set_reset_user_prompt(prompt)
        @reset_user_prompt = prompt
        self
      end

      def set_reset_consolidate(val)
        @reset_consolidate = val
        self
      end

      def set_reset_full_reset(val)
        @reset_full_reset = val
        self
      end

      def to_h
        step_h = {
          "name" => @name,
          "text" => render_text
        }

        step_h["step_criteria"]    = @step_criteria   if @step_criteria
        step_h["functions"]        = @functions        unless @functions.nil?
        step_h["valid_steps"]      = @valid_steps      if @valid_steps
        step_h["valid_contexts"]   = @valid_contexts   if @valid_contexts
        step_h["end"]              = true               if @end
        step_h["skip_user_turn"]   = true               if @skip_user_turn
        step_h["skip_to_next_step"] = true              if @skip_to_next_step

        reset = {}
        reset["system_prompt"] = @reset_system_prompt if @reset_system_prompt
        reset["user_prompt"]   = @reset_user_prompt   if @reset_user_prompt
        reset["consolidate"]   = @reset_consolidate   if @reset_consolidate
        reset["full_reset"]    = @reset_full_reset    if @reset_full_reset
        step_h["reset"] = reset if reset.any?

        step_h["gather_info"] = @gather_info.to_h if @gather_info

        step_h
      end

      # --- Idiomatic Ruby accessors (additive aliases over the get_/set_ originals) ---
      #
      # Writers use the block `def x=(v); set_x(v); end` form so the RHS is
      # returned (Ruby `=` semantics), not `self`. The chainable `set_*`
      # originals stay available and untouched.
      #
      # Skipped: set_end (`end=` is a Ruby keyword, illegal method name);
      # set_gather_info (keyword args, not a single-value setter).
      def text=(v)
        set_text(v)
      end

      def step_criteria=(v)
        set_step_criteria(v)
      end

      def functions=(v)
        set_functions(v)
      end

      def valid_steps=(v)
        set_valid_steps(v)
      end

      def valid_contexts=(v)
        set_valid_contexts(v)
      end

      def skip_user_turn=(v)
        set_skip_user_turn(v)
      end

      def skip_to_next_step=(v)
        set_skip_to_next_step(v)
      end

      def reset_system_prompt=(v)
        set_reset_system_prompt(v)
      end

      def reset_user_prompt=(v)
        set_reset_user_prompt(v)
      end

      def reset_consolidate=(v)
        set_reset_consolidate(v)
      end

      def reset_full_reset=(v)
        set_reset_full_reset(v)
      end

      private

      def render_text
        return @text if @text

        raise ArgumentError, "Step '#{@name}' has no text or POM sections defined" if @sections.empty?

        parts = []
        @sections.each do |section|
          if section.key?("bullets")
            parts << "## #{section['title']}"
            section["bullets"].each { |b| parts << "- #{b}" }
          else
            parts << "## #{section['title']}"
            parts << section["body"]
          end
          parts << "" # spacing
        end
        parts.join("\n").strip
      end
    end

    # Represents a single context containing multiple steps.
    class Context
      attr_reader :name

      def initialize(name)
        @name = name
        @steps      = {}   # name => Step
        @step_order = []

        # Navigation
        @valid_contexts = nil
        @valid_steps    = nil
        @initial_step   = nil

        # Context entry parameters
        @post_prompt     = nil
        @system_prompt   = nil
        @system_prompt_sections = []
        @consolidate     = false
        @full_reset      = false
        @user_prompt     = nil
        @isolated        = false

        # Context prompt
        @prompt_text     = nil
        @prompt_sections = []

        # Fillers
        @enter_fillers = nil
        @exit_fillers  = nil
      end

      # Add a new step. Returns the new Step object (not self).
      #
      # Python parity: ``Context.add_step(name, *, task=None, bullets=None,
      # criteria=None, functions=None, valid_steps=None)``. The optional
      # keyword arguments give a one-call configuration shortcut:
      #
      #   ctx.add_step("greet",
      #     task: "Greet the caller",
      #     bullets: ["Say hi", "Ask how can I help"],
      #     criteria: "User has been greeted",
      #     functions: ["weather"],
      #     valid_steps: ["help"])
      #
      # Without the optional args this stays the bare ``add_step("greet")``
      # form that returns a Step for further fluent configuration.
      def add_step(name, task: nil, bullets: nil, criteria: nil,
                   functions: nil, valid_steps: nil)
        raise ArgumentError, "Step '#{name}' already exists in context '#{@name}'" if @steps.key?(name)
        raise ArgumentError, "Maximum steps per context (#{MAX_STEPS_PER_CONTEXT}) exceeded" if @steps.size >= MAX_STEPS_PER_CONTEXT

        step = Step.new(name)
        @steps[name] = step
        @step_order << name

        step.add_section('Task', task)        unless task.nil?
        step.add_bullets('Process', bullets)  unless bullets.nil?
        step.set_step_criteria(criteria)      unless criteria.nil?
        step.set_functions(functions)         unless functions.nil?
        step.set_valid_steps(valid_steps)     unless valid_steps.nil?

        step
      end

      # Get an existing step by name. Returns Step or nil.
      def get_step(name)
        @steps[name]
      end

      # Remove a step by name. Returns self.
      def remove_step(name)
        if @steps.key?(name)
          @steps.delete(name)
          @step_order.delete(name)
        end
        self
      end

      # Move an existing step to a specific position. Returns self.
      def move_step(name, position)
        raise ArgumentError, "Step '#{name}' not found in context '#{@name}'" unless @steps.key?(name)

        @step_order.delete(name)
        @step_order.insert(position, name)
        self
      end

      # Set which step the context starts on when entered.
      #
      # By default, a context starts on its first step (index 0). Use
      # this to skip a preamble step on re-entry via +change_context+.
      #
      # @param step_name [String] name of the step to start on.
      def set_initial_step(step_name)
        @initial_step = step_name
        self
      end

      def set_valid_contexts(contexts)
        @valid_contexts = contexts
        self
      end

      def set_valid_steps(steps)
        @valid_steps = steps
        self
      end

      def set_post_prompt(prompt)
        @post_prompt = prompt
        self
      end

      def set_system_prompt(prompt)
        raise ArgumentError, "Cannot use set_system_prompt when POM system sections exist" if @system_prompt_sections.any?

        @system_prompt = prompt
        self
      end

      def set_prompt(prompt)
        raise ArgumentError, "Cannot use set_prompt when POM prompt sections exist" if @prompt_sections.any?

        @prompt_text = prompt
        self
      end

      def set_consolidate(val)
        @consolidate = val
        self
      end

      def set_full_reset(val)
        @full_reset = val
        self
      end

      def set_user_prompt(prompt)
        @user_prompt = prompt
        self
      end

      # Mark this context as isolated — entering it wipes conversation
      # history.
      #
      # When +val+ = true and the context is entered via change_context,
      # the runtime wipes the conversation array. The model starts
      # fresh with only the new context's system_prompt + step
      # instructions, with no memory of prior turns.
      #
      # EXCEPTION — reset overrides the wipe:
      #   If the context also has a reset configuration (via
      #   +set_consolidate+ or +set_full_reset+), the wipe is skipped in
      #   favor of the reset behavior. Use reset with consolidate=true
      #   to summarize prior history into a single message instead of
      #   dropping it entirely.
      #
      # Use cases: switching to a sensitive billing flow that should
      # not see prior small-talk; handing off to a different agent
      # persona; resetting after a long off-topic detour.
      def set_isolated(val)
        @isolated = val
        self
      end

      # Add a POM section to the context prompt.
      def add_section(title, body)
        raise ArgumentError, "Cannot add POM sections when set_prompt has been used" unless @prompt_text.nil?

        @prompt_sections << { "title" => title, "body" => body }
        self
      end

      # Add a POM section with bullets to the context prompt.
      def add_bullets(title, bullets)
        raise ArgumentError, "Cannot add POM sections when set_prompt has been used" unless @prompt_text.nil?

        @prompt_sections << { "title" => title, "bullets" => bullets }
        self
      end

      # Add a POM section to the system prompt.
      def add_system_section(title, body)
        raise ArgumentError, "Cannot add POM system sections when set_system_prompt has been used" unless @system_prompt.nil?

        @system_prompt_sections << { "title" => title, "body" => body }
        self
      end

      # Add a POM section with bullets to the system prompt.
      def add_system_bullets(title, bullets)
        raise ArgumentError, "Cannot add POM system sections when set_system_prompt has been used" unless @system_prompt.nil?

        @system_prompt_sections << { "title" => title, "bullets" => bullets }
        self
      end

      def set_enter_fillers(fillers)
        @enter_fillers = fillers if fillers.is_a?(Hash) && fillers.any?
        self
      end

      def set_exit_fillers(fillers)
        @exit_fillers = fillers if fillers.is_a?(Hash) && fillers.any?
        self
      end

      def add_enter_filler(lang_code, fillers)
        if lang_code && fillers.is_a?(Array) && fillers.any?
          @enter_fillers ||= {}
          @enter_fillers[lang_code] = fillers
        end
        self
      end

      def add_exit_filler(lang_code, fillers)
        if lang_code && fillers.is_a?(Array) && fillers.any?
          @exit_fillers ||= {}
          @exit_fillers[lang_code] = fillers
        end
        self
      end

      def to_h
        raise ArgumentError, "Context '#{@name}' has no steps defined" if @steps.empty?

        ctx = {
          "steps" => @step_order.map { |n| @steps[n].to_h }
        }

        ctx["valid_contexts"] = @valid_contexts if @valid_contexts
        ctx["valid_steps"]    = @valid_steps    if @valid_steps
        ctx["initial_step"]   = @initial_step   if @initial_step
        ctx["post_prompt"]    = @post_prompt    if @post_prompt

        sys = render_system_prompt
        ctx["system_prompt"] = sys if sys

        ctx["consolidate"]  = @consolidate  if @consolidate
        ctx["full_reset"]   = @full_reset   if @full_reset
        ctx["user_prompt"]  = @user_prompt  if @user_prompt
        ctx["isolated"]     = @isolated     if @isolated

        if @prompt_sections.any?
          ctx["pom"] = @prompt_sections
        elsif @prompt_text
          ctx["prompt"] = @prompt_text
        end

        ctx["enter_fillers"] = @enter_fillers if @enter_fillers
        ctx["exit_fillers"]  = @exit_fillers  if @exit_fillers

        ctx
      end

      # --- Idiomatic Ruby accessors (additive aliases over the get_/set_ originals) ---
      #
      # Writers use the block `def x=(v); set_x(v); end` form so the RHS is
      # returned (Ruby `=` semantics), not `self`. The chainable `set_*`
      # originals stay available and untouched.
      #
      # Skipped: get_step / get_context (take a required `name` arg — lookups,
      # not bare accessors).
      def initial_step=(v)
        set_initial_step(v)
      end

      def valid_contexts=(v)
        set_valid_contexts(v)
      end

      def valid_steps=(v)
        set_valid_steps(v)
      end

      def post_prompt=(v)
        set_post_prompt(v)
      end

      def system_prompt=(v)
        set_system_prompt(v)
      end

      def prompt=(v)
        set_prompt(v)
      end

      def consolidate=(v)
        set_consolidate(v)
      end

      def full_reset=(v)
        set_full_reset(v)
      end

      def user_prompt=(v)
        set_user_prompt(v)
      end

      def isolated=(v)
        set_isolated(v)
      end

      def enter_fillers=(v)
        set_enter_fillers(v)
      end

      def exit_fillers=(v)
        set_exit_fillers(v)
      end

      # Expose internal state for validation
      # @api private
      def _steps;        @steps;        end
      def _step_order;   @step_order;   end
      def _initial_step; @initial_step; end

      private

      def render_system_prompt
        return @system_prompt if @system_prompt
        return nil if @system_prompt_sections.empty?

        render_sections(@system_prompt_sections)
      end

      def render_sections(sections)
        parts = []
        sections.each do |s|
          if s.key?("bullets")
            parts << "## #{s['title']}"
            s["bullets"].each { |b| parts << "- #{b}" }
          else
            parts << "## #{s['title']}"
            parts << s["body"]
          end
          parts << ""
        end
        parts.join("\n").strip
      end
    end

    # Builder for multi-step, multi-context AI agent workflows.
    #
    # A ContextBuilder owns one or more Contexts; each Context owns an
    # ordered list of Steps. Only one context and one step is active at
    # a time. Per chat turn, the runtime injects the current step's
    # instructions as a system message, then asks the LLM for a
    # response.
    #
    # == Native tools auto-injected by the runtime
    #
    # When a step (or its enclosing context) declares +valid_steps+ or
    # +valid_contexts+, the runtime auto-injects two native tools so
    # the model can navigate the flow:
    #
    #   - +next_step(step: enum)+         — present when valid_steps is set
    #   - +change_context(context: enum)+ — present when valid_contexts is set
    #
    # Their +enum+ schemas are rewritten on every turn to match
    # whatever valid_steps / valid_contexts apply to the current step.
    # You do NOT need to define these tools yourself; they appear
    # automatically.
    #
    # A third native tool — +gather_submit+ — is injected during
    # gather_info questioning (see Step#set_gather_info /
    # Step#add_gather_question).
    #
    # These three names — +next_step+, +change_context+,
    # +gather_submit+ — are reserved. +validate!+ will reject any agent
    # that defines a SWAIG tool with one of these names. See
    # RESERVED_NATIVE_TOOL_NAMES.
    #
    # == Function whitelisting (Step#set_functions)
    #
    # Each step may declare a +functions+ whitelist. The whitelist is
    # applied in-memory at the start of each LLM turn. CRITICALLY: if a
    # step does NOT declare a +functions+ field, it INHERITS the
    # previous step's active set. See Step#set_functions for details
    # and examples.
    class ContextBuilder
      # Python parity: ``ContextBuilder.__init__(self, agent)`` accepts
      # an owning agent so ``validate!`` can introspect registered
      # SWAIG tools when checking for reserved-name collisions.
      # Ruby allows nil for standalone use (tests, idiom of building
      # a builder before attaching).
      def initialize(agent = nil)
        @contexts      = {}   # name => Context
        @context_order = []
        @agent         = agent
      end

      # Attach an agent reference so +validate!+ can check
      # user-defined tool names against RESERVED_NATIVE_TOOL_NAMES.
      # Called internally by AgentBase#define_contexts.
      def attach_agent(agent)
        @agent = agent
        self
      end

      # Remove all contexts, returning the builder to its initial state.
      # Use this in a dynamic config callback when you need to rebuild
      # contexts from scratch for a specific request.
      def reset
        @contexts.clear
        @context_order.clear
        self
      end

      # Add a new context. Returns the Context object.
      def add_context(name)
        raise ArgumentError, "Context '#{name}' already exists" if @contexts.key?(name)
        raise ArgumentError, "Maximum number of contexts (#{MAX_CONTEXTS}) exceeded" if @contexts.size >= MAX_CONTEXTS

        ctx = Context.new(name)
        @contexts[name] = ctx
        @context_order << name
        ctx
      end

      # Get an existing context by name. Returns Context or nil.
      def get_context(name)
        @contexts[name]
      end

      # Validate the full configuration. Raises ArgumentError on problems.
      def validate!
        raise ArgumentError, "At least one context must be defined" if @contexts.empty?

        # Single context must be named "default"
        if @contexts.size == 1
          ctx_name = @contexts.keys.first
          raise ArgumentError, "When using a single context, it must be named 'default'" if ctx_name != 'default'
        end

        # Each context must have at least one step
        @contexts.each do |ctx_name, ctx|
          raise ArgumentError, "Context '#{ctx_name}' must have at least one step" if ctx._steps.empty?
        end

        # Validate initial_step references a real step in the context
        @contexts.each do |ctx_name, ctx|
          is = ctx._initial_step
          if is && !ctx._steps.key?(is)
            available = ctx._steps.keys.sort
            raise ArgumentError,
                  "Context '#{ctx_name}' has initial_step='#{is}' but that step does " \
                  "not exist. Available steps: #{available.inspect}"
          end
        end

        # Validate step references in valid_steps
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            step_h = step.to_h
            if step_h["valid_steps"]
              step_h["valid_steps"].each do |vs|
                next if vs == "next"
                unless ctx._steps.key?(vs)
                  raise ArgumentError,
                        "Step '#{step_name}' in context '#{ctx_name}' references unknown step '#{vs}'"
                end
              end
            end
          end
        end

        # Validate context references at context level
        @contexts.each do |ctx_name, ctx|
          ctx_h = ctx.to_h
          if ctx_h["valid_contexts"]
            ctx_h["valid_contexts"].each do |vc|
              unless @contexts.key?(vc)
                raise ArgumentError,
                      "Context '#{ctx_name}' references unknown context '#{vc}'"
              end
            end
          end
        end

        # Validate context references at step level
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            step_h = step.to_h
            if step_h["valid_contexts"]
              step_h["valid_contexts"].each do |vc|
                unless @contexts.key?(vc)
                  raise ArgumentError,
                        "Step '#{step_name}' in context '#{ctx_name}' references unknown context '#{vc}'"
                end
              end
            end
          end
        end

        # Validate gather_info configurations
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            step_h = step.to_h
            next unless step_h.key?("gather_info")

            gi = step_h["gather_info"]
            questions = gi["questions"] || []
            raise ArgumentError,
                  "Step '#{step_name}' in context '#{ctx_name}' has gather_info with no questions" if questions.empty?

            keys_seen = Set.new
            questions.each do |q|
              raise ArgumentError,
                    "Step '#{step_name}' in context '#{ctx_name}' has duplicate gather_info question key '#{q['key']}'" if keys_seen.include?(q["key"])
              keys_seen << q["key"]
            end

            action = gi["completion_action"]
            if action
              if action == "next_step"
                idx = ctx._step_order.index(step_name)
                if idx >= ctx._step_order.size - 1
                  raise ArgumentError,
                        "Step '#{step_name}' in context '#{ctx_name}' has gather_info " \
                        "completion_action='next_step' but it is the last step in the " \
                        "context. Either (1) add another step after '#{step_name}', " \
                        "(2) set completion_action to the name of an existing step in " \
                        "this context to jump to it, or (3) set completion_action=nil " \
                        "(default) to stay in '#{step_name}' after gathering completes."
                end
              elsif !ctx._steps.key?(action)
                available = ctx._steps.keys.sort
                raise ArgumentError,
                      "Step '#{step_name}' in context '#{ctx_name}' has gather_info " \
                      "completion_action='#{action}' but '#{action}' is not a step in " \
                      "this context. Valid options: 'next_step' (advance to the next " \
                      "sequential step), nil (stay in the current step), or one of " \
                      "#{available.inspect}."
              end
            end
          end
        end

        # Validate that user-defined tools do not collide with reserved
        # native tool names. The runtime auto-injects next_step /
        # change_context / gather_submit when contexts/steps are
        # present, so user tools sharing those names would never be
        # called.
        if @agent && @agent.respond_to?(:list_tool_names)
          registered = @agent.list_tool_names.to_a
          colliding = registered.select { |n| RESERVED_NATIVE_TOOL_NAMES.include?(n) }.sort.uniq
          if colliding.any?
            raise ArgumentError,
                  "Tool name(s) #{colliding.inspect} collide with reserved native " \
                  "tools auto-injected by contexts/steps. The names " \
                  "#{RESERVED_NATIVE_TOOL_NAMES.sort.inspect} are reserved and " \
                  "cannot be used for user-defined SWAIG tools when contexts/steps " \
                  "are in use. Rename your tool(s) to avoid the collision."
          end
        end

        true
      end

      def to_h
        validate!
        result = {}
        @context_order.each do |name|
          result[name] = @contexts[name].to_h
        end
        result
      end
    end

    # Helper to create a standalone context (not via ContextBuilder).
    def self.create_simple_context(name = 'default')
      Context.new(name)
    end
  end
end
