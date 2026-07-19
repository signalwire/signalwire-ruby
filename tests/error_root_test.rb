# frozen_string_literal: true

# 6.2-ruby: a single SignalWire::Error root under StandardError, with every SDK
# error family reparented onto it (the Stripe `StripeError` pattern the port's
# philosophy doc already declares). Inserting a common ancestor is non-breaking:
# `SignalWire::Error < StandardError`, so existing `rescue StandardError` and
# `rescue <SpecificError>` handlers keep catching exactly what they did.

require 'minitest/autorun'
require 'signalwire'
require 'signalwire/rest/http_client'
require 'signalwire/relay/client'
require 'signalwire/relay/action'
require 'signalwire/core/auth_handler'
require 'signalwire/utils/schema_utils'

class ErrorRootTest < Minitest::Test
  # The five SDK error families, each of which used to subclass StandardError
  # directly. Any addition to this list should also be reparented.
  FAMILIES = [
    SignalWire::REST::SignalWireRestError,
    SignalWire::Relay::RelayError,
    SignalWire::Relay::ActionTimeoutError,
    SignalWire::Core::AuthError,
    SignalWire::Utils::SchemaValidationError
  ].freeze

  def test_root_is_under_standard_error
    assert_operator SignalWire::Error, :<, StandardError
  end

  def test_every_family_is_a_signalwire_error
    FAMILIES.each do |klass|
      assert_operator klass, :<, SignalWire::Error,
                      "#{klass} must subclass SignalWire::Error"
    end
  end

  def test_families_still_catchable_as_standard_error
    # Non-breaking: the reparent keeps StandardError catching them.
    FAMILIES.each do |klass|
      assert_operator klass, :<, StandardError, "#{klass} must remain a StandardError"
    end
  end
end
