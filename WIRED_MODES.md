# WIRED_MODES.md — signalwire-ruby load-bearing run-ci modes

The env/mode lines below are **load-bearing**: they are not gates themselves, but
they are the mode context that makes a gate actually check something. A merge that
silently drops one of them ships a green-and-vacuous gate. The `WIRED-MODES` gate
(porting-sdk `scripts/check_wired_modes.py`) greps `scripts/run-ci.sh` for each
pattern below and fails loud if any is missing — so a dropped mode reds this check
instead of shipping a vacuous gate.

Format: `` - `<python-regex>` — reason `` (one required pattern per line; prose and
headers are ignored).

- `MOCK_RELAY_STRICT=1` — RELAY strict mode: the RELAY mock rejects unknown wire keys/frames so SNIPPET-RUN / EXAMPLES-RUN fail on a bad shape on the RELAY wire instead of passing vacuously.
- `export MOCK_SIGNALWIRE_STRICT` — REST 400 strict default (D3): the REST mock returns 400 on a wire-truth violation so the TEST fleet catches a wrong/unknown REST wire key instead of only journaling it.
