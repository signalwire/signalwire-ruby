# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

module SignalWire
  module Prefabs
    # Prefab agent for greeting callers and transferring them to departments.
    #
    #   agent = Receptionist.new(
    #     departments: [
    #       { 'name' => 'sales',   'description' => 'Product inquiries', 'number' => '+15551235555' },
    #       { 'name' => 'support', 'description' => 'Technical help',    'number' => '+15551236666' }
    #     ]
    #   )
    #
    class Receptionist
      attr_reader :departments, :name, :route, :greeting

      def initialize(departments:, name: 'receptionist', route: '/receptionist',
                     greeting: 'Thank you for calling. How can I help you today?', **_opts)
        @departments = validate_departments(departments)
        @greeting    = greeting
        @name  = name
        @route = route
      end

      def tools
        %w[transfer_to_department collect_caller_info]
      end

      def prompt_sections
        bullets = @departments.map { |d| "#{d['name']}: #{d['description'] || d['name']} (#{d['number']})" }
        [
          {
            'title' => 'Receptionist',
            'body' => @greeting,
            'bullets' => bullets
          }
        ]
      end

      def global_data
        {
          'departments' => @departments,
          'caller_info' => {}
        }
      end

      def handle_transfer(args, _raw_data)
        dept_name = args['department']
        dept = @departments.find { |d| d['name'] == dept_name }
        return _department_not_found_result unless dept

        result = Swaig::FunctionResult.new("Transferring you to #{dept_name} now.")
        result.connect(dept['number'])
        result
      end

      # Lifecycle hook: on_summary.
      #
      # No-op extension point: the base receptionist does not process the
      # transfer summary. Subclasses override this to handle the summary
      # (mirrors Python's ``def on_summary(...): pass``).
      #
      # @param _summary [Hash, String, nil] conversation summary
      # @param _raw_data [Hash, nil] full raw POST data
      # @return [void]
      def on_summary(_summary, _raw_data = nil)
        nil
      end

      private

      def validate_departments(departments)
        unless departments.is_a?(Array) && !departments.empty?
          raise ArgumentError, 'departments must be a non-empty Array'
        end

        departments.each_with_index.map do |dept, i|
          stringified = dept.transform_keys(&:to_s)
          raise ArgumentError, "Department #{i} missing 'name'" unless stringified['name']
          raise ArgumentError, "Department #{i} missing 'number'" unless stringified['number']

          stringified
        end
      end

      def _department_not_found_result
        names = @departments.map { |d| d['name'] }.join(', ')
        Swaig::FunctionResult.new(
          "I couldn't find that department. Available departments: #{names}"
        )
      end
    end
  end
end
