# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Evaluate arithmetic expressions for the model, WITHOUT ever calling `eval`.
      # The expression is tokenized against a character whitelist and evaluated by a
      # hand-written recursive-descent parser, so a hostile string reaches no Ruby
      # interpreter. Supports `+ - * / % **` and parentheses.
      class MathSkill < SkillBase
        EXPRESSION_DESCRIPTION = "Mathematical expression to evaluate (e.g., '2 + 3 * 4', '(10 + 5) / 3')"
        INVALID_EXPRESSION_MESSAGE =
          'Error: Invalid expression. Only numbers and basic math operators ' \
          '(+, -, *, /, %, **, parentheses) are allowed.'

        # The name this skill is added under (`agent.add_skill('math')`).
        #
        # @return [String]
        def name = 'math'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Perform basic mathematical calculations'

        # The math skill has no external packages or environment to
        # validate; it is always ready once constructed.
        def setup
          true
        end

        # Returns only the base-class schema (the math skill adds no custom
        # parameters). The explicit super-only override is defined here
        # directly so it appears on public_instance_methods(false); the
        # cop is disabled on the def line for that reason.
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

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [{
            name: 'calculate',
            description: 'Perform a mathematical calculation with basic operations (+, -, *, /, %, **)',
            parameters: { 'expression' => { 'type' => 'string', 'description' => EXPRESSION_DESCRIPTION } },
            handler: method(:handle_calculate)
          }]
        end

        # Returns [] — this skill ships no example hints.
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

        # @param expr [String] the arithmetic expression to tokenize
        def initialize(expr)
          @expr = expr
          @tokens = []
        end

        # Tokenize the expression into number and operator tokens.
        #
        # @return [Array<String>] the token list
        # @raise [RuntimeError] on a character outside digits, `.`, whitespace and the
        #   supported operators — that whitelist is what makes evaluating
        #   model-supplied input safe
        def tokens
          idx = 0
          idx = step(idx) while idx < @expr.length
          @tokens
        end

        private

        # @api private — consume one token starting at +idx+ and return the next index.
        # Whitespace is skipped; `**` is matched before `*` so exponentiation is not
        # read as two multiplications.
        #
        # @raise [RuntimeError] on an unsupported character
        def step(idx)
          char = @expr[idx]
          if /\s/.match?(char) then idx + 1
          elsif number_start?(char) then read_number(idx)
          elsif char == '*' && @expr[idx + 1] == '*' then push_token('**', idx + 2)
          elsif '+-*/%()'.include?(char) then push_token(char, idx + 1)
          else raise "Invalid character: #{char}"
          end
        end

        # @api private — append a token and return the index to continue from.
        def push_token(token, next_idx)
          @tokens << token
          next_idx
        end

        # @api private — whether a character begins a number. A `-` counts only in
        # UNARY position (at the start, or right after an operator or an open paren),
        # so `3 - 2` is a subtraction while `-3` is a negative literal.
        def number_start?(char)
          char =~ /[\d.]/ || (char == '-' && (@tokens.empty? || UNARY_PRECEDERS.include?(@tokens.last)))
        end

        # @api private — read a numeric literal (optionally sign-prefixed) starting at
        # +idx+ and return the index after it.
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

        # @param expr [String] the arithmetic expression to evaluate
        def initialize(expr)
          @tokens = MathTokenizer.new(expr).tokens
          @pos = 0
        end

        # Parse and evaluate the tokenized expression.
        #
        # @return [Numeric] the computed value
        # @raise [RuntimeError] on a malformed expression, or when tokens remain after
        #   a complete expression was parsed
        # @raise [ZeroDivisionError] on division or modulo by zero
        def evaluate
          result = parse_expr
          raise 'Unexpected tokens after expression' unless @pos >= @tokens.length

          result
        end

        private

        # @api private — the lowest precedence level: terms joined by `+` / `-`,
        # evaluated left to right.
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

        # @api private — powers joined by `*` / `/` / `%`, evaluated left to right
        # (binding tighter than `+` / `-`).
        def parse_term
          left = parse_power
          while @pos < @tokens.length && MUL_OPS.include?(@tokens[@pos])
            oper = @tokens[@pos]
            @pos += 1
            left = apply_mul_op(left, oper, parse_power)
          end
          left
        end

        # @api private — apply one multiplicative operator. `/` produces a Float, so
        # integer division never silently truncates.
        #
        # @raise [ZeroDivisionError] when +right+ is zero for `/` or `%`
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

        # @api private — exponentiation, which binds tighter than `*` and is RIGHT
        # associative (`2 ** 3 ** 2` is `2 ** 9`). The exponent is capped at 1000 so a
        # model-supplied expression cannot hang the process computing a huge power.
        #
        # @raise [RuntimeError] when the exponent exceeds 1000
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

        # @api private — a leading unary `-` or `+` applied to an atom.
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

        # @api private — the innermost level: a parenthesized expression or a numeric
        # literal (Integer unless it contains a `.`).
        #
        # @raise [RuntimeError] on an unexpected token or a truncated expression
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

        # @api private — a parenthesized sub-expression, consuming both parens.
        #
        # @raise [RuntimeError] when the closing parenthesis is missing
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
