# frozen_string_literal: true

require 'json'

# Post-prompt normalization.
#
# One conversation can run over voice and over text chat, and both ends produce
# "the post-prompt" — but not in the same shape. This module absorbs that
# divergence so an application sees one artifact regardless of which engine
# finished the conversation:
#
#   field              voice                       chat
#   app_name           "swml app"                  "ai_chat"
#   conversation_id    absent                      present at top level
#   full log           raw_call_log                raw_messages
#   summary arrives as summarize_conversation      a bare role: assistant turn
#                      tool call                   inside call_log
#   post_prompt_data   parsed object               {"raw" => "```json ...```"}
#
# +conversation_type+ is a reliable top-level discriminator on both. A third
# +post_prompt_data+ shape seen from the voice engine — +{"parsed" => [ {...} ],
# "raw" => "..."}+ — is unwrapped too. Parsing is schema-agnostic: the summary's
# keys are whatever the application's post-prompt asked the model to produce.
module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # PostPrompt — normalize a post-prompt body from either engine.
    module PostPrompt
      # Roles that are actual dialogue. Everything else in a call log is
      # machinery: system (the prompt), system-log (lifecycle), tool (function
      # output), assistant-manual (filler speech).
      DIALOGUE_ROLES = %w[user assistant].freeze

      # The keys a conversation's log arrives under, in preference order.
      LOG_KEYS = %w[call_log raw_call_log raw_messages].freeze

      FENCE_OPEN = /\A```[a-zA-Z]*\s*/
      FENCE_CLOSE = /\s*```\z/
      private_constant :FENCE_OPEN, :FENCE_CLOSE, :LOG_KEYS

      # One finished conversation leg, in a shape that does not vary by engine.
      #
      # - +medium+: +conversation_type+ as reported ("voice" / "chat"), "" when
      #   the engine did not say.
      # - +conversation_id+: present on chat, absent (nil) on voice.
      # - +summary+: the parsed +post_prompt_data+; +{}+ when there was none. A
      #   prose answer yields +{"summary" => "<the prose>"}+.
      # - +dialogue+: user/assistant turns only, tool calls and the chat engine's
      #   summary echo removed.
      # - +call_id+: the platform call id, when present.
      # - +raw+: the complete request body, untouched.
      NormalizedPostPrompt = Struct.new(:medium, :conversation_id, :summary, :dialogue, :call_id, :raw,
                                        keyword_init: true) do
        # @param medium [String] conversation_type as reported
        # @param conversation_id [String, nil] the chat conversation id
        # @param summary [Hash] the parsed post_prompt_data
        # @param dialogue [Array<Hash>] the user/assistant turns
        # @param call_id [String, nil] the platform call id
        # @param raw [Hash] the complete request body
        def initialize(medium: '', conversation_id: nil, summary: {}, dialogue: [], call_id: nil, raw: {})
          super
          freeze
        end
      end

      module_function

      # Unwrap ```` ```json ... ``` ```` fencing — the chat engine hands the
      # model's answer back verbatim, fence and all.
      #
      # @param text [String, nil]
      # @return [String]
      def strip_json_fence(text)
        stripped = text.to_s.strip
        stripped = stripped.sub(FENCE_OPEN, '').sub(FENCE_CLOSE, '') if stripped.start_with?('```')
        stripped.strip
      end

      # Return +post_prompt_data+ as a plain Hash, whichever shape it arrived in.
      # Never raises: the conversation is already over, so a malformed summary
      # degrades rather than failing the request that delivered it.
      #
      # @param data [Object] the +post_prompt_data+ value from a post-prompt body
      # @return [Hash] the summary object, or +{}+ when there is nothing usable
      def parse_post_prompt_data(data)
        return {} unless data.is_a?(Hash)

        unwrapped = unwrap_parsed(data)
        return unwrapped if unwrapped && !unwrapped.empty?

        # Flat shape: real keys already present (anything but raw/parsed).
        flat = data.except('raw', 'parsed')
        return flat unless flat.empty?

        parse_raw_summary(data['raw'])
      end

      # Extract the real dialogue from a call log: drops non-dialogue roles,
      # entries carrying +tool_calls+, empty content, and — when +drop_echo+ is
      # given — the chat engine's summary echo (a bare assistant turn
      # byte-identical to +post_prompt_data.raw+).
      #
      # @param call_log [Array, Object] the log (call_log / raw_call_log / raw_messages)
      # @param roles [Array<String>] roles to keep
      # @param drop_echo [String, nil] exact content to treat as the summary echo
      # @return [Array<Hash{String=>String}>] +[{"role" => ..., "content" => ...}]+ in order
      def dialogue_turns(call_log, roles: DIALOGUE_ROLES, drop_echo: nil)
        return [] unless call_log.is_a?(Array)

        echo = drop_echo.to_s.strip
        call_log.filter_map do |entry|
          next unless dialogue_entry?(entry, roles, echo)

          { 'role' => entry['role'], 'content' => entry['content'] }
        end
      end

      # Normalize a post-prompt body from either engine. Never raises; a body it
      # cannot make sense of yields a {NormalizedPostPrompt} with empty fields.
      #
      #   leg = SignalWire::Core::PostPrompt.normalize_post_prompt(raw_body)
      #   store(leg.conversation_id, leg.medium, leg.summary, leg.dialogue) unless leg.dialogue.empty?
      #
      # @param body [Hash, Object] the complete post-prompt request body
      # @return [NormalizedPostPrompt]
      def normalize_post_prompt(body)
        return NormalizedPostPrompt.new unless body.is_a?(Hash)

        NormalizedPostPrompt.new(
          medium: body['conversation_type'].to_s,
          conversation_id: presence(body['conversation_id']),
          summary: parse_post_prompt_data(body['post_prompt_data']),
          dialogue: dialogue_turns(conversation_log(body), drop_echo: raw_summary(body)),
          call_id: presence(body['call_id']),
          raw: body
        )
      end

      # @api private — the object out of a +{"parsed" => [...]}+ wrapper, if present.
      def unwrap_parsed(data)
        parsed = data['parsed']
        return parsed if parsed.is_a?(Hash)
        return nil unless parsed.is_a?(Array)

        parsed.find { |item| item.is_a?(Hash) && !item.empty? }
      end

      # @api private — the summary from a +raw+ string: JSON when it parses to an
      # object, else the prose itself under "summary".
      def parse_raw_summary(raw)
        return {} unless raw.is_a?(String) && !raw.strip.empty?

        unfenced = strip_json_fence(raw)
        loaded = JSON.parse(unfenced)
        loaded.is_a?(Hash) ? loaded : { 'summary' => loaded.to_s }
      rescue JSON::ParserError
        { 'summary' => unfenced }
      end

      # @api private — whether one call-log entry is a dialogue turn worth keeping.
      def dialogue_entry?(entry, roles, echo)
        return false unless entry.is_a?(Hash) && roles.include?(entry['role'])
        return false if present?(entry['tool_calls'])

        content = entry['content']
        content.is_a?(String) && !content.strip.empty? && (echo.empty? || content.strip != echo)
      end

      # @api private — truthy and, when it has a size, non-empty.
      def present?(value)
        value && !(value.respond_to?(:empty?) && value.empty?)
      end

      # @api private — the log the engine sent: call_log, raw_call_log or raw_messages.
      def conversation_log(body)
        LOG_KEYS.each do |key|
          return body[key] if present?(body[key])
        end
        []
      end

      # @api private — the RAW summary string the engine returned (the echo the
      # chat engine appends carries the fence too), or nil.
      def raw_summary(body)
        ppd = body['post_prompt_data']
        raw = ppd.is_a?(Hash) ? ppd['raw'] : nil
        raw.is_a?(String) && !raw.empty? ? raw : nil
      end

      # @api private — +value+ unless it is nil or empty, else nil.
      def presence(value)
        present?(value) ? value : nil
      end

      private_class_method :unwrap_parsed, :parse_raw_summary, :dialogue_entry?, :present?,
                           :conversation_log, :raw_summary, :presence
    end
  end
end
