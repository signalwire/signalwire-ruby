# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative '../lib/signalwire/relay/client'

# Pins the `required`-ness and DEFAULT VALUES that the cross-port signature
# checker compares against the Python reference.
#
# Two properties are under test, and both are easy to "cover" vacuously:
#
#   * REQUIRED-ness — proven by asserting the call RAISES when the argument is
#     omitted. A test that always passes the argument proves nothing about
#     whether it could have been omitted.
#   * DEFAULT VALUE — proven by exercising the path that USES the default, i.e.
#     by NOT passing the argument. Passing it explicitly and asserting the value
#     came back only proves the parameter is wired, not what it defaults to.
#
# Every assertion below therefore either omits the argument or asserts a raise.
#
# BEHAVIOUR IS NOT ENOUGH for required-ness, and this was proven by mutation:
# reverting `on_call(handler)` to `on_call(handler = nil)` left every behavioural
# assertion GREEN, because the method raises from its own guard either way. What
# the cross-port checker actually compares is the SIGNATURE (`:req` vs `:opt`),
# so the required-ness assertions below read `Method#parameters` directly. The
# behavioural raise-tests are kept alongside them — they cover the runtime
# contract; the signature assertions cover the declared one.

# Assertion helpers over Ruby's parameter reflection — the same source the
# signature enumerator reads.
module ParameterKindAssertions
  # The [kind, name] pairs for an instance method, e.g. [[:req, :handler]].
  def params_of(klass, meth)
    klass.instance_method(meth).parameters
  end

  def assert_required_positional(klass, meth, name)
    assert_includes params_of(klass, meth), [:req, name],
                    "#{klass}##{meth} must declare #{name} as a REQUIRED positional " \
                    '(the reference requires it; an optional-with-guard is a different signature)'
  end

  def assert_required_keyword(klass, meth, name)
    assert_includes params_of(klass, meth), [:keyreq, name],
                    "#{klass}##{meth} must declare #{name}: as a REQUIRED keyword"
  end

  def assert_optional_positional(klass, meth, name)
    assert_includes params_of(klass, meth), [:opt, name],
                    "#{klass}##{meth} must declare #{name} as OPTIONAL (the reference defaults it)"
  end
end

