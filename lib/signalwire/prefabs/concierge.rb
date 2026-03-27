# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

module SignalWire
  module Prefabs
    # Prefab agent for providing virtual concierge services.
    #
    #   agent = Concierge.new(
    #     venue_name: 'Grand Hotel',
    #     services: ['room service', 'spa bookings'],
    #     amenities: { 'pool' => { 'hours' => '7 AM - 10 PM', 'location' => '2nd Floor' } }
    #   )
    #
    class Concierge
      attr_reader :venue_name, :services, :amenities, :name, :route

      def initialize(venue_name:, services:, amenities:, hours_of_operation: nil,
                     special_instructions: nil, welcome_message: nil,
                     name: 'concierge', route: '/concierge', **_opts)
        @venue_name     = venue_name
        @services       = services || []
        @amenities      = (amenities || {}).transform_keys(&:to_s)
        @hours          = hours_of_operation
        @instructions   = special_instructions || []
        @welcome        = welcome_message || "Welcome to #{venue_name}! How can I assist you today?"
        @name  = name
        @route = route
      end

      def tools
        %w[get_amenity_info get_service_info]
      end

      def prompt_sections
        amenity_bullets = @amenities.map { |k, v| "#{k}: #{v.is_a?(Hash) ? v.map { |a, b| "#{a}: #{b}" }.join(', ') : v}" }
        service_bullets = @services.map { |s| s.to_s }

        sections = [
          {
            'title' => "#{@venue_name} Concierge",
            'body' => @welcome,
            'bullets' => service_bullets + amenity_bullets
          }
        ]

        if @hours
          sections << {
            'title' => 'Hours of Operation',
            'body' => @hours.is_a?(Hash) ? @hours.map { |k, v| "#{k}: #{v}" }.join('; ') : @hours.to_s
          }
        end

        sections
      end

      def global_data
        {
          'venue_name' => @venue_name,
          'services'   => @services,
          'amenities'  => @amenities
        }
      end

      def handle_amenity_info(args, _raw_data)
        amenity = (args['amenity'] || '').downcase
        info = @amenities.find { |k, _v| k.downcase == amenity }&.last
        if info
          detail = info.is_a?(Hash) ? info.map { |k, v| "#{k}: #{v}" }.join(', ') : info.to_s
          Swaig::FunctionResult.new("#{amenity.capitalize}: #{detail}")
        else
          Swaig::FunctionResult.new("I don't have information about '#{amenity}'. Available amenities: #{@amenities.keys.join(', ')}")
        end
      end

      def handle_service_info(args, _raw_data)
        service = (args['service'] || '').downcase
        match = @services.find { |s| s.downcase.include?(service) }
        if match
          Swaig::FunctionResult.new("#{match} is available at #{@venue_name}.")
        else
          Swaig::FunctionResult.new("Available services: #{@services.join(', ')}")
        end
      end
    end
  end
end
