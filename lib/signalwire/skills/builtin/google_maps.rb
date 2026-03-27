# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class GoogleMapsSkill < SkillBase
        def name;        'google_maps'; end
        def description; 'Validate addresses and compute driving routes using Google Maps'; end

        def setup
          @api_key         = get_param('api_key', env_var: 'GOOGLE_MAPS_API_KEY')
          @lookup_tool     = get_param('lookup_tool_name', default: 'lookup_address')
          @route_tool      = get_param('route_tool_name', default: 'compute_route')
          return false unless @api_key && !@api_key.empty?
          true
        end

        def register_tools
          [
            {
              name: @lookup_tool,
              description: 'Validate and geocode a street address or business name using Google Maps',
              parameters: {
                'address'  => { 'type' => 'string', 'description' => 'The address or business name to look up' },
                'bias_lat' => { 'type' => 'number', 'description' => 'Latitude to bias results toward (optional)' },
                'bias_lng' => { 'type' => 'number', 'description' => 'Longitude to bias results toward (optional)' }
              },
              handler: method(:handle_lookup)
            },
            {
              name: @route_tool,
              description: 'Compute a driving route between two points using Google Maps Routes API',
              parameters: {
                'origin_lat' => { 'type' => 'number', 'description' => 'Origin latitude' },
                'origin_lng' => { 'type' => 'number', 'description' => 'Origin longitude' },
                'dest_lat'   => { 'type' => 'number', 'description' => 'Destination latitude' },
                'dest_lng'   => { 'type' => 'number', 'description' => 'Destination longitude' }
              },
              handler: method(:handle_route)
            }
          ]
        end

        def get_hints
          %w[address location route directions miles distance]
        end

        def get_prompt_sections
          [
            {
              'title' => 'Google Maps',
              'body' => 'You can validate addresses and compute driving routes.',
              'bullets' => [
                "Use #{@lookup_tool} to validate and geocode addresses or business names",
                "Use #{@route_tool} to get driving distance and time between two points",
                "Address lookup supports spoken numbers (e.g. 'seven one four' becomes '714')",
                'You can bias address results toward a known location to find the nearest match'
              ]
            }
          ]
        end

        def get_parameter_schema
          {
            'api_key'          => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'GOOGLE_MAPS_API_KEY' },
            'lookup_tool_name' => { 'type' => 'string', 'default' => 'lookup_address' },
            'route_tool_name'  => { 'type' => 'string', 'default' => 'compute_route' }
          }
        end

        private

        def handle_lookup(args, _raw_data)
          address = (args['address'] || '').strip
          if address.empty?
            return Swaig::FunctionResult.new('Please provide an address or business name to look up.')
          end

          bias_lat = args['bias_lat']
          bias_lng = args['bias_lng']

          # Use Geocoding API
          params = { address: address, key: @api_key }
          uri = URI('https://maps.googleapis.com/maps/api/geocode/json')
          uri.query = URI.encode_www_form(params)

          resp = Net::HTTP.get_response(uri)
          unless resp.is_a?(Net::HTTPSuccess)
            return Swaig::FunctionResult.new("I couldn't find that address. Could you provide a more specific address?")
          end

          data = JSON.parse(resp.body)
          results = data['results'] || []
          if results.empty?
            return Swaig::FunctionResult.new("I couldn't find that address. Could you provide a more specific address?")
          end

          r = results.first
          location = r.dig('geometry', 'location') || {}
          formatted = r['formatted_address'] || address

          Swaig::FunctionResult.new(
            "Address: #{formatted}\nCoordinates: #{location['lat']}, #{location['lng']}"
          )
        rescue => e
          Swaig::FunctionResult.new("Error looking up address: #{e.message}")
        end

        def handle_route(args, _raw_data)
          origin_lat = args['origin_lat']
          origin_lng = args['origin_lng']
          dest_lat   = args['dest_lat']
          dest_lng   = args['dest_lng']

          if [origin_lat, origin_lng, dest_lat, dest_lng].any?(&:nil?)
            return Swaig::FunctionResult.new('All four coordinates are required: origin_lat, origin_lng, dest_lat, dest_lng.')
          end

          uri = URI('https://routes.googleapis.com/directions/v2:computeRoutes')
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type']      = 'application/json'
          request['X-Goog-Api-Key']    = @api_key
          request['X-Goog-FieldMask']  = 'routes.distanceMeters,routes.duration'
          request.body = {
            origin:      { location: { latLng: { latitude: origin_lat, longitude: origin_lng } } },
            destination: { location: { latLng: { latitude: dest_lat,   longitude: dest_lng } } },
            travelMode: 'DRIVE',
            routingPreference: 'TRAFFIC_AWARE'
          }.to_json

          resp = http.request(request)
          data = JSON.parse(resp.body)

          routes = data['routes'] || []
          if routes.empty?
            return Swaig::FunctionResult.new("I couldn't compute a route between those locations.")
          end

          route = routes.first
          distance_m  = route['distanceMeters'] || 0
          duration_s  = (route['duration'] || '0s').to_s.delete('s').to_i
          distance_mi = distance_m / 1609.344
          duration_min = duration_s / 60.0

          Swaig::FunctionResult.new(
            "Distance: #{'%.1f' % distance_mi} miles\nEstimated travel time: #{duration_min.to_i} minutes"
          )
        rescue => e
          Swaig::FunctionResult.new("Error computing route: #{e.message}")
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('google_maps') do |params|
  SignalWire::Skills::Builtin::GoogleMapsSkill.new(params)
end
