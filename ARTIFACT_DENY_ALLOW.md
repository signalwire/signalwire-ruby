# Artifact-Deny Allowlist

The `artifact_deny` gate's DEFAULT mode is a `git ls-files` PROXY — it flags any
tracked path matching a porting-artifact pattern, as a stand-in for "what a naive
package with no include/exclude discipline would ship." These files are
LOAD-BEARING in-repo (the porting-audit contract + generated surfaces + the two
audit-tool bin scripts) and must stay tracked — the brief is explicit: do NOT
delete them, exclude them from the PACKAGE.

They ARE excluded from the published gem. `signalwire-sdk.gemspec` sets
`s.files = Dir['lib/**/*', 'README.md', 'LICENSE'] + ['bin/swaig-test']`, so none
of these enter the gem tarball. Authoritative proof (the real check the brief
names) — the built gem's own file list runs clean through `--listing` mode:

    gem build signalwire-sdk.gemspec
    gem specification signalwire-sdk-*.gem files | sed 's/^- //' \
      | python3 ~/src/porting-sdk/scripts/artifact_deny.py --port ruby --listing -
    # -> [artifact-deny] ruby: clean

The entries below silence only the PROXY for these tracked-but-excluded files.

- CHECKLIST.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- DOC_AUDIT_IGNORE.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- PORT_ADDITIONS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- PORT_EXAMPLE_OMISSIONS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- PORT_OMISSIONS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- PORT_SIGNATURE_OMISSIONS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- PORT_TEST_OMISSIONS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- REST_COVERAGE_GAPS.md — audit-contract file; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- audit_coverage.json — generated audit artifact; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- audit_coverage_baseline.json — generated audit artifact; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- port_signatures.json — generated signature surface; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- port_surface.json — generated public surface; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- bin/emit-corpus — porting audit-corpus tool; tracked in-repo, excluded from gem (s.files ships only bin/swaig-test) (orchestrator, 2026-07-06)
- bin/emit-skills — porting audit-corpus tool; tracked in-repo, excluded from gem (s.files ships only bin/swaig-test) (orchestrator, 2026-07-06)
- examples/relay_audit_harness.rb — audit harness example; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- examples/rest_audit_harness.rb — audit harness example; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
- examples/skills_audit_harness.rb — audit harness example; tracked in-repo, excluded from gem via s.files (orchestrator, 2026-07-06)