class ReferenceRequiredArgumentsTest < Minitest::Test
  include ParameterKindAssertions

  AB = SignalWire::AgentBase
  REGISTRY = SignalWire::Core::Agent::Tools::ToolRegistry
  SERVICE = SignalWire::SWML::Service

  def setup
    @agent = AB.new
  end

  # --- handler/callback slots the reference declares REQUIRED --------

  def test_define_tool_requires_parameters_and_handler
    assert_required_keyword(AB, :define_tool, :parameters)
    assert_required_keyword(AB, :define_tool, :handler)

    assert_raises(ArgumentError) { @agent.define_tool(name: 't', description: 'd') }
    assert_raises(ArgumentError) { @agent.define_tool(name: 't', description: 'd', parameters: {}) }
    assert_raises(ArgumentError) { @agent.define_tool(name: 't', description: 'd', handler: nil) }
  end

  def test_tool_registry_define_tool_requires_parameters_and_handler
    assert_required_keyword(REGISTRY, :define_tool, :parameters)
    assert_required_keyword(REGISTRY, :define_tool, :handler)

    reg = REGISTRY.new

    assert_raises(ArgumentError) { reg.define_tool(name: 't', description: 'd') }
    assert_raises(ArgumentError) { reg.define_tool(name: 't', description: 'd', parameters: {}) }
  end

  def test_on_debug_event_requires_a_handler
    assert_required_positional(AB, :on_debug_event, :handler)

    assert_raises(ArgumentError) { @agent.on_debug_event }
    # nil in the slot with no block is a registration of nothing -> also raises.
    assert_raises(ArgumentError) { @agent.on_debug_event(nil) }
  end

  def test_set_dynamic_config_callback_requires_a_callback
    assert_required_positional(AB, :set_dynamic_config_callback, :callable)

    assert_raises(ArgumentError) { @agent.set_dynamic_config_callback }
    assert_raises(ArgumentError) { @agent.set_dynamic_config_callback(nil) }
  end

  def test_on_summary_requires_the_summary_slot
    assert_required_positional(AB, :on_summary, :summary)

    assert_raises(ArgumentError) { @agent.on_summary }
  end

  def test_register_routing_callback_requires_a_callback
    assert_required_positional(SERVICE, :register_routing_callback, :callback_fn)

    assert_raises(ArgumentError) { @agent.register_routing_callback }
    assert_raises(ArgumentError) { @agent.register_routing_callback(nil) }
  end

  def test_register_global_routing_callback_requires_callback_and_path
    server = SignalWire::AgentServer.new

    assert_required_positional(SignalWire::AgentServer, :register_global_routing_callback, :callback_fn)
    assert_required_positional(SignalWire::AgentServer, :register_global_routing_callback, :path)

    assert_raises(ArgumentError) { server.register_global_routing_callback(->(_b, _h) {}) }
    assert_raises(ArgumentError) { server.register_global_routing_callback(nil, '/x') }
  end

  # --- AI-config slots the reference declares REQUIRED ---------------

  def test_add_language_requires_name_code_and_voice
    %i[name code voice].each { |p| assert_required_positional(AB, :add_language, p) }

    assert_raises(ArgumentError) { @agent.add_language('English') }
    assert_raises(ArgumentError) { @agent.add_language('English', 'en-US') }
  end

  def test_add_pattern_hint_requires_hint_pattern_and_replace
    %i[hint pattern replace].each { |p| assert_required_positional(AB, :add_pattern_hint, p) }

    assert_raises(ArgumentError) { @agent.add_pattern_hint('h') }
    assert_raises(ArgumentError) { @agent.add_pattern_hint('h', 'p') }
  end

  # `add_pattern_hint`'s ignore_case DEFAULT is false (reference parity).
  # Exercised by NOT passing it.
  def test_add_pattern_hint_ignore_case_defaults_to_false
    @agent.add_pattern_hint('SignalWire', 'sw.*', 'SignalWire')

    assert_equal false, @agent.instance_variable_get(:@hints).first['ignore_case']
  end
end

class ReferenceRequiredRelayArgumentsTest < Minitest::Test
  include ParameterKindAssertions

  RC = SignalWire::Relay::Client

  def client
    RC.new(project: 'p', token: 't', host: 'example')
  end

  def test_on_call_and_on_message_require_a_handler
    assert_required_positional(RC, :on_call, :handler)
    assert_required_positional(RC, :on_message, :handler)

    c = client

    assert_raises(ArgumentError) { c.on_call }
    assert_raises(ArgumentError) { c.on_call(nil) }
    assert_raises(ArgumentError) { c.on_message }
    assert_raises(ArgumentError) { c.on_message(nil) }
  end

  def test_execute_requires_params
    assert_required_positional(RC, :execute, :params)

    assert_raises(ArgumentError) { client.execute('calling.dial') }
  end

  def test_call_on_requires_a_handler
    assert_required_positional(SignalWire::Relay::Call, :on, :handler)

    call = SignalWire::Relay::Call.new(client, call_id: 'c1', node_id: 'n1')

    assert_raises(ArgumentError) { call.on('calling.call.state') }
    assert_raises(ArgumentError) { call.on('calling.call.state', nil) }
  end

  def test_message_on_event_requires_a_handler
    assert_required_positional(SignalWire::Relay::Message, :on_event, :handler)

    msg = SignalWire::Relay::Message.new(message_id: 'm1')

    assert_raises(ArgumentError) { msg.on_event }
    assert_raises(ArgumentError) { msg.on_event(nil) }
  end
end

