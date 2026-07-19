# SEMVER_DIFF_ALLOW.md — approved SEMVER-DIFF exceptions

Each line: `- <symbol> — reason (approver, date)`. An entry excuses a member-level
signature diff that SEMVER-DIFF would otherwise classify as demanding a higher
version bump. Reserved for provable non-breaking changes; prefer a real MAJOR bump
over an entry whenever a change is genuinely breaking.

- signalwire.rest._base.HttpClient.__init__ — NOT a breaking change: the RequestOptions envelope (plan 4.2) adds a `request_options:` argument. To match the Python reference's positional-or-keyword `request_options` slot (which sits immediately after `host`, index 4), the Ruby constructor declares it before the pre-existing port-only `base_url:` / `ca_file:` keyword arguments. This shifts `base_url` from declaration-index 4 to 5, which the index-aligned diff reports as a kind change on param[4]. All three (`request_options:`, `base_url:`, `ca_file:`) are KEYWORD arguments — position-independent in Ruby — so no existing caller (`HttpClient.new(id, tok, space, base_url: url)`) breaks; the change is a declaration-order reshuffle of keyword params only, plus one added keyword arg (a minor addition). Verified: the full test suite + request-options unit tests pass unchanged. (approver: mike@signalwire.com — PENDING SIGN-OFF, 2026-07-18)
