# frozen_string_literal: true

# Example: bind an inbound phone number to an SWML webhook (the happy path).
#
# This is the simplest way to route a SignalWire phone number to a backend
# that returns an SWML document per inbound call. You set +call_handler+ on
# the phone number; the server auto-materializes a +swml_webhook+ Fabric
# resource pointing at your URL. You do *not* need to create the Fabric
# webhook resource manually; you do *not* call +assign_phone_route+.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)
#   PHONE_NUMBER_SID        - SID of a phone number you own (pn-...)
#   SWML_WEBHOOK_URL        - your backend's SWML endpoint

require 'signalwire'
require 'signalwire/rest/rest_client' # opt-in subsystem (Python: from signalwire.rest import Client)

pn_sid      = ENV.fetch('PHONE_NUMBER_SID', 'pn-00000000-0000-0000-0000-000000000000')
webhook_url = ENV.fetch('SWML_WEBHOOK_URL', 'https://example.com/swml')

client = SignalWire::REST::RestClient.new

# The typed helper -- one line:
puts "Binding #{pn_sid} to #{webhook_url} ..."
client.phone_numbers.set_swml_webhook(pn_sid, url: webhook_url)

# The equivalent wire-level form (use this if you need unusual fields):
#
# client.phone_numbers.update(
#   pn_sid,
#   call_handler:          SignalWire::REST::PhoneCallHandler::RELAY_SCRIPT,
#   call_relay_script_url: webhook_url
# )

# Verify: the server auto-created a swml_webhook Fabric resource.
pn = client.phone_numbers.get(pn_sid)
puts "  call_handler = #{pn['call_handler'].inspect}"
puts "  call_relay_script_url = #{pn['call_relay_script_url'].inspect}"
puts '  calling_handler_resource_id (server-derived) = ' \
     "#{pn['calling_handler_resource_id'].inspect}"

# To route to something other than an SWML webhook, use:
#   client.phone_numbers.set_cxml_webhook(sid, url: ...)        # LAML / Twilio-compat
#   client.phone_numbers.set_ai_agent(sid, agent_id: ...)       # AI Agent
#   client.phone_numbers.set_call_flow(sid, flow_id: ...)       # Call Flow
#   client.phone_numbers.set_relay_application(sid, name: ...)  # Named RELAY app
#   client.phone_numbers.set_relay_topic(sid, topic: ...)       # RELAY topic
