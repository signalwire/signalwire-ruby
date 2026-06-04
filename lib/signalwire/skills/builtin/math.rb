# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class MathSkill < SkillBase
        def name;        'math'; end
        def description; 'Perform basic mathematical calculations'; end

        # Python parity: ``MathSkill.setup`` -> ``return True``. The math skill
        # has no external packages or environment to validate; it is always
        # ready once constructed.
        def setup
          true
        end

        # Python parity: ``MathSkill.get_parameter_schema`` returns only the
        # base-class schema (the math skill adds no custom parameters).
        def get_parameter_schema
          super
        end

        def register_tools
          [
            {
              name: 'calculate',
              description: 'Perform a mathematical calculation with basic operations (+, -, *, /, %, **)',
              parameters: {
                'expression' => { 'type' => 'string', 'description' => "Mathematical expression to evaluate (e.g., '2 + 3 * 4', '(10 + 5) / 3')" }
              },
              handler: method(:handle_calculate)
            }
          ]
        end

        def get_prompt_sections
          [
            {
              'title' => 'Mathematical Calculations',
              'body' => 'You can perform mathematical calculations for users.',
              'bullets' => [
                'Use the calculate tool for any math expressions',
                'Supports basic operations: +, -, *, /, %, ** (power)',
                'Can handle parentheses for complex expressions'
              ]
            }
          ]
        end

        private

        # Safe expression evaluator. Only allows numbers and basic operators.
        # Never calls eval on untrusted input.
        def handle_calculate(args, _raw_data)
          expression = (args['expression'] || '').strip
          if expression.empty?
            return Swaig::FunctionResult.new('Please provide a mathematical expression to calculate.')
          end

          result = safe_eval(expression)
          Swaig::FunctionResult.new("#{expression} = #{result}")
        rescue ZeroDivisionError
          Swaig::FunctionResult.new('Error: Division by zero is not allowed.')
        rescue => _e
          Swaig::FunctionResult.new('Error: Invalid expression. Only numbers and basic math operators (+, -, *, /, %, **, parentheses) are allowed.')
        end

        # Tokenize, parse, and evaluate a mathematical expression safely.
        # This uses a simple recursive-descent parser — no eval/exec.
        def safe_eval(expr)
          tokens = tokenize(expr)
          pos = [0]
          result = parse_expr(tokens, pos)
          raise 'Unexpected tokens after expression' unless pos[0] >= tokens.length
          result
        end

        def tokenize(expr)
          tokens = []
          i = 0
          while i < expr.length
            ch = expr[i]
            if ch =~ /\s/
              i += 1
            elsif ch =~ /[\d.]/ || (ch == '-' && (tokens.empty? || %w[( + - * / % **].include?(tokens.last)))
              num_str = +''
              if ch == '-'
                num_str << ch
                i += 1
              end
              while i < expr.length && expr[i] =~ /[\d.]/
                num_str << expr[i]
                i += 1
              end
              tokens << num_str
            elsif ch == '*' && i + 1 < expr.length && expr[i + 1] == '*'
              tokens << '**'
              i += 2
            elsif '+-*/%()'.include?(ch)
              tokens << ch
              i += 1
            else
              raise "Invalid character: #{ch}"
            end
          end
          tokens
        end

        def parse_expr(tokens, pos)
          left = parse_term(tokens, pos)
          while pos[0] < tokens.length && %w[+ -].include?(tokens[pos[0]])
            op = tokens[pos[0]]
            pos[0] += 1
            right = parse_term(tokens, pos)
            left = op == '+' ? left + right : left - right
          end
          left
        end

        def parse_term(tokens, pos)
          left = parse_power(tokens, pos)
          while pos[0] < tokens.length && %w[* / %].include?(tokens[pos[0]])
            op = tokens[pos[0]]
            pos[0] += 1
            right = parse_power(tokens, pos)
            case op
            when '*' then left *= right
            when '/'
              raise ZeroDivisionError, 'division by zero' if right == 0
              left = left.to_f / right
            when '%'
              raise ZeroDivisionError, 'division by zero' if right == 0
              left %= right
            end
          end
          left
        end

        def parse_power(tokens, pos)
          base = parse_unary(tokens, pos)
          if pos[0] < tokens.length && tokens[pos[0]] == '**'
            pos[0] += 1
            exp = parse_power(tokens, pos) # right-associative
            raise 'Exponent too large (maximum is 1000)' if exp.is_a?(Numeric) && exp > 1000
            base **= exp
          end
          base
        end

        def parse_unary(tokens, pos)
          if pos[0] < tokens.length && tokens[pos[0]] == '-'
            pos[0] += 1
            -parse_atom(tokens, pos)
          elsif pos[0] < tokens.length && tokens[pos[0]] == '+'
            pos[0] += 1
            parse_atom(tokens, pos)
          else
            parse_atom(tokens, pos)
          end
        end

        def parse_atom(tokens, pos)
          raise 'Unexpected end of expression' if pos[0] >= tokens.length

          tok = tokens[pos[0]]
          if tok == '('
            pos[0] += 1
            val = parse_expr(tokens, pos)
            raise 'Missing closing parenthesis' unless pos[0] < tokens.length && tokens[pos[0]] == ')'
            pos[0] += 1
            val
          elsif tok =~ /\A-?[\d.]+\z/
            pos[0] += 1
            tok.include?('.') ? tok.to_f : tok.to_i
          else
            raise "Unexpected token: #{tok}"
          end
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('math') do |params|
  SignalWire::Skills::Builtin::MathSkill.new(params)
end
