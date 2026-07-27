#!/usr/bin/env ruby
# frozen_string_literal: true

# enumerate_surface.rb --- emit port_surface.json for the Ruby SignalWire SDK.
#
# The porting-sdk ships a canonical inventory (python_surface.json) of every
# public class, method, and module-level function in signalwire-python. Each
# port must produce a JSON file in the same shape so the language-agnostic
# diff_port_surface.py tool can check symbol-level drift.
#
# Output shape (must match python_surface.json exactly):
#
#   {
#     "version": "1",
#     "generated_from": "signalwire-ruby @ <git sha or N/A>",
#     "ruby_version": "3.x",
#     "modules": {
#       "signalwire.core.agent_base": {
#         "classes": { "AgentBase": ["__init__", "serve", ...] },
#         "functions": [...]
#       }
#     }
#   }
#
# Critically, module paths in the emitted JSON use the **Python-reference**
# dotted names. Ruby's SignalWire::AgentBase becomes signalwire.core.agent_base
# (with class AgentBase), not signalwire.agent_base. That way, diff_port_surface
# can compare symbols one-to-one without a per-language translation table on
# the diff side.
#
# Method-name rules:
#   * Ruby methods are already snake_case; leave as-is.
#   * Ruby's `initialize` maps to Python's `__init__`.
#   * Private/protected methods are excluded (we use instance_methods(false)
#     which already filters private/protected).
#   * Methods starting with a single `_` are skipped (Python convention we
#     mirror in the port).
#
# Usage:
#   ruby scripts/enumerate_surface.rb                       # print to stdout
#   ruby scripts/enumerate_surface.rb --output port_surface.json
#   ruby scripts/enumerate_surface.rb --check --output port_surface.json

require 'json'
require 'optparse'
require 'pathname'

REPO_ROOT = Pathname.new(__dir__).parent.expand_path
LIB_DIR   = REPO_ROOT.join('lib')

# Where to look for the porting-sdk checkout. The script needs python_surface.json
# from there to map Ruby classes onto Python module paths; without it, every
# class falls back to a Ruby-namespace path and the resulting port_surface.json
# disagrees with python_surface.json on every symbol.
#
# Search order (first existing wins):
#   1. $PORTING_SDK      (the canonical cross-port var — what the workflows set)
#   2. $PORTING_SDK_PATH (this script's original, ruby-only spelling)
#   3. ./porting-sdk     (CI layout — checked out as a sibling under repo root)
#   4. ../porting-sdk    (local layout — sibling of signalwire-ruby)
#
# $PORTING_SDK is checked FIRST because it is the name every workflow here
# exports (test.yml, nightly.yml, publish.yml) and the name the sibling
# enumerate_signatures.py honours. Reading only PORTING_SDK_PATH — which nothing
# sets — made the env escape hatch dead: it happened to work solely because
# ../porting-sdk resolves in both the local and CI layouts, so an explicit
# override would have been silently ignored. A resolution failure still fails
# LOUD via abort_missing_python_surface; this never degrades to an empty oracle.
ENV_PORTING_SDK_VARS = %w[PORTING_SDK PORTING_SDK_PATH].freeze

def find_default_porting_sdk
  ENV_PORTING_SDK_VARS.each do |var|
    env = ENV.fetch(var, nil)
    return Pathname.new(env) if env && !env.empty?
  end

  [REPO_ROOT.join('porting-sdk'), REPO_ROOT.parent.join('porting-sdk')].each do |p|
    return p if p.directory?
  end
  REPO_ROOT.join('porting-sdk') # fall through; the file-existence check fails loudly later
end

PORTING_SDK_DEFAULT = find_default_porting_sdk

# The generated REST resource layer (scripts/generate_rest.py) emits every class
# into SignalWire::REST::Namespaces::Generated::<Name>; the idiom-blind
# projection onto the reference's <ns>_resources_generated / _client_tree_
# generated modules is driven by the committed sidecar the generator writes
# (single source of truth — never hand-maintained here). Class name is the
# reference name VERBATIM (L1/L2).
GENERATED_PREFIX = 'SignalWire::REST::Namespaces::Generated::'

# The generated wire-type DTOs (item A/H) live under
# SignalWire::REST::Namespaces::Generated::Types::<NsMod>::<TypeName> and are
# routed to the reference's signalwire.rest.namespaces.<ns>_types_generated
# module by PATH (their FQN namespace prefix), WINNING over the name-keyed
# class->module resolution — because type names recur across namespaces and
# collide with SDK class names (DataMap/Document/Section). Class name is the
# reference leaf VERBATIM (the module-suffix fold in diff_port_surface.py
# collapses a type duplicated across several <ns>_types_generated modules).
GENERATED_TYPES_PREFIX = "#{GENERATED_PREFIX}Types::".freeze
# Ruby module segment -> oracle <ns>_types_generated leaf (mirrors generate_rest
# TYPE_NS; kept here so the enumerator needs no import of the generator).
GENERATED_TYPES_NS = {
  'RelayRest' => 'relay_rest',
  'Fabric' => 'fabric',
  'Calling' => 'calling',
  'Video' => 'video',
  'Datasphere' => 'datasphere',
  'Logs' => 'logs',
  'Message' => 'message',
  'Messages' => 'messages',
  'Voice' => 'voice',
  'Fax' => 'fax',
  'Project' => 'project',
  'Projects' => 'projects',
  'Chat' => 'chat',
  'PubSub' => 'pubsub',
  'SwmlWebhooks' => 'swml_webhooks'
}.freeze
GENERATED_SURFACE_MAP =
  begin
    p = REPO_ROOT.join('generated_surface_map.json')
    p.file? ? JSON.parse(p.read) : {}
  end.freeze

# The generated Fabric BASE classes (in _fabric_bases.rb) are the Ruby analog of
# the reference's signalwire.rest._base FabricResource/FabricResourcePUT — base
# classes, not per-namespace resources. Mapped to _base, not via the sidecar.
GENERATED_BASE_CLASSES = [
  "#{GENERATED_PREFIX}FabricResource",
  "#{GENERATED_PREFIX}FabricResourcePUT"
].freeze

# -----------------------------------------------------------------------------
# Python class -> module index. Loaded from python_surface.json so we can look
# up the canonical module for each class in the port. If a Ruby class name has
# an exact match in Python, we use the Python module. If it doesn't (port-only
# classes like Runtime, LambdaHandler, Logging::Logger), we fall back to a
# translation of the Ruby namespace.
# -----------------------------------------------------------------------------
def load_python_index(python_surface_path)
  abort_missing_python_surface(python_surface_path) unless python_surface_path.file?

  data = JSON.parse(python_surface_path.read)
  index = {}
  data.fetch('modules', {}).each do |mod, entry|
    entry.fetch('classes', {}).each_key do |cls|
      (index[cls] ||= []) << mod
    end
  end
  index
end

def abort_missing_python_surface(path)
  abort <<~MSG
    error: python_surface.json not found at #{path}
      The script needs the canonical Python surface to map Ruby classes onto
      Python module paths. Without it the output is not comparable against
      python_surface.json and the Layer B audit will fail.
      Pass --python-surface PATH or set PORTING_SDK.
  MSG
end

# The generated read-side payload reference modules whose model classes expose
# TYPED field-accessor members on the reference SURFACE (griffe records a
# generated Pydantic model's class-typed / list<class> / union<..,SWMLVar>
# fields as accessor members — the porting-sdk B1 composition-attr enrichment).
# Ruby's generated models carry a zero-arg `attr_reader` per wire field, so the
# subset the reference records is emittable here (DTO-FIELD consistency fix):
# instead of surfacing these classes method-less (which OMITS every recorded
# field), emit exactly the readers the oracle records on each class — gated on
# the ORACLE'S member set so scalar wire fields the reference does NOT record
# (ai_volume, global_data, …) are never over-emitted. This mirrors what
# go/rust/cpp/ts/php/dotnet already emit. Other generated-payload modules
# (swaig_actions_generated, relay.protocol_types_generated) record zero members
# on every class, so they stay method-less naturally — this map only lists the
# modules the oracle records members on.
ORACLE_FIELD_ACCESSOR_MODULES = %w[
  signalwire.core.swml_verbs_generated
  signalwire.core.post_prompt_generated
  signalwire.core.swaig_request_generated
  signalwire.ai_chat.client
].freeze

# Load the oracle's per-class recorded surface members for the generated-payload
# modules that expose field accessors. Returns { [ref_module, class] => Set }.
# Empty-member classes are omitted (they surface method-less either way).
def load_oracle_generated_members(python_surface_path)
  abort_missing_python_surface(python_surface_path) unless python_surface_path.file?

  data = JSON.parse(python_surface_path.read)
  out = {}
  ORACLE_FIELD_ACCESSOR_MODULES.each do |mod|
    entry = data.dig('modules', mod) or next
    entry.fetch('classes', {}).each do |cls, members|
      out[[mod, cls]] = members.to_set unless members.empty?
    end
  end
  out
end

