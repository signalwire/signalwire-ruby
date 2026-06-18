# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

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
        %w[start_survey submit_survey_answer get_survey_summary validate_response log_response]
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
            'name' => @survey_name,
            'questions' => @questions,
            'current' => 0,
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

      # Tool: validate_response — Python parity
      # (signalwire.prefabs.survey.SurveyAgent#validate_response).
      #
      # Validates a user's answer against the constraints of the identified
      # question (rating range, multiple-choice options, yes/no, required
      # open-ended) and returns a human-readable validity message.
      #
      # @param args [Hash] expects "question_id", "response"
      # @return [Swaig::FunctionResult]
      def validate_response(args, _raw_data)
        question_id = args['question_id'] || ''
        response    = args['response'] || ''

        question = @questions.find { |q| q['id'] == question_id }
        return Swaig::FunctionResult.new("Error: Question with ID '#{question_id}' not found.") unless question

        valid = "Response to '#{question_id}' is valid."
        message = validation_message(question, response) || valid

        Swaig::FunctionResult.new(message)
      end

      # Tool: log_response — Python parity
      # (signalwire.prefabs.survey.SurveyAgent#log_response).
      #
      # Acknowledges that a validated response has been recorded, naming the
      # question by its text. A real implementation would persist the answer.
      #
      # @param args [Hash] expects "question_id", "response"
      # @return [Swaig::FunctionResult]
      def log_response(args, _raw_data)
        question_id = args['question_id'] || ''
        question = @questions.find { |q| q['id'] == question_id }
        question_text = question ? question['text'] : ''

        Swaig::FunctionResult.new("Response to '#{question_text}' has been recorded.")
      end

      # Lifecycle hook: on_summary — Python parity
      # (signalwire.prefabs.survey.SurveyAgent#on_summary).
      #
      # Logs the completed survey results; structured (Hash) summaries are
      # emitted as pretty JSON. Subclasses override to store responses or
      # trigger follow-up actions.
      #
      # @param summary [Hash, String, nil] survey responses summary
      # @param _raw_data [Hash, nil] full raw POST data
      # @return [void]
      def on_summary(summary, _raw_data = nil)
        return if summary.nil?

        if summary.is_a?(Hash)
          puts "Survey completed: #{JSON.pretty_generate(summary)}"
        else
          puts "Survey summary (unstructured): #{summary}"
        end
      rescue StandardError => e
        puts "Error processing survey summary: #{e.message}"
      end

      private

      # Return an error message for an invalid response, or +nil+ when the
      # response is valid for the question's type.
      def validation_message(question, response)
        case question['type']
        when 'rating'          then rating_error(question, response)
        when 'multiple_choice' then multiple_choice_error(question, response)
        when 'yes_no'          then yes_no_error(response)
        when 'open_ended'      then open_ended_error(question, response)
        end
      end

      def rating_error(question, response)
        scale = question['scale'] || 5
        rating = Integer(response.strip, exception: false)
        return unless rating.nil? || rating < 1 || rating > scale

        "Invalid rating. Please provide a number between 1 and #{scale}."
      end

      def multiple_choice_error(question, response)
        options = question['options'] || []
        return if options.any? { |opt| response.downcase.strip == opt.downcase }

        "Invalid choice. Please select one of: #{options.join(', ')}."
      end

      def yes_no_error(response)
        return if %w[yes no y n].include?(response.downcase.strip)

        "Please answer with 'yes' or 'no'."
      end

      def open_ended_error(question, response)
        required = question.key?('required') ? question['required'] : true
        'A response is required for this question.' if response.strip.empty? && required
      end
    end
  end
end
