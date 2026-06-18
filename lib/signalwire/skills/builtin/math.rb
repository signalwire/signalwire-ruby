# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class MathSkill < SkillBase
        EXPRESSION_DESCRIPTION = "Mathematical expression to evaluate (e.g., '2 + 3 * 4', '(10 + 5) / 3')"
        INVALID_EXPRESSION_MESSAGE =
          'Error: Invalid expression. Only numbers and basic math operators ' \
          '(+, -, *, /, %, **, parentheses) are allowed.'

        def name = 'math'
        def description = 'Perform basic mathematical calculations'

        # Python parity: ``MathSkill.setup`` -> ``return True``. The math skill
        # has no external packages or environment to validate; it is always
        # ready once constructed.
        def setup
          true
        end

        # Python parity: ``MathSkill.get_parameter_schema`` returns only the
        # base-class schema (the math skill adds no custom parameters). The
        # explicit super-only override is REQUIRED — the cross-port audit checks
        # public_instance_methods(false) includes it, so it must be defined here
        # directly, not merely inherited. rubocop:disable for that reason.
        def get_parameter_schema # rubocop:disable Lint/UselessMethodDefinition
          super
        end

        PROMPT_SECTIONS = [
          {
            'title' => 'Mathematical Calculations',
            'body' => 'You can perform mathematical calculations for users.',
            'bullets' => [
              'Use the calculate tool for any math expressions',
              'Supports basic operations: +, -, *, /, %, ** (power)',
              'Can handle parentheses for complex expressions'
            ]
          }
        ].freeze

        def register_tools
          [{
            name: 'calculate',
            description: 'Perform a mathematical calculation with basic operations (+, -, *, /, %, **)',
            parameters: { 'expression' => { 'type' => 'string', 'description' => EXPRESSION_DESCRIPTION } },
            handler: method(:handle_calculate)
          }]
        end

        def get_prompt_sections
          PROMPT_SECTIONS.map(&:dup)
        end

        private

        # Safe expression evaluator. Only allows numbers and basic operators.
        # Never calls eval on untrusted input.
        def handle_calculate(args, _raw_data)
          expression = (args['expression'] || '').strip
          if expression.empty?
            return Swaig::FunctionResult.new('Please provide a mathematical expression to calculate.')
          end

          result = SafeEvaluator.new(expression).evaluate
          Swaig::FunctionResult.new("#{expression} = #{result}")
        rescue ZeroDivisionError
          Swaig::FunctionResult.new('Error: Division by zero is not allowed.')
        rescue StandardError => _e
          Swaig::FunctionResult.new(INVALID_EXPRESSION_MESSAGE)
        end
      end

      # Tokenizes an arithmetic expression into number/operator tokens.
      class MathTokenizer
        UNARY_PRECEDERS = %w[( + - * / % **].freeze

        def initialize(expr)
          @expr = expr
          @tokens = []
        end

        def tokens
          idx = 0
          idx = step(idx) while idx < @expr.length
          @tokens
        end

        private

        def step(idx)
          char = @expr[idx]
          if /\s/.match?(char) then idx + 1
          elsif number_start?(char) then read_number(idx)
          elsif char == '*' && @expr[idx + 1] == '*' then push_token('**', idx + 2)
          elsif '+-*/%()'.include?(char) then push_token(char, idx + 1)
          else raise "Invalid character: #{char}"
          end
        end

        def push_token(token, next_idx)
          @tokens << token
          next_idx
        end

        def number_start?(char)
          char =~ /[\d.]/ || (char == '-' && (@tokens.empty? || UNARY_PRECEDERS.include?(@tokens.last)))
        end

        def read_number(idx)
          num_str = +''
          if @expr[idx] == '-'
            num_str << '-'
            idx += 1
          end
          while idx < @expr.length && @expr[idx] =~ /[\d.]/
            num_str << @expr[idx]
            idx += 1
          end
          push_token(num_str, idx)
        end
      end

      # Recursive-descent evaluator for arithmetic expressions. Tokenizes,
      # parses, and evaluates without ever calling eval/exec on input.
      class SafeEvaluator
        ADD_OPS = %w[+ -].freeze
        MUL_OPS = %w[* / %].freeze

        def initialize(expr)
          @tokens = MathTokenizer.new(expr).tokens
          @pos = 0
        end

        def evaluate
          result = parse_expr
          raise 'Unexpected tokens after expression' unless @pos >= @tokens.length

          result
        end

        private

        def parse_expr
          left = parse_term
          while @pos < @tokens.length && ADD_OPS.include?(@tokens[@pos])
            oper = @tokens[@pos]
            @pos += 1
            right = parse_term
            left = oper == '+' ? left + right : left - right
          end
          left
        end

        def parse_term
          left = parse_power
          while @pos < @tokens.length && MUL_OPS.include?(@tokens[@pos])
            oper = @tokens[@pos]
            @pos += 1
            left = apply_mul_op(left, oper, parse_power)
          end
          left
        end

        def apply_mul_op(left, oper, right)
          case oper
          when '*' then left * right
          when '/'
            raise ZeroDivisionError, 'division by zero' if right.zero?

            left.to_f / right
          when '%'
            raise ZeroDivisionError, 'division by zero' if right.zero?

            left % right
          end
        end

        def parse_power
          base = parse_unary
          if @pos < @tokens.length && @tokens[@pos] == '**'
            @pos += 1
            exp = parse_power # right-associative
            raise 'Exponent too large (maximum is 1000)' if exp.is_a?(Numeric) && exp > 1000

            base **= exp
          end
          base
        end

        def parse_unary
          if @pos < @tokens.length && @tokens[@pos] == '-'
            @pos += 1
            -parse_atom
          elsif @pos < @tokens.length && @tokens[@pos] == '+'
            @pos += 1
            parse_atom
          else
            parse_atom
          end
        end

        def parse_atom
          raise 'Unexpected end of expression' if @pos >= @tokens.length

          tok = @tokens[@pos]
          if tok == '('
            parse_parenthesized
          elsif /\A-?[\d.]+\z/.match?(tok)
            @pos += 1
            tok.include?('.') ? tok.to_f : tok.to_i
          else
            raise "Unexpected token: #{tok}"
          end
        end

        def parse_parenthesized
          @pos += 1
          val = parse_expr
          raise 'Missing closing parenthesis' unless @pos < @tokens.length && @tokens[@pos] == ')'

          @pos += 1
          val
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('math') do |params|
  SignalWire::Skills::Builtin::MathSkill.new(params)
end
