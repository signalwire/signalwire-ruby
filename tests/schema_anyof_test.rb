# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'minitest/autorun'
require 'fileutils'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/utils/schema_utils'

# Regression guard: a UNION-shaped verb schema must not disengage the shallow
# closed-key check.
#
# The verb's config node used to be resolved by following at most one $ref and
# then read for `properties` + a closed-key flag. A union node — `{"anyOf":
# [...]}` / `{"oneOf": [...]}` — carries NEITHER of its own; the BRANCHES carry
# both. So schema_closed? answered false, the unknown-key arm never ran, and
# validate_verb_top_level_keys reported valid for any key whatsoever. It did not
# report a problem; it stopped checking and reported success, which is strictly
# worse than failing.
#
# In the bundled schema.json every verb body is union-shaped (object | string |
# number | array forms — the engine's check_method_type_and_unknown_params).
#
# The #223 contract (porting-sdk docs/legacy-census/DISC-g-d21.md §1.4/§4):
# EXACTLY ONE closed object arm gives the verb's known keys; zero or several
# closed object arms DISENGAGE the shallow check (the deep validator owns the
# shape). Measured on this artifact: every union verb has at most one closed
# object arm, so 47 of 53 verbs engage and 6 stay disengaged.
class SchemaAnyOfTest < Minitest::Test
  include SignalWire::Utils

  # verb => [a key the union must expose, expected key-set size, a legitimate
  #          config the check must ACCEPT]
  UNION_SHAPED_VERBS = {
    'sleep' => ['duration', 1, { 'duration' => 5000 }],
    'play' => ['urls', 9, { 'url' => 'https://example.com/a.mp3' }],
    'send_sms' => ['media', 7,
                   { 'to_number' => '+15551230000', 'from_number' => '+15554560000',
                     'body' => 'hello' }],
    'connect' => ['serial_parallel', 31, { 'to' => 'sip:alice@example.com' }]
  }.freeze

  # Shapes with genuinely NO enumerable closed key-set. Pinned so the fix is not
  # read as "always enforce something":
  #   set    — OPEN object (a free-form variable bag by design)
  #   unset / return / transcribe_stop — union with no closed object branch
  #   cond   — array, eval — open object
  NON_ENUMERABLE_VERBS = %w[cond eval return set transcribe_stop unset].freeze

  def setup
    @su = SchemaUtils.new
  end

  def test_union_shaped_verbs_resolve_a_key_set
    UNION_SHAPED_VERBS.each do |verb, (want_key, want_count, _ok)|
      known = @su.__send__(:verb_top_level_property_names, verb)

      refute_nil known,
                 "#{verb}: closed-key check DISENGAGED on a union-shaped config; " \
                 'the union branches were not resolved'
      assert_includes known, want_key,
                      "#{verb}: resolved key set is missing branch key #{want_key.inspect}"
      assert_equal want_count, known.size,
                   "#{verb}: expected #{want_count} keys, got #{known.sort.inspect}"
    end
  end

  def test_union_shaped_verbs_reject_unknown_keys
    UNION_SHAPED_VERBS.each do |verb, (_want_key, _count, ok_config)|
      config = ok_config.merge('zzz_not_a_real_key' => 'nope')
      valid, errors = @su.__send__(:validate_verb_top_level_keys, verb, config)

      refute valid,
             "#{verb}: a schema-forbidden top-level key was ACCEPTED — the " \
             'closed-key check disengaged on the union'
      assert_includes errors.join(' '), 'zzz_not_a_real_key',
                      "#{verb}: rejection must name the offending key, got #{errors.inspect}"
    end
  end

  def test_union_shaped_verbs_accept_legitimate_configs
    # The other direction: unioning must not over-reject. An INTERSECTION of the
    # branches would fail here, since no key is common to every branch.
    UNION_SHAPED_VERBS.each do |verb, (_want_key, _count, ok_config)|
      valid, errors = @su.__send__(:validate_verb_top_level_keys, verb, ok_config)

      assert valid, "#{verb}: legitimate config rejected: #{errors.inspect}"
    end
  end

  # connect is a oneOf of four $refs whose discriminating keys are mutually
  # exclusive. All four must survive the unioned key-set.
  CONNECT_DISCRIMINATORS = {
    'to' => 'sip:alice@example.com',
    'serial' => [['sip:a@example.com']],
    'parallel' => [{ 'to' => 'sip:a@example.com' }],
    'serial_parallel' => [[{ 'to' => 'sip:a@example.com' }]]
  }.freeze

  def test_connect_branch_discriminators_all_accepted
    CONNECT_DISCRIMINATORS.each do |key, value|
      valid, errors = @su.__send__(:validate_verb_top_level_keys, 'connect', key => value)

      assert valid,
             "connect: branch discriminator #{key.inspect} rejected — an " \
             "intersection was computed instead of a union: #{errors.inspect}"
    end
  end

  def test_resolver_stays_disengaged_for_non_enumerable_shapes
    NON_ENUMERABLE_VERBS.each do |verb|
      assert_nil @su.__send__(:verb_top_level_property_names, verb),
                 "#{verb}: has no enumerable closed key-set and must stay disengaged"
    end
  end

  def test_disengaged_check_is_a_no_op_not_a_rejection
    NON_ENUMERABLE_VERBS.each do |verb|
      valid, errors = @su.__send__(:validate_verb_top_level_keys, verb, 'anything' => 1)

      assert valid, "#{verb}: disengaged check must pass, got #{errors.inspect}"
    end
  end

  def test_ai_ref_resolves
    # The pre-existing $ref case (ai -> #/$defs/AIObject) must keep working: the
    # union arm is added alongside it, not in place of it.
    known = @su.__send__(:verb_top_level_property_names, 'ai')

    refute_nil known, 'ai: $ref resolution regressed'
    %w[prompt SWAIG params post_prompt].each do |want|
      assert_includes known, want, "ai: resolved key set is missing #{want.inspect}"
    end
  end

  def test_engaged_count_and_membership
    # The whole-fleet number, so a resolver that engaged the WRONG verbs cannot
    # pass (the bundled schema at porting-sdk bd22268: 53 verbs, 47 engaged).
    all = @su.get_all_verb_names
    engaged = all.reject { |v| @su.__send__(:verb_top_level_property_names, v).nil? }
    disengaged = all - engaged

    assert_equal 47, engaged.size,
                 "expected 47 engaged verbs, got #{engaged.size}: #{engaged.sort.inspect}"
    UNION_SHAPED_VERBS.each_key do |verb|
      assert_includes engaged, verb, "#{verb} must be engaged after the fix"
    end
    assert_equal NON_ENUMERABLE_VERBS, disengaged.sort,
                 "the disengaged set must be exactly #{NON_ENUMERABLE_VERBS.inspect}"
  end
