# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

module SignalWire
  module Prefabs
    # Prefab agent for collecting answers to a series of questions.
    #
    #   agent = InfoGatherer.new(
    #     questions: [
    #       { 'key_name' => 'full_name', 'question_text' => 'What is your full name?' },
    #       { 'key_name' => 'email',     'question_text' => 'Email?', 'confirm' => true }
    #     ]
    #   )
    #
    class InfoGatherer
      attr_reader :questions, :name, :route

      def initialize(questions:, name: 'info_gatherer', route: '/info_gatherer', **_opts)
        raise ArgumentError, 'questions must be a non-empty Array' unless questions.is_a?(Array) && !questions.empty?
        questions.each_with_index do |q, i|
          raise ArgumentError, "Question #{i} missing key_name" unless q['key_name'] || q[:key_name]
          raise ArgumentError, "Question #{i} missing question_text" unless q['question_text'] || q[:question_text]
        end

        @questions = questions.map { |q| q.transform_keys(&:to_s) }
        @name  = name
        @route = route
      end

      # Tool definitions this prefab provides.
      def tools
        %w[start_questions submit_answer]
      end

      # Build the prompt sections.
      def prompt_sections
        [
          {
            'title' => 'Info Gatherer',
            'body' => 'You need to gather answers to a series of questions. ' \
                      'Call start_questions to get the first question, then submit_answer after each response.'
          }
        ]
      end

      # Global data for initial state.
      def global_data
        {
          'info_gatherer' => {
            'questions' => @questions,
            'question_index' => 0,
            'answers' => []
          }
        }
      end

      # Tool handler: start_questions
      def handle_start(_args, _raw_data)
        q = @questions.first
        Swaig::FunctionResult.new(
          "[Question 1 of #{@questions.size}]: \"#{q['question_text']}\""
        )
      end

      # Tool handler: submit_answer
      def handle_submit(args, _raw_data)
        answer = args['answer'] || ''
        # In a real implementation, state would be tracked via global_data.
        Swaig::FunctionResult.new("Answer recorded: #{answer}")
      end
    end
  end
end