# The oracle's FULL per-class recorded surface, every module — { [mod, cls] =>
# Set }. Used to ORACLE-GATE the idiom member-strip table (SURFACE_MEMBER_DROPS):
# a strip entry applies only while the reference does NOT record that name on
# that class. Rationale (ALLOWLIST_DISCIPLINE §15 / class B2): every entry in
# that table was written when the oracle recorded a caller-supplied ctor param
# ONLY as an `__init__` param and never as a surface member, so the Ruby
# `attr_reader` over it had no reference counterpart to compare against. Class B2
# closed that blind spot — the oracle now records those attributes — so a
# hand-maintained strip has become a hand-maintained CAPABILITY REMOVAL. Gating
# on the oracle makes the table self-retire member by member as the oracle grows,
# instead of needing a hand edit per oracle change.
#
# Populated once by `build_snapshot` from the oracle; read by
# `drop_idiom_members`. Mutable so the load happens after option parsing (the
# oracle path is a CLI flag) without threading it through every process_* frame.
ORACLE_ALL_MEMBERS = {} # rubocop:disable Style/MutableConstant -- filled by build_snapshot

def load_oracle_all_members(python_surface_path)
  abort_missing_python_surface(python_surface_path) unless python_surface_path.file?

  data = JSON.parse(python_surface_path.read)
  out = {}
  data.fetch('modules', {}).each do |mod, entry|
    entry.fetch('classes', {}).each { |cls, members| out[[mod, cls]] = members.to_set }
  end
  out
end

# When a class name has multiple Python modules or when Ruby's class name
# doesn't match Python's exactly, we need an explicit override. Keys are
# fully-qualified Ruby names; values are the canonical Python module.
#
# Ruby name -> Python module (the class name gets translated via
# RUBY_TO_PYTHON_CLASS_ALIASES below if it differs).
RUBY_TO_PYTHON_MODULE_OVERRIDES = {
  # Core: Ruby has no Core:: namespace; Python puts these under
  # signalwire.core.<file>. These MUST mirror enumerate_signatures.py's
  # RUBY_TO_PYTHON_MODULE_OVERRIDES so the surface and signature gates route
  # every class to the same reference module (they drifted: the signature
  # enumerator had these, the surface enumerator did not — item H).
  'SignalWire::AgentBase' => 'signalwire.core.agent_base',
  'SignalWire::SWML::Service' => 'signalwire.core.swml_service',
  'SignalWire::SWML::Schema' => 'signalwire.core.swml_schema',
  'SignalWire::Utils::SchemaUtils' => 'signalwire.utils.schema_utils',
  'SignalWire::Utils::SchemaValidationError' => 'signalwire.utils.schema_utils',
  'SignalWire::SWAIG::FunctionResult' => 'signalwire.core.function_result',
  'SignalWire::Swaig::FunctionResult' => 'signalwire.core.function_result',
  'SignalWire::Swaig::SWAIGFunction' => 'signalwire.core.swaig_function',
  'SignalWire::DataMap' => 'signalwire.core.data_map',
  'SignalWire::Contexts::Context' => 'signalwire.core.contexts',
  'SignalWire::Contexts::ContextBuilder' => 'signalwire.core.contexts',
  'SignalWire::Contexts::Step' => 'signalwire.core.contexts',
  'SignalWire::Contexts::GatherInfo' => 'signalwire.core.contexts',
  'SignalWire::Contexts::GatherQuestion' => 'signalwire.core.contexts',
  'SignalWire::Skills::SkillBase' => 'signalwire.core.skill_base',
  'SignalWire::Skills::SkillManager' => 'signalwire.core.skill_manager',
  'SignalWire::Skills::SkillRegistry' => 'signalwire.skills.registry',
  # Item-I implemented subsystems: route the new Ruby classes to their
  # reference core modules (class name matches the reference leaf verbatim).
  'SignalWire::Core::AuthHandler' => 'signalwire.core.auth_handler',
  'SignalWire::Core::ConfigLoader' => 'signalwire.core.config_loader',
  'SignalWire::Core::SecurityConfig' => 'signalwire.core.security_config',
  'SignalWire::Core::PomBuilder' => 'signalwire.core.pom_builder',
  'SignalWire::Web::WebService' => 'signalwire.web.web_service',
  'SignalWire::SWML::SwmlRenderer' => 'signalwire.core.swml_renderer',
  'SignalWire::SWML::SWMLBuilder' => 'signalwire.core.swml_builder',
  'SignalWire::SWML::AIVerbHandler' => 'signalwire.core.swml_handler',
  'SignalWire::SWML::SWMLVerbHandler' => 'signalwire.core.swml_handler',
  'SignalWire::SWML::VerbHandlerRegistry' => 'signalwire.core.swml_handler',
  'SignalWire::Agents::BedrockAgent' => 'signalwire.agents.bedrock',
  'SignalWire::Core::Agent::Prompt::PromptManager' => 'signalwire.core.agent.prompt.manager',
  'SignalWire::Core::Agent::Tools::ToolRegistry' => 'signalwire.core.agent.tools.registry',
  # Prompt Object Model: Ruby's SignalWire::POM::* mirror Python's
  # signalwire.pom.pom.* module (PromptObjectModel + Section).
  'SignalWire::POM::PromptObjectModel' => 'signalwire.pom.pom',
  'SignalWire::POM::Section' => 'signalwire.pom.pom',
  # AgentServer is duplicated in Python (agent_server + livewire). The Ruby
  # port matches the standalone agent_server.
  'SignalWire::AgentServer' => 'signalwire.agent_server',
  # SessionManager is duplicated in Python (core.security + mcp_gateway). The
  # Ruby port only ships the core one.
  'SignalWire::Security::SessionManager' => 'signalwire.core.security.session_manager',
  # Webhook signature validation: Python lives under core.security; Ruby
  # ships the validator module + a Rack middleware (Python ships a FastAPI
  # dependency factory in the same module — that one is in PORT_OMISSIONS.md).
  'SignalWire::Security::WebhookValidator' => 'signalwire.core.security.webhook_validator',
  'SignalWire::Security::WebhookMiddleware' => 'signalwire.core.security.webhook_middleware',
  # Prefabs: Ruby uses short names, Python appends "Agent".
  'SignalWire::Prefabs::Concierge' => 'signalwire.prefabs.concierge',
  'SignalWire::Prefabs::FaqBot' => 'signalwire.prefabs.faq_bot',
  'SignalWire::Prefabs::InfoGatherer' => 'signalwire.prefabs.info_gatherer',
  'SignalWire::Prefabs::Receptionist' => 'signalwire.prefabs.receptionist',
  'SignalWire::Prefabs::Survey' => 'signalwire.prefabs.survey',
  # Built-in skills that don't match Python names 1:1.
  'SignalWire::Skills::Builtin::SwmlTransferSkill' => 'signalwire.skills.swml_transfer.skill',
  'SignalWire::Skills::Builtin::DatasphereSkill' => 'signalwire.skills.datasphere.skill',
  'SignalWire::Skills::Builtin::DatasphereServerlessSkill' => 'signalwire.skills.datasphere_serverless.skill',
  # WebSearchSkill has duplicates in Python (skill, skill_improved, skill_original);
  # the Ruby port matches the canonical `skill` module.
  'SignalWire::Skills::Builtin::WebSearchSkill' => 'signalwire.skills.web_search.skill',
  # Built-in skills where Ruby names match Python names but are in a deeper
  # namespace (SignalWire::Skills::Builtin::*) than Python's module path.
  'SignalWire::Skills::Builtin::ApiNinjasTriviaSkill' => 'signalwire.skills.api_ninjas_trivia.skill',
  'SignalWire::Skills::Builtin::ClaudeSkillsSkill' => 'signalwire.skills.claude_skills.skill',
  'SignalWire::Skills::Builtin::DateTimeSkill' => 'signalwire.skills.datetime.skill',
  'SignalWire::Skills::Builtin::GoogleMapsSkill' => 'signalwire.skills.google_maps.skill',
  'SignalWire::Skills::Builtin::InfoGathererSkill' => 'signalwire.skills.info_gatherer.skill',
  'SignalWire::Skills::Builtin::JokeSkill' => 'signalwire.skills.joke.skill',
  'SignalWire::Skills::Builtin::MathSkill' => 'signalwire.skills.math.skill',
  'SignalWire::Skills::Builtin::MCPGatewaySkill' => 'signalwire.skills.mcp_gateway.skill',
  'SignalWire::Skills::Builtin::NativeVectorSearchSkill' => 'signalwire.skills.native_vector_search.skill',
  'SignalWire::Skills::Builtin::PlayBackgroundFileSkill' => 'signalwire.skills.play_background_file.skill',
  'SignalWire::Skills::Builtin::SpiderSkill' => 'signalwire.skills.spider.skill',
  'SignalWire::Skills::Builtin::WeatherApiSkill' => 'signalwire.skills.weather_api.skill',
  'SignalWire::Skills::Builtin::WikipediaSearchSkill' => 'signalwire.skills.wikipedia_search.skill',
  # Relay Client -> Python RelayClient in signalwire.relay.client.
  'SignalWire::Relay::Client' => 'signalwire.relay.client',
  # Relay error types - ActionTimeoutError is port-only; Ruby RelayError maps
  # to Python's RelayError in signalwire.relay.client (unique class name so
  # the auto-resolver already handles it, but we pin it for clarity).
  'SignalWire::Relay::ActionTimeoutError' => 'signalwire.relay.client',
  'SignalWire::Relay::RelayError' => 'signalwire.relay.client',
  # Relay actions: Python collapses every Action class under
  # signalwire/relay/call.py alongside Call itself.
  'SignalWire::Relay::Action' => 'signalwire.relay.call',
  'SignalWire::Relay::AIAction' => 'signalwire.relay.call',
  'SignalWire::Relay::CollectAction' => 'signalwire.relay.call',
  'SignalWire::Relay::DetectAction' => 'signalwire.relay.call',
  'SignalWire::Relay::FaxAction' => 'signalwire.relay.call',
  'SignalWire::Relay::PayAction' => 'signalwire.relay.call',
  'SignalWire::Relay::PlayAction' => 'signalwire.relay.call',
  'SignalWire::Relay::RecordAction' => 'signalwire.relay.call',
  'SignalWire::Relay::StandaloneCollectAction' => 'signalwire.relay.call',
  'SignalWire::Relay::StreamAction' => 'signalwire.relay.call',
  'SignalWire::Relay::TapAction' => 'signalwire.relay.call',
  'SignalWire::Relay::TranscribeAction' => 'signalwire.relay.call',
  'SignalWire::Relay::Message' => 'signalwire.relay.message',
  # RequestOptions envelope (plan 4.2): the reference collapses the value
  # type + its two private helpers into one module signalwire.rest._request_options.
  # Ruby splits them into sibling classes; route all three to that module.
  # EffectiveOptions/AbortSignal mirror the reference's PRIVATE _EffectiveOptions/
  # _AbortSignal (see RUBY_TO_PYTHON_CLASS_ALIASES + RUBY_EXCLUDED_CLASSES).
  'SignalWire::REST::RequestOptions' => 'signalwire.rest._request_options',
  'SignalWire::REST::EffectiveOptions' => 'signalwire.rest._request_options',
  'SignalWire::REST::AbortSignal' => 'signalwire.rest._request_options'
}.freeze