end

# Resolver-mechanics tests over SYNTHETIC schemas: recursion depth, nesting, and
# mixed branches. Split from SchemaAnyOfTest (which tests the SHIPPED schema) so
# neither class carries a mixed concern.
class SchemaAnyOfResolverTest < Minitest::Test
  include SignalWire::Utils

  TMP = File.expand_path('../.tmp/schema_anyof_resolver_test', __dir__)

  def teardown
    FileUtils.rm_rf(TMP)
  end

  def test_self_referential_ref_terminates
    # The depth bound: a $ref pointing at itself must return nil, not spin.
    su = schema_utils_with_defs('SelfRef' => { '$ref' => '#/$defs/SelfRef' })

    assert_nil su.__send__(:closed_key_set, { '$ref' => '#/$defs/SelfRef' }, 0)
  end

  def test_self_referential_union_terminates
    su = schema_utils_with_defs(
      'SelfUnion' => { 'anyOf' => [{ '$ref' => '#/$defs/SelfUnion' }] }
    )

    assert_nil su.__send__(:closed_key_set, { '$ref' => '#/$defs/SelfUnion' }, 0)
  end

  def test_nested_union_under_a_ref_resolves
    # verb -> $ref -> anyOf -> $ref -> closed object: the recursion must follow
    # all the way down, not just one level.
    su = schema_utils_with_defs(
      'Outer' => { 'anyOf' => [{ '$ref' => '#/$defs/Inner' }] },
      'Inner' => { 'type' => 'object', 'unevaluatedProperties' => { 'not' => {} },
                   'properties' => { 'deep_key' => { 'type' => 'string' } } }
    )

    assert_equal ['deep_key'], su.__send__(:closed_key_set, { '$ref' => '#/$defs/Outer' }, 0)
  end

  def test_union_with_one_open_and_one_closed_branch_uses_the_closed_branch
    # A branch with no enumerable key-set contributes nothing; it does not
    # poison the union into nil.
    su = schema_utils_with_defs(
      'Mixed' => { 'anyOf' => [{ 'type' => 'integer' },
                               { 'type' => 'object', 'additionalProperties' => false,
                                 'properties' => { 'a' => {}, 'b' => {} } }] }
    )

    assert_equal %w[a b], su.__send__(:closed_key_set, { '$ref' => '#/$defs/Mixed' }, 0).sort
  end

  def test_union_with_two_closed_object_arms_disengages
    # The #223 contract: exactly-one-closed-arm, else disengage. Unioning two
    # closed arms would accept {a, c} — keys no single arm admits.
    arm_ab = { 'type' => 'object', 'additionalProperties' => false, 'properties' => { 'a' => {}, 'b' => {} } }
    arm_c = { 'type' => 'object', 'additionalProperties' => false, 'properties' => { 'c' => {} } }
    su = schema_utils_with_defs('TwoArms' => { 'anyOf' => [arm_ab, arm_c] })

    assert_nil su.__send__(:closed_key_set, { '$ref' => '#/$defs/TwoArms' }, 0)
  end

  private

  # A SchemaUtils over a synthetic schema containing only the given $defs.
  # Built through the PUBLIC constructor; no monkeypatching.
  def schema_utils_with_defs(defs)
    FileUtils.mkdir_p(TMP)
    path = File.join(TMP, 'synthetic.json')
    File.write(path, JSON.generate('$defs' => defs))
    SchemaUtils.new(path)
  end
end
