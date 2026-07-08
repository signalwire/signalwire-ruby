# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# SWML Verb Handlers - Interface and implementations for SWML verb handling.
#
# This module defines the base interface for SWML verb handlers and provides
# implementations for specific verbs that require special handling. Mirrors the
# Python reference signalwire.core.swml_handler (SWMLVerbHandler / AIVerbHandler
# / VerbHandlerRegistry) and the PHP SignalWire\SWML\{SWMLVerbHandler,
# AIVerbHandler, VerbHandlerRegistry}.

module SignalWire
  module SWML
    # Base interface for SWML verb handlers.
    #
    # Verb handlers provide specialized logic for complex SWML verbs that cannot
    # be handled generically. This is an abstract base: the base methods raise
    # NotImplementedError so a subclass that forgets to override them fails
    # loudly.
    class SWMLVerbHandler
      # Get the name of the verb this handler handles.
      #
      # @return [String] the verb name
      def get_verb_name
        raise NotImplementedError, "#{self.class}#get_verb_name must be implemented"
      end

      # Validate the configuration for this verb.
      #
      # @param config [Hash] the configuration for this verb
      # @return [Array(Boolean, Array<String>)] (is_valid, error_messages)
      def validate_config(_config)
        raise NotImplementedError, "#{self.class}#validate_config must be implemented"
      end

      # Build a configuration for this verb from the provided arguments.
      #
      # @param kwargs [Hash] keyword arguments specific to this verb
      # @return [Hash] configuration dictionary
      def build_config(**_kwargs)
        raise NotImplementedError, "#{self.class}#build_config must be implemented"
      end
    end

    # Handler for the SWML 'ai' verb.
    #
    # The 'ai' verb is complex and requires specialized handling, particularly
    # for managing prompts, SWAIG functions, and AI configurations.
    class AIVerbHandler < SWMLVerbHandler
      # @return [String] "ai"
      def get_verb_name
        'ai'
      end

      # Validate the configuration for the AI verb.
      #
      # Checks that +prompt+ is present and an object, contains exactly one of
      # +text+ / +pom+ (mutually exclusive), that +prompt.contexts+ (if present)
      # is an object, and that +SWAIG+ (if present) is an object.
      #
      # @param config [Hash] the AI verb configuration
      # @return [Array(Boolean, Array<String>)] (is_valid, error_messages)
      def validate_config(config)
        return [false, ["Missing required field 'prompt'"]] unless config.key?('prompt')

        prompt = config['prompt']
        return [false, ["'prompt' must be an object"]] unless prompt.is_a?(Hash)

        errors = validate_base_prompt(prompt)
        errors << "'prompt.contexts' must be an object" if prompt.key?('contexts') && !prompt['contexts'].is_a?(Hash)
        errors << "'SWAIG' must be an object" if config.key?('SWAIG') && !config['SWAIG'].is_a?(Hash)

        [errors.empty?, errors]
      end

      # Build a configuration for the AI verb.
      #
      # Requires exactly one of +prompt_text+ / +prompt_pom+ (mutually
      # exclusive). +languages+, +hints+, +pronounce+ and +global_data+ are
      # placed at the top level; every other extra keyword is placed into
      # +config['params']+.
      #
      # @param prompt_text [String, nil] base text prompt
      # @param prompt_pom [Array<Hash>, nil] POM structure prompt
      # @param contexts [Hash, nil] optional contexts/steps configuration
      # @param post_prompt [String, nil] optional post-prompt text
      # @param post_prompt_url [String, nil] optional post-prompt URL
      # @param swaig [Hash, nil] optional SWAIG configuration
      # @param kwargs [Hash] additional AI parameters
      # @return [Hash] AI verb configuration dictionary
      def build_config(prompt_text: nil, prompt_pom: nil, contexts: nil,
                       post_prompt: nil, post_prompt_url: nil, swaig: nil, **kwargs)
        require_single_base_prompt(prompt_text, prompt_pom)

        config = { 'prompt' => build_prompt_config(prompt_text, prompt_pom, contexts) }
        config['post_prompt'] = { 'text' => post_prompt } unless post_prompt.nil?
        config['post_prompt_url'] = post_prompt_url unless post_prompt_url.nil?
        config['SWAIG'] = swaig unless swaig.nil?

        # Match Python behaviour: always initialise the params dict.
        config['params'] = {}
        route_extra_kwargs(config, kwargs)
        config
      end

      # Top-level AI keys that live outside the params object.
      TOP_LEVEL_AI_KEYS = %i[languages hints pronounce global_data].freeze

      private

      # Base-prompt errors for validate_config (exactly one of text/pom required).
      def validate_base_prompt(prompt)
        count = [prompt.key?('text'), prompt.key?('pom')].count(true)
        return ["'prompt' must contain either 'text' or 'pom' as base prompt"] if count.zero?
        return ["'prompt' can only contain one of: 'text' or 'pom' (mutually exclusive)"] if count > 1

        []
      end

      # Enforce the mutually-exclusive base-prompt contract for build_config.
      def require_single_base_prompt(prompt_text, prompt_pom)
        count = [prompt_text, prompt_pom].count { |x| !x.nil? }
        raise ArgumentError, 'Either prompt_text or prompt_pom must be provided as base prompt' if count.zero?
        raise ArgumentError, 'prompt_text and prompt_pom are mutually exclusive' if count > 1
      end

      # Build the prompt object ({"text"|"pom" => ...} plus optional contexts).
      def build_prompt_config(prompt_text, prompt_pom, contexts)
        prompt_config = {}
        if !prompt_text.nil?
          prompt_config['text'] = prompt_text
        elsif !prompt_pom.nil?
          prompt_config['pom'] = prompt_pom
        end
        prompt_config['contexts'] = contexts unless contexts.nil?
        prompt_config
      end

      # Route extra kwargs: recognised top-level keys stay at the top level,
      # everything else drops into config['params'].
      def route_extra_kwargs(config, kwargs)
        kwargs.each do |key, value|
          if TOP_LEVEL_AI_KEYS.include?(key)
            config[key.to_s] = value
          else
            config['params'][key.to_s] = value
          end
        end
      end
    end

    # Registry for SWML verb handlers.
    #
    # Maintains a registry of handlers for special SWML verbs and provides
    # methods for accessing them. The "ai" verb handler is registered
    # automatically on construction.
    class VerbHandlerRegistry
      # Initialize the registry with default handlers.
      def initialize
        @handlers = {}
        register_handler(AIVerbHandler.new)
      end

      # Register a new verb handler, replacing any existing handler for the same
      # verb name.
      #
      # @param handler [SWMLVerbHandler]
      # @return [void]
      def register_handler(handler)
        @handlers[handler.get_verb_name] = handler
        nil
      end

      # Get the handler for a specific verb, or nil when none is registered.
      #
      # @param verb_name [String]
      # @return [SWMLVerbHandler, nil]
      def get_handler(verb_name)
        @handlers[verb_name]
      end

      # Whether a handler exists for a specific verb.
      #
      # @param verb_name [String]
      # @return [Boolean]
      def has_handler(verb_name)
        @handlers.key?(verb_name)
      end
    end
  end
end
