# frozen_string_literal: true

require 'minitest/autorun'
require 'ripper'

# The RELAY examples under relay/examples/ are excluded from
# tests/examples_file_mode_smoke_test.rb (they open a live WebSocket to the
# platform on load, so they are not file-mode/introspection targets). That left
# them with NO coverage at all, and a real defect survived there unnoticed:
#
#   relay/examples/relay_ivr_connect.rb called
#     call.play_and_collect(media: [...], collect: {...})
#   but Call#play_and_collect's signature is
#     def play_and_collect(media, collect, volume: nil, control_id: nil, ...)
#
# `media:`/`collect:` are NOT the parameter names -- they are POSITIONAL. The
# keywords fall into **kwargs, the two required positionals get nothing, and the
# call raises ArgumentError ("wrong number of arguments (given 0, expected 2)")
# on the very first thing the example does with a call. Anyone following it hit
# an immediate crash.
#
# This test statically checks the arity of every Relay Call method a
# relay/examples file calls: parse the example, find each `<recv>.<method>(...)`
# whose method exists on SignalWire::Relay::Call, and assert the call supplies at
# least as many POSITIONAL arguments as the method requires. Static parsing (not
# execution) is what makes this runnable without a live socket.
class RelayExamplesArityTest < Minitest::Test
  REPO = File.expand_path('..', __dir__)

  def setup
    require 'signalwire'
    require 'signalwire/relay/client'
  end

  def example_files
    Dir[File.join(REPO, 'relay', 'examples', '*.rb')]
  end

  # Required positional arity for a public instance method of Call, or nil when
  # the name is not one.
  def required_positionals(name)
    return nil unless SignalWire::Relay::Call.public_method_defined?(name)

    SignalWire::Relay::Call.instance_method(name).parameters
                           .count { |kind, _| kind == :req }
  end

  # Walk the sexp for `command_call` / `method_add_arg` nodes and yield
  # [method_name, positional_arg_count] for each call with an explicit receiver.
  def each_receiver_call(node, &block)
    return unless node.is_a?(Array)

    emit_call(node, &block)
    node.each { |child| each_receiver_call(child, &block) if child.is_a?(Array) }
  end

  def emit_call(node)
    return unless node[0] == :method_add_arg
    return unless node[1].is_a?(Array) && node[1][0] == :call

    name = extract_ident(node[1][3])
    return if name.nil?

    yield(name, positional_count(node[2]))
  end

  def extract_ident(node)
    return nil unless node.is_a?(Array) && %i[@ident @const].include?(node[0])

    node[1]
  end

  # Unwrap arg_paren -> args_add_block -> the argument list, or nil.
  def argument_list(arg_paren)
    return nil unless arg_paren.is_a?(Array) && arg_paren[0] == :arg_paren

    args = arg_paren[1]
    return nil unless args.is_a?(Array) && args[0] == :args_add_block
    return nil unless args[1].is_a?(Array)

    args[1]
  end

  # Count the POSITIONAL arguments. A bare hash / keyword list
  # (bare_assoc_hash) is NOT positional for a method whose params are declared
  # positional -- which is exactly the defect this test exists to catch.
  def positional_count(arg_paren)
    list = argument_list(arg_paren)
    return 0 if list.nil?

    list.count { |a| !(a.is_a?(Array) && a[0] == :bare_assoc_hash) }
  end

  def underfilled_calls(path)
    sexp = Ripper.sexp(File.read(path))

    refute_nil sexp, "#{File.basename(path)} did not parse"
    found = []
    each_receiver_call(sexp) do |name, given|
      required = required_positionals(name)
      next if required.nil? || given >= required

      found << "#{File.basename(path)}: #{name} needs #{required} positional " \
               "arg(s), example supplies #{given}"
    end
    found
  end

  def test_relay_examples_pass_enough_positional_args_to_call_methods
    violations = example_files.flat_map { |path| underfilled_calls(path) }

    assert_empty violations,
                 'relay/examples calls a Relay::Call method with too few positional ' \
                 "arguments (it would raise ArgumentError at runtime):\n  " +
                 violations.join("\n  ")
  end
end
