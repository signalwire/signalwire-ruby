# frozen_string_literal: true

# Single-source-of-truth tests for SignalWire::Skills::SkillName.
#
# SkillName names the built-in skill registry — the same closed set the
# SkillRegistry registers and that AgentBase#add_skill validates against.
# We prove, with REAL behaviour (no mocks):
#
#   (a) each constant's value IS the snake_case wire skill name;
#   (b) the named constant and the bare string load the SAME skill — i.e.
#       SkillRegistry.get_factory returns the identical factory and the
#       resulting skill reports the same #name;
#   (c) SkillName::ALL is EXACTLY the registry's validated set — every
#       constant is registered? (so add_skill accepts it) and a name not in
#       the set is rejected by add_skill (single source of truth: the
#       registry derives builtin_skill_names from SkillName::ALL, so the
#       named set and the validated set cannot drift).

require 'minitest/autorun'
require_relative '../../lib/signalwire'

SignalWire::Skills::SkillRegistry.register_builtins!

class SkillNameTest < Minitest::Test
  SkillName = SignalWire::Skills::SkillName
  Registry  = SignalWire::Skills::SkillRegistry

  # The 18 built-ins, written out independently of the constant module so
  # this is a genuine cross-check rather than a tautology.
  EXPECTED = %w[
    api_ninjas_trivia claude_skills custom_skills datasphere
    datasphere_serverless datetime google_maps info_gatherer joke math
    mcp_gateway native_vector_search play_background_file spider
    swml_transfer weather_api web_search wikipedia_search
  ].freeze

  # ------------------------------------------------------------------
  # (a) each constant value IS the wire skill name
  # ------------------------------------------------------------------
  def test_constants_are_wire_names
    assert_equal 'datetime',          SkillName::DATETIME
    assert_equal 'weather_api',       SkillName::WEATHER_API
    assert_equal 'api_ninjas_trivia', SkillName::API_NINJAS_TRIVIA
    assert_equal 'native_vector_search', SkillName::NATIVE_VECTOR_SEARCH
    assert_equal EXPECTED.sort, SkillName::ALL.sort
    assert SkillName::ALL.frozen?
  end

  # ------------------------------------------------------------------
  # (b) named constant and bare string load the SAME skill
  # ------------------------------------------------------------------
  def test_constant_and_string_resolve_to_same_factory
    pairs = {
      SkillName::DATETIME    => 'datetime',
      SkillName::MATH        => 'math',
      SkillName::WEATHER_API => 'weather_api'
    }
    pairs.each do |const_val, literal|
      via_const  = Registry.get_factory(const_val)
      via_string = Registry.get_factory(literal)
      refute_nil via_const, "no factory for constant #{const_val.inspect}"
      assert_same via_string, via_const,
                  "SkillName constant #{literal.inspect} and string resolve to different factories"
      # The skill the factory builds reports the same name either way.
      assert_equal literal, via_const.call({}).name
    end
  end

  # ------------------------------------------------------------------
  # (c) SkillName::ALL is EXACTLY the registry's validated built-in set
  # ------------------------------------------------------------------
  def test_all_equals_registry_builtin_set
    # builtin_skill_names is the registry's notion of the built-in set;
    # add_skill validates against the registered factories derived from it.
    registry_builtins = Registry.send(:builtin_skill_names)
    assert_equal SkillName::ALL.sort, registry_builtins.sort,
                 'SkillName::ALL drifted from SkillRegistry.builtin_skill_names'
  end

  def test_every_constant_is_registered
    SkillName::ALL.each do |name|
      assert Registry.registered?(name),
             "built-in #{name.inspect} is in SkillName::ALL but not registered"
    end
  end

  # Drive the REAL add_skill validation gate: every constant is accepted
  # (no "Unknown skill" raise at the validation step) and an out-of-set
  # name is rejected. We stub nothing — add_skill calls the live registry.
  def test_add_skill_accepts_every_constant_and_rejects_out_of_set
    SkillName::ALL.each do |name|
      agent = SignalWire::AgentBase.new(suppress_logs: true)
      # add_skill raises ArgumentError "Unknown skill" ONLY when the name
      # is not in the validated set; a successful load proves acceptance.
      # Some skills surface their own load-time errors after the gate — we
      # only care that the validation gate let the name through, so we
      # treat the "Unknown skill" message as the single rejection signal.
      begin
        agent.add_skill(name)
      rescue ArgumentError => e
        refute_match(/Unknown skill/, e.message,
                     "#{name.inspect} should pass the add_skill validation gate")
      rescue StandardError
        # A skill's own constructor/load error is fine — the name was
        # accepted by the validation gate, which is what we assert here.
      end
    end

    # An out-of-set name is rejected by the same gate.
    refute_includes SkillName::ALL, 'datetiem' # the classic typo
    agent = SignalWire::AgentBase.new(suppress_logs: true)
    err = assert_raises(ArgumentError) { agent.add_skill('datetiem') }
    assert_match(/Unknown skill/, err.message)
  end

  def test_builtin_predicate
    assert SkillName.builtin?('datetime')
    assert SkillName.builtin?(SkillName::WEB_SEARCH)
    refute SkillName.builtin?('datetiem')      # typo
    refute SkillName.builtin?('my_custom_skill') # open set: custom names ok
  end
end
