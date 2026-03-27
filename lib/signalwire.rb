# frozen_string_literal: true

require_relative 'signalwire/version'
require_relative 'signalwire/logging'
require_relative 'signalwire/swml/document'
require_relative 'signalwire/swml/schema'
require_relative 'signalwire/swml/service'
require_relative 'signalwire/swaig/function_result'
require_relative 'signalwire/security/session_manager'
require_relative 'signalwire/contexts/context_builder'
require_relative 'signalwire/datamap/data_map'
require_relative 'signalwire/skills/skill_base'
require_relative 'signalwire/skills/skill_manager'
require_relative 'signalwire/skills/skill_registry'
require_relative 'signalwire/agent/agent_base'

module SignalWire
  # Top-level convenience: re-export VERSION from version.rb
end
