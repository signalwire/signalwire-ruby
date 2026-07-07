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
- port_surface.json — generated public surface read at ./port_surface.json by porting-sdk audit scripts + ignore_ledger_verify (orchestrator, 2026-07-06)
- rest_signatures.json — generated REST typed-param sidecar read at ./rest_signatures.json by this port's enumerators (orchestrator, 2026-07-06)
- generated_surface_map.json — generated module/class projection map read at ./generated_surface_map.json by this port's enumerators (orchestrator, 2026-07-06)
- audit_coverage.json — generated audit-coverage report read at ./audit_coverage.json by porting-sdk coverage scripts (orchestrator, 2026-07-06)
- audit_coverage_baseline.json — coverage baseline read at ./audit_coverage_baseline.json by porting-sdk coverage scripts (orchestrator, 2026-07-06)

## Gate allowlist files (each read by its gate at repo root)

- ROOT_HYGIENE_ALLOW.md — this allowlist file itself, read by the root_hygiene gate at repo root (orchestrator, 2026-07-06)
- ARTIFACT_DENY_ALLOW.md — allowlist read by the artifact_deny gate at repo root (orchestrator, 2026-07-06)

## Gem build/publish manifest

- signalwire-sdk.gemspec — gem build/publish manifest; the built-in allowlist covers Gemfile/Rakefile but not the per-port .gemspec (name varies), analogous to how .csproj/.sln are regex-allowed for dotnet (orchestrator, 2026-07-06)
