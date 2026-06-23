# RestClient Reference

## Constructor

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
| `client.compat` | Twilio-compatible LAML API |

## Error Handling

```ruby
begin
  client.fabric.ai_agents.get('bad-id')
rescue SignalWire::REST::SignalWireRestError => e
  puts e.status_code   # 404
  puts e.body          # {"error"=>"not found"}
  puts e.url           # "/api/fabric/resources/ai_agents/bad-id"
  puts e.method_name   # "GET"
end
```

`SignalWire::REST::SignalWireRestError` is raised on any non-2xx HTTP response.

### Error Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `status_code` | `Integer` | HTTP status code |
| `body` | `Hash` or `String` | Response body (parsed JSON or raw text) |
| `url` | `String` | Request path |
| `method_name` | `String` | HTTP method |

## Session Behavior

- Requests use `Net::HTTP` from the Ruby standard library.
- Content-Type is always `application/json`.
- User-Agent is `signalwire-agents-ruby-rest/1.0`.
- DELETE requests returning 204 return an empty Hash.
- Responses are plain Ruby Hashes (parsed JSON) -- there are no wrapper objects.