class ReferenceDefaultValuesTest < Minitest::Test
  include ParameterKindAssertions

  def setup
    @agent = SignalWire::AgentBase.new
  end

  # --- prompt body defaults to "" (reference: `body: str = ""`) ------

  # The default is exercised by NOT passing body. "" and nil must both leave the
  # 'body' key OFF the section, matching the reference's `if self.body:` omit.
  # The default VALUE is "" (not nil). Both produce the same wire (the key is
  # omitted either way), so a key-absence assertion cannot distinguish them — a
  # mutation to `body = nil` survived exactly such an assertion. The value is
  # therefore captured directly: call the method with body OMITTED and read back
  # what the parameter was bound to.
  #
  # `build_section` receives `body` verbatim, so a probe on it observes the
  # default value the caller never supplied.
  def observed_default_body
    seen = :not_called
    agent = SignalWire::AgentBase.new
    agent.singleton_class.send(:define_method, :build_section) do |title, body, **opts|
      seen = body
      super(title, body, **opts)
    end
    agent.prompt_add_section('Role')
    seen
  end

  def test_prompt_add_section_body_defaults_to_empty_string_not_nil
    assert_equal '', observed_default_body,
                 'reference is `body: str = ""`; a nil default is a different contract'
  end

  def test_prompt_add_section_omits_an_empty_default_body_from_the_wire
    @agent.prompt_add_section('Role')
    section = @agent.instance_variable_get(:@pom_sections).first

    refute section.key?('body'), 'an empty default body must not be emitted'
    assert_equal 'Role', section['title']
  end

  # `prompt_add_subsection` builds its hash inline, so its default is observed
  # the same way the signature enumerator sees it: off the parameter list.
  def test_prompt_add_subsection_body_defaults_to_empty_string_not_nil
    assert_equal '', default_of(:prompt_add_subsection, :body),
                 'reference is `body: str = ""`; a nil default is a different contract'
  end

  # The literal default expression for a positional param, read from the source
  # line the method is defined on. This is the ONLY way Ruby exposes a default
  # VALUE (Method#parameters reports only that one exists) and is precisely what
  # scripts/signature_dump.rb parses.
  def default_of(meth, param)
    file, line = SignalWire::AgentBase.instance_method(meth).source_location
    sig = File.readlines(file)[line - 1]
    m = /\b#{param}\s*=\s*('[^']*'|"[^"]*"|nil)/.match(sig)

    refute_nil m, "no default found for #{param} in: #{sig.strip}"
    eval(m[1]) # rubocop:disable Security/Eval -- a single matched literal from our own source
  end

  def test_prompt_add_subsection_omits_an_empty_default_body_from_the_wire
    @agent.prompt_add_section('Parent')
    @agent.prompt_add_subsection('Parent', 'Child')
    parent = @agent.instance_variable_get(:@pom_sections).first
    sub = parent['subsections'].first

    refute sub.key?('body'), 'an empty default body must not be emitted'
    assert_equal 'Child', sub['title']
  end

  # --- add_skill params defaults to nil (reference: `= None`) --------

  # Exercised by NOT passing params. The nil must reach the factory normalised to
  # {} — a factory that indexes params must not see a NoMethodError on nil.
  # A minimal registered skill whose factory records the params it received.
  class ParamsProbeSkill < SignalWire::Skills::SkillBase
    class << self
      attr_accessor :seen_params
    end

    def name = 'p2_default_probe'
    def description = 'records the params its factory was handed'
    def setup = true
    def register_tools = []
  end

  def test_add_skill_params_defaults_to_nil_and_normalises_for_the_factory
    ParamsProbeSkill.seen_params = :never_called
    SignalWire::Skills::SkillRegistry.register('p2_default_probe') do |params|
      ParamsProbeSkill.seen_params = params
      ParamsProbeSkill.new(nil, params)
    end

    @agent.add_skill('p2_default_probe')

    # The DEFAULT (nil) is normalised to {} before the factory sees it, so a
    # factory that indexes params never meets a nil.
    assert_equal({}, ParamsProbeSkill.seen_params)

    # ...but the DECLARED default must still be nil, matching the reference
    # (`params: dict | None = None`). The normalisation makes nil and {}
    # behaviourally identical downstream — proven by mutation: changing the
    # default to {} left the factory assertion above GREEN — so the declared
    # value is asserted directly. This is the value the signature enumerator
    # records and the cross-port checker compares.
    assert_nil default_of(:add_skill, :params),
               'reference is `params: dict | None = None`; a {} default is a different contract'
  end

  # --- AgentBase#define_contexts contexts defaults to nil ------------

  # The reference's AgentBase-facing define_contexts (PromptMixin) defaults it;
  # exercised by calling with NO argument, which must build/return the builder.
  def test_define_contexts_contexts_defaults_to_nil
    builder = @agent.define_contexts

    assert_kind_of SignalWire::Contexts::ContextBuilder, builder
    assert_same builder, @agent.define_contexts
  end

  # --- routing-callback path defaults to "/sip" ----------------------

  # Exercised by NOT passing the path: the callback must land on "/sip".
  def test_register_routing_callback_path_defaults_to_sip
    @agent.register_routing_callback(->(_body, _headers) { '/elsewhere' })
    paths = @agent.instance_variable_get(:@routing_callbacks).keys

    assert_equal ['/sip'], paths
  end

  # --- reverse direction: params the reference makes OPTIONAL --------

  # `add_answer_verb` config is optional in the reference; the no-argument call
  # must be accepted (it was REQUIRED here, which was the flip).
  def test_add_answer_verb_config_is_optional
    assert_optional_positional(SignalWire::AgentBase, :add_answer_verb, :config)
    assert_same @agent, @agent.add_answer_verb
  end

  # `on_function_call` raw_data is optional in the reference.
  def test_on_function_call_raw_data_is_optional
    assert_optional_positional(SignalWire::AgentBase, :on_function_call, :raw_data)
    assert_optional_positional(SignalWire::SWML::Service, :on_function_call, :raw_data)

    @agent.define_tool(name: 'echo', description: 'e', parameters: {}, handler: nil) do |_a, _r|
      SignalWire::Swaig::FunctionResult.new('ok')
    end

    assert_equal 'ok', @agent.on_function_call('echo', {})['response']
  end

  # `serve_static_files` route is optional in the reference (default "/").
  def test_serve_static_files_route_defaults_to_root
    assert_optional_positional(SignalWire::AgentServer, :serve_static_files, :route)

    server = SignalWire::AgentServer.new
    server.serve_static_files(__dir__)
    routes = server.instance_variable_get(:@static_routes).keys

    assert_equal [''], routes
  end

  # AgentBase#define_contexts is the PromptMixin analog -> OPTIONAL. Ruby's own
  # PromptManager#define_contexts is the PromptManager analog -> REQUIRED. The
  # two reference methods genuinely differ; both sides are pinned here so a
  # future "unify them" edit cannot silently reintroduce the drift.
  def test_define_contexts_required_ness_differs_by_class
    assert_optional_positional(SignalWire::AgentBase, :define_contexts, :contexts)
    assert_includes SignalWire::Core::Agent::Prompt::PromptManager
      .instance_method(:define_contexts).parameters,
                    %i[req contexts]
  end
end

class ReferenceDialKeywordsTest < Minitest::Test
  # `dial` mirrors the reference's `(devices, *, tag=None, max_duration=None,
  # dial_timeout=None)`. The old Ruby spelling was `timeout: 120` plus a
  # **kwargs passenger for max_duration; both are gone.
  def test_dial_rejects_the_removed_timeout_keyword
    c = SignalWire::Relay::Client.new(project: 'p', token: 't', host: 'example')

    assert_raises(ArgumentError) { c.dial([[{ 'type' => 'phone' }]], timeout: 5) }
  end

  def test_dial_accepts_the_reference_keywords
    params = SignalWire::Relay::Client.instance_method(:dial).parameters

    keywords = params.filter_map { |kind, name| name if kind == :key }

    assert_equal %i[tag max_duration dial_timeout], keywords
    # No **kwargs passenger: every keyword the reference names is explicit.
    refute_includes params.map(&:first), :keyrest
  end
end
