# Ruby Ergonomics Migration — idiomatic accessors

Rollout plan for giving `signalwire-ruby` a native-Ruby public surface without
breaking cross-port audit parity. Companion to the analysis in
`porting-sdk/PORT_PHILOSOPHY_RUBY.md` (tradeoff #1 + "escape hatch" section).

**Status:** **rolled out** across the genuine config-accessor surface
(uncommitted, pending review). Decisions locked: `X=` assignment writers,
`prompt` + `prompt_text` for the raw-prompt pair, ~40 genuine accessors aliased
with the rest documented as Bucket E (leave-alone). See "Rollout outcome" at
the end.

---

## Scope correction (read this first)

The "134" figure overcounts what should become idiomatic accessors. Of the 134
`get_`/`set_` methods, only ~40 are genuine **config accessors**. The rest are
**Bucket E — deliberately left as `get_`/`set_`** because aliasing them to
nouns would be semantically wrong:

- **REST API verbs** — `set_cxml_webhook(sid, url:)`, `get_media(sid, media_sid)`,
  `get_member` … These are actions that hit the API (multi-arg, side-effecting).
  `agent.media(sid, media_sid)` reading like an attribute but performing a GET is
  exactly the confusion a Rubyist would object to. Leave.
- **Skill hook/contract methods** — `get_hints`, `get_prompt_sections`,
  `get_global_data` on `SkillBase` return defaults in the base and are overridden
  per skill. They're behavioral hooks, not attribute reads. Leave.
- **Class-metadata / lookups** — `get_parameter_schema`, `get_param(key, ...)`,
  `get_step(name)`, `get_context(name)`, `get_function(name)`. Lookups with
  arguments, not accessors. Leave.

Only the agent/context/step/function-result **configuration** accessors are
aliased.

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

<!-- snippet: no-run illustrative fragment: alias_method/def accessor pair shown as a class-body excerpt, not a runnable program -->
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

> **Note:** the counts in this section (80 readers, 41/13 setters, "~134
> PORT_ADDITIONS entries", "examples = the bigger half") were the *pre-rollout
> estimate*. The actual rollout is smaller and cheaper — see "Scope correction"
> above and "Rollout outcome" below. In particular, most idiomatic names already
> match Python's surface, so only **3** PORT_ADDITIONS entries were needed, not
> ~134. The bucket *rules* below still hold; the *numbers* are superseded.

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

---

## Rollout outcome (what actually landed)

Aliases added (additive; every `get_`/`set_` original kept):

| Class | Aliases | Form |
|---|---|---|
| `AgentBase` | `prompt`, `prompt_text[=]`, `post_prompt[=]` (prototype) + `contexts`, `function_includes=`, `global_data=`, `internal_fillers=`, `languages=`, `native_functions=`, `params=`, `post_prompt_url=`, `prompt_pom=`, `pronunciations=`, `web_hook_url=` | readers (def-wrapper) + `X=` writers |
| `Contexts::Step` | 11 writers: `text=`, `step_criteria=`, `functions=`, `valid_steps=`, `valid_contexts=`, `skip_user_turn=`, `skip_to_next_step=`, `reset_system_prompt=`, `reset_user_prompt=`, `reset_consolidate=`, `reset_full_reset=` | `X=` |
| `Contexts::Context` | 12 writers: `initial_step=`, `valid_steps=`, `valid_contexts=`, `post_prompt=`, `system_prompt=`, `prompt=`, `consolidate=`, `full_reset=`, `user_prompt=`, `isolated=`, `enter_fillers=`, `exit_fillers=` | `X=` |
| `Swaig::FunctionResult` | `end_of_speech_timeout=`, `metadata=`, `post_process=`, `response=`, `speech_event_timeout=` | `X=` |
| `SWML::Service` | `all_functions`, `basic_auth_credentials_with_source`, `function?` | readers + predicate |
| `Utils` | `serverless?` | predicate |

### Two implementation facts worth knowing

1. **`def`-wrappers, not `alias_method`, for readers.** `alias_method` resolves
   at class-definition time, so it fails if the `get_*` target is defined *below*
   the alias in the class body (hit on `Service#all_functions` and
   `AgentBase#contexts`). The `X=` writers don't have this problem (they call
   `set_*` at *runtime*), but readers use `def noun = get_noun` to stay
   placement-independent.

2. **`X=` writers can't chain — and that's fine.** A Ruby `=` writer returns the
   RHS, not `self`, so a *mid-chain* setter can't become `X=`. The chainable
   `set_*` originals stay for fluent DSL chains
   (`step.set_text(...).set_valid_steps(...)`); the `X=` form is for standalone
   config (`step.text = "..."`). The example sweep reflects this — chain-terminal
   and multi-line setters were left as `set_*`.

### Audit cost

Near-zero, pleasantly: most idiomatic names (`text`, `global_data`, `contexts`,
`languages`, `params`, …) **already exist in the Python reference surface**, so
they match with no drift. Only 3 genuinely-new Ruby names
(`all_functions`, `basic_auth_credentials_with_source`, `function?`) needed
`PORT_ADDITIONS.md` entries. The full 4-gate CI (TEST / SIGNATURES / DRIFT /
NO-CHEAT) stays green.

### Examples

23 of the 23 candidate `examples/*.rb` files were swept (31 call sites rewritten
to the idiomatic form); chain-terminal / mid-chain / multi-line `set_*` calls
were intentionally left (see fact #2).

### Tests

Parity tests added in `tests/agent_test.rb`, `tests/contexts_test.rb`,
`tests/function_result_test.rb` — each asserts the idiomatic form and the
`get_`/`set_` original hit the same state, and that `X=` returns the RHS.

### Not done (Bucket D remainder)

`has_section`/`has_skill` already have `?` variants elsewhere; converging the
duplicate predicate names across classes is left as tidy-up.

---

## Option C — hide the superseded originals from docs (applied)

The idiomatic aliases are *additive*, so the `get_`/`set_` originals still
exist (keeps old callers working + keeps the cross-port audit's reflection
matching Python 1:1). To stop them cluttering the *documented* public API, the
**fully-superseded** originals carry `# @!visibility private` — a YARD doc
directive that hides them from generated docs while leaving the method
runtime-public (so `instance_methods(false)`, and therefore the audit, still
sees them; drift stays 0).

Hidden (8): the reader/predicate originals whose idiomatic form is a strict
replacement —
`AgentBase#get_prompt`/`get_post_prompt`/`get_raw_prompt`/`get_contexts`,
`SWML::Service#get_all_functions`/`get_basic_auth_credentials_with_source`/`has_function`,
`Utils#is_serverless_mode`.

**Not hidden — the chainable `set_*` setters stay documented.** A Ruby `=`
writer can't chain (it returns the RHS), so `step.set_text(...).set_valid_steps(...)`
remains the fluent builder form the examples use; `step.text = "..."` is the
attribute-assignment form. Both are legitimate, distinct Ruby idioms — keeping
both public is conventional, not noise. Hiding a `set_*` the examples chain
would also be self-contradictory (docs hiding a method the examples call).

**Residual leak (irreducible):** a still-public method answers
`agent.get_prompt`, so it remains visible to runtime introspection
(`agent.methods`, IRB tab-complete, `respond_to?`). Making it invisible *there*
too would require a `method_missing` dispatch layer + an adapter manifest
(Option D) — deliberately not done; the cost outweighs hiding 8 names from
`ls`-in-IRB.

Note: YARD isn't currently wired into this repo, so the directive is
forward-looking — it takes effect when API docs are generated and signals
intent to code readers now.
