# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

require_relative '../swaig/function_result'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Prefabs — ready-made agents assembled from the SDK's own building blocks.
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
      # The reference's default when the caller supplies no hours
      # (prefabs/concierge.py:78). It always renders an Hours of Operation
      # section, so the default has to exist rather than the section vanishing.
      DEFAULT_HOURS = { 'default' => '9 AM - 5 PM' }.freeze

      attr_reader :venue_name, :services, :amenities, :name, :route

      # @return [Hash{String=>String}] operating hours per label — the
      #   caller-supplied map or {DEFAULT_HOURS}. Reference attribute
      #   `self.hours_of_operation` (prefabs/concierge.py:78).
      # @return [Array<String>] +special_instructions+: extra instruction
      #   bullets appended to the agent's Instructions. Reference attribute
      #   `self.special_instructions` (prefabs/concierge.py:79).
      attr_reader :hours_of_operation, :special_instructions

      def initialize(venue_name:, services:, amenities:, hours_of_operation: nil,
                     special_instructions: nil, welcome_message: nil,
                     name: 'concierge', route: '/concierge', **_opts)
        @venue_name     = venue_name
        @services       = services || []
        @amenities      = (amenities || {}).transform_keys(&:to_s)
        # The reference takes a per-label MAP (`dict[str, str]`); normalise a
        # bare String to the default label so both shapes reach the prompt and
        # `global_data` always carries a map, as every other port does.
        @hours_of_operation = normalize_hours(hours_of_operation)
        @special_instructions = special_instructions || []
        @welcome = welcome_message || "Welcome to #{venue_name}! How can I assist you today?"
        @name  = name
        @route = route
      end

      def tools
        %w[get_amenity_info get_service_info check_availability get_directions]
      end

      def prompt_sections
        sections = [
          {
            'title' => "#{@venue_name} Concierge",
            'body' => @welcome,
            'bullets' => @services.map(&:to_s) + amenity_bullets
          }
        ]
        sections << instructions_section unless @special_instructions.empty?
        # Always emitted — the reference renders this section unconditionally
        # from a defaulted map, so hours are never silently absent.
        sections << hours_section
        sections
      end

      def global_data
        {
          'venue_name' => @venue_name,
          'services' => @services,
          'amenities' => @amenities,
          'hours_of_operation' => @hours_of_operation,
          'special_instructions' => @special_instructions
        }
      end

      def handle_amenity_info(args, _raw_data)
        amenity = (args['amenity'] || '').downcase
        info = @amenities.find { |k, _v| k.downcase == amenity }&.last
        return amenity_not_found(amenity) unless info

        Swaig::FunctionResult.new("#{amenity.capitalize}: #{format_amenity_detail(info)}")
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

      # Tool: check_availability.
      #
      # Simulated booking lookup: confirms availability when the requested
      # service is one of the venue's offered services, otherwise lists the
      # available services.
      #
      # @param args [Hash] expects "service", "date", "time"
      # @return [Swaig::FunctionResult]
      def check_availability(args, _raw_data)
        service = (args['service'] || '').downcase
        return service_unavailable(service) unless @services.any? { |s| s.downcase == service }

        date = args['date'] || ''
        time = args['time'] || ''
        Swaig::FunctionResult.new(
          "Yes, #{service} is available on #{date} at #{time}. " \
          'Would you like to make a reservation?'
        )
      end

      # Tool: get_directions.
      #
      # Returns directions to an amenity when that amenity declares a
      # "location" detail, otherwise points the caller at the front desk.
      #
      # @param args [Hash] expects "location"
      # @return [Swaig::FunctionResult]
      def get_directions(args, _raw_data)
        location = (args['location'] || '').downcase
        amenity  = @amenities.find { |k, _v| k.downcase == location }&.last
        return directions_unknown(location) unless amenity.is_a?(Hash) && amenity['location']

        where = amenity['location']
        Swaig::FunctionResult.new(
          "The #{location} is located at #{where}. " \
          "From the main entrance, follow the signs to #{where}."
        )
      end

      # Lifecycle hook: on_summary.
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

      private

      # Bullet lines for each amenity; a Hash value is flattened to "k: v, ..".
      def amenity_bullets
        @amenities.map { |k, v| "#{k}: #{format_amenity_detail(v)}" }
      end

      # Flatten one amenity's detail (Hash -> "k: v, .." else the value as text).
      def format_amenity_detail(info)
        info.is_a?(Hash) ? info.map { |k, v| "#{k}: #{v}" }.join(', ') : info.to_s
      end

      # Normalise the caller's hours to the reference's per-label map shape. A
      # bare String is accepted for convenience and filed under the default
      # label; nil falls back to DEFAULT_HOURS.
      def normalize_hours(hours)
        return DEFAULT_HOURS.dup if hours.nil?
        return { 'default' => hours.to_s } unless hours.is_a?(Hash)

        hours.transform_keys(&:to_s)
      end

      # The "Hours of Operation" prompt section. One "Label: value" line per
      # entry, labels title-cased and newline-joined, matching the reference
      # (`"\n".join(f"{k.title()}: {v}" ...)`, prefabs/concierge.py:133-135).
      def hours_section
        body = @hours_of_operation.map { |k, v| "#{k.to_s.split(/\s+/).map(&:capitalize).join(' ')}: #{v}" }
                                  .join("\n")
        { 'title' => 'Hours of Operation', 'body' => body }
      end

      # The extra instruction bullets the caller supplied. The reference appends
      # these to its Instructions section (prefabs/concierge.py:106); before this
      # they were stored and never reached the prompt at all.
      def instructions_section
        { 'title' => 'Instructions', 'bullets' => @special_instructions.map(&:to_s) }
      end

      def amenity_not_found(amenity)
        Swaig::FunctionResult.new(
          "I don't have information about '#{amenity}'. " \
          "Available amenities: #{@amenities.keys.join(', ')}"
        )
      end

      def service_unavailable(service)
        Swaig::FunctionResult.new(
          "I'm sorry, we don't offer #{service} at #{@venue_name}. " \
          "Our available services are: #{@services.join(', ')}."
        )
      end

      def directions_unknown(location)
        Swaig::FunctionResult.new(
          "I don't have specific directions to #{location}. " \
          'You can ask our staff at the front desk for assistance.'
        )
      end
    end
  end
end
