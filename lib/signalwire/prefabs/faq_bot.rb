# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

require_relative '../swaig/function_result'

module SignalWire
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
      attr_reader :faqs, :name, :route

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
        [
          {
            'title' => 'FAQ Bot',
            'body' => @persona,
            'bullets' => bullets
          }
        ]
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