# Ruby module -> Python module mapping for module-level functions.
# When we find singleton methods on a Ruby module, we emit them under the
# Python-reference module path (not the Ruby namespace fallback).
RUBY_MODULE_TO_PYTHON = {
  # SignalWire::Relay.parse_event -> Python's signalwire.relay.event.parse_event
  # (Ruby hoists it one level up to avoid a dedicated relay_event module).
  'SignalWire::Relay' => 'signalwire.relay.event',
  # WebhookValidator is a Ruby module (with self.* methods) that mirrors
  # Python's module-level webhook_validator helpers under
  # signalwire/core/security/.
  'SignalWire::Security::WebhookValidator' => 'signalwire.core.security.webhook_validator',
  # SecurityUtils is a Ruby module (with self.* methods) mirroring Python's
  # module-level free functions in signalwire.core.security.security_utils
  # (filter_sensitive_headers, redact_url, is_valid_hostname).
  'SignalWire::Security::SecurityUtils' => 'signalwire.core.security.security_utils'
}.freeze

# Ruby class name -> Python class name (when they differ).
RUBY_TO_PYTHON_CLASS_ALIASES = {
  'SignalWire::Prefabs::Concierge' => 'ConciergeAgent',
  'SignalWire::Prefabs::FaqBot' => 'FAQBotAgent',
  'SignalWire::Prefabs::InfoGatherer' => 'InfoGathererAgent',
  'SignalWire::Prefabs::Receptionist' => 'ReceptionistAgent',
  'SignalWire::Prefabs::Survey' => 'SurveyAgent',
  'SignalWire::Skills::Builtin::SwmlTransferSkill' => 'SWMLTransferSkill',
  'SignalWire::Skills::Builtin::DatasphereSkill' => 'DataSphereSkill',
  'SignalWire::Skills::Builtin::DatasphereServerlessSkill' => 'DataSphereServerlessSkill',
  # Ruby Relay::Client maps to Python RelayClient.
  'SignalWire::Relay::Client' => 'RelayClient',
  # Ruby SWML::Service maps to Python SWMLService (in signalwire.core.swml_service).
  'SignalWire::SWML::Service' => 'SWMLService',
  # The RequestOptions helpers mirror the reference's PRIVATE classes
  # (signalwire.rest._request_options._EffectiveOptions / _AbortSignal).
  'SignalWire::REST::EffectiveOptions' => '_EffectiveOptions',
  'SignalWire::REST::AbortSignal' => '_AbortSignal'
}.freeze

# Ruby SWML classes (Document/Schema/Service) are consolidated wrappers that
# do not have exact Python counterparts — Python splits the same surface
# across SWMLBuilder, SwmlRenderer, SchemaUtils, and SWMLService. We emit
# these under Ruby-namespaced module paths (signalwire.swml.*) so they show
# up as port additions; the Python classes are recorded as omissions with
# rationale. This surfaces the design delta honestly rather than hiding it
# behind fuzzy renames.
#
# SignalWire::SWML::Document MUST be pinned here: the Python oracle records a
# UNIQUE class named `Document` (the method-less datasphere REST wire-type DTO,
# signalwire.rest.namespaces.datasphere_types_generated.Document). Without this
# override, translate_class step 3 (unique-Python-name match) routes the Ruby
# SWML Document into the datasphere_types_generated slot, colliding with the
# real DTO — last-write-wins in ObjectSpace order clobbers the method-less DTO
# with SWML Document's methods (or vice-versa), making the surface regen
# nondeterministic. Pinning it to signalwire.swml.document keeps the SWML
# wrapper as its declared PORT_ADDITION and leaves the datasphere DTO untouched.
# (Schema/Service need no pin: neither name matches a unique Python class, so
# both already reach the fallback signalwire.swml.* path.)
RUBY_SWML_MODULE_OVERRIDES = {
  'SignalWire::SWML::Document' => 'signalwire.swml.document'
}.freeze

# Nested helper/middleware classes we don't want in the surface (they're
# internal plumbing, not public API).
#
# `SignalWire::Logging` (and its nested `Logger`) is the PRIVATE BACKING
# IMPLEMENTATION of the public reference-parity facade
# `SignalWire::Core::LoggingConfig`, which is already projected onto the
# reference's `signalwire.core.logging_config` free functions via
# RUBY_FREE_FUNCTION_MODULES — all five of them (`configure_logging`,
# `get_execution_mode`, `get_logger`, `reset_logging_configuration`,
# `strip_control_chars`), with zero omissions. The delegation is explicit in
# lib/signalwire/core/logging_config.rb: `get_logger` -> `Logging.logger`,
# `reset_logging_configuration` -> `Logging.reset!`, `configure_logging` ->
# `Logging.configure`. The remaining members are reachable through the
# reference too — `global_level` / `suppressed?` are the SIGNALWIRE_LOG_LEVEL /
# SIGNALWIRE_LOG_MODE=off settings the reference's `configure_logging` reads
# from the environment. So `Logging` adds NO server capability the reference
# cannot reach; it is the Ruby-idiom shape of an already-ported capability and
# folds here (ALLOWLIST_DISCIPLINE §0/§0b) rather than surfacing as five
# ADDITION entries.
RUBY_EXCLUDED_CLASSES = %w[
  SignalWire::AgentBase::AgentBodyLimitMiddleware
  SignalWire::AgentBase::AgentSecurityHeadersMiddleware
  SignalWire::AgentBase::AgentTimingSafeBasicAuth
  SignalWire::SWML::Service::SecurityHeadersMiddleware
  SignalWire::SWML::Service::TimingSafeBasicAuth
  SignalWire::Logging::Logger
  SignalWire::Logging
  SignalWire::REST::Namespaces
  SignalWire::Skills::Builtin::SafeEvaluator
  SignalWire::Skills::Builtin::MathTokenizer
  SignalWire::POM::SectionBuilder
  SignalWire::Skills::SkillIntrospection
  SignalWire::Relay::MessageSerialization
  SignalWire::REST::Namespaces::Generated
  SignalWire::REST::Namespaces::Generated::ResourceTree
  SignalWire::Core::AuthHandler::BasicCredentials
  SignalWire::Core::AuthHandler::BearerCredentials
  SignalWire::REST::EffectiveOptions
  SignalWire::REST::AbortSignal
  SignalWire::REST::Attempt
].freeze

