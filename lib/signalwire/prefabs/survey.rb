# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

module SignalWire
  module Prefabs
    # Prefab agent for conducting automated surveys.
    #
    #   agent = Survey.new(
    #     survey_name: 'Customer Satisfaction',
    #     questions: [
    #       { 'id' => 'satisfaction', 'text' => 'How satisfied were you?', 'type' => 'rating', 'scale' => 5 }
    #     ]
    #   )
    #
    class Survey
      attr_reader :survey_name, :questions, :name, :route

      def initialize(survey_name:, questions:, introduction: nil, conclusion: nil,
                     name: 'survey', route: '/survey', **_opts)
        raise ArgumentError, 'questions must be a non-empty Array' unless questions.is_a?(Array) && !questions.empty?

        @survey_name  = survey_name
        @questions    = questions.map { |q| q.transform_keys(&:to_s) }
        @introduction = introduction || "Welcome to the #{survey_name}. Let's get started."
        @conclusion   = conclusion   || 'Thank you for completing the survey!'
        @name  = name
        @route = route
      end

      def tools
        %w[start_survey submit_survey_answer get_survey_summary]
      end

      def prompt_sections
        [
          {
            'title' => "Survey: #{@survey_name}",
            'body' => @introduction,
            'bullets' => @questions.map { |q| "#{q['id']}: #{q['text']} (#{q['type'] || 'open_ended'})" }
          }
        ]
      end

      def global_data
        {
          'survey' => {
            'name'      => @survey_name,
            'questions' => @questions,
            'current'   => 0,
            'responses' => {}
          }
        }
      end

      def handle_start(_args, _raw_data)
        q = @questions.first
        Swaig::FunctionResult.new("#{@introduction}\n\n[Question 1 of #{@questions.size}]: #{q['text']}")
      end

      def handle_submit(args, _raw_data)
        Swaig::FunctionResult.new("Response recorded: #{args['answer']}")
      end

      def handle_summary(_args, _raw_data)
        Swaig::FunctionResult.new(@conclusion)
      end
    end
  end
end
