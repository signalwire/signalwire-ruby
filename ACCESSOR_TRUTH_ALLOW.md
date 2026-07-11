# ACCESSOR-TRUTH allowlist

Each entry is a documented backtick `method()` the ACCESSOR-TRUTH gate flags but
is a genuinely-justified non-finding — the method really exists (with file:line
proof) but the gate's Ruby `def_re` cannot see it, OR it is an explicitly-
illustrative / other-language reference. Format: `- <method> — reason (approver, date)`.

- create_payment_action — real static method, `lib/signalwire/swaig/function_result.rb:712` (`def self.create_payment_action(action_type, phrase)`); Python parity `FunctionResult.create_payment_action` (function_result.py:1499), recorded in the signature oracle + port_signatures.json. The gate's Ruby `def_re` (`def\s+([a-z_]...)`) captures `self` from a `def self.NAME` singleton-method definition and so cannot see any of the 91 `def self.` class methods in the SDK. Wire-neutral gate-regex limitation, not a doc mismatch (orchestrator gate-gap, 2026-07-11)
- create_payment_parameter — real static method, `lib/signalwire/swaig/function_result.rb:721` (`def self.create_payment_parameter(name, value)`); Python parity `FunctionResult.create_payment_parameter` (function_result.py:1513), recorded in the signature oracle + port_signatures.json. Same `def self.`-not-captured gate-regex limitation as above (orchestrator gate-gap, 2026-07-11)
- create_payment_prompt — real static method, `lib/signalwire/swaig/function_result.rb:697` (`def self.create_payment_prompt(for_situation, actions, card_type: nil, error_type: nil)`); Python parity `FunctionResult.create_payment_prompt` (function_result.py:1471), recorded in the signature oracle + port_signatures.json. Same `def self.`-not-captured gate-regex limitation as above (orchestrator gate-gap, 2026-07-11)
