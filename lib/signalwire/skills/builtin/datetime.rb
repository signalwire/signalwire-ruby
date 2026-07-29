# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Tell the model the current date and time, optionally in a named timezone.
      # Timezones are resolved through tzinfo rather than by mutating the process's
      # `TZ`, so concurrent calls for different zones never interfere.
      class DateTimeSkill < SkillBase
        TIMEZONE_DESCRIPTION = "Timezone name (e.g., 'America/New_York', 'Europe/London'). Defaults to UTC."
        PROMPT_SECTIONS = [
          {
            'title' => 'Date and Time Information',
            'body' => 'You can provide current date and time information.',
            'bullets' => [
              'Use get_current_time to tell users what time it is',
              'Use get_current_date to tell users today\'s date',
              'Both tools support different timezones'
            ]
          }
        ].freeze

        # The name this skill is added under (`agent.add_skill('datetime')`).
        #
        # @return [String]
        def name = 'datetime'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Get current date, time, and timezone information'

        # Timezones are resolved through the ``tzinfo`` gem — a thread-safe,
        # OS-tzdata-independent lookup that needs no process-global ENV['TZ']
        # mutation. Setup verifies the libraries are loadable and returns
        # whether the skill is ready.
        def setup
          require 'time'
          require 'date'
          require 'tzinfo'
          true
        rescue LoadError => e
          logger.error("datetime skill setup failed: #{e.message}")
          false
        end

        # Returns only the base-class schema (the datetime skill adds no
        # custom parameters). The explicit super-only override is defined
        # here directly so it appears on public_instance_methods(false);
        # the cop is disabled on the def line for that reason.
        def get_parameter_schema # rubocop:disable Lint/UselessMethodDefinition
          super
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [get_current_time_tool, get_current_date_tool]
        end

        # Returns [] — this skill ships no example hints. Defined directly
        # on the class so it appears on public_instance_methods(false).
        def get_hints = []

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          PROMPT_SECTIONS.map(&:dup)
        end

        private

        # @api private — the current-time tool definition. The timezone parameter is
        # optional and defaults to UTC.
        def get_current_time_tool
          {
            name: 'get_current_time',
            description: 'Get the current time, optionally in a specific timezone',
            parameters: { 'timezone' => { 'type' => 'string', 'description' => TIMEZONE_DESCRIPTION } },
            handler: method(:handle_get_time)
          }
        end

        # @api private — the current-date tool definition. The timezone parameter is
        # optional and defaults to UTC.
        def get_current_date_tool
          {
            name: 'get_current_date',
            description: 'Get the current date',
            parameters: {
              'timezone' => { 'type' => 'string', 'description' => 'Timezone name for the date. Defaults to UTC.' }
            },
            handler: method(:handle_get_date)
          }
        end

        # @api private — the time handler, formatting as 12-hour time with the zone
        # abbreviation. An unknown timezone yields a spoken error naming it rather than
        # silently falling back to UTC.
        #
        # @return [Swaig::FunctionResult]
        def handle_get_time(args, _raw_data)
          tz_name = (args['timezone'] || 'UTC').strip
          now = resolve_time(tz_name)
          if now.nil?
            Swaig::FunctionResult.new("Error: unknown timezone '#{tz_name}'")
          else
            time_str = now.strftime('%I:%M:%S %p %Z')
            Swaig::FunctionResult.new("The current time is #{time_str}")
          end
        end

        # @api private — the date handler, formatting as "Weekday, Month DD, YYYY"
        # so TTS reads it naturally. An unknown timezone yields a spoken error.
        #
        # @return [Swaig::FunctionResult]
        def handle_get_date(args, _raw_data)
          tz_name = (args['timezone'] || 'UTC').strip
          now = resolve_time(tz_name)
          if now.nil?
            Swaig::FunctionResult.new("Error: unknown timezone '#{tz_name}'")
          else
            date_str = now.strftime('%A, %B %d, %Y')
            Swaig::FunctionResult.new("Today's date is #{date_str}")
          end
        end

        # @api private — the current time in +tz_name+. `UTC` short-circuits; anything
        # else goes through tzinfo.
        #
        # @return [Time, nil] nil when the timezone is unknown
        def resolve_time(tz_name)
          return Time.now.utc if tz_name.upcase == 'UTC'

          time_in_zone(tz_name)
        end

        # Thread-safe timezone resolution via tzinfo — no process-global
        # ENV['TZ'] mutation, so concurrent calls with different timezones
        # never clobber each other, and the result is independent of the host
        # OS tzdata layout. An unknown timezone returns nil so the caller
        # emits the "unknown timezone" error result.
        def time_in_zone(tz_name)
          require 'tzinfo'
          TZInfo::Timezone.get(tz_name).now
        rescue TZInfo::InvalidTimezoneIdentifier
          nil
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datetime') do |params|
  SignalWire::Skills::Builtin::DateTimeSkill.new(params)
end
