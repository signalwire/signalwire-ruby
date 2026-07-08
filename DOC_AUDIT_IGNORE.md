# Doc Audit Ignore List

Names listed here are ignored by `scripts/audit_docs.py` when it scans the
Ruby port's docs and examples for method calls. Every entry carries a
one-line rationale plus an approver and date — these are **not** phantom
SignalWire APIs; they are:

- Ruby stdlib / gem calls (`dig`, `fetch`, `merge`, `sleep`, `JSON.pretty_generate`, ...)
- User-defined placeholders in illustrative examples (`alert_ops_team`, `load_user_preferences`, ...)
- Python syntax retained verbatim in a contrast/migration example block
- Internal logger helpers (`Signalwire::Logging::Logger#info` etc. are
  intentionally excluded from `port_surface.json` as internal plumbing)

Phantom SignalWire APIs (things docs promised that don't exist in the port)
are not ignored — they are fixed in the docs.

Field format: `name: rationale (by <approver>, YYYY-MM-DD)`.

---

## Ruby stdlib, core, and common gems

new: Ruby `Class.new` constructor — ubiquitous across all Ruby code (by orchestrator, 2026-07-06)
fetch: `Hash#fetch` and `Array#fetch` — Ruby stdlib (by orchestrator, 2026-07-06)
first: `Array#first` / `Enumerable#first` — Ruby stdlib (by orchestrator, 2026-07-06)
dig: `Hash#dig` / `Array#dig` — Ruby stdlib (by orchestrator, 2026-07-06)
merge: `Hash#merge` — Ruby stdlib (by orchestrator, 2026-07-06)
sleep: `Kernel#sleep` — Ruby stdlib (by orchestrator, 2026-07-06)
pack: `Array#pack` — Ruby stdlib, used for Base64 header building (by orchestrator, 2026-07-06)
pretty_generate: `JSON.pretty_generate` — Ruby stdlib json gem (by orchestrator, 2026-07-06)
generate: `JSON.generate` — Ruby stdlib json gem (by orchestrator, 2026-07-06)
rb: Ruby filename extension literal (e.g. `"foo.rb"`) — not a method call (by orchestrator, 2026-07-06)
expand_path: `File.expand_path` — Ruby stdlib, resolves $LOAD_PATH (by orchestrator, 2026-07-06)
reject: `Enumerable#reject` — Ruby stdlib (by orchestrator, 2026-07-06)
sub: `String#sub` — Ruby stdlib (by orchestrator, 2026-07-06)
transform_keys: `Hash#transform_keys` — Ruby stdlib, Ruby 2.5+ (by orchestrator, 2026-07-06)
clamp: `Comparable#clamp` / `Integer#clamp` — Ruby stdlib, constrain a number to a range (by orchestrator, 2026-07-06)
HTTP: `Net::HTTP` stdlib constant named in an examples/skills_audit_harness.rb prose comment ("issues real HTTP through Net::HTTP"), not a method call (by orchestrator, 2026-07-08)

## Python syntax retained verbatim in contrast/migration example blocks

tool: Python `@AgentBase.tool(...)` decorator syntax shown for contrast; Ruby uses `define_tool(name:, ...) do |args, raw| ... end` blocks (by orchestrator, 2026-07-06)
warning: Python-style `.warning` kept in a Python contrast block; the Ruby method is `warn` (by orchestrator, 2026-07-06)
include_router: Python FastAPI `app.include_router(...)` shown in a docs/architecture.md multi-agent-mode contrast example; Ruby mounts via `agent.rack_app` / `AgentServer` (by orchestrator, 2026-07-08)

## SignalWire internal logger (`Signalwire::Logging::Logger`)

The Logger class is intentionally excluded from `port_surface.json` by
`scripts/enumerate_surface.rb` (`RUBY_EXCLUDED_CLASSES`) as internal plumbing.
Its public methods appear in Ruby example code and docs:

debug: `Signalwire::Logging::Logger#debug` internal logger helper (by orchestrator, 2026-07-06)
info: `Signalwire::Logging::Logger#info` internal logger helper (by orchestrator, 2026-07-06)
warn: `Signalwire::Logging::Logger#warn` internal logger helper (by orchestrator, 2026-07-06)
error: `Signalwire::Logging::Logger#error` internal logger helper (by orchestrator, 2026-07-06)

## Prefab-authoring pattern: user-defined private helpers

These appear inside example prefab classes to illustrate the authoring
pattern. They are user code, not SDK API. Audit cannot distinguish
`self.my_helper(...)` as user code from a phantom SDK call, so we list them.

apply_custom_config: user-defined prefab helper in agent_guide example (by orchestrator, 2026-07-06)
apply_default_config: user-defined prefab helper in agent_guide example (by orchestrator, 2026-07-06)
register_knowledge_base_tool: user-defined prefab helper in agent_guide example (by orchestrator, 2026-07-06)
schedule_follow_up: user-defined application callback in api_reference example (by orchestrator, 2026-07-06)

## User-defined application callbacks in lifecycle / analytics examples

These names illustrate the shape of callbacks developers would implement —
they are explicitly application-specific hooks, not SDK-provided methods.

alert_ops_team: user-defined alerting helper in api_reference example (by orchestrator, 2026-07-06)
customer_settings: user-defined `database.customer_settings(...)` lookup in agent_guide dynamic-config example (by orchestrator, 2026-07-06)

## Real Ruby methods the surface enumerator aliases to their Python-oracle name

These are genuine public methods that exist in the Ruby source and are called
correctly in the docs/examples, but `scripts/enumerate_surface.rb`
(`SURFACE_METHOD_ALIASES`) renames them to their Python-reference counterpart so
the surface compares equal to the oracle. The port_surface.json therefore
carries the oracle name, not the Ruby name — so the audit can't resolve the
real Ruby name. The Ruby method is real; the rename is idiom reconciliation.

get_factory: `SignalWire::Skills::SkillRegistry.get_factory` surface-aliased to `get_skill_class` in enumerate_surface.rb (by orchestrator, 2026-07-06)
handle_search: `SignalWire::Prefabs::FaqBot#handle_search` surface-aliased to `search_faqs` in enumerate_surface.rb (by orchestrator, 2026-07-06)
tap_audio: `SignalWire::Relay::Call#tap_audio` (call.rb) surface-aliased to `tap` in enumerate_surface.rb (SURFACE_METHOD_ALIASES) to avoid colliding with `Object#tap`; the docs use the real Ruby name (by orchestrator, 2026-07-06)
