# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# SWML Builder - Fluent API for building SWML documents.
#
# Provides a fluent builder API for creating SWML documents by chaining method
# calls. It delegates to an underlying SWML::Service instance for the actual
# document creation.

module SignalWire
  # SWML — SWML document construction, rendering and serving.
  module SWML
    # Fluent builder for SWML documents.
    #
    # The explicit verb helpers (#answer, #hangup, #play, #ai, #say) cover the
    # common verbs; every other schema verb is auto-vivified through
    # #method_missing (e.g. +builder.denoise.goto(...)+).
    class SWMLBuilder
      # Initialize with a SWML::Service instance to delegate to.
      #
      # @param service [SignalWire::SWML::Service]
      def initialize(service)
        @service = service
      end

      # Expose the underlying service (tests / subclasses).
      attr_reader :service

      # Add an 'answer' verb to the main section.
      #
      # @param max_duration [Integer, nil] maximum duration in seconds
      # @param codecs [String, nil] comma-separated list of codecs
      # @return [self]
      def answer(max_duration: nil, codecs: nil)
        config = {}
        config['max_duration'] = max_duration unless max_duration.nil?
        config['codecs'] = codecs unless codecs.nil?
        add_verb('answer', config)
      end

      # Add a 'hangup' verb to the main section.
      #
      # @param reason [String, nil] optional reason for hangup
      # @return [self]
      def hangup(reason: nil)
        config = {}
        config['reason'] = reason unless reason.nil?
        add_verb('hangup', config)
      end

      # Add an 'ai' verb to the main section.
      #
      # The SWML +ai+ verb requires +prompt+ to be an OBJECT — +{"text": ...}+ or
      # +{"pom": [...]}+; a bare string is a fatal error in the AI engine, so the
      # text/pom form is wrapped accordingly.
      #
      # @param prompt_text [String, nil] text prompt (mutually exclusive with prompt_pom)
      # @param prompt_pom [Array<Hash>, nil] POM structure prompt (mutually exclusive with prompt_text)
      # @param post_prompt [String, nil] optional post-prompt text
      # @param post_prompt_url [String, nil] optional post-prompt URL
      # @param swaig [Hash, nil] optional SWAIG configuration
      # @param kwargs [Hash] additional AI parameters merged into the config
      # @return [self]
      def ai(prompt_text: nil, prompt_pom: nil, post_prompt: nil,
             post_prompt_url: nil, swaig: nil, **kwargs)
        config = {}
        config['prompt'] = ai_prompt(prompt_text, prompt_pom) unless prompt_text.nil? && prompt_pom.nil?
        config['post_prompt'] = { 'text' => post_prompt } unless post_prompt.nil?
        put(config, 'post_prompt_url' => post_prompt_url, 'SWAIG' => swaig)
        # Merge any additional kwargs into the config, stringifying their keys.
        kwargs.each { |key, value| config[key.to_s] = value }

        add_verb('ai', config)
      end

      # Add a 'play' verb to the main section.
      #
      # @param url [String, nil] single URL to play (mutually exclusive with urls)
      # @param urls [Array<String>, nil] list of URLs to play (mutually exclusive with url)
      # @param volume [Float, nil] volume level (-40 to 40)
      # @param say_voice [String, nil] voice for text-to-speech
      # @param say_language [String, nil] language for text-to-speech
      # @param say_gender [String, nil] gender for text-to-speech
      # @param auto_answer [Boolean, nil] whether to auto-answer the call
      # @return [self]
      def play(url: nil, urls: nil, volume: nil, say_voice: nil,
               say_language: nil, say_gender: nil, auto_answer: nil)
        config = play_source_config(url, urls)
        config['volume'] = volume unless volume.nil?
        config['say_voice'] = say_voice unless say_voice.nil?
        config['say_language'] = say_language unless say_language.nil?
        config['say_gender'] = say_gender unless say_gender.nil?
        config['auto_answer'] = auto_answer unless auto_answer.nil?

        add_verb('play', config)
      end

      # Add a 'play' verb with a +say:+ prefix for text-to-speech.
      #
      # @param text [String] text to speak
      # @param voice [String, nil] voice for text-to-speech
      # @param language [String, nil] language for text-to-speech
      # @param gender [String, nil] gender for text-to-speech
      # @param volume [Float, nil] volume level (-40 to 40)
      # @return [self]
      def say(text, voice: nil, language: nil, gender: nil, volume: nil)
        play(url: "say:#{text}", say_voice: voice, say_language: language,
             say_gender: gender, volume: volume)
      end

      # Add a new section to the document.
      #
      # @param section_name [String]
      # @return [self]
      def add_section(section_name)
        @service.document.add_section(section_name)
        self
      end

      # Build and return the SWML document as a Hash.
      #
      # @return [Hash]
      def build
        @service.document.to_h
      end

      # Build and render the SWML document as a JSON string.
      #
      # @return [String]
      def render
        @service.render
      end

      # Reset the document to an empty state.
      #
      # @return [self]
      def reset
        @service.document.reset
        self
      end

      # Auto-vivify SWML verb methods from the schema.
      #
      # Any schema verb name not covered by an explicit method above is
      # dispatched to the underlying document, returning +self+ for chaining
      # (e.g. +builder.denoise.record+, +builder.sleep(2000)+).
      def method_missing(method_name, *args, **kwargs)
        verb = method_name.to_s
        return super unless SWML.schema.valid_verb?(verb)

        if verb == 'sleep'
          add_verb('sleep', sleep_duration(args, kwargs))
        else
          add_verb(verb, SWML._verb_config(verb, args, kwargs))
        end
      end

      # Report the auto-vivified verbs as respondable, so +respond_to?+ answers
      # true for any valid schema verb name.
      def respond_to_missing?(method_name, include_private = false)
        SWML.schema.valid_verb?(method_name.to_s) || super
      end

      private

      # Copy each pair whose value is non-nil into +config+ (skips absent options).
      def put(config, pairs)
        pairs.each { |key, value| config[key] = value unless value.nil? }
      end

      # Add a verb to the underlying document and return self for chaining.
      #
      # Every builder verb funnels through here and through the *validating*
      # Service#add_verb — never the raw Document entry point. The raw path
      # writes whatever it is handed, which is how schema-invalid configs
      # (a +play+ with a +text+ key, a +hangup+ with a reason outside the
      # closed +hangup|busy|decline+ enum) shipped unnoticed. A rejected
      # config now raises SchemaValidationError at build time.
      def add_verb(name, config)
        @service.add_verb(name, config)
        self
      end

      # The prompt object for an ai verb — {"text": ...} preferred, else {"pom": ...}.
      def ai_prompt(prompt_text, prompt_pom)
        return { 'text' => prompt_text } unless prompt_text.nil?

        { 'pom' => prompt_pom }
      end

      # The +url+/+urls+ source config for a play verb (mutually exclusive).
      def play_source_config(url, urls)
        return { 'url' => url } unless url.nil?
        return { 'urls' => urls } unless urls.nil?

        raise ArgumentError, 'Either url or urls must be provided'
      end

      # The +sleep+ verb takes a bare Integer (+sleep(2000)+) or a +duration:+
      # keyword; SWML emits the raw integer, not a config object.
      def sleep_duration(args, kwargs)
        if args.length == 1 && args.first.is_a?(Integer)
          args.first
        elsif kwargs.key?(:duration)
          kwargs[:duration]
        elsif !kwargs.empty?
          kwargs.values.first
        else
          raise ArgumentError, 'sleep requires an integer duration'
        end
      end
    end
  end
end
