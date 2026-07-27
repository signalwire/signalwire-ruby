# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

module SignalWire
  module Contexts
    MAX_CONTEXTS = 50
    MAX_STEPS_PER_CONTEXT = 100

    # Valid values for a step's or context's +history+ visibility mode,
    # controlling what the model still sees when a step is entered:
    #
    #   - "keep"     nothing is cleared — every prior step's instructions
    #                *and* dialogue stay in the model's context.
    #   - "default"  prior step instructions are hidden; the dialogue is kept.
    #   - "hide"     prior instructions hidden **and** the prior dialogue
    #                pulled out of the model's context. The only way back in
    #                is an explicit ${step_history.*} reference in the new
    #                prompt.
    HISTORY_MODES = %w[keep default hide].freeze

    # Validate a history mode against HISTORY_MODES, raising ArgumentError
    # (Ruby's idiomatic validation error, like the other validated setters)
    # when it is not one of the three. Returns the mode on success.
    def self._validate_history(mode)
      return mode if HISTORY_MODES.include?(mode)

      raise ArgumentError, "history must be one of #{HISTORY_MODES.inspect}, got #{mode.inspect}"
    end

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

    # Render an ordered list of POM sections to the markdown text the
    # runtime expects: a "## <title>" heading per section, followed by
    # bullet lines ("- <b>") when the section has +bullets+, or the raw
    # +body+ otherwise. Shared by Step and Context so the byte-for-byte
    # output stays identical across both.
    def self._render_pom_sections(sections)
      sections.flat_map { |section| _render_section(section) }.join("\n").strip
    end

    # One section's lines: a "## <title>" heading, then bullet ("- <b>") lines
    # or the raw body, then a blank spacer line.
    def self._render_section(section)
      lines = ["## #{section['title']}"]
      if section.key?('bullets')
        section['bullets'].each { |b| lines << "- #{b}" }
      else
        lines << section['body']
      end
      lines << '' # spacing
      lines
    end

    # Represents a single question in a gather_info configuration.
    class GatherQuestion
      attr_accessor :key, :question, :type, :confirm, :prompt, :functions, :isolated

      # +isolated+ is TRI-STATE: +nil+ inherits the gather's default, +true+
      # hides the sibling Q&A while this question is asked, +false+ keeps it
      # visible even inside an isolated gather.
      def initialize(key:, question:, type: 'string', confirm: false, prompt: nil,
                     functions: nil, isolated: nil)
        @key       = key
        @question  = question
        @type      = type
        @confirm   = confirm
        @prompt    = prompt
        @functions = functions
        # Tri-state: nil means "inherit the gather_info default"
        @isolated  = isolated
      end

      def to_h
        h = { 'key' => @key, 'question' => @question }
        h['type']      = @type      if @type != 'string'
        h['confirm']   = true       if @confirm
        h['prompt']    = @prompt    if @prompt
        h['functions'] = @functions if @functions
        # Emitted even when false, so it can override an isolated gather
        h['isolated'] = @isolated unless @isolated.nil?
        h
      end
    end

    # Configuration for gathering information in a step via the C-side gather_info system.
    class GatherInfo
      attr_accessor :output_key, :completion_action, :prompt
      attr_reader   :questions

      # +isolated+ is the default for every question in this gather: when
      # true, each question is asked with the sibling Q&A hidden from the
      # model. A question's own +isolated:+ overrides this default. Held
      # privately, matching the reference's `self._isolated`.
      def initialize(output_key: nil, completion_action: nil, prompt: nil, isolated: false)
        @output_key        = output_key
        @completion_action = completion_action
        @prompt            = prompt
        @isolated          = isolated
        @questions         = []
      end

      # Add a question. Returns +self+ for chaining.
      def add_question(key:, question:, **opts)
        @questions << GatherQuestion.new(
          key: key,
          question: question,
          type: opts.fetch(:type, 'string'),
          confirm: opts.fetch(:confirm, false),
          prompt: opts[:prompt],
          functions: opts[:functions],
          isolated: opts[:isolated]
        )
        self
      end

      def to_h
        raise ArgumentError, 'gather_info must have at least one question' if @questions.empty?

        h = { 'questions' => @questions.map(&:to_h) }
        h['prompt']            = @prompt            if @prompt
        h['output_key']        = @output_key        if @output_key
        h['completion_action'] = @completion_action if @completion_action
        h['isolated']          = true               if @isolated
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
        @text = @step_criteria = @valid_steps = @valid_contexts = @gather_info = nil
        @functions = nil # nil | "none" | Array<String>
        @sections = []

        # Behavior flags, plus history visibility mode ("keep" | "default" |
        # "hide"; nil = unset).
        @end = @skip_user_turn = @skip_to_next_step = false
        @history = nil

        # Reset object for context-switching from steps
        @reset_system_prompt = @reset_user_prompt = nil
        @reset_consolidate = @reset_full_reset = false
      end

      # Set the step's prompt text directly. Mutually exclusive with POM sections.
      def set_text(text)
        raise ArgumentError, 'Cannot use set_text when POM sections have been added' if @sections.any?

        @text = text
        self
      end

      # Add a POM section (title + body). Mutually exclusive with +set_text+.
      def add_section(title, body)
        raise ArgumentError, 'Cannot add POM sections when set_text has been used' unless @text.nil?

        @sections << { 'title' => title, 'body' => body }
        self
      end

      # Add a POM section with bullet points. Mutually exclusive with +set_text+.
      def add_bullets(title, bullets)
        raise ArgumentError, 'Cannot add POM sections when set_text has been used' unless @text.nil?

        @sections << { 'title' => title, 'bullets' => bullets }
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

      # Control what the model still sees when this step is entered.
      #
      # +history+ is one of:
      #   - "keep":    clear nothing. Every prior step's instructions and
      #                dialogue stay visible to the model.
      #   - "default": hide the prior step *instructions*, keep the
      #                user/assistant dialogue. This is the effective
      #                behavior when unset.
      #   - "hide":    hide the prior instructions AND pull the prior
      #                dialogue out of the model's context.
      #
      # A step's own +set_history+ overrides the enclosing context's default.
      # Returns +self+ for chaining. Raises ArgumentError if +history+ is not
      # one of the three modes.
      def set_history(history)
        @history = Contexts._validate_history(history)
        self
      end

      # Enable info gathering for this step. Returns +self+.
      # After calling this, use +add_gather_question+ to define questions.
      #
      # +isolated+ is the default for every question in this gather. When
      # true, a question is asked with the sibling Q&A hidden from the model,
      # so it must ask rather than derive the answer from an earlier one. A
      # question's own +isolated:+ overrides this. The hidden turns remain in
      # the call log.
      def set_gather_info(output_key: nil, completion_action: nil, prompt: nil, isolated: false)
        @gather_info = GatherInfo.new(
          output_key: output_key,
          completion_action: completion_action,
          prompt: prompt,
          isolated: isolated
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
      # The +type+, +confirm+, +prompt+, +functions+ and +isolated+ options
      # are all optional keyword args.
      #
      #   +isolated+ overrides the gather's +isolated+ default for this one
      #   question. True hides the sibling Q&A while this question is asked;
      #   false keeps it visible even in an isolated gather. nil (default)
      #   inherits the gather's setting.
      def add_gather_question(key:, question:, type: 'string', confirm: false,
                              prompt: nil, functions: nil, isolated: nil)
        raise ArgumentError, 'Must call set_gather_info before add_gather_question' if @gather_info.nil?

        @gather_info.add_question(
          key: key, question: question, type: type, confirm: confirm,
          prompt: prompt, functions: functions, isolated: isolated
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
        step_h = { 'name' => @name, 'text' => render_text }
        add_step_fields(step_h)

        reset = reset_hash
        step_h['reset'] = reset if reset.any?
        step_h['gather_info'] = @gather_info.to_h if @gather_info
        step_h
      end

      def add_step_fields(step_h)
        step_h['step_criteria']  = @step_criteria if @step_criteria
        step_h['functions']      = @functions     unless @functions.nil?
        step_h['valid_steps']    = @valid_steps    if @valid_steps
        step_h['valid_contexts'] = @valid_contexts if @valid_contexts
        step_h['history']        = @history        if @history
        add_step_flags(step_h)
      end
      private :add_step_fields

      def add_step_flags(step_h)
        step_h['end']               = true if @end
        step_h['skip_user_turn']    = true if @skip_user_turn
        step_h['skip_to_next_step'] = true if @skip_to_next_step
      end
      private :add_step_flags

      def reset_hash
        reset = {}
        reset['system_prompt'] = @reset_system_prompt if @reset_system_prompt
        reset['user_prompt']   = @reset_user_prompt   if @reset_user_prompt
        reset['consolidate']   = @reset_consolidate   if @reset_consolidate
        reset['full_reset']    = @reset_full_reset    if @reset_full_reset
        reset
      end
      private :reset_hash

      # --- Idiomatic Ruby accessors (additive aliases over the get_/set_ originals) ---
      #
      # Writers use the block `def x=(v); set_x(v); end` form so the RHS is
      # returned (Ruby `=` semantics), not `self`. The chainable `set_*`
      # originals stay available and untouched.
      #
      # Skipped: set_end (`end=` is a Ruby keyword, illegal method name);
      # set_gather_info (keyword args, not a single-value setter). Each writer
      # delegates to its chainable `set_*` original but returns the RHS (Ruby
      # `=` semantics). Generated so the list stays a single source of truth.
      %i[text step_criteria functions valid_steps valid_contexts skip_user_turn
         skip_to_next_step history reset_system_prompt reset_user_prompt
         reset_consolidate reset_full_reset].each do |attr|
        define_method("#{attr}=") { |value| send("set_#{attr}", value) }
      end

      private

      def render_text
        return @text if @text

        raise ArgumentError, "Step '#{@name}' has no text or POM sections defined" if @sections.empty?

        Contexts._render_pom_sections(@sections)
      end
    end

    # Represents a single context containing multiple steps.
    class Context
      attr_reader :name

      # rubocop:disable Metrics/AbcSize -- a flat field-initialization list for
      # one Python class (Context): every line is a distinct default assignment,
      # not branching logic. Splitting it would only hide the data shape.
      def initialize(name)
        @name = name
        @steps = {} # name => Step
        @step_order = []

        # Navigation
        @valid_contexts = @valid_steps = @initial_step = nil

        # Context entry parameters
        @post_prompt = @system_prompt = @user_prompt = nil
        @system_prompt_sections = []
        @consolidate = @full_reset = @isolated = false

        # Context prompt
        @prompt_text = nil
        @prompt_sections = []

        # Fillers, plus the history visibility mode ("keep" | "default" |
        # "hide"; nil = unset). Context history sets the default for every
        # step in the context; a step's own set_history overrides it.
        @enter_fillers = @exit_fillers = @history = nil
      end
      # rubocop:enable Metrics/AbcSize

      # Add a new step. Returns the new Step object (not self).
      #
      # The optional +task+, +bullets+, +criteria+, +functions+ and
      # +valid_steps+ keyword arguments give a one-call configuration
      # shortcut:
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
        if @steps.size >= MAX_STEPS_PER_CONTEXT
          raise ArgumentError, "Maximum steps per context (#{MAX_STEPS_PER_CONTEXT}) exceeded"
        end

        step = Step.new(name)
        @steps[name] = step
        @step_order << name
        apply_step_shortcuts(step, task, bullets, criteria, functions, valid_steps)
        step
      end

      # @api private — apply add_step's optional one-call configuration.
      def apply_step_shortcuts(step, task, bullets, criteria, functions, valid_steps)
        step.add_section('Task', task)        unless task.nil?
        step.add_bullets('Process', bullets)  unless bullets.nil?
        step.set_step_criteria(criteria)      unless criteria.nil?
        step.set_functions(functions)         unless functions.nil?
        step.set_valid_steps(valid_steps)     unless valid_steps.nil?
      end
      private :apply_step_shortcuts

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
        if @system_prompt_sections.any?
          raise ArgumentError,
                'Cannot use set_system_prompt when POM system sections exist'
        end

        @system_prompt = prompt
        self
      end

      def set_prompt(prompt)
        raise ArgumentError, 'Cannot use set_prompt when POM prompt sections exist' if @prompt_sections.any?

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

      # Set the default history visibility mode for every step in this
      # context. A step's own +set_history+ overrides this default. See
      # Step#set_history for the meaning of each mode.
      #
      # +history+ is one of "keep", "default", or "hide". Returns +self+
      # for chaining. Raises ArgumentError if +history+ is not one of the
      # three modes.
      def set_history(history)
        @history = Contexts._validate_history(history)
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
        raise ArgumentError, 'Cannot add POM sections when set_prompt has been used' unless @prompt_text.nil?

        @prompt_sections << { 'title' => title, 'body' => body }
        self
      end

      # Add a POM section with bullets to the context prompt.
      def add_bullets(title, bullets)
        raise ArgumentError, 'Cannot add POM sections when set_prompt has been used' unless @prompt_text.nil?

        @prompt_sections << { 'title' => title, 'bullets' => bullets }
        self
      end

      # Add a POM section to the system prompt.
      def add_system_section(title, body)
        unless @system_prompt.nil?
          raise ArgumentError,
                'Cannot add POM system sections when set_system_prompt has been used'
        end

        @system_prompt_sections << { 'title' => title, 'body' => body }
        self
      end

      # Add a POM section with bullets to the system prompt.
      def add_system_bullets(title, bullets)
        unless @system_prompt.nil?
          raise ArgumentError,
                'Cannot add POM system sections when set_system_prompt has been used'
        end

        @system_prompt_sections << { 'title' => title, 'bullets' => bullets }
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
          @enter_fillers = {} unless defined?(@enter_fillers) && @enter_fillers
          @enter_fillers[lang_code] = fillers
        end
        self
      end

      def add_exit_filler(lang_code, fillers)
        if lang_code && fillers.is_a?(Array) && fillers.any?
          @exit_fillers = {} unless defined?(@exit_fillers) && @exit_fillers
          @exit_fillers[lang_code] = fillers
        end
        self
      end

      def to_h
        raise ArgumentError, "Context '#{@name}' has no steps defined" if @steps.empty?

        ctx = { 'steps' => @step_order.map { |n| @steps[n].to_h } }
        add_navigation(ctx)
        add_reset_flags(ctx)
        add_prompt(ctx)
        ctx['enter_fillers'] = @enter_fillers if @enter_fillers
        ctx['exit_fillers']  = @exit_fillers  if @exit_fillers
        ctx['history']       = @history       if @history
        ctx
      end

      # --- Idiomatic Ruby accessors (additive aliases over the get_/set_ originals) ---
      #
      # Writers use the block `def x=(v); set_x(v); end` form so the RHS is
      # returned (Ruby `=` semantics), not `self`. The chainable `set_*`
      # originals stay available and untouched.
      #
      # Skipped: get_step / get_context (take a required `name` arg — lookups,
      # not bare accessors). Each writer delegates to its chainable `set_*`
      # original but returns the RHS (Ruby `=` semantics). Generated so the
      # attribute list stays a single source of truth.
      %i[initial_step valid_contexts valid_steps post_prompt system_prompt prompt
         consolidate full_reset user_prompt isolated enter_fillers exit_fillers
         history].each do |attr|
        define_method("#{attr}=") { |value| send("set_#{attr}", value) }
      end

      # Expose internal state for validation
      # @api private
      def _steps = @steps
      def _step_order = @step_order
      def _initial_step = @initial_step

      private

      def render_system_prompt
        return @system_prompt if @system_prompt
        return nil if @system_prompt_sections.empty?

        Contexts._render_pom_sections(@system_prompt_sections)
      end

      def add_navigation(ctx)
        ctx['valid_contexts'] = @valid_contexts if @valid_contexts
        ctx['valid_steps']    = @valid_steps    if @valid_steps
        ctx['initial_step']   = @initial_step   if @initial_step
        ctx['post_prompt']    = @post_prompt    if @post_prompt
        sys = render_system_prompt
        ctx['system_prompt'] = sys if sys
      end

      def add_reset_flags(ctx)
        ctx['consolidate']  = @consolidate  if @consolidate
        ctx['full_reset']   = @full_reset   if @full_reset
        ctx['user_prompt']  = @user_prompt  if @user_prompt
        ctx['isolated']     = @isolated     if @isolated
      end

      def add_prompt(ctx)
        if @prompt_sections.any?
          ctx['pom'] = @prompt_sections
        elsif @prompt_text
          ctx['prompt'] = @prompt_text
        end
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
      # Accepts an owning agent so ``validate!`` can introspect registered
      # SWAIG tools when checking for reserved-name collisions. Allows nil
      # for standalone use (building a builder before attaching).
      def initialize(agent = nil)
        @contexts      = {} # name => Context
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
      # rubocop:disable Metrics/MethodLength -- a flat, ordered list of
      # validation passes; each line is one distinct check. Splitting it would
      # only hide the validation flow, not simplify it.
      def validate!
        raise ArgumentError, 'At least one context must be defined' if @contexts.empty?

        validate_single_context_name
        validate_steps_present
        validate_initial_steps
        validate_valid_steps_refs
        validate_step_function_refs
        validate_context_level_refs
        validate_step_level_context_refs
        validate_gather_infos
        validate_reserved_tool_names
        true
      end
      # rubocop:enable Metrics/MethodLength

      def to_h
        validate!
        result = {}
        @context_order.each do |name|
          result[name] = @contexts[name].to_h
        end
        result
      end
    end

    # @api private — validate! decomposed into focused passes. Mixed into
    # {ContextBuilder} so the builder class stays small; runs with the builder
    # as +self+, reading its +@contexts+ / +@agent+ state.
    module ContextValidation
      private

      # Single context must be named "default".
      def validate_single_context_name
        return unless @contexts.size == 1

        ctx_name = @contexts.keys.first
        return if ctx_name == 'default'

        raise ArgumentError, "When using a single context, it must be named 'default'"
      end

      def validate_steps_present
        @contexts.each do |ctx_name, ctx|
          raise ArgumentError, "Context '#{ctx_name}' must have at least one step" if ctx._steps.empty?
        end
      end

      # initial_step (when set) must reference a real step in the context.
      def validate_initial_steps
        @contexts.each do |ctx_name, ctx|
          is = ctx._initial_step
          next unless is && !ctx._steps.key?(is)

          available = ctx._steps.keys.sort
          raise ArgumentError,
                "Context '#{ctx_name}' has initial_step='#{is}' but that step does " \
                "not exist. Available steps: #{available.inspect}"
        end
      end

      def validate_valid_steps_refs
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            valid = step.to_h['valid_steps']
            next unless valid

            valid.each { |ref| check_step_ref(ctx, ctx_name, step_name, ref) }
          end
        end
      end

      def check_step_ref(ctx, ctx_name, step_name, ref)
        return if ref == 'next' || ctx._steps.key?(ref)

        raise ArgumentError,
              "Step '#{step_name}' in context '#{ctx_name}' references unknown step '#{ref}'"
      end

      # A step's set_functions([...]) whitelist must reference the known tool
      # universe: registered SWAIG tools plus the reserved native tools. A name
      # that is neither is a DANGLING reference — the step would render an
      # active-function set silently pointing at nothing (r5 F3, e.g.
      # get_datetime vs get_current_time). Only enforced when a real tool
      # registry is present (@agent responds to list_tool_names); a builder with
      # no agent cannot know the tool universe, so a valid document must not red.
      # "none"/[] are explicit disable-all, not lists of references to resolve.
      def validate_step_function_refs
        return unless @agent.respond_to?(:list_tool_names)

        known = @agent.list_tool_names.to_a.to_set | RESERVED_NATIVE_TOOL_NAMES.to_set
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            funcs = step.to_h['functions']
            next unless funcs.is_a?(Array)

            funcs.each { |func| check_step_function_ref(known, ctx_name, step_name, func) }
          end
        end
      end

      def check_step_function_ref(known, ctx_name, step_name, func)
        return if known.include?(func)

        raise ArgumentError,
              "Step '#{step_name}' in context '#{ctx_name}' whitelists function " \
              "'#{func}' via set_functions(), but no such SWAIG tool is registered " \
              'on the agent and it is not a reserved native tool. This would emit ' \
              'a dangling function reference. Register the tool (define_tool / a ' \
              "skill) or remove it from the step. Available: #{known.to_a.sort.inspect}"
      end

      def validate_context_level_refs
        @contexts.each do |ctx_name, ctx|
          valid = ctx.to_h['valid_contexts']
          next unless valid

          valid.each do |ref|
            next if @contexts.key?(ref)

            raise ArgumentError, "Context '#{ctx_name}' references unknown context '#{ref}'"
          end
        end
      end

      def validate_step_level_context_refs
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            valid = step.to_h['valid_contexts']
            next unless valid

            valid.each { |ref| check_context_ref(ctx_name, step_name, ref) }
          end
        end
      end

      def check_context_ref(ctx_name, step_name, ref)
        return if @contexts.key?(ref)

        raise ArgumentError,
              "Step '#{step_name}' in context '#{ctx_name}' references unknown context '#{ref}'"
      end
    end

    # @api private — gather_info validation passes, split out of
    # {ContextValidation} to keep each module focused.
    module GatherInfoValidation
      private

      def validate_gather_infos
        @contexts.each do |ctx_name, ctx|
          ctx._steps.each do |step_name, step|
            gather = step.to_h['gather_info']
            next unless gather

            validate_gather_questions(gather, ctx_name, step_name)
            validate_gather_completion(gather, ctx, ctx_name, step_name)
          end
        end
      end

      def validate_gather_questions(gather, ctx_name, step_name)
        questions = gather['questions'] || []
        if questions.empty?
          raise ArgumentError,
                "Step '#{step_name}' in context '#{ctx_name}' has gather_info with no questions"
        end

        check_duplicate_keys(questions, ctx_name, step_name)
      end

      def check_duplicate_keys(questions, ctx_name, step_name)
        keys_seen = Set.new
        questions.each do |q|
          if keys_seen.include?(q['key'])
            raise ArgumentError,
                  "Step '#{step_name}' in context '#{ctx_name}' has duplicate " \
                  "gather_info question key '#{q['key']}'"
          end
          keys_seen << q['key']
        end
      end

      def validate_gather_completion(gather, ctx, ctx_name, step_name)
        action = gather['completion_action']
        return unless action

        if action == 'next_step'
          validate_next_step_action(ctx, ctx_name, step_name)
        elsif !ctx._steps.key?(action)
          raise_unknown_completion_action(ctx, ctx_name, step_name, action)
        end
      end

      def validate_next_step_action(ctx, ctx_name, step_name)
        idx = ctx._step_order.index(step_name)
        return if idx < ctx._step_order.size - 1

        raise ArgumentError,
              "Step '#{step_name}' in context '#{ctx_name}' has gather_info " \
              "completion_action='next_step' but it is the last step in the " \
              "context. Either (1) add another step after '#{step_name}', " \
              '(2) set completion_action to the name of an existing step in ' \
              'this context to jump to it, or (3) set completion_action=nil ' \
              "(default) to stay in '#{step_name}' after gathering completes."
      end

      def raise_unknown_completion_action(ctx, ctx_name, step_name, action)
        available = ctx._steps.keys.sort
        raise ArgumentError,
              "Step '#{step_name}' in context '#{ctx_name}' has gather_info " \
              "completion_action='#{action}' but '#{action}' is not a step in " \
              "this context. Valid options: 'next_step' (advance to the next " \
              'sequential step), nil (stay in the current step), or one of ' \
              "#{available.inspect}."
      end

      # User-defined tools must not collide with reserved native tool names
      # (next_step / change_context / gather_submit auto-injected by the
      # runtime when contexts/steps are present).
      def validate_reserved_tool_names
        return unless @agent.respond_to?(:list_tool_names)

        registered = @agent.list_tool_names.to_a
        colliding = registered.select { |n| RESERVED_NATIVE_TOOL_NAMES.include?(n) }.sort.uniq
        return if colliding.empty?

        raise ArgumentError,
              "Tool name(s) #{colliding.inspect} collide with reserved native " \
              'tools auto-injected by contexts/steps. The names ' \
              "#{RESERVED_NATIVE_TOOL_NAMES.sort.inspect} are reserved and " \
              'cannot be used for user-defined SWAIG tools when contexts/steps ' \
              'are in use. Rename your tool(s) to avoid the collision.'
      end
    end

    # Mix the validation passes into the builder now that the modules are defined.
    ContextBuilder.include(ContextValidation, GatherInfoValidation)

    # Helper to create a standalone context (not via ContextBuilder).
    def self.create_simple_context(name = 'default')
      Context.new(name)
    end
  end
end
