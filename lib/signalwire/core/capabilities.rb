# frozen_string_literal: true

# Reading what a client says it can do.
#
# A browser client — the SignalWire address widget, or anything speaking the
# same convention — declares its rendering capabilities in the user variables it
# sends at dial time:
#
#   { "vars" => { "userVariables" => {
#       "capabilities" => { "display_content" => true, "transcript" => true,
#                           "chat_handoff" => false },
#       "metadata" => { "page" => {...}, "client" => {...}, "widget" => {...} } } } }
#
# These are declarations of what the client can RENDER, not grants of
# authority: treat them as hints for deciding what to offer, never as permission
# to do anything privileged — a caller controls its own user variables.
#
# Absence means no. Every function here resolves errors and missing data to "not
# declared", because offering a caller something they cannot reach is worse than
# never mentioning it. There is deliberately no enum of known capability names:
# a client must be able to declare something this SDK has never heard of and
# have an application act on it today.

module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Capabilities — the client capability declarations carried in a SWML
    # request body's user variables.
    module Capabilities
      module_function

      # Return the user variables from a SWML request body. They are nested two
      # levels down (+vars.userVariables+), which is easy to get wrong silently.
      #
      # @param body_params [Hash, nil] the SWML request body
      # @return [Hash] the user variables, or +{}+
      def user_variables(body_params)
        return {} unless body_params.is_a?(Hash)

        vars = body_params['vars']
        variables = vars.is_a?(Hash) ? vars['userVariables'] : nil
        variables.is_a?(Hash) ? variables : {}
      end

      # Return the capability names the client declared as truthy. Accepts a full
      # SWML request body or an already-extracted user variables hash, so it is
      # usable from a dynamic-config callback and from a SWAIG handler alike.
      #
      #   caps = SignalWire::Core::Capabilities.declared_capabilities(body_params)
      #   agent.prompt_add_section('Screen', body: '...') if caps.include?('display_content')
      #
      # @param body_params [Hash, nil] SWML request body, or a user variables hash
      # @return [Set<String>] frozen set of declared names; empty when nothing was
      #   declared, the payload was malformed, or the client is not a browser
      def declared_capabilities(body_params)
        variables = user_variables(body_params)
        # Already-extracted user variables were passed directly.
        variables = body_params if variables.empty? && body_params.is_a?(Hash)

        capabilities = variables['capabilities']
        return Set.new.freeze unless capabilities.is_a?(Hash)

        capabilities.each_with_object(Set.new) do |(name, value), names|
          names << name if name.is_a?(String) && declared?(value)
        end.freeze
      end

      # Whether the client declared +name+.
      #
      # @param body_params [Hash, nil] SWML request body, or a user variables hash
      # @param name [String] capability name, e.g. "display_content"
      # @return [Boolean] true only when explicitly declared truthy
      def has_capability(body_params, name)
        declared_capabilities(body_params).include?(name)
      end

      # @api private — a declared value is "on" by the wire's JSON truthiness:
      # false / null / 0 / "" / [] / {} are not declarations.
      def declared?(value)
        case value
        when nil, false then false
        when Numeric then !value.zero?
        when String, Array, Hash then !value.empty?
        else true
        end
      end
      private_class_method :declared?
    end
  end
end
