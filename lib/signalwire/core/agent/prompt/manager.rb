# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Prompt management functionality for AgentBase.

require_relative '../../../pom/prompt_object_model'
require_relative '../../../contexts/context_builder'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Agent — the agent internals: prompt management and tool registration.
    module Agent
      # Prompt — prompt construction and management.
      module Prompt
        # Manages prompt building and configuration for an agent.
        #
        # Mirrors Python's
        # ``signalwire.core.agent.prompt.manager.PromptManager`` and the
        # TypeScript ``PromptManager`` class. It manages a POM-backed
        # prompt (via {SignalWire::POM::PromptObjectModel}), an optional
        # raw prompt text, a post-prompt, and a contexts configuration
        # (via {SignalWire::Contexts::ContextBuilder}).
        #
        # The prompt has two mutually exclusive modes: raw text
        # (``set_prompt_text``) OR POM sections (the ``prompt_add_*``
        # methods). Mixing the two raises. Contexts, when defined, take
        # precedence over both in {#get_prompt}.
        class PromptManager
          # @return [SignalWire::POM::PromptObjectModel] the backing POM
          attr_reader :pom

          # @return [Object, nil] the parent AgentBase back-reference this
          #   manager was constructed with. The reference exposes the same
          #   attribute (core/agent/prompt/manager.py), so a caller that passes
          #   an agent can read it back.
          attr_reader :agent

          # @param agent [Object, nil] optional parent AgentBase instance
          #   (kept as a back-reference; may be nil for standalone use).
          def initialize(agent = nil)
            @agent = agent
            @pom = SignalWire::POM::PromptObjectModel.new
            @prompt_text = nil
            @post_prompt_text = nil
            @contexts = nil
          end

          # Set the agent's prompt as raw text.
          #
          # @param text [String] prompt text
          # @raise [ArgumentError] if POM sections are already in use
          # @return [self]
          def set_prompt_text(text)
            validate_prompt_mode_exclusivity
            @prompt_text = text
            self
          end

          # Set the post-prompt text.
          #
          # @param text [String] post-prompt text
          # @return [self]
          def set_post_prompt(text)
            @post_prompt_text = text
            self
          end

          # Set the prompt from a POM array (list of section Hashes).
          #
          # Mirrors Python's ``set_prompt_pom(pom)``.
          #
          # @param pom [Array<Hash>] POM section descriptors
          # @return [self]
          def set_prompt_pom(pom)
            @prompt_text = nil
            @pom = SignalWire::POM::PromptObjectModel.from_json(pom)
            self
          end

          # Add a section to the prompt.
          #
          # Mirrors Python's ``prompt_add_section(title, body="",
          # bullets=None, numbered=False, numbered_bullets=False,
          # subsections=None)``.
          #
          # @param title [String] section title
          # @param body [String] optional body text
          # @param bullets [Array<String>, nil] optional bullet points
          # @param numbered [Boolean] number this section
          # @param numbered_bullets [Boolean] number the bullets
          # @param subsections [Array<Hash>, nil] optional subsection Hashes
          # @return [self]
          def prompt_add_section(title, body: '', bullets: nil, numbered: false,
                                 numbered_bullets: false, subsections: nil)
            validate_prompt_mode_exclusivity
            section = @pom.add_section(title, body: body, bullets: bullets || [],
                                              numbered: numbered, numbered_bullets: numbered_bullets)
            add_subsections(section, subsections)
            self
          end

          # Add content to an existing section (creating it if needed).
          #
          # Mirrors Python's ``prompt_add_to_section(title, body=None,
          # bullet=None, bullets=None)``.
          #
          # @param title [String] section title
          # @param body [String, nil] text to append to the section body
          # @param bullet [String, nil] single bullet to add
          # @param bullets [Array<String>, nil] bullets to add
          # @return [self]
          def prompt_add_to_section(title, body: nil, bullet: nil, bullets: nil)
            section = @pom.find_section(title) || @pom.add_section(title, body: '')
            append_body(section, body)
            append_bullets(section, bullet, bullets)
            self
          end

          # Add a subsection to an existing section (creating the parent if
          # needed).
          #
          # Mirrors Python's ``prompt_add_subsection(parent_title, title,
          # body="", bullets=None)``.
          #
          # @param parent_title [String] parent section title
          # @param title [String] subsection title
          # @param body [String] optional subsection body
          # @param bullets [Array<String>, nil] optional bullets
          # @return [self]
          def prompt_add_subsection(parent_title, title, body: '', bullets: nil)
            parent = @pom.find_section(parent_title) || @pom.add_section(parent_title, body: '')
            parent.add_subsection(title, body: body, bullets: bullets || [])
            self
          end

          # Check whether a section exists in the prompt.
          #
          # @param title [String] section title
          # @return [Boolean] true if the section exists
          def prompt_has_section(title)
            !@pom.find_section(title).nil?
          end

          # Define contexts for the agent.
          #
          # Mirrors Python's ``define_contexts(contexts)`` which accepts a
          # ``ContextBuilder`` (materialised via ``to_h``) or a raw Hash.
          #
          # @param contexts [SignalWire::Contexts::ContextBuilder, Hash]
          # @raise [ArgumentError] if not a ContextBuilder or Hash
          # @return [self]
          def define_contexts(contexts)
            @contexts =
              if contexts.respond_to?(:to_h) && !contexts.is_a?(Hash)
                contexts.to_h
              elsif contexts.is_a?(Hash)
                contexts
              else
                raise ArgumentError, 'contexts must be a Hash or a ContextBuilder object'
              end
            self
          end

          # Get the prompt configuration.
          #
          # Contexts take precedence (return nil — they render their own
          # sections); otherwise raw text if set, else the POM section
          # array, else nil.
          #
          # @return [String, Array<Hash>, nil]
          def get_prompt
            return nil if @contexts
            return @prompt_text if @prompt_text

            sections = @pom.to_h
            sections.empty? ? nil : sections
          end

          # Get the raw prompt text if set.
          #
          # @return [String, nil]
          def get_raw_prompt
            @prompt_text
          end

          # Get the post-prompt text.
          #
          # @return [String, nil]
          def get_post_prompt
            @post_prompt_text
          end

          # Get the contexts configuration.
          #
          # @return [Hash, nil]
          def get_contexts
            @contexts
          end

          private

          # Raise if both prompt modes (raw text + POM sections) are active.
          def validate_prompt_mode_exclusivity
            return unless @prompt_text && !@pom.to_h.empty?

            raise ArgumentError,
                  'Cannot use both prompt_text and POM sections. ' \
                  'Please use either set_prompt_text() OR the prompt_add_* methods, not both.'
          end

          def add_subsections(section, subsections)
            return unless subsections.is_a?(Array)

            subsections.each do |sub|
              h = sub.transform_keys(&:to_s)
              next unless h['title']

              section.add_subsection(h['title'], body: h.fetch('body', ''), bullets: h['bullets'] || [])
            end
          end

          def append_body(section, body)
            return unless body

            section.body = section.body.to_s.empty? ? body : "#{section.body}\n\n#{body}"
          end

          def append_bullets(section, bullet, bullets)
            to_add = []
            to_add << bullet if bullet
            to_add.concat(bullets) if bullets.is_a?(Array)
            section.add_bullets(to_add) unless to_add.empty?
          end
        end
      end
    end
  end
end
