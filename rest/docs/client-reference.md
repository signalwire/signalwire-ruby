# RestClient Reference

## Constructor

<!-- snippet: no-run constructor signature illustration: passing nil for project/token/host raises ArgumentError (missing credentials) at runtime -->
```ruby
SignalWire::REST::RestClient.new(
  project: nil,   # SIGNALWIRE_PROJECT_ID
  token:   nil,   # SIGNALWIRE_API_TOKEN
  host:    nil    # SIGNALWIRE_SPACE
)
```

All parameters fall back to their corresponding environment variables. An
`ArgumentError` is raised if any are missing.

Authentication uses HTTP Basic Auth (`project:token`).

## Namespaces

Every API surface is available as a namespace attribute on the client:

### Fabric API

| Attribute | Description |
|-----------|-------------|
| `client.fabric.swml_scripts` | SWML script resources (CRUD + addresses) |
| `client.fabric.swml_webhooks` | SWML webhook resources |
| `client.fabric.ai_agents` | AI agent resources |
| `client.fabric.relay_applications` | Relay application resources |
| `client.fabric.call_flows` | Call flow resources (+ versions) |
| `client.fabric.conference_rooms` | Conference room resources |
| `client.fabric.freeswitch_connectors` | FreeSWITCH connector resources |
| `client.fabric.subscribers` | Subscriber resources (+ SIP endpoints) |
| `client.fabric.sip_endpoints` | SIP endpoint resources |
| `client.fabric.sip_gateways` | SIP gateway resources |
| `client.fabric.cxml_scripts` | cXML script resources |
| `client.fabric.cxml_webhooks` | cXML webhook resources |
| `client.fabric.cxml_applications` | cXML application resources (no create) |
| `client.fabric.resources` | Generic resource operations |
| `client.fabric.addresses` | Fabric addresses (list/get only) |
| `client.fabric.tokens` | Subscriber/guest/invite/embed token creation |

### Calling API

| Attribute | Description |
|-----------|-------------|
| `client.calling` | REST call control -- 37 commands via POST |

### Relay REST Resources

| Attribute | Description |
|-----------|-------------|
| `client.phone_numbers` | Phone number management (+ search) |
| `client.addresses` | Address management |
| `client.queues` | Queue management (+ members) |
| `client.recordings` | Recording management |
| `client.number_groups` | Number group management (+ memberships) |
| `client.verified_callers` | Verified caller ID management (+ verification flow) |
| `client.sip_profile` | Project SIP profile (get/update) |
| `client.lookup` | Phone number lookup |
| `client.short_codes` | Short code management |
| `client.imported_numbers` | Import external phone numbers |
| `client.mfa` | Multi-factor authentication (SMS/call/verify) |
| `client.registry` | 10DLC brand/campaign registry |

### Other APIs

| Attribute | Description |
|-----------|-------------|
| `client.datasphere` | Datasphere document management and semantic search |
| `client.video` | Video rooms, sessions, recordings, conferences |
| `client.logs` | Message, voice, fax, and conference logs |
| `client.project` | API token management |
| `client.pubsub` | PubSub token creation |
| `client.chat` | Chat token creation |

## Error Handling

```ruby
begin
  client.fabric.ai_agents.get('bad-id')
rescue SignalWire::REST::SignalWireRestError => e
  puts e.status_code   # 404
  puts e.body          # {"error"=>"not found"}
  puts e.url           # "https://acme.signalwire.com/api/fabric/resources/ai_agents/bad-id"
  puts e.method_name   # "GET"
  puts e.request_id    # "89ca56c9-…" (from the response headers, or nil)
end
```

`SignalWire::REST::SignalWireRestError` is raised on any non-2xx HTTP response. It
descends from `SignalWire::Error` (the SDK's root error class), so a single
`rescue SignalWire::Error` catches every error the SDK raises on its own behalf.

A **transport** failure — the request never reaches an HTTP response (connection
refused, DNS failure, reset, TLS error, timeout) — is raised as
`SignalWire::REST::SignalWireRestTransportError`, a subclass of
`SignalWireRestError` with `status_code == nil`. One `rescue SignalWireRestError`
therefore handles both HTTP-error and transport-failure cases.

### Error Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `status_code` | `Integer` or `nil` | HTTP status code (`nil` for a transport failure — no response was received) |
| `body` | `Hash` or `String` | Response body (parsed JSON or raw text); the transport error message for a transport failure |
| `url` | `String` | The **full** request URL — scheme, host, path and query (e.g. `https://acme.signalwire.com/api/…`), not just the path |
| `method_name` | `String` | HTTP method |
| `headers` | `Hash` or `nil` | Response headers (case-insensitively accessible), when a response was received |
| `request_id` | `String` or `nil` | The SignalWire request id extracted from the response headers, for support correlation |

## Session Behavior

- Requests use `Net::HTTP` from the Ruby standard library.
- Content-Type is always `application/json`.
- User-Agent is `signalwire-ruby/<version>` (the stable product token plus the real SDK version).
- DELETE requests returning 204 return an empty Hash.
- Responses are plain Ruby Hashes (parsed JSON) -- there are no wrapper objects.

## Timeouts, retries and cancellation

Transport behavior is governed by a `SignalWire::REST::RequestOptions` envelope.
Pass it as a **client default** (applied to every request) and/or override it
**per request**; a per-request options object shallow-merges over the client
default, so you set only what you want to change.

```ruby
require 'signalwire'

# Client default: 10s per attempt, up to 2 retries with exponential backoff.
client = SignalWire::REST::RestClient.new(
  project: 'proj', token: 'tok', host: 'acme.signalwire.com',
  request_options: SignalWire::REST::RequestOptions.new(timeout: 10, retries: 2)
)

# Per-request override (wins over the client default for this call only).
client.fabric.ai_agents.list(
  request_options: SignalWire::REST::RequestOptions.new(timeout: 30)
)
```

`RequestOptions` fields:

| Field | Default | Meaning |
|-------|---------|---------|
| `timeout` | none | Max wall-clock seconds per attempt; on exceed the attempt fails (and may retry). |
| `retries` | `0` | Number of RETRY attempts (total attempts = `retries + 1`). Retries are **opt-in**. |
| `retry_on_status` | `[429, 500, 502, 503, 504]` | Statuses that trigger a retry for an idempotent method. |
| `retry_backoff` | | Base seconds for exponential backoff (`backoff * 2 ** (attempt - 1)`), honoring a `Retry-After` response header when present. |
| `abort_signal` | none | A cooperative-cancellation object (responds to `set?`, e.g. `SignalWire::REST::AbortSignal`); when set before/between attempts the request stops. |

**Idempotency asymmetry.** Idempotent methods (`GET`/`PUT`/`DELETE`/`HEAD`/`OPTIONS`)
retry on the full `retry_on_status` set. Non-idempotent methods (`POST`/`PATCH`)
retry **only** on a transport error or `429`/`503` (throttles), never blindly on a
`5xx` — so a request that may have created or mutated a resource is not silently
replayed. The SDK also sets `Net::HTTP`'s own hidden idempotent retry to `0`, so
`retries` is the single source of truth.