# Mixin projections: Ruby collapses Python's mixin classes into
# SignalWire::AgentBase via include/extend, so AgentBase ends up owning
# every mixin method. To align with the canonical Python Layer B oracle
# (which keeps these methods on their mixin classes), we project named
# methods from AgentBase onto the corresponding mixin module path.
#
# Parallels MIXIN_PROJECTIONS in scripts/enumerate_signatures.py — keep
# the two in sync when methods land on a Python mixin.
#
# Only methods that appear here AND are present on AgentBase get
# projected; missing-on-AgentBase entries are silently skipped so the
# Layer B diff reports them as real gaps. Projected methods are
# *removed* from AgentBase so they don't double-count as port additions.
#
# Keys: [Python module, Python class]. Values: list of canonical Python
# method names (i.e. already-translated; Ruby's snake_case method names
# match here verbatim).
MIXIN_PROJECTIONS = {
  ['signalwire.core.mixins.ai_config_mixin', 'AIConfigMixin'] => %w[
    add_function_include add_hint add_hints add_internal_filler add_language
    add_pattern_hint add_pronunciation enable_debug_events get_language_params
    set_function_includes set_global_data set_internal_fillers
    set_language_params set_languages set_native_functions set_param set_params
    set_post_prompt_llm_params set_prompt_llm_params set_pronunciations
    update_global_data add_mcp_server enable_mcp_server set_multilingual
  ],
  ['signalwire.core.mixins.prompt_mixin', 'PromptMixin'] => %w[
    contexts define_contexts get_post_prompt get_prompt prompt_add_section
    prompt_add_subsection prompt_add_to_section prompt_has_section
    reset_contexts set_post_prompt set_prompt_pom set_prompt_text
  ],
  ['signalwire.core.mixins.skill_mixin', 'SkillMixin'] => %w[
    add_skill has_skill list_skills remove_skill
  ],
  ['signalwire.core.mixins.tool_mixin', 'ToolMixin'] => %w[
    define_tool define_tools on_function_call register_swaig_function tool
  ],
  ['signalwire.core.mixins.web_mixin', 'WebMixin'] => %w[
    as_router enable_debug_routes get_app manual_set_proxy_url on_request
    on_swml_request register_routing_callback run serve
    set_dynamic_config_callback setup_graceful_shutdown
  ],
  ['signalwire.core.mixins.auth_mixin', 'AuthMixin'] => %w[
    get_basic_auth_credentials validate_basic_auth
  ],
  ['signalwire.core.mixins.state_mixin', 'StateMixin'] => %w[
    validate_tool_token
  ],
  ['signalwire.core.mixins.serverless_mixin', 'ServerlessMixin'] => %w[
    handle_serverless_request
  ]
}.freeze

# Per-[module, class] method-NAME aliases: Ruby-idiom method name -> the
# reference's method name, so the two compare EQUAL (Rule 2 — reconcile idiom
# in the enumerator, not via an omission). Applied after method enumeration.
# Mirrors the reserved-word/`initialize`->`__init__` rename philosophy.
SURFACE_METHOD_ALIASES = {
  ['signalwire.core.contexts', 'Context'] => { 'to_h' => 'to_dict' },
  ['signalwire.core.contexts', 'ContextBuilder'] => { 'to_h' => 'to_dict', 'validate!' => 'validate' },
  ['signalwire.core.contexts', 'Step'] => { 'to_h' => 'to_dict' },
  ['signalwire.core.contexts', 'GatherInfo'] => { 'to_h' => 'to_dict' },
  ['signalwire.core.contexts', 'GatherQuestion'] => { 'to_h' => 'to_dict' },
  ['signalwire.pom.pom', 'PromptObjectModel'] => { 'to_h' => 'to_dict' },
  # `numberedBullets` is recorded camelCase VERBATIM because it IS the POM wire
  # key (pom.py:345,361,371 round-trip it through the section dict unchanged), not
  # reference sloppiness. Ruby spells the reader snake_case per its own idiom and
  # the RENAME re-establishes the identity; converting the wire key would be wrong.
  ['signalwire.pom.pom', 'Section'] => { 'to_h' => 'to_dict', 'numbered_bullets' => 'numberedBullets' },
  ['signalwire.core.function_result', 'FunctionResult'] => { 'to_h' => 'to_dict' },
  ['signalwire.relay.event', 'DialEvent'] => { 'call_data' => 'call' },
  ['signalwire.relay.call', 'Action'] => { 'done?' => 'is_done' },
  ['signalwire.relay.call', 'Call'] => { 'inspect' => '__repr__', 'pass_call' => 'pass_', 'tap_audio' => 'tap' },
  ['signalwire.relay.message', 'Message'] => { 'inspect' => '__repr__', 'done?' => 'is_done', 'on_event' => 'on' },
  # `project_id` is Ruby's spelling of the reference's `project` ctor param /
  # attribute (RelayClient reads it back as `self.project`, relay/client.py:171).
  # A rename, not an omission: the identity lines up and every other member of
  # the class keeps comparing.
  ['signalwire.relay.client', 'RelayClient'] => { 'stop' => 'disconnect', 'project_id' => 'project' },
  # Ruby cannot name these readers `message`: `Exception#message` is already
  # defined by the stdlib and overriding it would change what `raise`/`rescue`
  # and every logger prints. So the port spells them `error_message` /
  # `server_message` and the rename re-establishes the reference identity.
  ['signalwire.relay.client', 'RelayError'] => { 'error_message' => 'message' },
  ['signalwire.ai_chat.client', 'AIChatError'] => { 'server_message' => 'message' },
  # `method` is `Object#method` in Ruby — a core reflection method on every
  # object. The port spells the HTTP-verb reader `method_name`; renamed here.
  ['signalwire.rest._base', 'SignalWireRestError'] => { 'method_name' => 'method' },
  ['signalwire.prefabs.faq_bot', 'FAQBotAgent'] => { 'handle_search' => 'search_faqs' },
  ['signalwire.prefabs.info_gatherer', 'InfoGathererAgent'] => {
    'handle_start' => 'start_questions', 'handle_submit' => 'submit_answer'
  },
  ['signalwire.core.swml_builder', 'SWMLBuilder'] => { 'method_missing' => '__getattr__' },
  ['signalwire.core.swml_service', 'SWMLService'] => { 'method_missing' => '__getattr__' },
  ['signalwire.core.swaig_function', 'SWAIGFunction'] => { 'call' => '__call__' },
  ['signalwire.agents.bedrock', 'BedrockAgent'] => { 'inspect' => '__repr__' },
  ['signalwire.core.skill_base', 'SkillBase'] => { 'instance_key' => 'get_instance_key' },
  ['signalwire.core.skill_manager', 'SkillManager'] => {
    'load' => 'load_skill', 'unload' => 'unload_skill', 'get' => 'get_skill',
    'loaded?' => 'has_skill', 'loaded_keys' => 'list_loaded_skills'
  },
  ['signalwire.skills.registry', 'SkillRegistry'] => { 'get_factory' => 'get_skill_class' },
  ['signalwire.utils.schema_utils', 'SchemaUtils'] => { 'full_validation_available?' => 'full_validation_available' }
}.freeze

# Built-in skill classes rename their Ruby `instance_key` override to the
# reference's `get_instance_key` (every skill.* module). Applied by prefix so
# each per-skill override compares equal without 16 explicit table rows.
SKILLS_MODULE_METHOD_ALIASES = { 'instance_key' => 'get_instance_key' }.freeze

# Methods projected onto a class from a DIFFERENT Ruby class (design split):
# the reference declares them on class X, but Ruby implements them on class Y.
# [ref_module, ref_class] => [ [ruby_fqn, [methods...]] ]. Copied verbatim
# (already-reference-named) onto the target class's surface.
SURFACE_METHOD_DONORS = {
  ['signalwire.core.swml_service', 'SWMLService'] => [
    ['SignalWire::SWML::Document', %w[add_section add_verb add_verb_to_section reset]]
  ],
  # WebMixin / AuthMixin: Ruby hosts these on the base SWML::Service (Python
  # composes them onto AgentBase via the mixins). Donate the Service-own
  # methods to the mixin classes so the reference mixin surface is present.
  ['signalwire.core.mixins.web_mixin', 'WebMixin'] => [
    ['SignalWire::SWML::Service', %w[on_request on_swml_request register_routing_callback]]
  ],
  ['signalwire.core.mixins.auth_mixin', 'AuthMixin'] => [
    ['SignalWire::SWML::Service', %w[validate_basic_auth get_basic_auth_credentials]]
  ]
}.freeze

# Ruby module singleton-methods -> reference module functions[]. Extends the
# RUBY_MODULE_TO_PYTHON table for the free-function subsystems Ruby hosts as
# module_function modules (Ruby is NOT file-per-class, so these are genuine
# module-level functions, matching the reference's functions[] list — L19 does
# NOT apply; no `impossible:` needed).
RUBY_FREE_FUNCTION_MODULES = {
  'SignalWire::Core::LoggingConfig' => 'signalwire.core.logging_config',
  'SignalWire::Utils' => 'signalwire.utils',
  'SignalWire::Utils::UrlValidator' => 'signalwire.utils.url_validator',
  'SignalWire::Core::Agent::Tools::TypeInference' => 'signalwire.core.agent.tools.type_inference',
  # SignalWire::Contexts.create_simple_context -> the reference's module-level
  # signalwire.core.contexts.create_simple_context free function.
  'SignalWire::Contexts' => 'signalwire.core.contexts'
}.freeze

