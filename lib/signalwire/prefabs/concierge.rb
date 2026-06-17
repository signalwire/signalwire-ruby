# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

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
        %w[get_amenity_info get_service_info check_availability get_directions]
      end

      def prompt_sections
        amenity_bullets = @amenities.map do |k, v|
          "#{k}: #{if v.is_a?(Hash)
                     v.map do |a, b|
                       "#{a}: #{b}"
                     end.join(', ')
                   else
                     v
                   end}"
        end
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
          'services' => @services,
          'amenities' => @amenities
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

      # Tool: check_availability — Python parity
      # (signalwire.prefabs.concierge.ConciergeAgent#check_availability).
      #
      # Simulated booking lookup: confirms availability when the requested
      # service is one of the venue's offered services, otherwise lists the
      # available services.
      #
      # @param args [Hash] expects "service", "date", "time"
      # @return [Swaig::FunctionResult]
      def check_availability(args, _raw_data)
        service = (args['service'] || '').downcase
        date    = args['date'] || ''
        time    = args['time'] || ''

        if @services.any? { |s| s.downcase == service }
          Swaig::FunctionResult.new(
            "Yes, #{service} is available on #{date} at #{time}. " \
            'Would you like to make a reservation?'
          )
        else
          Swaig::FunctionResult.new(
            "I'm sorry, we don't offer #{service} at #{@venue_name}. " \
            "Our available services are: #{@services.join(', ')}."
          )
        end
      end

      # Tool: get_directions — Python parity
      # (signalwire.prefabs.concierge.ConciergeAgent#get_directions).
      #
      # Returns directions to an amenity when that amenity declares a
      # "location" detail, otherwise points the caller at the front desk.
      #
      # @param args [Hash] expects "location"
      # @return [Swaig::FunctionResult]
      def get_directions(args, _raw_data)
        location = (args['location'] || '').downcase
        amenity  = @amenities.find { |k, _v| k.downcase == location }&.last

        if amenity.is_a?(Hash) && amenity['location']
          where = amenity['location']
          Swaig::FunctionResult.new(
            "The #{location} is located at #{where}. " \
            "From the main entrance, follow the signs to #{where}."
          )
        else
          Swaig::FunctionResult.new(
            "I don't have specific directions to #{location}. " \
            'You can ask our staff at the front desk for assistance.'
          )
        end
      end

      # Lifecycle hook: on_summary — Python parity
      # (signalwire.prefabs.concierge.ConciergeAgent#on_summary).
      #
      # Processes the post-prompt interaction summary. Structured (Hash)
      # summaries are logged as pretty JSON; anything else is logged as-is.
      # Subclasses may override to persist or forward the interaction.
      #
      # @param summary [Hash, String, nil] conversation summary
      # @param _raw_data [Hash, nil] full raw POST data
      # @return [void]
      def on_summary(summary, _raw_data = nil)
        return if summary.nil?

        if summary.is_a?(Hash)
          puts "Concierge interaction summary: #{JSON.pretty_generate(summary)}"
        else
          puts "Concierge interaction summary: #{summary}"
        end
      rescue StandardError => e
        puts "Error processing summary: #{e.message}"
      end
    end
  end
end
