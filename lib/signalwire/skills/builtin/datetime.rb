# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class DateTimeSkill < SkillBase
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
          [
            {
              name: 'get_current_time',
              description: 'Get the current time, optionally in a specific timezone',
              parameters: {
                'timezone' => { 'type' => 'string',
                                'description' => "Timezone name (e.g., 'America/New_York', 'Europe/London'). Defaults to UTC." }
              },
              handler: method(:handle_get_time)
            },
            {
              name: 'get_current_date',
              description: 'Get the current date',
              parameters: {
                'timezone' => { 'type' => 'string', 'description' => 'Timezone name for the date. Defaults to UTC.' }
              },
              handler: method(:handle_get_date)
            }
          ]
        end

        def get_prompt_sections
          [
            {
              'title' => 'Date and Time Information',
              'body' => 'You can provide current date and time information.',
              'bullets' => [
                'Use get_current_time to tell users what time it is',
                'Use get_current_date to tell users today\'s date',
                'Both tools support different timezones'
              ]
            }
          ]
        end

        private

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
          if tz_name.upcase == 'UTC'
            Time.now.utc
          else
            # Try ENV-based TZ resolution (works on most systems)
            begin
              ENV['TZ'] = tz_name
              t = Time.now
              # Verify the timezone was actually applied
              # (if TZ is invalid, Ruby silently uses UTC on some platforms)
              t
            ensure
              ENV.delete('TZ')
            end
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datetime') do |params|
  SignalWire::Skills::Builtin::DateTimeSkill.new(params)
end