# Class-method free-function projections: a Ruby `def self.X` on a class that
# the reference exposes as a MODULE-level function (not a class method). Move
# it from the class's method list to the module's functions[]. Ruby's idiom is
# a class factory method; the reference's is a module function — same callable.
# [ruby_fqn, ref_module] => [method names to project as module functions].
FREE_FUNCTION_PROJECTIONS = {
  'SignalWire::DataMap' => ['signalwire.core.data_map', %w[create_expression_tool create_simple_api_tool]],
  # The decomposed framework-free webhook-validation core. Ruby ships it as a
  # `def self.validate` singleton method on WebhookMiddleware (the Rack #call
  # wrapper delegates to it); the reference records it as the module-level
  # function signalwire.core.security.webhook_middleware.validate. Move it off
  # the class's method list onto the module's functions[] so the two compare
  # EQUAL (mirrors SIG_FREE_FUNCTION_PROJECTIONS in enumerate_signatures.py).
  'SignalWire::Security::WebhookMiddleware' =>
    ['signalwire.core.security.webhook_middleware', %w[validate]],
  # RequestOptions envelope: the reference exposes resolve + status_is_retryable
  # as MODULE-level functions of signalwire.rest._request_options; Ruby ships
  # them as `def self.` factory/predicate methods on RequestOptions. Project
  # both onto the module's functions[] so the surface compares EQUAL.
  'SignalWire::REST::RequestOptions' =>
    ['signalwire.rest._request_options', %w[resolve status_is_retryable]]
}.freeze

# -----------------------------------------------------------------------------
# Name translation
# -----------------------------------------------------------------------------
def snake_case(camel)
  camel
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .downcase
end

# Project a generated REST class (SignalWire::REST::Namespaces::Generated::*)
# onto its reference module, or nil if +ruby_fqn+ is not a generated class.
#   * the two Fabric BASE classes live in the reference's shared
#     signalwire.rest._base (like BaseResource/CrudResource), not a namespace
#     resources_generated module (both have an empty own-method set → match);
#   * every other generated resource/container maps via the sidecar to its
#     <ns>_resources_generated / _client_tree_generated module, class VERBATIM.
# Project a generated wire-type class onto its <ns>_types_generated module by
# the FQN namespace prefix (PATH-based, wins over name-keyed lookup). Returns
# [module, class] or nil if +ruby_fqn+ is not a generated type class.
def translate_generated_type_class(ruby_fqn, cls)
  return nil unless ruby_fqn.start_with?(GENERATED_TYPES_PREFIX)

  rest = ruby_fqn.delete_prefix(GENERATED_TYPES_PREFIX) # "<NsMod>::<TypeName>"
  ns_mod = rest.split('::').first
  ns_key = GENERATED_TYPES_NS[ns_mod]
  if ns_key.nil?
    abort "generated type class #{ruby_fqn} has unknown Types namespace #{ns_mod.inspect} " \
          '(add it to GENERATED_TYPES_NS)'
  end
  ["signalwire.rest.namespaces.#{ns_key}_types_generated", cls]
end

# The generated read-side payload modules (SESSION_CHANGESET item D): SWML-verbs
# config types, RELAY protocol types, and SWAIG payloads. Each is routed to its
# reference module by the Ruby FQN namespace PREFIX (path-based, wins over the
# name-keyed lookup) — required because the class names recur across modules and
# collide with SDK/REST-type names (AIObject/Cond/Section/…). Class name is the
# reference leaf VERBATIM; the diff-tool gen-payload / gen-type folds collapse the
# cross-module duplicates on both sides.
GENERATED_PAYLOAD_PREFIXES = {
  'SignalWire::Core::SwmlVerbsGenerated::' => 'signalwire.core.swml_verbs_generated',
  'SignalWire::Relay::ProtocolTypesGenerated::' => 'signalwire.relay.protocol_types_generated',
  'SignalWire::Core::PostPromptGenerated::' => 'signalwire.core.post_prompt_generated',
  'SignalWire::Core::SwaigRequestGenerated::' => 'signalwire.core.swaig_request_generated',
  'SignalWire::Core::SwaigActionsGenerated::' => 'signalwire.core.swaig_actions_generated'
}.freeze

# Project a generated read-side payload class onto its reference module by FQN
# prefix. Returns [module, class] or nil.
def translate_generated_payload_class(ruby_fqn, cls)
  GENERATED_PAYLOAD_PREFIXES.each do |prefix, mod|
    return [mod, cls] if ruby_fqn.start_with?(prefix)
  end
  nil
end

# Route a generated wire-type OR read-side-payload class by its FQN namespace
# prefix (PATH-based, wins over the name-keyed lookup). Returns [module, class]
# or nil. Their names recur across modules / collide with SDK class names.
def translate_generated_by_path(ruby_fqn, cls)
  translate_generated_type_class(ruby_fqn, cls) ||
    translate_generated_payload_class(ruby_fqn, cls)
end

def translate_generated_class(ruby_fqn, cls)
  return ['signalwire.rest._base', cls] if GENERATED_BASE_CLASSES.include?(ruby_fqn)

  path_route = translate_generated_by_path(ruby_fqn, cls)
  return path_route if path_route
  return nil unless ruby_fqn.start_with?(GENERATED_PREFIX)

  mod = GENERATED_SURFACE_MAP[cls]
  if mod.nil?
    abort "generated class #{ruby_fqn} not in generated_surface_map.json " \
          '(regenerate: python3 scripts/generate_rest.py)'
  end
  [mod, cls]
end

# Translate a fully-qualified Ruby name to the Python-reference dotted module
# + class name. Returns [module_path, class_name].
def translate_class(ruby_fqn, python_index)
  cls = ruby_fqn.split('::').last

  # 0. Generated REST resource/container/base (via the generator sidecar).
  gen = translate_generated_class(ruby_fqn, cls)
  return gen if gen

  # 1. Explicit override wins.
  if RUBY_TO_PYTHON_MODULE_OVERRIDES.key?(ruby_fqn)
    return [RUBY_TO_PYTHON_MODULE_OVERRIDES[ruby_fqn], RUBY_TO_PYTHON_CLASS_ALIASES[ruby_fqn] || cls]
  end

  # 2. SWML-specific mapping.
  return [RUBY_SWML_MODULE_OVERRIDES[ruby_fqn], cls] if RUBY_SWML_MODULE_OVERRIDES.key?(ruby_fqn)

  # 3. Ruby class name matches a Python class name uniquely -> use Python mod.
  return [python_index[cls].first, cls] if python_index.key?(cls) && python_index[cls].length == 1

  # 4. No Python match -> fall back to a port-only signalwire.* module path.
  [fallback_module_path(ruby_fqn, cls), cls]
end

# Translate a Ruby namespace to a dotted snake_case path, emitting under a
# signalwire.* module. Port-only additions show up in PORT_ADDITIONS.md.
#
# Python uses per-file module paths (signalwire.core.agent_base.AgentBase),
# so for Ruby we append snake_case(class_name) to the namespace segments —
# that matches Ruby's convention of one class per file (agent_base.rb holds
# SignalWire::AgentBase). This keeps port-only classes in distinct modules
# rather than collapsing them into their parent namespace.
def fallback_module_path(ruby_fqn, cls)
  parts = ruby_fqn.split('::').map { |p| snake_case(p) }
  # SignalWire -> signalwire
  parts[0] = 'signalwire'
  # Drop the class name segment and append it as the final module segment
  # (so SignalWire::Runtime -> signalwire.runtime, and
  #  SignalWire::SWML::Document -> signalwire.swml.document).
  (parts[0..-2] + [snake_case(cls)]).join('.')
end

# Translate a Ruby module FQN (e.g. "SignalWire::Runtime") to the module path
# used for port-only modules. Mirrors the fallback in `translate_class`.
def ruby_fqn_to_port_module(fqn)
  parts = fqn.split('::').map { |p| snake_case(p) }
  parts[0] = 'signalwire'
  parts.join('.')
end

# Singleton methods on a Ruby module mirror Python's @classmethod/@staticmethod
# methods on a class. Emit them using the same filtering rules as class
# methods. No `initialize` handling because modules aren't instantiated.
def enumerate_module_methods(mod)
  mod.singleton_methods(false).map(&:to_s).select { |m| surface_method?(m) }.uniq.sort
end

# -----------------------------------------------------------------------------
# Enumerate public methods of a Ruby class.
#
# public_instance_methods(false) already excludes private and protected; we
# only add "initialize" back (it's private by default in Ruby) since it maps
# to Python's __init__.
# -----------------------------------------------------------------------------
def enumerate_methods(klass)
  seen = {}
  raw_class_methods(klass).each do |m|
    next unless surface_method?(m)

    # Keep `?`- and `!`-suffixed method names as-is. Ruby predicate
    # methods (has_skill?) and bang methods (reset!) are idiomatic; they
    # show up as port additions (Python has no equivalent, so they end up
    # in PORT_ADDITIONS.md with the Ruby-idiom rationale).
    name = m == 'initialize' ? '__init__' : m
    seen[name] = true
  end
  seen.keys.sort
