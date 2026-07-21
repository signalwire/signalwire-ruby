# EXAMPLES_RUN allowlist

Examples that LEGITIMATELY require real credentials or a live/driver harness the
mock SignalWire environment cannot provide, and so are skipped by the EXAMPLES-RUN
gate (`porting-sdk/scripts/examples_run.py`). Each entry names the missing
dependency and the approver. The mock injects only `SIGNALWIRE_*` creds + a
loopback REST endpoint; it does NOT provide third-party API keys, real datasphere
document IDs, or the audit-driver fixture env (`REST_OPERATION` / `SKILL_NAME` /
`SIGNALWIRE_RELAY_HOST` + a loopback fixture port), which these examples require.

- examples/quickstart_rest.rb — issues a real fabric.ai_agents.create() REST call on load; needs real SignalWire project creds (401 against mock), mirrors python quickstart_rest allow (approver: mike, 2026-07-08)
- examples/joke_agent.rb — needs real API_NINJAS_KEY creds, not mockable (approver: user, 2026-07-07)
- examples/joke_skill_demo.rb — needs real API_NINJAS_KEY creds, not mockable (approver: user, 2026-07-07)
- examples/skills_demo.rb — add_skill('joke') needs real API_NINJAS_KEY creds, not mockable (approver: user, 2026-07-07)
- examples/web_search_agent.rb — needs real GOOGLE_SEARCH_API_KEY + GOOGLE_SEARCH_ENGINE_ID creds, not mockable (approver: user, 2026-07-07)
- examples/datasphere_serverless_env.rb — needs real DATASPHERE_DOCUMENT_ID + datasphere creds, not mockable (approver: user, 2026-07-07)
- examples/datasphere_webhook_env_demo.rb — needs real DATASPHERE_DOCUMENT_ID + datasphere creds, not mockable (approver: user, 2026-07-07)
- examples/relay_audit_harness.rb — RELAY audit driver probe; needs porting-sdk audit_relay_handshake.py to inject SIGNALWIRE_RELAY_HOST + a loopback WS fixture, not a standalone run (approver: user, 2026-07-07)
- relay/examples/relay_dial_and_play.rb — connect() opens a live RELAY WebSocket + dials RELAY_FROM_NUMBER/RELAY_TO_NUMBER; the shared harness runs only mock_signalwire (REST), no mock_relay, so this needs a real relay endpoint (same owner-approved connect() class + reason as signalwire-php relay/examples/relay_dial_and_play.php, approver: user, 2026-07-09)
- examples/rest_audit_harness.rb — REST audit driver probe; needs porting-sdk audit_rest_transport.py to inject REST_OPERATION + REST_FIXTURE_URL, not a standalone run (approver: user, 2026-07-07)
- examples/skills_audit_harness.rb — skills audit driver probe; needs porting-sdk audit_skills_dispatch.py to inject SKILL_NAME + SKILL_FIXTURE_URL, not a standalone run (approver: user, 2026-07-07)
