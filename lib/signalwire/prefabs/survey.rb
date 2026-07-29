# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

require_relative '../swaig/function_result'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Prefabs — ready-made agents assembled from the SDK's own building blocks.
  module Prefabs
    # @api private — per-question-type answer validation for Survey. Split out
    # of Survey so the class keeps only its public API + survey state; these
    # helpers are pure functions of (question, response).
    module AnswerValidation
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

      # @api private — reject a rating outside 1..scale (default 5) or one that is
      # not a whole number at all.
      #
      # @return [String, nil] the error text, or nil when valid
      def rating_error(question, response)
        scale = question['scale'] || 5
        rating = Integer(response.strip, exception: false)
        return unless rating.nil? || rating < 1 || rating > scale

        "Invalid rating. Please provide a number between 1 and #{scale}."
      end

      # @api private — reject an answer that is not one of the question's options.
      # The comparison is case-insensitive and whitespace-trimmed, so a spoken answer
      # matches without exact casing.
      #
      # @return [String, nil] the error text, or nil when valid
      def multiple_choice_error(question, response)
        options = question['options'] || []
        return if options.any? { |opt| response.downcase.strip == opt.downcase }

        "Invalid choice. Please select one of: #{options.join(', ')}."
      end

      # @api private — accept `yes`/`no`/`y`/`n`, case-insensitive and trimmed.
      #
      # @return [String, nil] the error text, or nil when valid
      def yes_no_error(response)
        return if %w[yes no y n].include?(response.downcase.strip)

        "Please answer with 'yes' or 'no'."
      end

      # @api private — reject an empty answer only when the question is required.
      # Required defaults to TRUE, so a question must opt OUT of being required.
      #
      # @return [String, nil] the error text, or nil when valid
      def open_ended_error(question, response)
        required = question.key?('required') ? question['required'] : true
        'A response is required for this question.' if response.strip.empty? && required
      end
    end

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
      include AnswerValidation

      # Brand used when the caller does not supply one.
      DEFAULT_BRAND_NAME = 'Our Company'
      # Times the agent re-asks a question after an invalid answer.
      DEFAULT_MAX_RETRIES = 2
      # Closing message used when the caller does not supply one.
      DEFAULT_CONCLUSION = 'Thank you for completing the survey!'

      attr_reader :survey_name, :questions, :name, :route, :brand_name, :max_retries

      # @return [String] the opening message in force — the caller-supplied
      #   +introduction:+ or the generated default. Reference attribute
      #   `self.introduction` (prefabs/survey.py).
      # @return [String] +conclusion+: the closing message — caller-supplied or
      #   {DEFAULT_CONCLUSION}. Also a public reference attribute. Both are
      #   defaulted, so reading back is the only way a caller learns which text
      #   the agent will actually speak.
      attr_reader :introduction, :conclusion

      # @param brand_name [String, nil] brand or company name the agent
      #   represents; defaults to +DEFAULT_BRAND_NAME+ when nil.
      # @param max_retries [Integer] maximum number of times to retry an
      #   invalid answer before moving on.
      def initialize(survey_name:, questions:, introduction: nil, conclusion: nil,
                     brand_name: nil, max_retries: DEFAULT_MAX_RETRIES,
                     name: 'survey', route: '/survey', **_opts)
        validate_questions!(questions)

        @survey_name  = survey_name
        @questions    = questions.map { |q| q.transform_keys(&:to_s) }
        @introduction = introduction || default_introduction(survey_name)
        @conclusion   = conclusion   || DEFAULT_CONCLUSION
        @brand_name   = brand_name   || DEFAULT_BRAND_NAME
        @max_retries  = max_retries
        @name  = name
        @route = route
      end

      # The SWAIG tool names this prefab's agent exposes.
      #
      # @return [Array<String>]
      def tools
        %w[start_survey submit_survey_answer get_survey_summary validate_response log_response]
      end

      # The POM sections that make up the survey agent's prompt.
      #
      # @return [Array<Hash>]
      def prompt_sections
        [personality_section, instructions_section, questions_section]
      end

      # The `global_data` the survey agent starts with: the survey name, brand and
      # retry budget, plus the `survey` state object holding the questions, the
      # current index and the collected responses.
      #
      # @return [Hash]
      def global_data
        {
          'survey_name' => @survey_name, 'brand_name' => @brand_name,
          'max_retries' => @max_retries,
          'survey' => {
            'name' => @survey_name, 'questions' => @questions,
            'current' => 0, 'responses' => {}
          }
        }
      end

      # @api private — the start handler: speak the introduction and ask the first
      # question, numbered so the caller knows how long the survey is.
      #
      # @return [Swaig::FunctionResult]
      def handle_start(_args, _raw_data)
        q = @questions.first
        Swaig::FunctionResult.new("#{@introduction}\n\n[Question 1 of #{@questions.size}]: #{q['text']}")
      end

      # @api private — the submit handler: acknowledge the answer back to the model.
      # The response is carried in the agent's `global_data` by the runtime, not
      # stored on this object.
      #
      # @return [Swaig::FunctionResult]
      def handle_submit(args, _raw_data)
        Swaig::FunctionResult.new("Response recorded: #{args['answer']}")
      end

      # @api private — the summary handler: speak the closing message.
      #
      # @return [Swaig::FunctionResult]
      def handle_summary(_args, _raw_data)
        Swaig::FunctionResult.new(@conclusion)
      end

      # Tool: validate_response.
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

      # Tool: log_response.
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

      # Lifecycle hook: on_summary.
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

      # @api private — a survey needs at least one question; an empty list is
      # rejected at construction rather than producing an agent with nothing to ask.
      #
      # @raise [ArgumentError]
      def validate_questions!(questions)
        return if questions.is_a?(Array) && !questions.empty?

        raise ArgumentError, 'questions must be a non-empty Array'
      end

      # @api private — the opening line used when the caller supplied no
      # `introduction:`.
      #
      # @return [String]
      def default_introduction(survey_name)
        "Welcome to the #{survey_name}. Let's get started."
      end

      # The brand the agent represents reaches the model here.
      def personality_section
        {
          'title' => 'Personality',
          'body' => "You are a friendly and professional survey agent representing #{@brand_name}."
        }
      end

      # The retry budget reaches the model here.
      def instructions_section
        {
          'title' => 'Instructions',
          'bullets' => [
            'Ask only one question at a time and wait for a response.',
            "If a response is invalid, explain and retry up to #{@max_retries} times.",
            'After all questions are answered, thank the user for their participation.'
          ]
        }
      end

      # @api private — the prompt section listing every question with its id and
      # type, so the model knows the full sequence and what kind of answer each
      # expects. An untyped question is presented as open-ended.
      #
      # @return [Hash]
      def questions_section
        {
          'title' => "Survey: #{@survey_name}",
          'body' => @introduction,
          'bullets' => @questions.map { |q| "#{q['id']}: #{q['text']} (#{q['type'] || 'open_ended'})" }
        }
      end
    end
  end
end