end

def raw_class_methods(klass)
  raw = klass.public_instance_methods(false).map(&:to_s)
  # Class methods (Python module-level "classmethod"/"staticmethod" show up as
  # methods on the class too).
  raw.concat(klass.singleton_methods(false).map(&:to_s))
  # Methods the class COMPOSES via `include` from a non-surface module.
  raw.concat(composed_module_methods(klass))
  # initialize is private by default — include it explicitly.
  raw << 'initialize' if klass.private_method_defined?(:initialize, false)
  raw
end

# Public instance methods a class reaches through `include`, lifted onto the
# class so a reflective walk sees the surface a CALLER sees.
#
# The blind spot this closes: `public_instance_methods(false)` is
# DECLARED-ONLY. `RestClient` composes its 22 flat-resource / namespace-container
# accessors by including the generated `Namespaces::Generated::ResourceTree`
# (rest/rest_client.rb:42) instead of writing 22 `def`s, so every one of them was
# invisible to this enumerator — and reported as 22 missing symbols against a
# reference that records them all on `RestClient`. They were never missing;
# `client.calling` / `client.fabric` / `client.video` have always worked (pinned
# by tests/rest/resource_tree_accessors_mock_test.rb). This is the Ruby analog of
# `_wired_base_attributes` in porting-sdk's own reference enumerator, which lifts
# members off a base the walker would otherwise miss.
#
# Scoped deliberately narrow, mirroring that precedent:
#   * Only modules EXCLUDED from the surface scan (RUBY_EXCLUDED_CLASSES) are
#     lifted. A module that is its own surface symbol already has its members
#     enumerated on itself; lifting those onto every includer would duplicate
#     real composition into flattened members. `ResourceTree` and `Generated`
#     are both excluded, so nothing double-counts.
#   * Only SignalWire-owned modules — never a stdlib/gem mixin (Comparable,
#     Enumerable, Kernel), which are language idiom and not port surface.
#   * `initialize` is skipped; the class's own constructor is handled above.
#   * RUBY_PROTOCOL_METHODS are skipped — see that constant.
# Filtering to the public surface (`_`-prefixed, `=` writers) happens in the
# caller via `surface_method?`, exactly as for declared methods.
def composed_module_methods(klass)
  klass.included_modules.select { |mod| composed_module?(mod.name) }
                        .flat_map { |mod| liftable_module_methods(mod) }
end

# A module whose members are lifted onto its includers: SignalWire-owned AND
# excluded from the surface scan (so lifting cannot double-count a module that is
# its own surface symbol).
def composed_module?(name)
  return false if name.nil? || !name.start_with?('SignalWire')

  RUBY_EXCLUDED_CLASSES.include?(name)
end

# The public instance methods of a composed module that count as lifted surface.
def liftable_module_methods(mod)
  mod.public_instance_methods(false).map(&:to_s).reject do |m|
    m == 'initialize' || RUBY_PROTOCOL_METHODS.include?(m)
  end
end

# Ruby LANGUAGE-PROTOCOL hooks: methods the interpreter (or a core protocol like
# pattern matching / Hash keying / JSON) calls on an object, not methods a caller
# invokes for a SignalWire capability. These are never port surface — the same
# reasoning that already folds `AIChatClient#inspect`/`#to_s` in
# SURFACE_MEMBER_DROPS ("token-redacting Ruby object hooks; the reference defines
# no `__repr__`/`__str__`").
#
# Only consulted by `composed_module_methods`, i.e. for methods reached through an
# `include`. A class that DECLARES one of these keeps its existing treatment, so
# this cannot retroactively strip anything that was already emitted.
#
# Concretely: `MessageSerialization` (an excluded mixin, extracted from
# `Relay::Message` so the class stays focused on lifecycle) contributes
# to_s / to_json / hash / eql? / deconstruct / deconstruct_keys — Ruby's
# JSON, equality, and Ruby-3 pattern-matching protocols. The reference `Message`
# records none of them (it records `__repr__`, which is the Python side of the
# same idiom), so lifting them would surface pure language idiom as 6 port
# ADDITIONS. Folding them here is the emitter doing the idiom reconciliation.
RUBY_PROTOCOL_METHODS = %w[
  to_s to_json inspect hash eql? deconstruct deconstruct_keys
].freeze

# A method is part of the public surface unless it's a single-underscore
# "private convention" name or an auto-generated writer (attr_writer/accessor);
# the Python surface file emits neither.
def surface_method?(method_name)
  return false if method_name.start_with?('_') && !method_name.start_with?('__')
  return false if method_name.end_with?('=')

  true
end

# -----------------------------------------------------------------------------
# Gather everything.
# -----------------------------------------------------------------------------
def collect_modules(python_index, oracle_generated_members = {})
  # Modules in the final snapshot. Each entry: {"classes" => {...}, "functions" => [...]}.
  modules = Hash.new { |h, k| h[k] = { 'classes' => {}, 'functions' => [] } }
  scan_object_space(modules, python_index, oracle_generated_members)
  apply_method_donors(modules)
  apply_mixin_projections(modules)
  add_toplevel_functions(modules)

  # Drop modules that ended up completely empty after filtering (no classes,
  # no functions) — matches the Python enumerator's behaviour.
  modules.reject { |_k, v| v['classes'].empty? && v['functions'].empty? }
end

def scan_object_space(modules, python_index, oracle_generated_members = {})
  seen_classes = {}
  ObjectSpace.each_object(Module) do |m|
    name = m.name
    next unless surface_module?(name, seen_classes)

    seen_classes[name] = true
    process_module(m, name, modules, python_index, oracle_generated_members)
  end
end

# A module/class qualifies for the surface scan unless it's anonymous, the
# top-level SignalWire module, already seen, an excluded internal class, or a
# private constant (leaf starts with `_`).
def surface_module?(name, seen_classes)
  return false unless name&.start_with?('SignalWire')
  return false if name == 'SignalWire'
  return false if seen_classes[name]
  return false if RUBY_EXCLUDED_CLASSES.include?(name)
  return false if name.split('::').last.start_with?('_')

  true
end

# The AI-Chat response models are Ruby `Struct.new(..., keyword_init: true)`
# value types — the idiomatic Ruby analog of the reference's `@dataclass`
# ConversationInfo / ChatResponse / ChatLog. The oracle now records each
# dataclass's PUBLIC FIELDS as surface members (`id`/`status`/`initial_message`,
# `text`/`conversation_id`/`user_event`, `messages`/`call_timeline`). A Ruby
# Struct auto-generates a reader per field whose spelling MATCHES the reference
# field name, so we surface exactly the oracle-recorded field subset (via
# `signalwire.ai_chat.client` in ORACLE_FIELD_ACCESSOR_MODULES) and drop the rest
# of the Struct machinery (`[]`, `new`, `members`, `keyword_init?`, …). Emission
# covers the Struct idiom; no PORT_ADDITIONS entry per accessor. Scoped by FQN so
# no other class is affected.
AI_CHAT_METHODLESS_CLASSES = %w[
  SignalWire::AIChat::ConversationInfo
  SignalWire::AIChat::ChatResponse
  SignalWire::AIChat::ChatLog
].freeze

