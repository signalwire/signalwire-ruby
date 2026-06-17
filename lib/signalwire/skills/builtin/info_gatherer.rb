# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class InfoGathererSkill < SkillBase
        def name = 'info_gatherer'
        def description = 'Gather answers to a configurable list of questions'
        def supports_multiple_instances? = true

        def setup
          @questions = get_param('questions')
          return false unless @questions.is_a?(Array) && !@questions.empty?

          @questions.each_with_index do |q, _i|
            return false unless q.is_a?(Hash) && q['key_name'] && q['question_text']
          end

          prefix = get_param('prefix')
          if prefix && !prefix.empty?
            @start_tool = "#{prefix}_start_questions"
            @submit_tool = "#{prefix}_submit_answer"
            @namespace = "skill:#{prefix}"
          else
            @start_tool = 'start_questions'
            @submit_tool = 'submit_answer'
            @namespace = 'skill:info_gatherer'
          end

          @completion_message = get_param('completion_message',
                                          default: 'Thank you! All questions have been answered.')
          true
        end

        def instance_key
          prefix = get_param('prefix')
          prefix && !prefix.to_s.empty? ? "info_gatherer_#{prefix}" : 'info_gatherer'
        end

        def register_tools
          [
            {
              name: @start_tool,
              description: 'Start the question sequence with the first question',
              parameters: {},
              handler: method(:handle_start)
            },
            {
              name: @submit_tool,
              description: 'Submit an answer to the current question and move to the next one',
              parameters: {
                'answer' => { 'type' => 'string',
                              'description' => "The user's answer to the current question" },
                'confirmed_by_user' => { 'type' => 'boolean',
                                         'description' => 'Only set to true when the user has explicitly confirmed the answer.' }
              },
              handler: method(:handle_submit)
            }
          ]
        end

        def get_global_data
          {
            @namespace => {
              'questions' => @questions,
              'question_index' => 0,
              'answers' => []
            }
          }
        end

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

        def get_parameter_schema
          {
            'questions' => { 'type' => 'array', 'required' => true },
            'prefix' => { 'type' => 'string' },
            'completion_message' => { 'type' => 'string' }
          }
        end

        private

        def handle_start(_args, raw_data)
          state = extract_state(raw_data)
          questions = state['questions'] || @questions
          index = state['question_index'] || 0

          if questions.empty? || index >= questions.size
            return Swaig::FunctionResult.new("I don't have any questions to ask.")
          end

          current = questions[index]
          instruction = generate_instruction(current, index, questions.size, true)
          Swaig::FunctionResult.new(instruction)
        end

        def handle_submit(args, raw_data)
          answer    = args['answer'] || ''
          confirmed = args['confirmed_by_user']

          state     = extract_state(raw_data)
          questions = state['questions'] || @questions
          index     = state['question_index'] || 0
          answers   = state['answers'] || []

          return Swaig::FunctionResult.new('All questions have already been answered.') if index >= questions.size

          current = questions[index]

          if current['confirm'] && !confirmed
            return Swaig::FunctionResult.new(
              "Before submitting, read the answer \"#{answer}\" back to the user and ask them to confirm."
            )
          end

          new_answers = answers + [{ 'key_name' => current['key_name'], 'answer' => answer }]
          new_index   = index + 1

          if new_index < questions.size
            next_q = questions[new_index]
            instruction = generate_instruction(next_q, new_index, questions.size, false)
            result = Swaig::FunctionResult.new(instruction)
          else
            result = Swaig::FunctionResult.new(@completion_message)
            result.toggle_functions([
                                      { 'function' => @start_tool, 'active' => false },
                                      { 'function' => @submit_tool, 'active' => false }
                                    ])
          end

          result.update_global_data({
                                      @namespace => {
                                        'questions' => questions,
                                        'question_index' => new_index,
                                        'answers' => new_answers
                                      }
                                    })
          result
        end

        def extract_state(raw_data)
          return {} unless raw_data.is_a?(Hash)

          gd = raw_data['global_data'] || {}
          gd[@namespace] || {}
        end

        def generate_instruction(question, index, total, first)
          text = question['question_text']
          num  = index + 1

          instr = if first
                    "Ask each question one at a time, wait for the user's answer, " \
                      "then call #{@submit_tool} with their answer.\n\n" \
                      "[Question #{num} of #{total}]: \"#{text}\""
                  else
                    "Previous answer saved. [Question #{num} of #{total}]: \"#{text}\""
                  end

          instr += "\nNote: #{question['prompt_add']}" if question['prompt_add'] && !question['prompt_add'].empty?

          if question['confirm']
            instr += "\nThis question requires confirmation. Read the answer back and ask the user to confirm."
          end

          instr
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('info_gatherer') do |params|
  SignalWire::Skills::Builtin::InfoGathererSkill.new(params)
end
