# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Private helpers for {InfoGathererSkill}. Extracted to a mixin so the
      # skill class stays focused on its public surface (the audit reads the
      # class's own public methods, never these helpers).
      module InfoGathererHelpers
        private

        def start_tool_definition
          { name: @start_tool,
            description: 'Start the question sequence with the first question',
            parameters: {}, handler: method(:handle_start) }
        end

        def submit_tool_definition
          { name: @submit_tool,
            description: 'Submit an answer to the current question and move to the next one',
            parameters: submit_tool_parameters, handler: method(:handle_submit) }
        end

        def submit_tool_parameters
          { 'answer' => { 'type' => 'string',
                          'description' => "The user's answer to the current question" },
            'confirmed_by_user' =>
              { 'type' => 'boolean',
                'description' => 'Only set to true when the user has explicitly confirmed the answer.' } }
        end

        def valid_questions?(questions)
          return false unless questions.is_a?(Array) && !questions.empty?

          questions.all? { |q| q.is_a?(Hash) && q['key_name'] && q['question_text'] }
        end

        def configure_tool_names(prefix)
          slug = prefix && !prefix.empty? ? prefix : nil
          @start_tool  = slug ? "#{slug}_start_questions" : 'start_questions'
          @submit_tool = slug ? "#{slug}_submit_answer" : 'submit_answer'
          @namespace   = slug ? "skill:#{slug}" : 'skill:info_gatherer'
        end

        def handle_start(_args, raw_data)
          questions, index, = load_progress(raw_data)
          if questions.empty? || index >= questions.size
            return Swaig::FunctionResult.new("I don't have any questions to ask.")
          end

          instruction = generate_instruction(questions[index], index, questions.size, true)
          Swaig::FunctionResult.new(instruction)
        end

        def handle_submit(args, raw_data)
          answer = args['answer'] || ''
          questions, index, answers = load_progress(raw_data)

          return Swaig::FunctionResult.new('All questions have already been answered.') if index >= questions.size

          current = questions[index]
          return confirmation_prompt(answer) if current['confirm'] && !args['confirmed_by_user']

          new_index   = index + 1
          new_answers = answers + [{ 'key_name' => current['key_name'], 'answer' => answer }]
          apply_state(submit_result(questions, new_index), questions, new_index, new_answers)
        end

        # [questions, question_index, answers] from SWAIG global_data state.
        def load_progress(raw_data)
          state = extract_state(raw_data)
          [state['questions'] || @questions, state['question_index'] || 0, state['answers'] || []]
        end

        # Persist updated questions/index/answers onto the SWAIG result.
        def apply_state(result, questions, new_index, new_answers)
          result.update_global_data(
            @namespace => { 'questions' => questions, 'question_index' => new_index,
                            'answers' => new_answers }
          )
          result
        end

        def confirmation_prompt(answer)
          Swaig::FunctionResult.new(
            "Before submitting, read the answer \"#{answer}\" back to the user and ask them to confirm."
          )
        end

        # SWAIG result for the next question, or the completion message
        # (both tools toggled off) when the last answer is in.
        def submit_result(questions, new_index)
          if new_index < questions.size
            instruction = generate_instruction(questions[new_index], new_index, questions.size, false)
            return Swaig::FunctionResult.new(instruction)
          end

          result = Swaig::FunctionResult.new(@completion_message)
          result.toggle_functions(
            [{ 'function' => @start_tool, 'active' => false },
             { 'function' => @submit_tool, 'active' => false }]
          )
          result
        end

        def extract_state(raw_data)
          return {} unless raw_data.is_a?(Hash)

          (raw_data['global_data'] || {})[@namespace] || {}
        end

        def generate_instruction(question, index, total, first)
          instr = base_instruction(question['question_text'], index + 1, total, first)
          prompt_add = question['prompt_add']
          instr += "\nNote: #{prompt_add}" if prompt_add && !prompt_add.empty?
          if question['confirm']
            instr += "\nThis question requires confirmation. Read the answer back and ask the user to confirm."
          end
          instr
        end

        def base_instruction(text, num, total, first)
          if first
            "Ask each question one at a time, wait for the user's answer, " \
              "then call #{@submit_tool} with their answer.\n\n" \
              "[Question #{num} of #{total}]: \"#{text}\""
          else
            "Previous answer saved. [Question #{num} of #{total}]: \"#{text}\""
          end
        end
      end

      class InfoGathererSkill < SkillBase
        include InfoGathererHelpers

        def name = 'info_gatherer'
        def description = 'Gather answers to a configurable list of questions'
        # This skill may be loaded more than once on one agent — each instance
        # is distinguished by its `prefix` param, which also namespaces its
        # tools and its slice of `global_data`.
        #
        # @return [Boolean] true
        def supports_multiple_instances? = true

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @questions = get_param('questions')
          return false unless valid_questions?(@questions)

          configure_tool_names(get_param('prefix'))
          @completion_message = get_param('completion_message',
                                          default: 'Thank you! All questions have been answered.')
          true
        end

        def instance_key
          prefix = get_param('prefix')
          prefix && !prefix.to_s.empty? ? "info_gatherer_#{prefix}" : 'info_gatherer'
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [start_tool_definition, submit_tool_definition]
        end

        # Data this skill merges into the agent's `global_data`, so its prompts
        # and tools can reference the values as `${global_data.*}`.
        #
        # @return [Hash]
        def get_global_data
          { @namespace => { 'questions' => @questions, 'question_index' => 0, 'answers' => [] } }
        end

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          [
            {
              'title' => "Info Gatherer (#{instance_key})",
              'body' => 'You need to gather answers to a series of questions from the user. ' \
                        "Start by asking if they are ready, then call #{@start_tool} to get the first question. " \
                        "After each answer, call #{@submit_tool} to record it and get the next question."
            }
          ]
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          { 'questions' => { 'type' => 'array', 'required' => true },
            'prefix' => { 'type' => 'string' },
            'completion_message' => { 'type' => 'string' } }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('info_gatherer') do |params|
  SignalWire::Skills::Builtin::InfoGathererSkill.new(params)
end
