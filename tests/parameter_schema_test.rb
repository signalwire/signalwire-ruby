# frozen_string_literal: true

# Tests for SignalWire::Swaig::ParameterSchema — the Tier-2 idiom flagship:
# a typed block-DSL builder for SWAIG tool parameters
# (porting-sdk/IDIOM_PASS_JOURNAL.md §4 "Tier 2 flagship").
#
# These prove TWO things with REAL behaviour (NO mocks):
#
#   (a) BYTE-IDENTICAL WIRE OUTPUT. For every property kind (string, number,
#       integer, boolean, enum, array, nested object) the builder's Hash is
#       byte-identical (== AND JSON.generate-equal) to the equivalent
#       hand-written +parameters+ Hash AFTER it passes through the SAME
#       normalisation that +define_tool+ applies. The hand-written baseline
#       is produced by actually calling +define_tool+ and reading back its
#       stored definition, so we compare against the real wire shape, not a
#       hand-massaged copy. The +required+ list is covered, including the
#       rule that the +required+ key is OMITTED when empty.
#
#   (b) END-TO-END THROUGH define_tool + render + invoke. A real AgentBase
#       tool is defined with builder-built params, the agent renders its
#       SWML, and we assert the builder's parameters appear verbatim in the
#       generated SWAIG function JSON — then we actually invoke the function
#       and assert its handler ran.
#
# The enum kind is exercised against the Tier-1 frozen closed-set constant
# RecordFormat::ALL (single source of truth), proving the builder integrates
# the existing vocabularies rather than re-listing them.

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class ParameterSchemaByteIdenticalTest < Minitest::Test
  PS = SignalWire::Swaig::ParameterSchema
  RecordFormat = SignalWire::Swaig::RecordFormat

  # Produce the REAL normalised wire shape for a hand-written parameters
  # Hash by routing it through an actual define_tool call and reading back
  # the stored definition. This is the exact Hash the SWML renderer emits,
  # so the builder must match it byte-for-byte.
  def handwritten(parameters, required: nil)
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 't', description: 'd',
                      parameters: parameters, required: required) { |_, _| }
    agent.define_tools[0]['parameters']
  end

  # Assert two parameter Hashes are byte-identical: structurally equal AND
  # serialise to identical JSON (catches key-order / type divergence a plain
  # == would miss).
  def assert_byte_identical(expected, actual, msg = nil)
    assert_equal expected, actual, msg
    assert_equal JSON.generate(expected), JSON.generate(actual),
                 "#{msg} (JSON byte mismatch)"
  end

  # --- string ---
  def test_string_kind_byte_identical
    built = PS.build { string :service, 'The service' }
    hand  = handwritten({ 'service' => { 'type' => 'string', 'description' => 'The service' } })
    assert_byte_identical hand, built
  end

  # --- number ---
  def test_number_kind_byte_identical
    built = PS.build { number :amount, 'Dollar amount' }
    hand  = handwritten({ 'amount' => { 'type' => 'number', 'description' => 'Dollar amount' } })
    assert_byte_identical hand, built
  end

  # --- integer (with default) ---
  def test_integer_kind_with_default_byte_identical
    built = PS.build { integer :count, 'How many', default: 10 }
    hand  = handwritten({ 'count' => { 'type' => 'integer', 'description' => 'How many', 'default' => 10 } })
    assert_byte_identical hand, built
  end

  # --- boolean ---
  def test_boolean_kind_byte_identical
    built = PS.build { boolean :urgent, 'Is urgent?' }
    hand  = handwritten({ 'urgent' => { 'type' => 'boolean', 'description' => 'Is urgent?' } })
    assert_byte_identical hand, built
  end

  # --- enum (closed set via Tier-1 constant) ---
  def test_enum_kind_byte_identical_with_tier1_constant
    built = PS.build { enum :fmt, RecordFormat::ALL, 'format' }
    # Hand-written equivalent spells the same closed set inline.
    hand  = handwritten({ 'fmt' => { 'type' => 'string', 'description' => 'format',
                                     'enum' => %w[wav mp3 mp4] } })
    assert_byte_identical hand, built
    # And the values came from the frozen Tier-1 vocabulary, not a re-list.
    assert_equal RecordFormat::ALL, built['properties']['fmt']['enum']
  end

  # Building from a frozen constant ALL must not alias (and thus expose
  # mutation of) the shared frozen array through the produced schema.
  def test_enum_does_not_alias_frozen_constant
    built = PS.build { enum :fmt, RecordFormat::ALL, 'format' }
    refute_same RecordFormat::ALL, built['properties']['fmt']['enum']
    assert_equal RecordFormat::ALL, built['properties']['fmt']['enum']
  end

  # --- array (of a scalar kind) ---
  def test_array_kind_byte_identical
    built = PS.build { array :tags, 'Search tags', of: :string }
    hand  = handwritten({ 'tags' => { 'type' => 'array', 'description' => 'Search tags',
                                      'items' => { 'type' => 'string' } } })
    assert_byte_identical hand, built
  end

  # --- nested object (with its own required list) ---
  def test_object_kind_byte_identical
    built = PS.build do
      object :filter, 'Structured filter' do
        string :status, 'open|closed'
        required :status
      end
    end
    hand = handwritten({ 'filter' => {
                         'type' => 'object', 'description' => 'Structured filter',
                         'properties' => { 'status' => { 'type' => 'string', 'description' => 'open|closed' } },
                         'required' => ['status']
                       } })
    assert_byte_identical hand, built
  end

  # --- required list folds the same way define_tool(required:) does ---
  def test_required_list_byte_identical
    built = PS.build do
      string :service, 'The service'
      string :date, 'YYYY-MM-DD'
      required :service, :date
    end
    hand = handwritten(
      {
        'service' => { 'type' => 'string', 'description' => 'The service' },
        'date'    => { 'type' => 'string', 'description' => 'YYYY-MM-DD' }
      },
      required: %w[service date]
    )
    assert_byte_identical hand, built
    assert_equal %w[service date], built['required']
  end

  # Per-property `required: true` folds into the SAME top-level required list.
  def test_inline_required_flag_folds_into_top_level
    built = PS.build do
      string :service, 'The service', required: true
      string :date, 'YYYY-MM-DD', required: true
    end
    hand = handwritten(
      {
        'service' => { 'type' => 'string', 'description' => 'The service' },
        'date'    => { 'type' => 'string', 'description' => 'YYYY-MM-DD' }
      },
      required: %w[service date]
    )
    assert_byte_identical hand, built
  end

  # The `required` key is OMITTED entirely when nothing is required — exactly
  # what define_tool does (it only writes `required` for a non-empty Array).
  def test_required_key_omitted_when_empty
    built = PS.build { string :q, 'query' }
    refute built.key?('required'), 'required key must be absent when no property is required'
    hand = handwritten({ 'q' => { 'type' => 'string', 'description' => 'query' } })
    refute hand.key?('required')
    assert_byte_identical hand, built
  end

  # required de-duplicates while preserving first-seen order (matches the
  # `.uniq` define_tool applies).
  def test_required_dedupes_preserving_order
    built = PS.build do
      string :a, 'a'
      string :b, 'b'
      required :a, :b, :a
    end
    assert_equal %w[a b], built['required']
  end

  # The full mixed-kind schema (every kind at once) is byte-identical end to
  # end — the flagship "all property kinds incl. an enum property" assertion.
  def test_all_kinds_combined_byte_identical
    built = PS.build do
      string  :service, 'The service'
      number  :amount,  'Dollar amount'
      integer :count,   'How many', default: 10
      boolean :urgent,  'Is urgent?'
      enum    :fmt, RecordFormat::ALL, 'format'
      array   :tags,    'Search tags', of: :string
      object  :filter,  'Structured filter' do
        string :status, 'open|closed'
        required :status
      end
      required :service, :date
    end

    hand = handwritten(
      {
        'service' => { 'type' => 'string', 'description' => 'The service' },
        'amount'  => { 'type' => 'number', 'description' => 'Dollar amount' },
        'count'   => { 'type' => 'integer', 'description' => 'How many', 'default' => 10 },
        'urgent'  => { 'type' => 'boolean', 'description' => 'Is urgent?' },
        'fmt'     => { 'type' => 'string', 'description' => 'format', 'enum' => %w[wav mp3 mp4] },
        'tags'    => { 'type' => 'array', 'description' => 'Search tags', 'items' => { 'type' => 'string' } },
        'filter'  => {
          'type' => 'object', 'description' => 'Structured filter',
          'properties' => { 'status' => { 'type' => 'string', 'description' => 'open|closed' } },
          'required' => ['status']
        }
      },
      required: %w[service date]
    )
    assert_byte_identical hand, built
  end

  # Fluent (non-block) usage produces the same wire shape as the block DSL.
  def test_fluent_builder_matches_block_dsl
    fluent = PS.new.string(:q, 'query').integer(:n, 'count').require(:q).to_h
    block  = PS.build do
      string :q, 'query'
      integer :n, 'count'
      required :q
    end
    assert_byte_identical block, fluent
  end
