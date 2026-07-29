# SNIPPET_RUN_ALLOW.md — SNIPPET-RUN execution allowlist (ruby)

Doc snippets that legitimately cannot run to a zero exit against the mock because
they require real credentials, a live network endpoint, or an optional external
dependency the SDK does not vendor. Format:

    - <repo-relative-path>:<line> — <reason> (approver, date)

The `<line>` is the opening-fence line of the fenced block (matches SNIPPET-RUN's
report key). Everything not listed here (and not marked `<!-- snippet: no-run -->`)
must run clean.

Pages whose snippets exercise the `web_search` builtin supply demo Google Custom
Search credentials in their `<!-- snippet-setup -->` block (its `setup` only checks
that `GOOGLE_SEARCH_API_KEY` / `GOOGLE_SEARCH_ENGINE_ID` are present — the network
call happens at tool-execution, not at `add_skill` time), so those snippets run
clean and need no entry here.

## README quickstart `<!-- include: … -->` blocks — ledgered, not inline-marked

These three README blocks are byte-identical `include` regions of the shipped
`examples/quickstart_*.rb` files (enforced by the README-INCLUDE gate, which
requires the fence to immediately follow the `<!-- include: -->` marker — so an
inline `<!-- snippet: no-run -->` marker cannot be placed on them). The examples
themselves are exercised by EXAMPLES-RUN; here they each start a blocking server or
make a live REST call and so cannot run standalone under SNIPPET-RUN.

- README.md:49 — quickstart_agent: ends with agent.run (blocking WEBrick server) (burn-ruby, 2026-07-09)
- README.md:132 — quickstart_relay: client.run connects to a live RELAY WebSocket (burn-ruby, 2026-07-09; line re-synced 2026-07-15, 2026-07-29)
- README.md:167 — quickstart_rest: makes live REST calls; base URL derives from the space host, no loopback-mock override; the #rest region also references call_id defined outside the region (burn-ruby, 2026-07-09; line re-synced 2026-07-15, 2026-07-29)
