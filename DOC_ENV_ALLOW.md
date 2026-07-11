# DOC-ENV allowlist

Each entry is an SDK env var the DOC-ENV gate flags but is a genuinely-justified
non-finding. Format: `- <VAR_NAME> — reason (approver, date)`.

Two kinds appear here:
  1. **gate-regex gap** — the var IS read by SDK code via `ENV.fetch('X', default)`,
     the idiomatic Ruby env read. The gate's `ENV_READ_RE` matches `ENV['X']` /
     `ENV.get` but its char-class `[\s\[("']` stops at the `.` in `ENV.fetch`, so
     `ENV.fetch('X', …)` reads are invisible to it. Wire-neutral idiom the gate
     misparses — the read is real (file:line below).
  2. **deliberately-not-consumed, illustrative doc** — the SDK intentionally does
     not auto-read the var; the doc explicitly says so and shows the user how to
     wire it themselves.

- SIGNALWIRE_LOG_LEVEL — read by SDK code via `ENV.fetch('SIGNALWIRE_LOG_LEVEL', nil)` (`lib/signalwire/logging.rb:84`); gate-regex gap: `ENV.fetch` not matched by `ENV_READ_RE` (orchestrator gate-gap, 2026-07-11)
- SIGNALWIRE_RELAY_HOST — read by SDK code via `ENV.fetch('SIGNALWIRE_RELAY_HOST', nil)` (`lib/signalwire/relay/client.rb:468`, the RELAY endpoint-host override); gate-regex gap: `ENV.fetch` not matched by `ENV_READ_RE` (orchestrator gate-gap, 2026-07-11)
- SWML_PROXY_URL_BASE — read by SDK code via `ENV.fetch('SWML_PROXY_URL_BASE', nil)` (`lib/signalwire/security/webhook_middleware.rb:215`, the reverse-proxy base URL); gate-regex gap: `ENV.fetch` not matched by `ENV_READ_RE` (orchestrator gate-gap, 2026-07-11)
- SIGNALWIRE_SKILL_PATHS — deliberately NOT auto-consumed by the Ruby SDK. Unlike the Python reference (registry.py reads it), the Ruby port does not read this var; `docs/third_party_skills.md` § "Method 4: Environment Variable" states this explicitly ("the Ruby port does not auto-consume the variable, so wire it up at startup") and shows the user how to register the directories themselves via `add_skill_directory`. An illustrative user-wiring example, not a promised SDK knob (orchestrator, 2026-07-11)