# Per-[module, class] surface members to DROP: a Ruby-idiom accessor/method that
# the reference records as a plain instance ATTRIBUTE (not a surface method), so
# there is no reference member to compare against — the idiomatic-Ruby getter is
# folded away rather than surfaced as an addition. Applied after the alias pass.
#
# ORACLE-GATED (see `drop_idiom_members`): an entry takes effect ONLY while the
# oracle does NOT record that name on that class. The premise of every entry is
# "the reference has no such surface member", so the oracle is the authority on
# whether the premise still holds — and class B2 (ALLOWLIST_DISCIPLINE §15) made
# several of these premises false by recording caller-supplied `__init__`
# attributes. Gating rather than hand-pruning means the table degrades itself as
# the oracle grows; a stale entry can no longer silently remove a reader the
# reference publishes (which is CONSTRUCTION-READBACK's exact failure mode).
#   * AIChatClient#url        → the reference's `self.url` instance attribute;
#   * AIChatClient#inspect/to_s → token-redacting Ruby object hooks (the reference
#                                 AIChatClient defines no `__repr__`/`__str__`);
#   * AIChatClient#resolve_url → the reference's PRIVATE `_resolve_url`
#                                 @staticmethod (excluded from the reference
#                                 surface by the leading `_`); Ruby exposes the
#                                 same helper public for testability, so drop it
#                                 to match the reference's private form;
#   * AIChatError#code/#server_message → the reference's `self.code` / message
#                                 instance attributes set in `__init__`.
#   * #logger on AgentServer / SkillBase / SkillManager / SkillRegistry → the
#                                 reference sets `self.logger = get_logger(...)`
#                                 in each of these four `__init__`s
#                                 (signalwire/agent_server.py:65,
#                                 core/skill_base.py:41, core/skill_manager.py:24,
#                                 skills/registry.py:31), so Ruby's
#                                 `attr_reader :logger` reaches the SAME
#                                 capability. Per the owner ruling 2026-07-24
#                                 (ALLOWLIST_DISCIPLINE §8) logging is a
#                                 MODULE-LEVEL capability — the contract is the
#                                 five `signalwire.core.logging_config` free
#                                 functions, and the per-instance attribute was
#                                 dropped from the oracle as a marked exclusion.
#                                 With no oracle member to compare against, the
#                                 Ruby reader folds here rather than surfacing as
#                                 an ADDITION (§7 accessor row).
#   * GatherQuestion#isolated → the reference's PUBLIC `self.isolated`
#                                 instance attribute (core/contexts.py:59, the
#                                 tri-state that `to_dict` emits even when
#                                 False). Written for the pre-B2 oracle blind
#                                 spot; the oracle NOW records it, so the gate
#                                 retires this entry and the Ruby
#                                 `attr_accessor` is emitted.
#   * SurveyAgent#brand_name / #max_retries → the reference's PUBLIC
#                                 `self.brand_name` / `self.max_retries`
#                                 (prefabs/survey.py:93-94). Same pre-B2 blind
#                                 spot; also now oracle-retired.
# Entries kept here are deliberately RETAINED as documentation of intent: the
# gate reads them, so a future oracle change flips each one automatically and the
# comment above it records why it was written. Deleting an entry that the gate
# already neutralises would lose that provenance.
SURFACE_MEMBER_DROPS = {
  ['signalwire.ai_chat.client', 'AIChatClient'] => %w[url inspect to_s resolve_url],
  # `message` is the POST-ALIAS spelling (SURFACE_METHOD_ALIASES renames Ruby's
  # `server_message` first); this table is keyed by the name the emitter will
  # EMIT, never the source name. Keying a member table by the source spelling
  # while the consumer sees the emitted one is how typescript silently dropped
  # every field of an aliased class.
  ['signalwire.ai_chat.client', 'AIChatError'] => %w[code message],
  ['signalwire.agent_server', 'AgentServer'] => %w[logger],
  ['signalwire.core.skill_base', 'SkillBase'] => %w[logger],
  ['signalwire.core.skill_manager', 'SkillManager'] => %w[logger],
  ['signalwire.skills.registry', 'SkillRegistry'] => %w[logger],
  ['signalwire.core.contexts', 'GatherQuestion'] => %w[isolated],
  ['signalwire.prefabs.survey', 'SurveyAgent'] => %w[brand_name max_retries]
}.freeze

# A generated wire-type / read-side-payload class surfaces METHOD-LESS: the
# reference records these as method-less type definitions (griffe: dataclass
# fields are attributes, not surface methods). The SWML-verbs / post-prompt /
# swaig-request classes carry zero-arg field READERS (needed for the SIGNATURE
# gate — the reference records those accessors), but on the SURFACE those readers
# are dropped so the class compares equal to the reference's method-less type.
# Scoped to the generated-payload/type FQN prefixes so no SDK class is affected.
def generated_methodless_class?(ruby_fqn)
  return true if ruby_fqn.start_with?(GENERATED_TYPES_PREFIX)
  return true if AI_CHAT_METHODLESS_CLASSES.include?(ruby_fqn)

  GENERATED_PAYLOAD_PREFIXES.each_key { |prefix| return true if ruby_fqn.start_with?(prefix) }
  false
end

# For a generated read-side payload class, return the subset of its zero-arg
# field readers the oracle records as surface members on the reference class.
# Gated on the ORACLE'S member set (never the full reader list) so scalar wire
# fields the reference does not record are not over-emitted. Empty (method-less)
# when the class is not one the oracle records field accessors for.
def oracle_gated_field_accessors(klass, target_mod, cls, oracle_generated_members)
  wanted = oracle_generated_members[[target_mod, cls]]
  return [] unless wanted

  readers = klass.public_instance_methods(false).to_set(&:to_s)
  missing = wanted.to_a - readers.to_a
  unless missing.empty?
    abort "generated model #{target_mod}.#{cls} is missing oracle-recorded field " \
          "reader(s) #{missing.sort.inspect}; regenerate the model or update the oracle"
  end
  wanted.to_a.select { |m| readers.include?(m) }.sort
end

# Record one Ruby class or module into `modules`.
def process_module(mod, name, modules, python_index, oracle_generated_members = {})
  if mod.is_a?(Class)
    process_class(mod, name, modules, python_index, oracle_generated_members)
  else
    process_namespace_module(mod, name, modules)
  end
end

# Record one Ruby CLASS into `modules` (the method surface after projections,
# aliasing, and idiom drops).
def process_class(mod, name, modules, python_index, oracle_generated_members)
  target_mod, cls = translate_class(name, python_index)
  methods = surface_methods_for(mod, name, target_mod, cls, oracle_generated_members)
  methods = project_free_functions(name, methods, modules)
  methods = apply_method_aliases(target_mod, cls, methods)
  methods = drop_idiom_members(target_mod, cls, methods)
  modules[target_mod]['classes'][cls] = methods
end

# The raw method surface for a Ruby class before projection/aliasing. A generated
# read-side payload/type class is method-less on the SURFACE EXCEPT for the typed
# field accessors the reference records (class-typed / list<class> / union
# members): emit exactly that oracle-recorded subset of the class's zero-arg
# readers so the port matches go/rust/cpp/ts/php/dotnet instead of omitting them.
def surface_methods_for(mod, name, target_mod, cls, oracle_generated_members)
  return enumerate_methods(mod) unless generated_methodless_class?(name)

  oracle_gated_field_accessors(mod, target_mod, cls, oracle_generated_members)
end

# Drop the per-[module, class] Ruby-idiom accessors the reference records as
# plain instance attributes (SURFACE_MEMBER_DROPS). Applied after aliasing so the
# names being dropped are already in their reference spelling.
#
# ORACLE-GATED: a drop applies only while the oracle does NOT record that name as
# a surface member of that same class. The moment it does, the port MUST emit its
# reader — a strip would remove a capability the reference publishes, which is
# precisely what CONSTRUCTION-READBACK exists to catch. This makes the table
# self-retiring: no hand edit is needed when the oracle grows.
def drop_idiom_members(target_mod, cls, methods)
  drops = SURFACE_MEMBER_DROPS[[target_mod, cls]]
  return methods unless drops

  recorded = ORACLE_ALL_MEMBERS[[target_mod, cls]] || Set.new
  effective = drops.reject { |m| recorded.include?(m) }
  return methods if effective.empty?

  methods - effective
end

# Apply the per-[module, class] Ruby-idiom -> reference method-name aliases,
# plus the by-prefix skills alias (instance_key -> get_instance_key).
def apply_method_aliases(target_mod, cls, methods)
  table = SURFACE_METHOD_ALIASES[[target_mod, cls]] || {}
  if target_mod.start_with?('signalwire.skills.') && target_mod.end_with?('.skill')
    table = SKILLS_MODULE_METHOD_ALIASES.merge(table)
  end
  return methods if table.empty?

  methods.map { |m| table.fetch(m, m) }.uniq.sort
end

# Move `def self.X` class methods the reference exposes as MODULE functions off
# the class's method list and onto the reference module's functions[]. Returns
# the reduced method list.
def project_free_functions(ruby_fqn, methods, modules)
  spec = FREE_FUNCTION_PROJECTIONS[ruby_fqn]
  return methods unless spec

  target_mod, fn_names = spec
  present = fn_names & methods
  return methods if present.empty?

  merge_module_functions(modules, target_mod, present)
  methods - present
end

# Modules (not Classes): if they have singleton methods, those are Ruby module
# functions. Map them to a Python module's functions[] when we have a mapping;
# otherwise emit as a class-like entry so port-only modules (Runtime, Logging)
# still show up. Pure namespace modules with no functions are skipped.
def process_namespace_module(mod, name, modules)
  return if mod.singleton_methods(false).empty? && mod.instance_methods(false).empty?

  if RUBY_FREE_FUNCTION_MODULES.key?(name)
    merge_module_functions(modules, RUBY_FREE_FUNCTION_MODULES[name],
                           normalize_predicate_fns(enumerate_module_methods(mod)))
  elsif RUBY_MODULE_TO_PYTHON.key?(name)
    merge_module_functions(modules, RUBY_MODULE_TO_PYTHON[name], enumerate_module_methods(mod))
  else
    emit_port_only_module(mod, name, modules)
  end
end

# Port-only module with its own singleton methods: emit as a class-like entry
# (signalwire.runtime.Runtime etc.). These land in PORT_ADDITIONS.
def emit_port_only_module(mod, name, modules)
  modules[ruby_fqn_to_port_module(name)]['classes'][name.split('::').last] = enumerate_module_methods(mod)
