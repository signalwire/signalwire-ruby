# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
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

        # Python parity: ``DateTimeSkill.setup`` -> ``self.validate_packages()``.
        # Python validates that ``pytz`` is importable before the skill is
        # usable. Ruby resolves timezones through the stdlib ``time``/``date``
        # libraries (no third-party dependency), so setup here verifies those
        # are loadable and returns whether the skill is ready.
        def setup
          require 'time'
          require 'date'
          true
        rescue LoadError => e
          logger.error("datetime skill setup failed: #{e.message}")
          false
        end

        # Python parity: ``DateTimeSkill.get_parameter_schema`` returns only the
        # base-class schema (the datetime skill adds no custom parameters). The
        # explicit super-only override is REQUIRED — the cross-port audit checks
        # public_instance_methods(false) includes it, so it must be defined here
        # directly, not merely inherited. rubocop:disable for that reason.
        def get_parameter_schema # rubocop:disable Lint/UselessMethodDefinition
          super
        end

        def register_tools
          [get_current_time_tool, get_current_date_tool]
        end

        # Python parity: ``DateTimeSkill.get_hints`` returns [] (the
        # reference documents optional example hints in a comment but ships
        # none). Defined directly on the class so the cross-port audit sees
        # it on public_instance_methods(false).
        def get_hints = []

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
        rescue StandardError
          nil
        end

        # ENV-based TZ resolution (works on most systems). If TZ is invalid,
        # Ruby silently falls back to UTC on some platforms.
        def time_in_zone(tz_name)
          ENV['TZ'] = tz_name
          Time.now
        ensure
          ENV.delete('TZ')
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datetime') do |params|
  SignalWire::Skills::Builtin::DateTimeSkill.new(params)
end
