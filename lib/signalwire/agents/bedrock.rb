# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Bedrock Agent - Amazon Bedrock voice-to-voice integration.
#
# BedrockAgent extends AgentBase to support Amazon Bedrock's
# voice-to-voice model while keeping compatibility with all SignalWire
# agent features (skills, POM, SWAIG functions, post-prompt). The one
# difference from a standard agent is that it emits SWML with the
# dedicated ``amazon_bedrock`` verb instead of ``ai``.

require_relative '../agent/agent_base'

module SignalWire
  module Agents
    # Agent implementation for the Amazon Bedrock voice-to-voice model.
    #
    # Mirrors Python's ``signalwire.agents.bedrock.BedrockAgent`` and the
    # PHP ``SignalWire\Agents\BedrockAgent``. It renders the same base
    # SWML as {SignalWire::AgentBase} and then transforms the ``ai`` verb
    # into an ``amazon_bedrock`` verb whose object carries voice and
    # inference parameters inside its prompt config, per the SWML
    # ``amazon_bedrock`` schema (keys: ``prompt``, ``SWAIG``, ``params``,
    # ``global_data``, ``post_prompt``, ``post_prompt_url``).
    class BedrockAgent < AgentBase
      # Prompt keys that apply to text models but not to Bedrock's
      # voice-to-voice model; stripped from the prompt config.
      TEXT_MODEL_ONLY_PROMPT_KEYS = %w[barge_confidence presence_penalty frequency_penalty].freeze

      # Initialize a BedrockAgent.
      #
      # Defaults: ``name="bedrock_agent"``, ``route="/bedrock"``,
      # ``voice_id="matthew"``, ``temperature=0.7``, ``top_p=0.9``,
      # ``max_tokens=1024``.
      #
      # @param name [String] agent name
      # @param route [String] HTTP route for the agent
      # @param system_prompt [String, nil] initial prompt (can be
      #   overridden later with set_prompt_text)
      # @param voice_id [String] Bedrock voice id (default "matthew")
      # @param temperature [Float] generation temperature (0-1)
      # @param top_p [Float] nucleus sampling parameter (0-1)
      # @param max_tokens [Integer] maximum tokens to generate
      # @param kwargs [Hash] additional arguments passed to AgentBase
      def initialize(name: 'bedrock_agent', route: '/bedrock', system_prompt: nil,
                     voice_id: 'matthew', temperature: 0.7, top_p: 0.9,
                     max_tokens: 1024, **)
        @voice_id = voice_id
        @temperature = temperature
        @top_p = top_p
        @max_tokens = max_tokens

        super(name: name, route: route, **)

        set_prompt_text(system_prompt) if system_prompt
      end

      # Render the SWML document, transforming the ``ai`` verb into an
      # ``amazon_bedrock`` verb.
      #
      # Overrides the base render to swap the ``ai`` verb structure for
      # ``amazon_bedrock``. The base render builds a Hash (not a JSON
      # string), so this operates on that Hash directly.
      #
      # @api private
      def _render_swml_internal
        swml = super
        main = swml.dig('sections', 'main')
        return swml unless main.is_a?(Array)

        idx = main.index { |verb| verb.is_a?(Hash) && verb.key?('ai') }
        main[idx] = { 'amazon_bedrock' => build_bedrock_object(main[idx]['ai']) } if idx

        swml
      end

      # Set the Bedrock voice id.
      #
      # @param voice_id [String] Bedrock voice identifier (e.g. "matthew")
      # @return [self]
      def set_voice(voice_id)
        @voice_id = voice_id
        self
      end

      # Update Bedrock inference parameters. Only non-nil values are
      # applied.
      #
      # @param temperature [Float, nil]
      # @param top_p [Float, nil]
      # @param max_tokens [Integer, nil]
      # @return [self]
      def set_inference_params(temperature: nil, top_p: nil, max_tokens: nil)
        @temperature = temperature unless temperature.nil?
        @top_p = top_p unless top_p.nil?
        @max_tokens = max_tokens unless max_tokens.nil?
        self
      end

      # Set LLM model — not applicable for Bedrock (fixed voice-to-voice
      # model). Logs a warning and does nothing.
      #
      # @param model [String] model name (ignored)
      # @return [self]
      def set_llm_model(model)
        @logger.warn("set_llm_model('#{model}') called but Bedrock uses a fixed voice-to-voice model")
        self
      end

      # Set LLM temperature — redirects to {#set_inference_params}.
      #
      # @param temperature [Float]
      # @return [self]
      def set_llm_temperature(temperature)
        set_inference_params(temperature: temperature)
      end

      # Set post-prompt LLM parameters — not applicable for Bedrock (the
      # post-prompt uses OpenAI configured server-side). Warns and no-ops.
      #
      # @param _params [Hash] ignored
      # @return [self]
      def set_post_prompt_llm_params(**_params)
        @logger.warn('set_post_prompt_llm_params() called but Bedrock post-prompt uses OpenAI configured in C code')
        self
      end

      # Set prompt LLM parameters — use {#set_inference_params} instead for
      # Bedrock. Warns and no-ops.
      #
      # @param _params [Hash] ignored
      # @return [self]
      def set_prompt_llm_params(**_params)
        @logger.warn('set_prompt_llm_params() called - use set_inference_params() for Bedrock')
        self
      end

      # String representation of the agent.
      #
      # Both ``inspect`` and ``to_s`` are implemented and return the same
      # representation.
      #
      # @return [String]
      def inspect
        "BedrockAgent(name='#{@name}', route='#{@route}', voice='#{@voice_id}')"
      end
      alias to_s inspect

      private

      # Build the amazon_bedrock verb object from the base ``ai`` config.
      # Voice + inference params live inside the prompt config; only
      # non-nil keys are emitted (matches the Python reference and the
      # amazon_bedrock schema).
      def build_bedrock_object(ai_config)
        object = {
          'prompt' => add_voice_to_prompt(ai_config['prompt'] || {}),
          'SWAIG' => ai_config['SWAIG'],
          'params' => ai_config['params'],
          'global_data' => ai_config['global_data'],
          'post_prompt' => ai_config['post_prompt'],
          'post_prompt_url' => ai_config['post_prompt_url']
        }
        object.compact
      end

      # Add voice + inference params to the prompt object, stripping
      # text-model-only keys.
      def add_voice_to_prompt(prompt_config)
        filtered = prompt_config.except(*TEXT_MODEL_ONLY_PROMPT_KEYS)
        filtered['voice_id'] = @voice_id
        filtered['temperature'] = @temperature
        filtered['top_p'] = @top_p
        filtered
      end
    end
  end
end
