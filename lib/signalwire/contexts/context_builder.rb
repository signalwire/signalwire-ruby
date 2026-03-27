# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

module SignalWire
  module Contexts
    MAX_CONTEXTS = 50
    MAX_STEPS_PER_CONTEXT = 100

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

      # @param functions [String, Array<String>] "none" to disable all, or list of names
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
      def add_gather_question(key:, question:, **opts)
        raise ArgumentError, "Must call set_gather_info before add_gather_question" if @gather_info.nil?

        @gather_info.add_question(key: key, question: question, **opts)
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
      def add_step(name)
        raise ArgumentError, "Step '#{name}' already exists in context '#{@name}'" if @steps.key?(name)
        raise ArgumentError, "Maximum steps per context (#{MAX_STEPS_PER_CONTEXT}) exceeded" if @steps.size >= MAX_STEPS_PER_CONTEXT

        step = Step.new(name)
        @steps[name] = step
        @step_order << name
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

      # Expose internal state for validation
      # @api private
      def _steps;      @steps;      end
      def _step_order; @step_order; end

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

    # Main builder that holds multiple contexts and validates the configuration.
    class ContextBuilder
      def initialize
        @contexts      = {}   # name => Context
        @context_order = []
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
                        "Step '#{step_name}' in context '#{ctx_name}' has gather_info completion_action='next_step' but it is the last step"
                end
              elsif !ctx._steps.key?(action)
                raise ArgumentError,
                      "Step '#{step_name}' in context '#{ctx_name}' has gather_info completion_action='#{action}' but step '#{action}' does not exist"
              end
            end
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
