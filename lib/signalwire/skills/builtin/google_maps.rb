# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Private HTTP/formatting helpers for {GoogleMapsSkill}, extracted to
      # keep the skill class small. Not part of the public skill surface.
      module GoogleMapsHttp
        private

        def geocode(address)
          resp = Net::HTTP.get_response(geocode_uri(address))
          return [] unless resp.is_a?(Net::HTTPSuccess)

          JSON.parse(resp.body)['results'] || []
        end

        def format_geocode_result(result, address)
          location = result.dig('geometry', 'location') || {}
          formatted = result['formatted_address'] || address
          Swaig::FunctionResult.new(
            "Address: #{formatted}\nCoordinates: #{location['lat']}, #{location['lng']}"
          )
        end

        def geocode_uri(address)
          uri = URI('https://maps.googleapis.com/maps/api/geocode/json')
          uri.query = URI.encode_www_form(address: address, key: @api_key)
          uri
        end

        def geocode_not_found
          Swaig::FunctionResult.new("I couldn't find that address. Could you provide a more specific address?")
        end

        def fetch_routes(origin_lat, origin_lng, dest_lat, dest_lng)
          uri = URI('https://routes.googleapis.com/directions/v2:computeRoutes')
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = build_route_request(uri, origin_lat, origin_lng, dest_lat, dest_lng)
          JSON.parse(http.request(request).body)['routes'] || []
        end

        def build_route_request(uri, origin_lat, origin_lng, dest_lat, dest_lng)
          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type']      = 'application/json'
          request['X-Goog-Api-Key']    = @api_key
          request['X-Goog-FieldMask']  = 'routes.distanceMeters,routes.duration'
          request.body = route_request_body(origin_lat, origin_lng, dest_lat, dest_lng)
          request
        end

        def route_request_body(origin_lat, origin_lng, dest_lat, dest_lng)
          {
            origin: { location: { latLng: { latitude: origin_lat, longitude: origin_lng } } },
            destination: { location: { latLng: { latitude: dest_lat, longitude: dest_lng } } },
            travelMode: 'DRIVE',
            routingPreference: 'TRAFFIC_AWARE'
          }.to_json
        end

        def format_route(route)
          distance_mi  = (route['distanceMeters'] || 0) / 1609.344
          duration_min = (route['duration'] || '0s').to_s.delete('s').to_i / 60.0
          Swaig::FunctionResult.new(
            "Distance: #{format('%.1f', distance_mi)} miles\nEstimated travel time: #{duration_min.to_i} minutes"
          )
        end
      end

      class GoogleMapsSkill < SkillBase
        include GoogleMapsHttp

        LOOKUP_PARAMETERS = {
          'address' => { 'type' => 'string', 'description' => 'The address or business name to look up' },
          'bias_lat' => { 'type' => 'number', 'description' => 'Latitude to bias results toward (optional)' },
          'bias_lng' => { 'type' => 'number', 'description' => 'Longitude to bias results toward (optional)' }
        }.freeze

        ROUTE_PARAMETERS = {
          'origin_lat' => { 'type' => 'number', 'description' => 'Origin latitude' },
          'origin_lng' => { 'type' => 'number', 'description' => 'Origin longitude' },
          'dest_lat' => { 'type' => 'number', 'description' => 'Destination latitude' },
          'dest_lng' => { 'type' => 'number', 'description' => 'Destination longitude' }
        }.freeze

        def name = 'google_maps'
        def description = 'Validate addresses and compute driving routes using Google Maps'

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @api_key         = get_param('api_key', env_var: 'GOOGLE_MAPS_API_KEY')
          @lookup_tool     = get_param('lookup_tool_name', default: 'lookup_address')
          @route_tool      = get_param('route_tool_name', default: 'compute_route')
          return false unless @api_key && !@api_key.empty?

          true
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [lookup_tool_def, route_tool_def]
        end

        # Speech-recognition hints this skill contributes to the AI verb, biasing
        # the recognizer toward the vocabulary the skill's domain uses.
        #
        # @return [Array<String>]
        def get_hints
          %w[address location route directions miles distance]
        end

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          [
            {
              'title' => 'Google Maps',
              'body' => 'You can validate addresses and compute driving routes.',
              'bullets' => prompt_bullets
            }
          ]
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true,
                           'env_var' => 'GOOGLE_MAPS_API_KEY' },
            'lookup_tool_name' => { 'type' => 'string', 'default' => 'lookup_address' },
            'route_tool_name' => { 'type' => 'string', 'default' => 'compute_route' }
          }
        end

        private

        def prompt_bullets
          [
            "Use #{@lookup_tool} to validate and geocode addresses or business names",
            "Use #{@route_tool} to get driving distance and time between two points",
            "Address lookup supports spoken numbers (e.g. 'seven one four' becomes '714')",
            'You can bias address results toward a known location to find the nearest match'
          ]
        end

        def lookup_tool_def
          {
            name: @lookup_tool,
            description: 'Validate and geocode a street address or business name using Google Maps',
            parameters: LOOKUP_PARAMETERS,
            handler: method(:handle_lookup)
          }
        end

        def route_tool_def
          {
            name: @route_tool,
            description: 'Compute a driving route between two points using Google Maps Routes API',
            parameters: ROUTE_PARAMETERS,
            handler: method(:handle_route)
          }
        end

        def handle_lookup(args, _raw_data)
          address = (args['address'] || '').strip
          return Swaig::FunctionResult.new('Please provide an address or business name to look up.') if address.empty?

          results = geocode(address)
          return geocode_not_found if results.empty?

          format_geocode_result(results.first, address)
        rescue StandardError => e
          Swaig::FunctionResult.new("Error looking up address: #{e.message}")
        end

        def handle_route(args, _raw_data)
          coords = %w[origin_lat origin_lng dest_lat dest_lng].map { |k| args[k] }
          if coords.any?(&:nil?)
            msg = 'All four coordinates are required: origin_lat, origin_lng, dest_lat, dest_lng.'
            return Swaig::FunctionResult.new(msg)
          end

          routes = fetch_routes(*coords)
          return Swaig::FunctionResult.new("I couldn't compute a route between those locations.") if routes.empty?

          format_route(routes.first)
        rescue StandardError => e
          Swaig::FunctionResult.new("Error computing route: #{e.message}")
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('google_maps') do |params|
  SignalWire::Skills::Builtin::GoogleMapsSkill.new(params)
end