end

# (b) End-to-end: builder-built params through a REAL define_tool, rendered
# into SWML, then invoked. No mocks — drives the actual AgentBase.
class ParameterSchemaDefineToolIntegrationTest < Minitest::Test
  PS = SignalWire::Swaig::ParameterSchema
  RecordFormat = SignalWire::Swaig::RecordFormat

  def setup
    @agent = SignalWire::AgentBase.new
    @params = PS.build do
      string :service, 'The service to look up'
      string :date,    'Appointment date, YYYY-MM-DD'
      enum   :fmt, RecordFormat::ALL, 'Audio container format'
      required :service, :date
    end
    @invoked_with = nil
    @agent.define_tool(name: 'lookup', description: 'Look up a service',
                       parameters: @params) do |args, _raw|
      @invoked_with = args
      SignalWire::Swaig::FunctionResult.new("Looked up #{args['service']}")
    end
  end

  # The builder's parameters appear verbatim in the rendered SWAIG JSON.
  def test_builder_params_appear_in_rendered_swaig_json
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert ai.key?('SWAIG'), 'rendered SWML should carry a SWAIG block'

    fn = ai['SWAIG']['functions'].find { |f| f['function'] == 'lookup' }
    refute_nil fn, 'lookup function should be present in rendered SWAIG functions'

    rendered = fn['parameters']
    # Verbatim: the rendered parameters ARE the builder's output.
    assert_equal @params, rendered
    assert_equal JSON.generate(@params), JSON.generate(rendered)

    # Spot-check the schema content actually made it through, incl. the enum.
    assert_equal 'object', rendered['type']
    assert_equal %w[service date], rendered['required']
    props = rendered['properties']
    assert_equal 'string', props['service']['type']
    assert_equal 'The service to look up', props['service']['description']
    assert_equal %w[wav mp3 mp4], props['fmt']['enum']
  end

  # Defining with builder-built params yields a working, invokable tool.
  def test_builder_built_tool_invokes
    result = @agent.on_function_call('lookup', { 'service' => 'haircut', 'date' => '2026-06-10' }, {})
    assert_equal 'Looked up haircut', result['response']
    # The handler actually ran with the supplied args (real dispatch, no mock).
    assert_equal({ 'service' => 'haircut', 'date' => '2026-06-10' }, @invoked_with)
  end
end
