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
      # Fallback questions used in dynamic mode when no callback is registered
      # or the callback raises (mirrors Python's fallback list).
      FALLBACK_QUESTIONS = [
        { 'key_name' => 'name',    'question_text' => 'What is your name?' },
        { 'key_name' => 'message', 'question_text' => 'How can I help you today?' }
      ].freeze

      attr_reader :questions, :name, :route

      # @param questions [Array<Hash>, nil] static questions, or nil for dynamic
      #   mode (questions resolved per-request via #set_question_callback).
      def initialize(questions: nil, name: 'info_gatherer', route: '/info_gatherer', **_opts)
        unless questions.nil?
          raise ArgumentError, 'questions must be a non-empty Array' unless questions.is_a?(Array) && !questions.empty?

          questions.each_with_index do |q, i|
            raise ArgumentError, "Question #{i} missing key_name" unless q['key_name'] || q[:key_name]
            raise ArgumentError, "Question #{i} missing question_text" unless q['question_text'] || q[:question_text]
          end
        end

        @questions         = questions&.map { |q| q.transform_keys(&:to_s) }
        @static_questions  = @questions
        @question_callback = nil
        @name  = name
        @route = route
      end

      # Register a callback for dynamic, per-request question configuration —
      # Python parity (InfoGathererAgent#set_question_callback). The callback
      # receives (query_params, body_params, headers) and returns the list of
      # questions to ask on that call.
      #
      # @param callback [#call] callable taking three Hash args, returning
      #   an Array of question Hashes
      # @return [self]
      def set_question_callback(callback)
        @question_callback = callback
        self
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
            'questions' => @questions || [],
            'question_index' => 0,
            'answers' => []
          }
        }
      end

      # Tool handler: start_questions
      def handle_start(_args, _raw_data)
        q = (@questions || []).first
        return Swaig::FunctionResult.new("I don't have any questions to ask.") unless q

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

      # Lifecycle hook: on_swml_request — Python parity
      # (InfoGathererAgent#on_swml_request). In dynamic mode, invokes the
      # registered question callback (or a fallback) and returns a
      # { 'global_data' => {...} } Hash that AgentBase merges into the SWML
      # response. In static mode this is a no-op (returns nil).
      #
      # @param request_data [Hash, nil] parsed request body
      # @param callback_path [String, nil] callback path (accepted for parity)
      # @param request [#query_params, #headers, nil] request object
      # @return [Hash, nil]
      def on_swml_request(request_data = nil, _callback_path = nil, request: nil)
        # Static mode: questions are already configured.
        return nil unless @static_questions.nil?

        # Dynamic mode with no callback: fall back to default questions.
        return { 'global_data' => fresh_global_data(FALLBACK_QUESTIONS) } if @question_callback.nil?

        query_params = (request.respond_to?(:query_params) ? request.query_params : nil) || {}
        headers      = (request.respond_to?(:headers) ? request.headers : nil) || {}
        body_params  = request_data || {}

        begin
          questions = @question_callback.call(query_params, body_params, headers)
          unless questions.is_a?(Array) && !questions.empty?
            raise ArgumentError,
                  'callback must return a non-empty Array'
          end

          normalized = questions.map { |q| q.transform_keys(&:to_s) }
          { 'global_data' => fresh_global_data(normalized) }
        rescue StandardError => e
          puts "Error in question callback: #{e.message}"
          { 'global_data' => fresh_global_data(FALLBACK_QUESTIONS) }
        end
      end

      private

      def fresh_global_data(questions)
        {
          'questions' => questions,
          'question_index' => 0,
          'answers' => []
        }
      end
    end
  end
end
