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

# Regression guard: a validator that could not be BUILT must REFUSE, never
# silently pass.
#
# init_full_validator used to fuse the load-failure and compile-failure rescues
# into a single `rescue LoadError, StandardError => @full_validator = nil`, and a
# nil full validator routed validate_verb to the required-props-only lightweight
# check. So ONE exception at construction disabled closed-key validation for
# EVERY verb, silently, reporting valid=true for configs nobody validated.
#
# These tests pin both directions:
#   - validator failed to build  -> refuse, naming the reason
#   - full validation simply N/A -> keep the documented lightweight behaviour
class SchemaUtilsFailClosedTest < Minitest::Test
  include SignalWire::Utils

  TMP = File.expand_path('../.tmp/schema_utils_fail_closed_test', __dir__)

  def teardown
    FileUtils.rm_rf(TMP)
  end

  # A schema whose $schema names a draft json_schemer cannot resolve, so
  # JSONSchemer.schema raises. Reaches the compile-failure path through the
  # PUBLIC constructor only — no monkeypatching, so this is a condition a real
  # environment can be in (e.g. a newer schema against an older gem).
  def uncompilable_schema_path
    raw = JSON.parse(File.read(File.expand_path('../lib/signalwire/swml/schema.json', __dir__)))
    raw['$schema'] = 'https://json-schema.org/draft/2021-07/schema'
    write_schema('uncompilable.json', raw)
  end

  # A partial/mocked schema: verbs register via $defs, but there is no
  # properties.sections, so full validation legitimately does not apply.
  def partial_schema_path
    write_schema('partial.json',
                 '$defs' => {
                   'SWMLMethod' => { 'anyOf' => [{ '$ref' => '#/$defs/PlayMethod' }] },
                   'PlayMethod' => {
                     'properties' => {
                       'play' => { 'required' => %w[url],
                                   'properties' => { 'url' => { 'type' => 'string' } } }
                     }
                   }
                 })
  end

  def write_schema(name, doc)
    FileUtils.mkdir_p(TMP)
    path = File.join(TMP, name)
    File.write(path, JSON.generate(doc))
    path
  end

  # Assert one verb's forbidden-key config is REFUSED, naming the reason.
  def assert_refused_not_validated(schema_utils, verb, base)
    valid, errors = schema_utils.validate_verb(verb, base.merge('zzz_forbidden_key' => 'nope'))

    refute valid, "#{verb}: a config that was never validated must not report valid=true"
    assert_equal 1, errors.size
    assert_match(/validation unavailable/i, errors[0])
    assert_match(/NOT validated; this is not a pass/, errors[0])
    assert_match(/failed to compile/, errors[0])
  end

  def test_compile_failure_refuses_forbidden_key_rather_than_accepting_it
    su = SchemaUtils.new(uncompilable_schema_path)

    refute_predicate su, :full_validation_available?

    # Every verb, not just one: the bug was gated behind nothing at all.
    { 'sleep' => { 'duration' => 1000 }, 'answer' => { 'max_duration' => 30 },
      'connect' => { 'to' => 'sip:x@y' } }.each do |verb, base|
      assert_refused_not_validated(su, verb, base)
    end
  end

  def test_compile_failure_refusal_also_covers_a_legitimate_config
    # The refusal is about "validation did not happen", so it is not
    # config-dependent: a config that WOULD have passed is refused too. That is
    # the point — the caller is told validation could not run instead of being
    # handed a pass it did not earn.
    su = SchemaUtils.new(uncompilable_schema_path)
    valid, errors = su.validate_verb('answer', 'max_duration' => 30)

    refute valid
    assert_match(/NOT validated; this is not a pass/, errors[0])
  end

  def test_partial_schema_still_uses_lightweight_check
    # The OTHER direction: no properties.sections is NOT a build failure, so the
    # documented lightweight required-props behaviour (Python's
    # _validate_verb_lightweight condition) must survive and must NOT become a
    # refusal.
    su = SchemaUtils.new(partial_schema_path)

    refute_predicate su, :full_validation_available?
    assert_equal [false, ["Missing required property 'url' for verb 'play'"]],
                 su.validate_verb('play', {})
    # Required present => lightweight passes. Unlike the compile-failure case
    # this is a real (if shallow) validation result, not a swallowed exception.
    assert_equal [true, []], su.validate_verb('play', 'url' => 'u')
  end

  def test_explicitly_disabled_validation_is_still_a_clean_skip
    # Turning validation OFF deliberately is not the same as failing to build a
    # validator: it must keep returning valid=true, unchanged by this fix.
    su = SchemaUtils.new(nil, false)

    assert_equal [true, []], su.validate_verb('answer', 'zzz_forbidden_key' => 'nope')
  end
end
