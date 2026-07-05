# Doc Audit Ignore List

Names listed here are ignored by `scripts/audit_docs.py` when it scans the
Ruby port's docs and examples for method calls. Every entry must have a
one-line rationale — these are **not** phantom SignalWire APIs; they are:

- Ruby stdlib / gem calls (`dig`, `fetch`, `merge`, `sleep`, `JSON.pretty_generate`, ...)
- User-defined placeholders in illustrative examples (`alert_ops_team`, `load_user_preferences`, ...)
- Intentionally omitted Python features that docs still reference with a "not ported" note
  (see [`PORT_OMISSIONS.md`](PORT_OMISSIONS.md))
- Internal logger helpers (`Signalwire::Logging::Logger#info` etc. are
  intentionally excluded from `port_surface.json` as internal plumbing)

Phantom SignalWire APIs (things docs promised that don't exist in the port)
are not ignored — they are fixed in the docs.

---

## Ruby stdlib, core, and common gems

new: Ruby `Class.new` constructor — ubiquitous across all Ruby code
fetch: `Hash#fetch` and `Array#fetch` — Ruby stdlib
first: `Array#first` / `Enumerable#first` — Ruby stdlib
dig: `Hash#dig` / `Array#dig` — Ruby stdlib
merge: `Hash#merge` — Ruby stdlib
sleep: `Kernel#sleep` — Ruby stdlib
pack: `Array#pack` — Ruby stdlib (used for Base64 header building)
pretty_generate: `JSON.pretty_generate` — Ruby stdlib (json gem)
generate: `JSON.generate` — Ruby stdlib (json gem)
rb: Ruby filename extension literal (e.g. `"foo.rb"`) — not a method call
expand_path: `File.expand_path` — Ruby stdlib (used to resolve $LOAD_PATH)
reject: `Enumerable#reject` — Ruby stdlib
sub: `String#sub` — Ruby stdlib
transform_keys: `Hash#transform_keys` — Ruby stdlib (Ruby 2.5+)
clamp: `Comparable#clamp` / `Integer#clamp` — Ruby stdlib (constrain a number to a range)

## Python-decorator syntax retained in illustrative examples

tool: Python `@AgentBase.tool(...)` decorator syntax from Python docs;
    Ruby uses `define_tool(name:, ...) do |args, raw| ... end` blocks
basicConfig: Python `logging.basicConfig` — Ruby uses
    `Signalwire::Logging.global_level=` instead
to_dict: Python `to_dict()` — Ruby uses `to_h` instead

## SignalWire internal logger (`Signalwire::Logging::Logger`)

The Logger class is intentionally excluded from `port_surface.json` by
`scripts/enumerate_surface.rb` (`RUBY_EXCLUDED_CLASSES`) as internal plumbing.
Its public methods appear in Ruby example code and docs:

debug: `Signalwire::Logging::Logger#debug`
info: `Signalwire::Logging::Logger#info`
warn: `Signalwire::Logging::Logger#warn`
warning: Python-style `.warning` kept in a Python example block; Ruby method is `warn`
error: `Signalwire::Logging::Logger#error`

## Intentionally omitted subsystems (see PORT_OMISSIONS.md)

validate_packages: `SkillBase#validate_packages` — not ported; Python-specific
    package validation that doesn't map to the gem ecosystem
validate_env_vars: `SkillBase#validate_env_vars` — not_yet_implemented helper;
    Ruby skills perform env-var validation manually
list_all_skill_sources: `SkillRegistry#list_all_skill_sources` — external
    skill source listing not_yet_implemented

## Prefab-authoring pattern: user-defined private helpers

These appear inside example prefab classes to illustrate the authoring
pattern. They are user code, not SDK API. Audit cannot distinguish
`self.my_helper(...)` as user code from a phantom SDK call, so we list them.

_configure_instructions: user-defined prefab helper in agent_guide example
_register_custom_tools: user-defined prefab helper in api_reference example
_register_default_tools: user-defined prefab helper in agent_guide example
_setup_contexts: user-defined prefab helper in api_reference example
_setup_static_config: user-defined prefab helper in agent_guide example
_test_api_connection: user-defined skill helper in third_party_skills example
apply_custom_config: user-defined prefab helper in agent_guide example
apply_default_config: user-defined prefab helper in agent_guide example
register_default_tools: user-defined prefab helper in architecture.md
register_knowledge_base_tool: user-defined prefab helper in agent_guide example
schedule_follow_up: user-defined application callback in api_reference example

## User-defined application callbacks in lifecycle / analytics examples

These names illustrate the shape of callbacks developers would implement —
they are explicitly application-specific hooks, not SDK-provided methods.

alert_ops_team: user-defined alerting helper in api_reference example
is_valid_customer: user-defined auth helper in agent_guide example
get_customer_config: user-defined customer-config lookup in agent_guide example
get_customer_settings: user-defined customer-settings lookup in agent_guide example
get_customer_tier: user-defined customer-tier lookup in agent_guide example
customer_settings: user-defined `database.customer_settings(...)` lookup in agent_guide dynamic-config example (idiomatic Ruby rename of get_customer_settings)

## Real Ruby methods the surface enumerator aliases to their Python-oracle name

These are genuine public methods that exist in the Ruby source and are called
correctly in the docs/examples, but `scripts/enumerate_surface.rb`
(`SURFACE_METHOD_ALIASES`) renames them to their Python-reference counterpart so
the surface compares equal to the oracle. The port_surface.json therefore
carries the oracle name, not the Ruby name — so the audit can't resolve the
real Ruby name. The Ruby method is real; the rename is idiom reconciliation.

get_factory: `SignalWire::Skills::SkillRegistry.get_factory` — surface-aliased to `get_skill_class` (enumerate_surface.rb line ~407)
handle_search: `SignalWire::Prefabs::FaqBot#handle_search` — surface-aliased to `search_faqs` (enumerate_surface.rb line ~407)
