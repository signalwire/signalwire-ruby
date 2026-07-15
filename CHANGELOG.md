# Changelog

All notable changes to the SignalWire AI Agents SDK for Ruby (`signalwire-sdk`)
are documented here. This project adheres to [Semantic Versioning](https://semver.org).

## 3.1.0

### Added
- `client.projects` — the new `/api/projects` full-CRUD project-management REST
  resource (list / create / get / update / delete subprojects, plus
  `rotate_signing_key`). Distinct from the singular `client.project` token
  namespace. Generated from the canonical `projects` REST spec with full
  success + error wire-test coverage.

## 3.0.2

Parity release aligning the Ruby SDK with the Python reference SDK across the
REST, RELAY, SWML, and SWAIG surfaces.

### Added
- Spec-generated REST surface: a typed REST client with generated typed I/O and
  full success + error wire-test coverage across the SignalWire REST namespaces.
- `paginate()` parity on read resources via a `PaginatedIterator`.
- Typed SWAIG `ParameterSchema` builder for `define_tool`, and typed RELAY state
  enums (`Device`, `CollectConfig`, record/tap direction/format/codec, skill names).
- Typed `Call` convenience methods (`play_*` / `detect_*` / `prompt_*` /
  `wait_for_*`) and RELAY event pattern-matching (`to_h` / `to_json`, value equality).
- `set_history` on `Context` and `Step` (Python parity).
- Security utilities: `filter_sensitive_headers`, `redact_url`, `is_valid_hostname`.
- Verified HTTPS + WSS transport, including server-side TLS.
- Ported agent / contexts / SDK-features documentation from the Python SDK.

### Fixed
- `SIGNALWIRE_SKILL_PATHS` is now read like the reference; documented
  `RELAY_SCHEME` / `RELAY_SSL_CA_FILE`.
- `--env` / `--env-file` are wired into the `swaig-test` serverless simulator.
- `FabricResource` update now uses the correct PUT verb.
