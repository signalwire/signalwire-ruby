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
require_relative '../lib/signalwire/swml/service'

# Parity tests for SchemaUtils — mirrors Python's
# tests/unit/utils/test_schema_utils.py and the TS / Perl reference
# implementations.
#
# Each public method is exercised; assertions check shape (not just
# nullness) so the no-cheat-tests audit accepts them.
class SchemaUtilsParityTest < Minitest::Test
  include SignalWire::Utils

  def test_default_load
    su = SchemaUtils.new
    names = su.get_all_verb_names

    refute_empty names
    assert_includes names, 'ai'
    assert_includes names, 'answer'
  end

  def test_disabled_validation
    su = SchemaUtils.new(nil, false)

    refute_predicate su, :full_validation_available?
    valid, errors = su.validate_verb('ai', {})

    assert valid, 'validation skipped should return valid=true'
    assert_empty errors
  end

  def test_env_skip_disables_validation
    ENV['SWML_SKIP_SCHEMA_VALIDATION'] = '1'
    begin
      su = SchemaUtils.new(nil, true)

      refute_predicate su, :full_validation_available?
      valid, errors = su.validate_verb('ai', {})

      assert valid
      assert_empty errors
    ensure
      ENV.delete('SWML_SKIP_SCHEMA_VALIDATION')
    end
  end

  def test_validate_verb_unknown
    su = SchemaUtils.new
    valid, errors = su.validate_verb('not_a_real_verb', {})

    refute valid
    assert_equal 1, errors.size
    assert_match(/Unknown verb/, errors[0])
  end

  def test_get_verb_properties
    su = SchemaUtils.new
    props = su.get_verb_properties('answer')

    refute_empty props, 'expected non-empty properties for answer'
    assert_equal 'object', props['type']
  end

  def test_get_verb_properties_nonexistent
    su = SchemaUtils.new

    assert_equal({}, su.get_verb_properties('not_a_verb'))
  end

  def test_get_verb_required_properties_nonexistent
    su = SchemaUtils.new

    assert_equal [], su.get_verb_required_properties('not_a_verb')
  end

  def test_validate_document_valid_doc
    # With schema validation ON (the default) the json_schemer full validator
    # is wired, so a well-formed document validates true — mirroring Python's
    # jsonschema-rs-backed validate_document.
    su = SchemaUtils.new
    valid, errors = su.validate_document(
      'version' => '1.0.0',
      'sections' => { 'main' => [{ 'answer' => { 'max_duration' => 5 } }] }
    )

    assert valid, "expected valid document, got errors: #{errors.inspect}"
    assert_empty errors
  end

  def test_validate_document_no_full_validator_when_disabled
    # When validation is disabled no full validator is initialized, so
    # validate_document reports the same [false, ['...not initialized']]
    # contract as Python's uninitialized path.
    su = SchemaUtils.new(nil, false)
    valid, errors = su.validate_document(
      'version' => '1.0.0',
      'sections' => { 'main' => [] }
    )

    refute valid
    assert_equal 1, errors.size
    assert_match(/validator not initialized/, errors[0])
  end

  def test_generate_method_signature
    su = SchemaUtils.new
    sig = su.generate_method_signature('answer')

    assert sig.start_with?('def answer('), "got: #{sig}"
    assert_match(/\*\*kwargs/, sig)
  end

  def test_generate_method_body
    su = SchemaUtils.new
    body = su.generate_method_body('answer')

    assert_match(/self\.add_verb\('answer'/, body)
    assert_match(/config = \{\}/, body)
  end

  def test_service_schema_utils_accessor
    svc = SignalWire::SWML::Service.new(name: 'test')
    su = svc.schema_utils

    assert_kind_of SchemaUtils, su
    refute_empty su.get_all_verb_names
  end

  def test_healthy_validator_still_rejects_and_accepts_correctly
    su = SchemaUtils.new

    assert_predicate su, :full_validation_available?
    valid, = su.validate_verb('answer', 'max_duration' => 30, 'zzz_forbidden_key' => 'nope')

    refute valid, 'healthy validator must still reject a forbidden key'
    assert_equal [true, []], su.validate_verb('answer', 'max_duration' => 30)
  end

  def test_schema_validation_error
    err = SchemaValidationError.new('ai', ['missing prompt', 'bad type'])

    assert_equal 'ai', err.verb_name
    assert_equal 2, err.errors.size
    assert_match(/ai/, err.message)
    assert_match(/missing prompt/, err.message)
  end
end
