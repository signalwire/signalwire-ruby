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
    # Prefab agent for answering frequently asked questions.
    #
    #   agent = FaqBot.new(
    #     faqs: [
    #       { 'question' => 'What is SignalWire?', 'answer' => 'A cloud communications platform.' }
    #     ]
    #   )
    #
    class FaqBot
      # The bullet the reference appends to its Instructions section when
      # suggest_related is on (prefabs/faq_bot.py:111-113).
      SUGGEST_RELATED_INSTRUCTION =
        'When appropriate, suggest other related questions from the FAQ database ' \
        'that might be helpful.'

      attr_reader :faqs, :name, :route

      # @return [String] the personality body in force — the caller-supplied
      #   +persona:+ or the default. Reference attribute `self.persona`
      #   (prefabs/faq_bot.py:76).
      # @return [Boolean] +suggest_related+: whether the agent is instructed to
      #   offer related questions. Reference attribute `self.suggest_related`
      #   (prefabs/faq_bot.py:75).
      attr_reader :persona, :suggest_related

      def initialize(faqs:, suggest_related: true, persona: nil,
                     name: 'faq_bot', route: '/faq', **_opts)
        raise ArgumentError, 'faqs must be a non-empty Array' unless faqs.is_a?(Array) && !faqs.empty?

        @faqs            = faqs.map { |f| f.transform_keys(&:to_s) }
        @suggest_related = suggest_related
        @persona         = persona || 'You are a helpful FAQ bot that provides accurate answers to common questions.'
        @name  = name
        @route = route
      end

      def tools
        %w[search_faq]
      end

      def prompt_sections
        bullets = @faqs.map { |f| "Q: #{f['question']}" }
        sections = [
          {
            'title' => 'FAQ Bot',
            'body' => @persona,
            'bullets' => bullets
          }
        ]
        # suggest_related must reach the PROMPT, not just global_data — it is the
        # switch that tells the agent to offer related questions, and the
        # reference renders it in two places (an Instructions bullet plus a
        # Related Questions section, prefabs/faq_bot.py:110,143-148). Without
        # this the flag was accepted and had no effect on agent behaviour.
        sections << { 'title' => 'Related Questions', 'body' => SUGGEST_RELATED_INSTRUCTION } if @suggest_related
        sections
      end

      def global_data
        {
          'faqs' => @faqs,
          'suggest_related' => @suggest_related
        }
      end

      def handle_search(args, _raw_data)
        query = (args['query'] || '').downcase
        match = @faqs.find { |f| f['question'].downcase.include?(query) || query.include?(f['question'].downcase) }
        return Swaig::FunctionResult.new(match['answer']) if match

        topics = @faqs.map { |f| f['question'] }.join('; ')
        Swaig::FunctionResult.new(
          "I don't have a specific answer for that. Here are the topics I can help with: #{topics}"
        )
      end

      # Lifecycle hook: on_summary.
      #
      # Logs the post-prompt interaction summary; structured (Hash) summaries
      # are emitted as pretty JSON. Subclasses may override to persist.
      #
      # @param summary [Hash, String, nil] conversation summary
      # @param _raw_data [Hash, nil] full raw POST data
      # @return [void]
      def on_summary(summary, _raw_data = nil)
        return if summary.nil?

        if summary.is_a?(Hash)
          puts "FAQ interaction summary: #{JSON.pretty_generate(summary)}"
        else
          puts "FAQ interaction summary: #{summary}"
        end
      rescue StandardError => e
        puts "Error processing summary: #{e.message}"
      end
    end
  end
end
