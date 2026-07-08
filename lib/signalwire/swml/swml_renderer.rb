# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# SWML document rendering utilities for SignalWire AI Agents.
#
# Mirrors the Python reference signalwire.core.swml_renderer.SwmlRenderer (two
# staticmethod-like helpers) and the PHP SignalWire\SWML\SwmlRenderer. Both
# helpers are module functions in Ruby (def self.) since the reference methods
# are static.

require_relative 'swml_builder'

module SignalWire
  module SWML
    # Renders SWML documents for SignalWire AI Agents with AI and SWAIG
    # components, built on top of the SWML::Service document model.
    class SwmlRenderer
      # Special hook function names that are deduped from the caller's list.
      HOOK_FUNCTIONS = %w[startup_hook hangup_hook].freeze
      # Action verbs (in precedence order) recognised in a function response.
      RESPONSE_ACTION_VERBS = %w[play hangup transfer ai].freeze

      # Generate a complete SWML document with an AI configuration.
      #
      # @param prompt [String, Array<Hash>] AI prompt text, or a POM structure when prompt_is_pom
      # @param service [SignalWire::SWML::Service] service to build the document with
      # @param post_prompt [String, nil] optional post-prompt text
      # @param post_prompt_url [String, nil] optional post-prompt URL
      # @param swaig_functions [Array<Hash>, nil] SWAIG function definitions
      # @param startup_hook_url [String, nil] optional startup hook URL
      # @param hangup_hook_url [String, nil] optional hangup hook URL
      # @param prompt_is_pom [Boolean] whether +prompt+ is a POM structure
      # @param params [Hash, nil] additional AI verb parameters
      # @param add_answer [Boolean] whether to add an answer verb
      # @param record_call [Boolean] whether to add a record_call verb
      # @param record_format [String] recording format
      # @param record_stereo [Boolean] whether to record in stereo
      # @param format [String] output format ("json" or "yaml")
      # @param default_webhook_url [String, nil] default webhook URL for SWAIG functions
      # @return [String] SWML document as a string
      def self.render_swml(prompt:, service:, post_prompt: nil, post_prompt_url: nil,
                           swaig_functions: nil, startup_hook_url: nil, hangup_hook_url: nil,
                           prompt_is_pom: false, params: nil, add_answer: false,
                           record_call: false, record_format: 'mp4', record_stereo: true,
                           format: 'json', default_webhook_url: nil)
        builder = SWMLBuilder.new(service)
        builder.reset
        builder.answer if add_answer
        add_record_call(service, record_format, record_stereo) if record_call

        functions = build_functions(swaig_functions, startup_hook_url, hangup_hook_url)
        swaig_config = build_swaig_config(functions, default_webhook_url)
        emit_ai(builder, prompt, prompt_is_pom, swaig_config,
                post_prompt: post_prompt, post_prompt_url: post_prompt_url, params: params)
        render_in(builder, format)
      end

      # Add the record_call verb with its exact wire keys (format + stereo).
      def self.add_record_call(service, record_format, record_stereo)
        service.document.add_verb('record_call', { 'format' => record_format, 'stereo' => record_stereo })
      end

      # Emit the ai verb on the builder from the renderer's inputs.
      def self.emit_ai(builder, prompt, prompt_is_pom, swaig_config, post_prompt:, post_prompt_url:, params:)
        builder.ai(
          prompt_text: prompt_is_pom ? nil : prompt, prompt_pom: prompt_is_pom ? prompt : nil,
          post_prompt: post_prompt, post_prompt_url: post_prompt_url,
          swaig: swaig_config.empty? ? nil : swaig_config, **(params || {}).transform_keys(&:to_sym)
        )
      end

      # Render the builder's document in the requested format ("json" | "yaml").
      def self.render_in(builder, format)
        format.to_s.downcase == 'yaml' ? render_yaml(builder.build) : builder.render
      end

      # Generate a SWML document for a function response — a +play+ of the
      # response text followed by any provided actions.
      #
      # @param response_text [String] text response to include in the document
      # @param service [SignalWire::SWML::Service] service to build with
      # @param actions [Array<Hash>, nil] optional list of actions to perform
      # @param format [String] output format ("json" or "yaml")
      # @return [String] SWML document as a string
      def self.render_function_response_swml(response_text:, service:, actions: nil, format: 'json')
        service.document.reset
        service.document.add_verb('play', { 'text' => response_text }) if response_text && !response_text.empty?
        (actions || []).each { |action| add_response_action(service, action) }

        format.to_s.downcase == 'yaml' ? render_yaml(service.document.to_h) : service.render
      end

      # Add the first recognised action verb from an action hash to the document.
      def self.add_response_action(service, action)
        verb = RESPONSE_ACTION_VERBS.find { |v| action.key?(v) }
        service.document.add_verb(verb, action[verb]) if verb
      end

      # Build the SWAIG function list, prepending startup/hangup hooks and
      # skipping any duplicate hooks in the caller-supplied list.
      def self.build_functions(swaig_functions, startup_hook_url, hangup_hook_url)
        functions = hook_functions(startup_hook_url, hangup_hook_url)
        (swaig_functions || []).each do |func|
          fn = func['function'] || func[:function]
          functions << func unless HOOK_FUNCTIONS.include?(fn)
        end
        functions
      end

      # The startup/hangup hook function definitions (only for non-empty URLs).
      def self.hook_functions(startup_hook_url, hangup_hook_url)
        list = []
        if startup_hook_url && !startup_hook_url.empty?
          list << hook_function('startup_hook', 'Called when the call starts', startup_hook_url)
        end
        if hangup_hook_url && !hangup_hook_url.empty?
          list << hook_function('hangup_hook', 'Called when the call ends', hangup_hook_url)
        end
        list
      end

      # Build a single startup/hangup hook function definition.
      def self.hook_function(name, description, url)
        {
          'function' => name,
          'description' => description,
          'parameters' => { 'type' => 'object', 'properties' => {} },
          'web_hook_url' => url
        }
      end

      # Build the SWAIG config object from the function list + default URL.
      def self.build_swaig_config(functions, default_webhook_url)
        swaig_config = {}
        has_default = default_webhook_url && !default_webhook_url.empty?
        return swaig_config unless !functions.empty? || has_default

        swaig_config['defaults'] = { 'web_hook_url' => default_webhook_url } if has_default
        swaig_config['functions'] = functions unless functions.empty?
        swaig_config
      end

      # Render a document Hash as YAML. Ruby's stdlib +yaml+ is always
      # available.
      def self.render_yaml(doc)
        require 'yaml'
        YAML.dump(doc)
      end

      private_class_method :build_functions, :build_swaig_config, :render_yaml,
                           :hook_function, :hook_functions, :add_response_action, :render_in,
                           :add_record_call, :emit_ai
    end
  end
end
