# REST coverage — signalwire-ruby accepted SDK gaps

Per-port half of the REST-COVERAGE allowlist (type sdk-gap). Universal gaps (2
doubled-path fabric artifacts + video.get_room routing collision) live in
porting-sdk/REST_COVERAGE_BASELINE.md. These 18 match the python reference. Ruby
reached 286/307 after the FabricResourcePUT update-verb inheritance fix.

## fabric — dialogflow_agents not wired
fabric.list_dialogflow_agents: sdk-gap — no dialogflow_agents resource (as python).
fabric.get_dialogflow_agent: sdk-gap — no dialogflow_agents resource.
fabric.update_dialogflow_agent: sdk-gap — no dialogflow_agents resource.
fabric.delete_dialogflow_agent: sdk-gap — no dialogflow_agents resource.
fabric.list_dialogflow_agent_addresses: sdk-gap — no dialogflow_agents resource.

## relay-rest — SIP endpoints + domain applications have no relay-rest namespace
relay-rest.list_sip_endpoints: sdk-gap — no relay-rest namespace (Fabric-side only; as python).
relay-rest.create_sip_endpoint: sdk-gap — see above.
relay-rest.retrieve_sip_endpoint: sdk-gap — see above.
relay-rest.update_sip_endpoint: sdk-gap — see above.
relay-rest.delete_sip_endpoint: sdk-gap — see above.
relay-rest.list_domain_applications: sdk-gap — no relay-rest namespace (as python).
relay-rest.create_domain_application: sdk-gap — see above.
relay-rest.retrieve_domain_application: sdk-gap — see above.
relay-rest.update_domain_application: sdk-gap — see above.
relay-rest.delete_domain_application: sdk-gap — see above.

## video — no logs accessor
video.list_logs: sdk-gap — no client.video.logs accessor (as python).
video.get_log: sdk-gap — no video logs accessor.

## compatibility — bare per-country node
compatibility.list_available_phone_number_resources_by_country: sdk-gap — only /Local + /TollFree searches exist, not the bare /AvailablePhoneNumbers/{IsoCountry} node (as python).
