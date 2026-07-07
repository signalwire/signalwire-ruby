# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptSwaigLogEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptSwaigLogEntry — generated read-side payload (post-prompt components/schemas 'PostPromptSwaigLogEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptSwaigLogEntry
        FIELDS = {
          'command_name' => :string,
          'command_arg' => :string,
          'epoch_time' => :integer,
          'native' => :boolean,
          'active_count' => :object,
          'url' => :string,
          'post_data' => :object,
          'post_response' => :object,
          'delayed_post_response' => :object,
          'mcp_url' => :string,
          'mcp_tool' => :string,
          'mcp_response' => :object,
          'mcp_error' => :string
        }.freeze

        attr_reader :command_name, :command_arg, :epoch_time, :native, :active_count, :url, :post_data, :post_response, :delayed_post_response, :mcp_url, :mcp_tool, :mcp_response, :mcp_error
      end
    end
  end
end
# rubocop:enable Layout/LineLength
