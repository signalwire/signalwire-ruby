# Ruby Ergonomics Migration — idiomatic accessors

Rollout plan for giving `signalwire-ruby` a native-Ruby public surface without
breaking cross-port audit parity. Companion to the analysis in
`porting-sdk/PORT_PHILOSOPHY_RUBY.md` (tradeoff #1 + "escape hatch" section).

**Status:** prototype landed on `AgentBase` prompt accessors; full rollout
**proposed, not done**. This doc is the map and the cost ledger — not a
commitment.

---

## Why

The port carries **134 `get_`/`set_` accessor methods** (80 `get_*`, 54
`set_*`) plus a handful of Python-style `has_`/`is_` predicates. They keep
Python's exact names so the cross-language audit matches them 1:1
(`get_prompt` ≡ Python `get_prompt` ≡ Go `GetPrompt`). The cost: the public
API reads like Python transliterated into Ruby. A Ruby caller wants
`agent.prompt`, `agent.post_prompt = "…"`, `agent.skill?(:datetime)` — not
`agent.get_prompt` / `agent.set_post_prompt(…)` / `agent.has_skill(…)`.

## The mechanism — additive, audit-preserving

**Keep every Python-named method.** Layer Ruby-idiomatic aliases *on top*. The
originals satisfy the audit; the aliases are port-only symbols recorded in
`PORT_ADDITIONS.md` (one line each). Nothing is renamed, nothing breaks.

The prototype (live in `lib/signalwire/agent/agent_base.rb`, tests in
`tests/agent_test.rb` → `AgentBaseIdiomaticAccessorsTest`):

```ruby
# Reader-only alias over a computed getter:
alias_method :prompt, :get_prompt

# Symmetric raw reader/writer pair:
alias_method :prompt_text, :get_raw_prompt
def prompt_text=(text) = set_prompt_text(text)

# Clean reader/writer pair (the showcase):
alias_method :post_prompt, :get_post_prompt
def post_prompt=(text) = set_post_prompt(text)
```

PORT_ADDITIONS gets three lines (writers normalise under the base symbol, so
`post_prompt=` is covered by the `post_prompt` entry). Verified: surface diff
stays green (`port matches Python reference`), both call styles hit the same
state.

---

## The full inventory and the rules

### Bucket A — `get_*` readers (80) → bare-noun `alias_method`

`get_prompt → prompt`, `get_global_data → global_data`, `get_hints → hints`,
`get_parameter_schema → parameter_schema`, … Pure `alias_method`. The only
work is checking each target name isn't already taken (see Edge cases).

### Bucket B — single-value `set_*` setters (41) → `X=` writers

`set_text(text) → text=`, `set_functions(functions) → functions=`,
`set_post_prompt(text) → post_prompt=`, … Each becomes
`def x=(v) = set_x(v)`. Note: the `set_*` originals return `self` (chainable);
the `=` writer returns the assigned value (Ruby `=` semantics) and **can't
chain** — that's fine, `=` writers are never chained, and the chainable
`set_*` form stays available for fluent code.

### Bucket C — multi-arg / keyword `set_*` setters (13) → stay as methods

A `=` writer takes exactly one value, so these can't become `X=`. They keep
their `set_*` names (and optionally gain a non-`set_` method alias if a nicer
verb exists). The full list:

```
set_ai_agent(sid, agent_id:, **extra)     set_relay_application(sid, name:, **extra)
set_call_flow(sid, flow_id:, version:, …) set_relay_topic(sid, topic:, …)
set_cxml_application(sid, application_id:) set_swml_webhook(sid, url:, **extra)
set_cxml_webhook(sid, url:, …)            set_param(key, value)
set_dynamic_config_callback(callable, &b) set_gather_info(output_key:, …)
set_language_params(code, params)         set_prompt_llm_params(**params)
set_post_prompt_llm_params(**params)
```

(Several are REST sub-resource binders — `sid` + keyword payload — where a
`set_*(sid, …)` verb is arguably clearer than any `=` form anyway.)

### Bucket D — predicates → `?` forms

Mixed today. Already idiomatic (keep): `has_section?`, `has_skill?`. Un-Ruby
(add `?` aliases): `has_function → function?`, `has_section → section?`,
`has_skill → skill?`, `is_serverless_mode → serverless?`. Note `has_skill` and
`has_skill?` currently **both** exist on different classes — the rollout should
converge them.

---

## Edge cases (surfaced by the prototype)

1. **Computed getters aren't symmetric.** `get_prompt` returns the *effective*
   prompt (raw string in text mode, POM array otherwise) while
   `set_prompt_text` sets only the raw text. So `prompt` is reader-only; the
   writable raw pair is `prompt_text` / `prompt_text=`. Don't blindly assume
   `get_X`/`set_X` are a reader/writer pair — audit each.
2. **Writer return value.** `set_X` returns `self`; `X=` must return the RHS.
   The thin `def x=(v) = set_x(v)` already does this (Ruby `=` discards the
   method's return and yields the RHS). Just don't `alias_method :x=, :set_x` —
   that would leak `self`.
3. **Name collisions.** Before aliasing `get_foo → foo`, confirm no existing
   `foo` method/attr. Grep `def foo\b` and `attr_.*:foo` first.
4. **Raw-vs-rendered duplicates.** Some subsystems expose both `get_X` and
   `get_raw_X` (prompt). Pick deliberate idiomatic names (`prompt` vs
   `prompt_text`) rather than `raw_prompt`.

---

## The examples sweep — the bigger half

**27 of the 54 files in `examples/`** call `get_`/`set_`/`has_`. They model the
API; if they keep the Python names, users copy them. The sweep also fixes the
string-rocket hashes the examples model today:

```ruby
agent.add_skill('joke', 'api_key' => key)   # before — Python-in-Ruby
agent.add_skill('joke', api_key: key)        # after  — native (transform_keys handles it)
```

Most-referenced offenders: `set_global_data` (13), `set_text` (12),
`set_valid_steps` (9), `set_functions` (9), `set_post_prompt` (6),
`set_prompt_llm_params` (6). Budget the examples as roughly the same effort as
the `lib/` change.

---

## Cost ledger

- **~134 new `PORT_ADDITIONS.md` entries** (one per alias), roughly doubling
  the public accessor count. Mechanical but bulky; keep them under a single
  clearly-headed section.
- **No new audit risk** — every alias is additive; the Python-named originals
  remain the audit-matched symbols. Drift stays 0 as long as each alias has its
  PORT_ADDITIONS line (the prototype proves the loop).
- **Test surface** — one parity assertion per idiomatic accessor (original and
  alias hit the same state), as in `AgentBaseIdiomaticAccessorsTest`.

## Phasing

Do it per-subsystem so each is a reviewable PR, not one 134-method megachange:

1. **Prompt accessors** (done — prototype) — `prompt`, `prompt_text`, `post_prompt`.
2. **AI config** — hints, languages, pronunciations, params, global_data.
3. **Tools / SWAIG** — functions, includes, native functions.
4. **Skills** — `skill?`, skill data accessors; also the `add_skill` symbol-key
   ergonomics.
5. **REST sub-resource binders** (Bucket C) — decide keep-`set_` vs nicer verbs.
6. **Predicates convergence** (Bucket D) — `?` forms, dedupe `has_skill`/`has_skill?`.
7. **Examples sweep** — rewrite all 27 files to idiomatic forms.

## Open decisions (need a human call)

- **Bucket C**: leave the 13 multi-arg setters as `set_*`, or add verb aliases?
  (Recommendation: leave REST binders as `set_*(sid, …)`; they read fine.)
- **String→symbol keys**: do the example sweep *and* document symbol keys as the
  blessed form, or just accept both quietly? (Recommendation: document symbol
  keys as canonical; `transform_keys(&:to_s)` already accepts both, so it's
  doc + examples only, no lib risk.)
- **Scope**: full 134 + examples is a real chunk (~a day of careful work +
  review). Worth it for SDK adoption feel; not urgent. Ship per-phase.
