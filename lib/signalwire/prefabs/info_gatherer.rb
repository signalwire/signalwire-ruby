# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../agent/agent_base'
require_relative '../swaig/function_result'

module SignalWire
  module Prefabs
    # Prefab agent for collecting answers to a series of questions.
    #
    # A real, functional prefab: it composes {SignalWire::AgentBase}, registers
    # its SWAIG tools via +define_tool+, builds its prompt, and seeds
    # +global_data+ so the served SWML actually drives the question flow. The
    # +submit_answer+ tool is a real state machine — it reads the current
    # +question_index+/+answers+ from the request's +global_data+, records the
    # answer, advances the index, and returns the next question (or completion),
    # mirroring the Python +InfoGathererAgent+.
    #
    #   agent = InfoGatherer.new(
    #     questions: [
    #       { 'key_name' => 'full_name', 'question_text' => 'What is your full name?' },
    #       { 'key_name' => 'email',     'question_text' => 'Email?', 'confirm' => true }
    #     ]
    #   )
    #
    class InfoGatherer < AgentBase
      # Fallback questions used in dynamic mode when no callback is registered
      # or the callback raises (mirrors Python's fallback list).
      FALLBACK_QUESTIONS = [
        { 'key_name' => 'name',    'question_text' => 'What is your name?' },
        { 'key_name' => 'message', 'question_text' => 'How can I help you today?' }
      ].freeze

      COMPLETION_TEXT =
        'Thank you! All questions have been answered. You can now summarize the information collected ' \
        "or ask if there's anything else the user would like to discuss."

      PROMPT_PREFIX = { first: 'Ask the user to answer the following question',
                        next: 'Previous Answer recorded. Now ask the user to answer the following question' }.freeze
      CONFIRM_TEXT = { true => 'Insist that the user confirms the answer as many times as needed ' \
                               'until they say it is correct.',
                       false => "You don't need the user to confirm the answer to this question." }.freeze

      attr_reader :questions

      # @param questions [Array<Hash>, nil] static questions, or nil for dynamic
      #   mode (questions resolved per-request via #set_question_callback).
      def initialize(questions: nil, name: 'info_gatherer', route: '/info_gatherer', **)
        super(name: name, route: route, use_pom: true, **)

        validate_questions!(questions) unless questions.nil?

        @questions         = questions&.map { |q| q.transform_keys(&:to_s) }
        @static_questions  = @questions
        @question_callback = nil

        register_info_gatherer_tools
        build_info_gatherer_prompt
        seed_static_global_data unless @static_questions.nil?
        configure_agent_settings
      end

      # Register a callback for dynamic, per-request question configuration.
      # The callback receives (query_params, body_params, headers) and
      # returns the list of questions to ask on that call.
      #
      # @param callback [#call] callable taking three Hash args, returning
      #   an Array of question Hashes
      # @return [self]
      def set_question_callback(callback)
        @question_callback = callback
        self
      end

      # Names of the tools this prefab provides (Ruby convenience reader; the
      # authoritative registration is via +define_tool+ in the constructor).
      def tools
        %w[start_questions submit_answer]
      end

      # The prompt sections this prefab contributes (Ruby convenience reader).
      def prompt_sections
        [
          {
            'title' => 'Info Gatherer',
            'body' => 'You need to gather answers to a series of questions. ' \
                      'Call start_questions to get the first question, then submit_answer after each response.'
          }
        ]
      end

      # The initial global-data seed for the static question set (Ruby
      # convenience reader; mirrors what the constructor sets via
      # +set_global_data+).
      def global_data
        {
          'info_gatherer' => {
            'questions' => @questions || [],
            'question_index' => 0,
            'answers' => []
          }
        }
      end

      # Tool handler: start_questions. Reads the current question index from the
      # request's global_data and returns the corresponding question.
      def handle_start(_args, raw_data)
        gd = request_global_data(raw_data)
        questions = gd['questions']
        index     = gd['question_index']

        if questions.empty? || index >= questions.size
          return Swaig::FunctionResult.new("I don't have any questions to ask.")
        end

        q = questions[index]
        Swaig::FunctionResult.new(
          question_instruction(q['question_text'], q['confirm'], first: true)
        )
      end

      # Tool handler: submit_answer. Real state machine — records the answer,
      # advances the index, and returns the next question (or completion),
      # persisting the updated state back into global_data.
      def handle_submit(args, raw_data)
        answer = args['answer'] || ''
        gd = request_global_data(raw_data)
        questions = gd['questions']
        index     = gd['question_index']
        answers   = gd['answers']

        return Swaig::FunctionResult.new('All questions have already been answered.') if index >= questions.size

        key_name    = questions[index]['key_name'] || ''
        new_answers = answers + [{ 'key_name' => key_name, 'answer' => answer }]
        next_index  = index + 1

        build_submit_result(questions, next_index, new_answers)
      end

      # Lifecycle hook: on_swml_request. In dynamic mode, invokes the
      # registered question callback (or a fallback) and returns a
      # { 'global_data' => {...} } Hash that AgentBase merges into the SWML
      # response. In static mode this is a no-op (returns nil).
      #
      # @param request_data [Hash, nil] parsed request body
      # @param callback_path [String, nil] callback path (accepted but unused)
      # @param request [#query_params, #headers, nil] request object
      # @return [Hash, nil]
      def on_swml_request(request_data = nil, _callback_path = nil, request: nil)
        # Static mode: questions are already configured.
        return nil unless @static_questions.nil?

        # Dynamic mode with no callback: fall back to default questions.
        return { 'global_data' => fresh_global_data(FALLBACK_QUESTIONS) } if @question_callback.nil?

        { 'global_data' => fresh_global_data(resolve_dynamic_questions(request_data, request)) }
      end

      private

      # Register the two SWAIG tools so the served SWML advertises them and a
      # SWAIG call actually dispatches to the state machine (real prefab, not a
      # bag of loose methods).
      def register_info_gatherer_tools
        define_tool(name: 'start_questions', parameters: {}, handler: method(:handle_start),
                    description: 'Start the question sequence with the first question')
        define_tool(name: 'submit_answer', handler: method(:handle_submit),
                    description: 'Submit an answer to the current question and move to the next one',
                    parameters: { 'answer' => {
                      'type' => 'string', 'description' => "The user's answer to the current question"
                    } })
      end

      def build_info_gatherer_prompt
        section = prompt_sections.first
        prompt_add_section(section['title'], section['body'])
      end

      def seed_static_global_data
        set_global_data(
          'questions' => @questions, 'question_index' => 0, 'answers' => []
        )
      end

      def configure_agent_settings
        set_params('end_of_speech_timeout' => 800, 'speech_event_timeout' => 1000)
      end

      # Pull the question-flow state out of a SWAIG request's global_data, with
      # the same defaults Python uses. Accepts both the flat seed shape
      # ({questions,question_index,answers}) and a nil/empty raw_data.
      def request_global_data(raw_data)
        gd = (raw_data.is_a?(Hash) ? raw_data['global_data'] : nil) || {}
        {
          'questions' => gd['questions'] || @questions || [],
          'question_index' => gd['question_index'] || 0,
          'answers' => gd['answers'] || []
        }
      end

      # Build the submit_answer FunctionResult, persisting the advanced state
      # into global_data and returning the next question or completion.
      def build_submit_result(questions, next_index, new_answers)
        text =
          if next_index < questions.size
            nq = questions[next_index]
            question_instruction(nq['question_text'], nq['confirm'], first: false)
          else
            COMPLETION_TEXT
          end
        result = Swaig::FunctionResult.new(text)
        result.update_global_data('answers' => new_answers, 'question_index' => next_index)
        result
      end

      def question_instruction(question_text, needs_confirmation, first:)
        "#{PROMPT_PREFIX[first ? :first : :next]}: #{question_text}\n\n" \
        'Make sure the answer fits the scope and context of the question before submitting it. ' +
          CONFIRM_TEXT[needs_confirmation ? true : false]
      end

      def validate_questions!(questions)
        raise ArgumentError, 'questions must be a non-empty Array' unless questions.is_a?(Array) && !questions.empty?

        questions.each_with_index do |q, i|
          raise ArgumentError, "Question #{i} missing key_name" unless question_field(q, 'key_name')
          raise ArgumentError, "Question #{i} missing question_text" unless question_field(q, 'question_text')
        end
      end

      # A question Hash may carry either string or symbol keys; check both.
      def question_field(question, name)
        question[name] || question[name.to_sym]
      end

      # Invoke the per-request question callback, normalizing keys to strings.
      # Falls back to FALLBACK_QUESTIONS on any error (matching Python).
      def resolve_dynamic_questions(request_data, request)
        query_params = request_attr(request, :query_params)
        headers      = request_attr(request, :headers)
        body_params  = request_data || {}

        questions = @question_callback.call(query_params, body_params, headers)
        raise ArgumentError, 'callback must return a non-empty Array' unless questions.is_a?(Array) && !questions.empty?

        questions.map { |q| q.transform_keys(&:to_s) }
      rescue StandardError => e
        puts "Error in question callback: #{e.message}"
        FALLBACK_QUESTIONS
      end

      def request_attr(request, name)
        (request.respond_to?(name) ? request.public_send(name) : nil) || {}
      end

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
