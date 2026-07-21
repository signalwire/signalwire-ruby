# frozen_string_literal: true

# Example: Full phone number inventory lifecycle.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# 1. Search for available phone numbers
puts 'Searching available numbers...'
available = client.phone_numbers.search(areacode: '512', max_results: 3)
(available['data'] || []).each do |num|
  puts "  - #{num.fetch('e164', num.fetch('number', 'unknown'))}"
end

# 2. Purchase a number
puts "\nPurchasing a phone number..."
num_id = nil
begin
  first = (available['data'] || [{}]).first
  number = client.phone_numbers.create(number: first.fetch('e164', '+15125551234'))
  num_id = number['id']
  puts "  Purchased: #{num_id}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Purchase failed (expected in demo): #{e.status_code}"
end

# 3. List and get owned numbers
puts "\nListing owned numbers..."
owned = client.phone_numbers.list
(owned['data'] || []).first(5).each do |n|
  puts "  - #{n.fetch('number', 'unknown')} (#{n['id']})"
end

if num_id
  detail = client.phone_numbers.get(num_id)
  puts "  Detail: #{detail.fetch('number', 'N/A')}"
end

# 4. Update a number
if num_id
  puts "\nUpdating number #{num_id}..."
  client.phone_numbers.update(num_id, name: 'Main Line')
  puts "  Updated name to 'Main Line'"
end

# 5. Create a number group
puts "\nCreating number group..."
group_id = nil
group = safe('Create group') { client.number_groups.create(name: 'Sales Pool') }
group_id = group && group['id']

# 6. Add a membership and list memberships
if group_id && num_id
  puts "\nAdding number to group..."
  begin
    membership = client.number_groups.add_membership(group_id, phone_number_id: num_id)
    mem_id = membership['id']
    puts "  Membership: #{mem_id}"

    memberships = client.number_groups.list_memberships(group_id)
    (memberships['data'] || []).each do |m|
      puts "  - Member: #{m.fetch('id', 'unknown')}"
    end
  rescue SignalWire::REST::SignalWireRestError => e
    puts "  Membership failed (expected in demo): #{e.status_code}"
  end
end

# 7. Lookup carrier info
puts "\nLooking up carrier info..."
safe('Carrier lookup') do
  info = client.lookup.phone_number('+15125551234')
  puts "  Carrier: #{info.dig('carrier', 'name') || 'unknown'}"
end

# 8. Create a verified caller
puts "\nCreating verified caller..."
caller_id = nil
begin
  caller = client.verified_callers.create(number: '+15125559999')
  caller_id = caller['id']
  puts "  Created verified caller: #{caller_id}"
  client.verified_callers.submit_verification(caller_id, verification_code: '123456')
  puts '  Verification code submitted'
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Verified caller failed (expected in demo): #{e.status_code}"
end

# 9. Get and update SIP profile
puts "\nGetting SIP profile..."
safe('SIP profile') do
  profile = client.sip_profile.get
  puts "  SIP profile: #{profile}"
  client.sip_profile.update(default_codecs: %w[PCMU PCMA])
  puts '  Updated SIP codecs'
end

# 10. List short codes
puts "\nListing short codes..."
safe('Short codes') do
  codes = client.short_codes.list
  (codes['data'] || []).each do |sc|
    puts "  - #{sc.fetch('short_code', 'unknown')}"
  end
end

# 11. Create an address
puts "\nCreating address..."
addr_id = nil
addr = safe('Create address') do
  client.addresses.create(
    label:         'HQ Address',
    country:       'US',
    first_name:    'Jane',
    last_name:     'Doe',
    street_number: '123',
    street_name:   'Main St',
    city:          'Austin',
    state:         'TX',
    postal_code:   '78701'
  )
end
addr_id = addr && addr['id']

# 12. Clean up
puts "\nCleaning up..."
safe('Delete address')         { client.addresses.delete(addr_id) } if addr_id
safe('Delete verified caller') { client.verified_callers.delete(caller_id) } if caller_id
safe('Delete number group')    { client.number_groups.delete(group_id) } if group_id
safe('Release number')         { client.phone_numbers.delete(num_id) } if num_id
