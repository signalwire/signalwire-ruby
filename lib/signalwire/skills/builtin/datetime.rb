# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
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

        def name = 'datetime'
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

        def get_current_time_tool
          {
            name: 'get_current_time',
            description: 'Get the current time, optionally in a specific timezone',
            parameters: { 'timezone' => { 'type' => 'string', 'description' => TIMEZONE_DESCRIPTION } },
            handler: method(:handle_get_time)
          }
        end

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
