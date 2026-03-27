# frozen_string_literal: true

# Example: 10DLC brand and campaign compliance registration.
#
# WARNING: This example interacts with the real 10DLC registration system.
# Brand and campaign registrations may have side effects and costs.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# 1. Register a brand
puts 'Registering 10DLC brand...'
brand = safe('Register brand') do
  client.registry.brands.create(
    company_name: 'Acme Corp',
    ein:          '12-3456789',
    entity_type:  'PRIVATE_PROFIT',
    vertical:     'TECHNOLOGY',
    website:      'https://acme.example.com',
    country:      'US'
  )
end
brand_id = brand && brand['id']

# 2. List brands
puts "\nListing brands..."
brands = client.registry.brands.list
(brands['data'] || []).each do |b|
  puts "  - #{b['id']}: #{b.fetch('name', 'unnamed')}"
end
brand_id ||= (brands['data'] || []).first&.dig('id')

# 3. Get brand details
if brand_id
  detail = client.registry.brands.get(brand_id)
  puts "\nBrand detail: #{detail.fetch('name', 'N/A')} (#{detail.fetch('state', 'N/A')})"
end

# 4. Create a campaign under the brand
campaign_id = nil
if brand_id
  puts "\nCreating campaign..."
  campaign = safe('Create campaign') do
    client.registry.brands.create_campaign(
      brand_id,
      use_case:       'MIXED',
      description:    'Customer notifications and support messages',
      sample_message: 'Your order #12345 has shipped.'
    )
  end
  campaign_id = campaign && campaign['id']
end

# 5. List campaigns for the brand
if brand_id
  puts "\nListing brand campaigns..."
  campaigns = client.registry.brands.list_campaigns(brand_id)
  (campaigns['data'] || []).each do |c|
    puts "  - #{c['id']}: #{c.fetch('name', 'unknown')}"
    campaign_id ||= c['id']
  end
end

# 6. Get and update campaign
if campaign_id
  camp_detail = client.registry.campaigns.get(campaign_id)
  puts "\nCampaign: #{camp_detail.fetch('name', 'N/A')} (#{camp_detail.fetch('state', 'N/A')})"

  safe('Update campaign') do
    client.registry.campaigns.update(campaign_id, description: 'Updated: customer notifications')
  end
end

# 7. Create an order to assign numbers
order_id = nil
if campaign_id
  puts "\nCreating number assignment order..."
  order = safe('Create order') do
    client.registry.campaigns.create_order(campaign_id, phone_numbers: ['+15125551234'])
  end
  order_id = order && order['id']
end

# 8. Get order status
if order_id
  order_detail = client.registry.orders.get(order_id)
  puts "  Order status: #{order_detail.fetch('status', 'N/A')}"
end

# 9. List campaign numbers and orders
if campaign_id
  puts "\nListing campaign numbers..."
  numbers = client.registry.campaigns.list_numbers(campaign_id)
  (numbers['data'] || []).each do |n|
    puts "  - #{n.fetch('phone_number', n.fetch('id', 'unknown'))}"
  end

  orders = client.registry.campaigns.list_orders(campaign_id)
  (orders['data'] || []).each do |o|
    puts "  - Order #{o['id']}: #{o.fetch('status', 'unknown')}"
  end
end

# 10. Unassign numbers (clean up)
if campaign_id
  puts "\nUnassigning numbers..."
  nums = client.registry.campaigns.list_numbers(campaign_id)
  (nums['data'] || []).each do |n|
    safe("Unassign #{n['id']}") { client.registry.numbers.delete(n['id']) }
  end
end
