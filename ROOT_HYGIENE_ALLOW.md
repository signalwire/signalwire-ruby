# Root-Hygiene Allowlist

Repo-root files that the `root_hygiene` gate would otherwise flag, but which are
LOAD-BEARING and must stay at the repo root: the porting-audit contract files
(read at `./<name>` by porting-sdk audit scripts + this port's own scripts and by
CLAUDE.md's verify recipe), the generated audit artifacts those scripts consume,
and the gem build manifest. Moving any of these would break the shared audit
pipeline (which this port cannot edit).

## Porting-audit contract files (read at repo root by porting-sdk audit scripts)

- PORT_OMISSIONS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- PORT_ADDITIONS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- PORT_SIGNATURE_OMISSIONS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- PORT_TEST_OMISSIONS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- PORT_EXAMPLE_OMISSIONS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- DOC_AUDIT_IGNORE.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- CHECKLIST.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)
- REST_COVERAGE_GAPS.md — required audit-contract file read by porting-sdk audit scripts (orchestrator, 2026-07-06)

## Generated audit artifacts consumed at repo root by the audit/enumerate scripts

- port_signatures.json — generated signature surface read at ./port_signatures.json by porting-sdk diff_port_signatures.py + this port's enumerators (orchestrator, 2026-07-06)
- port_signatures.baseline.json — load-bearing SEMVER-DIFF release-floor file read at ./port_signatures.baseline.json by porting-sdk semver_diff.py; mirrors port_signatures.json; must be at root, must not ship (orchestrator, 2026-07-13)
- port_surface.json — generated public surface read at ./port_surface.json by porting-sdk audit scripts + ignore_ledger_verify (orchestrator, 2026-07-06)
- rest_signatures.json — generated REST typed-param sidecar read at ./rest_signatures.json by this port's enumerators (orchestrator, 2026-07-06)
- generated_surface_map.json — generated module/class projection map read at ./generated_surface_map.json by this port's enumerators (orchestrator, 2026-07-06)
- audit_coverage.json — generated audit-coverage report read at ./audit_coverage.json by porting-sdk coverage scripts (orchestrator, 2026-07-06)
- audit_coverage_baseline.json — coverage baseline read at ./audit_coverage_baseline.json by porting-sdk coverage scripts (orchestrator, 2026-07-06)

## Gate allowlist files (each read by its gate at repo root)

- ROOT_HYGIENE_ALLOW.md — this allowlist file itself, read by the root_hygiene gate at repo root (orchestrator, 2026-07-06)
- ARTIFACT_DENY_ALLOW.md — allowlist read by the artifact_deny gate at repo root (orchestrator, 2026-07-06)
- SEMVER_DIFF_ALLOW.md — allowlist read by porting-sdk semver_diff.py (SEMVER-DIFF) at ./SEMVER_DIFF_ALLOW.md; excuses provable non-breaking signature diffs (mirrors the TS port) (ro-ruby, 2026-07-18)
- EXAMPLES_RUN_ALLOW.md — allowlist read by the examples_run (EXAMPLES-RUN) gate at repo root (approver: user, 2026-07-07)
- SNIPPET_RUN_ALLOW.md — allowlist read by the snippet_run (SNIPPET-RUN) gate at repo root (approver: user, 2026-07-09)
- WIRED_MODES.md — load-bearing manifest of run-ci strict-mode lines, read at ./WIRED_MODES.md by porting-sdk check_wired_modes.py (WIRED-MODES gate, plan 1.6/D7); must be at root (lane-ruby, 2026-07-19)
- .doc_surface_floor — DOC-SURFACE coverage-ratchet floor read at ./.doc_surface_floor by porting-sdk doc_surface.py (plan 6.3); must be at root, must ratchet in-repo (lane-ruby, 2026-07-19)

## Gem build/publish manifest

- signalwire-sdk.gemspec — gem build/publish manifest; the built-in allowlist covers Gemfile/Rakefile but not the per-port .gemspec (name varies), analogous to how .csproj/.sln are regex-allowed for dotnet (orchestrator, 2026-07-06)

## Standard developer-config templates

- .env.example — dotenv template documenting every env var the SDK reads (issue #36); a copy-to-`.env` file that must live at the repo root by the dotenv convention to serve its purpose, alongside the built-in .gitignore/.editorconfig config files (fix-ruby, 2026-07-14)
- WIRE_VIOLATIONS_ALLOW.md — STRICT-MOCKS signed-exception ledger read by porting-sdk assert_no_wire_violations.py / examples_run.py / snippet_run.py at repo root (mike@signalwire.com, 2026-07-18)