end

def merge_module_functions(modules, target_mod, fns)
  target = modules[target_mod]
  target['functions'] = (target['functions'] + fns).uniq.sort
end

# Ruby predicate methods (`foo?`) map to the reference's plain name (`foo`)
# when the reference exposes the boolean helper without the `?` (the `?` is
# pure Ruby idiom). Used for module free functions like
# schema_utils.full_validation_available.
def normalize_predicate_fns(fns)
  fns.map { |f| f.end_with?('?') ? f[0..-2] : f }.uniq.sort
end

# Copy design-split donor methods (already reference-named) onto a target
# reference class. Runs after the object-space scan so the target class exists.
def apply_method_donors(modules)
  SURFACE_METHOD_DONORS.each do |(target_mod, target_cls), donors|
    entry = modules[target_mod] ||= { 'classes' => {}, 'functions' => [] }
    existing = entry['classes'][target_cls] || []
    donors.each { |(_ruby_fqn, meths)| existing = (existing + meths) }
    entry['classes'][target_cls] = existing.uniq.sort
  end
end

# Mixin projection: take selected methods off AgentBase and emit them under
# the canonical Python mixin module/class. Parallels the MIXIN_PROJECTIONS step
# in scripts/enumerate_signatures.py — the two tables must stay in sync.
def apply_mixin_projections(modules)
  ab_entry = modules['signalwire.core.agent_base']&.[]('classes')&.[]('AgentBase')
  return unless ab_entry

  MIXIN_PROJECTIONS.each do |(target_mod, target_cls), expected|
    project_mixin_methods(modules, ab_entry, target_mod, target_cls, expected)
  end
  modules['signalwire.core.agent_base']['classes'].delete('AgentBase') if ab_entry.empty?
end

# Move the methods in `expected` (that are present on AgentBase) onto the
# target mixin module/class, removing them from `ab_entry` so they don't
# double-count as port additions. A reference method `foo` matches AgentBase's
# Ruby-idiom predicate/bang variant (`foo?` / `foo!`) too — the projected
# surface records the reference name `foo`.
def project_mixin_methods(modules, ab_entry, target_mod, target_cls, expected)
  # Map each expected reference name to the AgentBase method that satisfies it
  # (exact, else the `?`/`!` idiom variant), then record under the reference name.
  matched_ref_names = expected.select { |ref| ab_variant_for(ab_entry, ref) }
  return if matched_ref_names.empty?

  record_projected_methods(modules, target_mod, target_cls, matched_ref_names)
  ab_variants = matched_ref_names.map { |ref| ab_variant_for(ab_entry, ref) }
  ab_entry.reject! { |m| ab_variants.include?(m) }
end

# Record `ref_names` under target_mod/target_cls, creating the module entry if
# absent and merging/sorting against any methods already there.
def record_projected_methods(modules, target_mod, target_cls, ref_names)
  modules[target_mod] ||= { 'classes' => {}, 'functions' => [] }
  classes = modules[target_mod]['classes']
  classes[target_cls] = ((classes[target_cls] || []) + ref_names).uniq.sort
end

# The AgentBase method name satisfying reference name `ref`: exact match, or
# the Ruby predicate (`ref?`) / bang (`ref!`) idiom variant. nil if absent.
def ab_variant_for(ab_entry, ref)
  return ref if ab_entry.include?(ref)
  return "#{ref}?" if ab_entry.include?("#{ref}?")
  return "#{ref}!" if ab_entry.include?("#{ref}!")

  nil
end

# Top-level signalwire functions (Ruby's top-level "def" equivalents). In Ruby,
# these are typically module-level singleton methods on the SignalWire module.
# The Python "signalwire" module exposes run_agent, start_agent, etc., which in
# Ruby don't exist as module functions yet — they're invoked via instance
# methods on AgentBase. So we emit the empty set for the base "signalwire"
# module if no functions are found; PORT_OMISSIONS accounts for the missing ones.
def add_toplevel_functions(modules)
  sig_funcs = SignalWire.singleton_methods(false).map(&:to_s).reject { |m| m.start_with?('_') }.sort
  return unless sig_funcs.any? || modules.key?('signalwire')

  modules['signalwire'] ||= { 'classes' => {}, 'functions' => [] }
  modules['signalwire']['functions'] = sig_funcs
end

def git_sha
  sha = `git -C #{REPO_ROOT} rev-parse HEAD 2>/dev/null`.strip
  sha.empty? ? 'N/A' : sha
end

def build_snapshot(python_surface_path)
  python_index = load_python_index(python_surface_path)
  oracle_generated_members = load_oracle_generated_members(python_surface_path)
  prime_oracle_gate(python_surface_path)
  load_all_lib_files
  mods = collect_modules(python_index, oracle_generated_members)
  snapshot_envelope(mods)
end

# The versioned envelope around the enumerated modules.
def snapshot_envelope(mods)
  {
    'version' => '1',
    'generated_from' => "signalwire-ruby @ #{git_sha}",
    'ruby_version' => RUBY_VERSION,
    'modules' => sort_modules(mods)
  }
end

# Fill ORACLE_ALL_MEMBERS, the gate for SURFACE_MEMBER_DROPS. Must run before
# any class is processed.
def prime_oracle_gate(python_surface_path)
  ORACLE_ALL_MEMBERS.replace(load_oracle_all_members(python_surface_path))
end

# Load all Ruby source files so every class/module is visible to ObjectSpace.
# We intentionally require each file under lib/signalwire/ so that a missing
# entry in lib/signalwire.rb doesn't silently shrink the surface.
def load_all_lib_files
  $LOAD_PATH.unshift(LIB_DIR.to_s) unless $LOAD_PATH.include?(LIB_DIR.to_s)
  require 'signalwire'
  Dir[LIB_DIR.join('signalwire/**/*.rb').to_s].each { |f| require f }
end

# Sort everything for deterministic output: modules by key, classes within
# each module by key, methods/functions as arrays of sorted strings.
def sort_modules(mods)
  sorted = {}
  mods.keys.sort.each do |k|
    entry = mods[k]
    sorted_classes = {}
    entry['classes'].keys.sort.each { |cls| sorted_classes[cls] = entry['classes'][cls] }
    sorted[k] = { 'classes' => sorted_classes, 'functions' => entry['functions'].sort }
  end
  sorted
end

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------
# Metadata fields that vary across runs/environments (commit SHA, interpreter
# version) and are not part of the structural surface. Excluded from --check.
META_FIELDS = %w[generated_from ruby_version].freeze

def strip_meta(obj)
  obj.except(*META_FIELDS)
end

def parse_options(argv)
  options = {
    output: nil,
    check: false,
    python_surface: PORTING_SDK_DEFAULT.join('python_surface.json')
  }
  option_parser(options).parse!(argv)
  options
end

def option_parser(options)
  OptionParser.new do |o|
    o.banner = 'Usage: ruby scripts/enumerate_surface.rb [options]'
    o.on('--output PATH', 'Write JSON to this path (default: stdout)') { |v| options[:output] = Pathname.new(v) }
    o.on('--check', 'Compare against --output; exit 1 on drift') { options[:check] = true }
    o.on('--python-surface PATH', 'Path to python_surface.json') { |v| options[:python_surface] = Pathname.new(v) }
    o.on('-h', '--help', 'Show this help') do
      puts o
      exit 0
    end
  end
end

# Compare the freshly rendered surface against the on-disk --output file.
# Returns a process exit code (0 fresh, 1 missing/stale).
def run_check(output_path, rendered)
  unless output_path.file?
    warn "error: #{output_path} does not exist"
    return 1
  end

  existing = JSON.parse(output_path.read)
  actual   = JSON.parse(rendered)
  return 0 if strip_meta(existing) == strip_meta(actual)

  warn 'DRIFT: port_surface.json is stale relative to lib/.'
  warn '  Regenerate: ruby scripts/enumerate_surface.rb --output port_surface.json'
  1
end

def main(argv)
  options = parse_options(argv)
  if options[:check] && options[:output].nil?
    warn 'error: --check requires --output'
    return 2
  end

  rendered = "#{JSON.pretty_generate(deep_sort(build_snapshot(options[:python_surface])))}\n"
  return run_check(options[:output], rendered) if options[:check]

  emit(options[:output], rendered)
  0
end

def emit(output_path, rendered)
  if output_path
    output_path.write(rendered)
  else
    $stdout.write(rendered)
  end
end

# JSON.pretty_generate doesn't recursively sort hash keys; the Python reference
# emits with sort_keys=True. Mirror that here.
def deep_sort(obj)
  case obj
  when Hash
    sorted = {}
    obj.keys.sort.each { |k| sorted[k] = deep_sort(obj[k]) }
    sorted
  when Array
    obj.map { |x| deep_sort(x) }
  else
    obj
  end
end

exit main(ARGV) if $PROGRAM_NAME == __FILE__
