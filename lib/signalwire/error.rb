# frozen_string_literal: true

module SignalWire
  # Root of the SignalWire SDK exception hierarchy.
  #
  # Every error the SDK raises on its own behalf descends from this class, so a
  # caller can rescue the whole SDK with a single `rescue SignalWire::Error`
  # (the Stripe gem's `StripeError` pattern). It subclasses `StandardError`, so
  # existing `rescue StandardError` / `rescue => e` handlers keep catching SDK
  # errors exactly as before — the root is a common ancestor, not a rename.
  #
  # Boundary-validation failures raised as stdlib `ArgumentError` / `TypeError`
  # are intentionally NOT reparented: they are standard-library contract
  # violations, not SignalWire service/protocol errors.
  class Error < StandardError; end
end
