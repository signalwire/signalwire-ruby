# frozen_string_literal: true

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
          'mcp_error' => :string,
        }.freeze

        attr_reader :command_name
        attr_reader :command_arg
        attr_reader :epoch_time
        attr_reader :native
        attr_reader :active_count
        attr_reader :url
        attr_reader :post_data
        attr_reader :post_response
        attr_reader :delayed_post_response
        attr_reader :mcp_url
        attr_reader :mcp_tool
        attr_reader :mcp_response
        attr_reader :mcp_error
      end
    end
  end
end
