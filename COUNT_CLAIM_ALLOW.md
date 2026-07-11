# COUNT-CLAIM allowlist

Each entry is a numeric doc claim the COUNT-CLAIM gate flags but is a
genuinely-justified non-finding. Format: `- <noun>:<claimed> — reason (approver, date)`.

- namespaces:20 — the claim is TRUE (the Ruby client exposes exactly 20 REST namespace accessors — see `lib/signalwire/rest/namespaces/generated/resource_tree.rb`, matching the Python reference's own "20 API namespaces" README claim after the Twilio-compatibility namespace was excised matrix-wide). The gate counts only 1 because the gate's `ns_glob` (`lib/**/rest/namespaces/*.rb`, `_generated`-excluded) matches only the top-level `namespaces/generated.rb` aggregator: the Ruby port GENERATES every namespace module into the `namespaces/generated/` SUBTREE (per the module scheme), which the direct-children glob cannot see. Wire-neutral generated-layout gate limitation, not a stale count (orchestrator gate-gap, 2026-07-11)
