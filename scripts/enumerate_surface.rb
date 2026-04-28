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
#   1. $PORTING_SDK_PATH (env override)
#   2. ./porting-sdk     (CI layout — checked out as a sibling under repo root)
#   3. ../porting-sdk    (local layout — sibling of signalwire-ruby)
def find_default_porting_sdk
  env = ENV['PORTING_SDK_PATH']
  return Pathname.new(env) if env && !env.empty?

  [REPO_ROOT.join('porting-sdk'), REPO_ROOT.parent.join('porting-sdk')].each do |p|
    return p if p.directory?
  end
  REPO_ROOT.join('porting-sdk') # fall through; the file-existence check fails loudly later
end

PORTING_SDK_DEFAULT = find_default_porting_sdk

# -----------------------------------------------------------------------------
# Python class -> module index. Loaded from python_surface.json so we can look
# up the canonical module for each class in the port. If a Ruby class name has
# an exact match in Python, we use the Python module. If it doesn't (port-only
# classes like Runtime, LambdaHandler, Logging::Logger), we fall back to a
# translation of the Ruby namespace.
# -----------------------------------------------------------------------------
def load_python_index(python_surface_path)
  unless python_surface_path.file?
    abort <<~MSG
      error: python_surface.json not found at #{python_surface_path}
        The script needs the canonical Python surface to map Ruby classes onto
        Python module paths. Without it the output is not comparable against
        python_surface.json and the Layer B audit will fail.
        Pass --python-surface PATH or set PORTING_SDK_PATH.
    MSG
  end

  data = JSON.parse(python_surface_path.read)
  index = {}
  data.fetch('modules', {}).each do |mod, entry|
    entry.fetch('classes', {}).each_key do |cls|
      (index[cls] ||= []) << mod
    end
  end
  index
end

# When a class name has multiple Python modules or when Ruby's class name
# doesn't match Python's exactly, we need an explicit override. Keys are
# fully-qualified Ruby names; values are the canonical Python module.
#
# Ruby name -> Python module (the class name gets translated via
# RUBY_TO_PYTHON_CLASS_ALIASES below if it differs).
RUBY_TO_PYTHON_MODULE_OVERRIDES = {
  # AgentServer is duplicated in Python (agent_server + livewire). The Ruby
  # port matches the standalone agent_server.
  'SignalWire::AgentServer' => 'signalwire.agent_server',
  # SessionManager is duplicated in Python (core.security + mcp_gateway). The
  # Ruby port only ships the core one.
  'SignalWire::Security::SessionManager' => 'signalwire.core.security.session_manager',
  # Prefabs: Ruby uses short names, Python appends "Agent".
  'SignalWire::Prefabs::Concierge' => 'signalwire.prefabs.concierge',
  'SignalWire::Prefabs::FaqBot' => 'signalwire.prefabs.faq_bot',
  'SignalWire::Prefabs::InfoGatherer' => 'signalwire.prefabs.info_gatherer',
  'SignalWire::Prefabs::Receptionist' => 'signalwire.prefabs.receptionist',
  'SignalWire::Prefabs::Survey' => 'signalwire.prefabs.survey',
  # Built-in skills that don't match Python names 1:1.
  'SignalWire::Skills::Builtin::SwmlTransferSkill' => 'signalwire.skills.swml_transfer.skill',
  'SignalWire::Skills::Builtin::McpGatewaySkill' => 'signalwire.skills.mcp_gateway.skill',
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
}.freeze

# Ruby module -> Python module mapping for module-level functions.
# When we find singleton methods on a Ruby module, we emit them under the
# Python-reference module path (not the Ruby namespace fallback).
RUBY_MODULE_TO_PYTHON = {
  # SignalWire::Relay.parse_event -> Python's signalwire.relay.event.parse_event
  # (Ruby hoists it one level up to avoid a dedicated relay_event module).
  'SignalWire::Relay' => 'signalwire.relay.event',
}.freeze

# Ruby class name -> Python class name (when they differ).
RUBY_TO_PYTHON_CLASS_ALIASES = {
  'SignalWire::Prefabs::Concierge' => 'ConciergeAgent',
  'SignalWire::Prefabs::FaqBot' => 'FAQBotAgent',
  'SignalWire::Prefabs::InfoGatherer' => 'InfoGathererAgent',
  'SignalWire::Prefabs::Receptionist' => 'ReceptionistAgent',
  'SignalWire::Prefabs::Survey' => 'SurveyAgent',
  'SignalWire::Skills::Builtin::SwmlTransferSkill' => 'SWMLTransferSkill',
  'SignalWire::Skills::Builtin::McpGatewaySkill' => 'MCPGatewaySkill',
  'SignalWire::Skills::Builtin::DatasphereSkill' => 'DataSphereSkill',
  'SignalWire::Skills::Builtin::DatasphereServerlessSkill' => 'DataSphereServerlessSkill',
  # Ruby Relay::Client maps to Python RelayClient.
  'SignalWire::Relay::Client' => 'RelayClient',
}.freeze

# Ruby SWML classes (Document/Schema/Service) are consolidated wrappers that
# do not have exact Python counterparts — Python splits the same surface
# across SWMLBuilder, SwmlRenderer, SchemaUtils, and SWMLService. We emit
# these under Ruby-namespaced module paths (signalwire.swml.*) so they show
# up as port additions; the Python classes are recorded as omissions with
# rationale. This surfaces the design delta honestly rather than hiding it
# behind fuzzy renames.
RUBY_SWML_MODULE_OVERRIDES = {}.freeze

# Nested helper/middleware classes we don't want in the surface (they're
# internal plumbing, not public API).
RUBY_EXCLUDED_CLASSES = %w[
  SignalWire::AgentBase::AgentBodyLimitMiddleware
  SignalWire::AgentBase::AgentSecurityHeadersMiddleware
  SignalWire::AgentBase::AgentTimingSafeBasicAuth
  SignalWire::SWML::Service::SecurityHeadersMiddleware
  SignalWire::SWML::Service::TimingSafeBasicAuth
  SignalWire::Logging::Logger
  SignalWire::REST::Namespaces
].freeze

# -----------------------------------------------------------------------------
# Name translation
# -----------------------------------------------------------------------------
def snake_case(camel)
  camel
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .downcase
end

# Translate a fully-qualified Ruby name to the Python-reference dotted module
# + class name. Returns [module_path, class_name].
def translate_class(ruby_fqn, python_index)
  # 1. Explicit override wins.
  if RUBY_TO_PYTHON_MODULE_OVERRIDES.key?(ruby_fqn)
    mod = RUBY_TO_PYTHON_MODULE_OVERRIDES[ruby_fqn]
    cls = RUBY_TO_PYTHON_CLASS_ALIASES[ruby_fqn] || ruby_fqn.split('::').last
    return [mod, cls]
  end

  # 2. SWML-specific mapping.
  if RUBY_SWML_MODULE_OVERRIDES.key?(ruby_fqn)
    return [RUBY_SWML_MODULE_OVERRIDES[ruby_fqn], ruby_fqn.split('::').last]
  end

  cls = ruby_fqn.split('::').last

  # 3. Ruby class name matches a Python class name uniquely -> use Python mod.
  if python_index.key?(cls) && python_index[cls].length == 1
    return [python_index[cls].first, cls]
  end

  # 4. No Python match -> translate Ruby namespace to dotted snake_case path,
  # emitting under a signalwire.* module. Port-only additions show up in
  # PORT_ADDITIONS.md.
  #
  # Python uses per-file module paths (signalwire.core.agent_base.AgentBase),
  # so for Ruby we append snake_case(class_name) to the namespace segments —
  # that matches Ruby's convention of one class per file (agent_base.rb holds
  # SignalWire::AgentBase). This keeps port-only classes in distinct modules
  # rather than collapsing them into their parent namespace.
  parts = ruby_fqn.split('::').map { |p| snake_case(p) }
  # SignalWire -> signalwire
  parts[0] = 'signalwire'
  # Drop the class name segment and append it as the final module segment
  # (so SignalWire::Runtime -> signalwire.runtime, and
  #  SignalWire::SWML::Document -> signalwire.swml.document).
  mod_parts = parts[0..-2] + [snake_case(cls)]
  [mod_parts.join('.'), cls]
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
  seen = {}
  mod.singleton_methods(false).map(&:to_s).each do |m|
    next if m.start_with?('_') && !m.start_with?('__')
    next if m.end_with?('=')
    seen[m] = true
  end
  seen.keys.sort
end

# -----------------------------------------------------------------------------
# Enumerate public methods of a Ruby class.
#
# public_instance_methods(false) already excludes private and protected; we
# only add "initialize" back (it's private by default in Ruby) since it maps
# to Python's __init__.
# -----------------------------------------------------------------------------
def enumerate_methods(klass)
  raw = []
  raw.concat(klass.public_instance_methods(false).map(&:to_s))
  # Class methods (Python module-level "classmethod"/"staticmethod" show up as
  # methods on the class too).
  raw.concat(klass.singleton_methods(false).map(&:to_s))
  # initialize is private by default — include it explicitly.
  raw << 'initialize' if klass.private_instance_methods(false).include?(:initialize)

  seen = {}
  raw.each do |m|
    # Skip single-underscore-prefixed methods (Python convention mirrored).
    next if m.start_with?('_') && !m.start_with?('__')
    # Skip auto-generated writer methods (attr_writer/attr_accessor). The
    # Python surface file doesn't emit setters either.
    next if m.end_with?('=')
    # Keep `?`- and `!`-suffixed method names as-is. Ruby predicate
    # methods (has_skill?) and bang methods (reset!) are idiomatic; they
    # show up as port additions (Python has no equivalent, so they end up
    # in PORT_ADDITIONS.md with the Ruby-idiom rationale).
    name = m == 'initialize' ? '__init__' : m
    seen[name] = true
  end
  seen.keys.sort
end

# -----------------------------------------------------------------------------
# Gather everything.
# -----------------------------------------------------------------------------
def collect_modules(python_index)
  # Modules in the final snapshot. Each entry: {"classes" => {...}, "functions" => [...]}.
  modules = Hash.new { |h, k| h[k] = { 'classes' => {}, 'functions' => [] } }

  seen_classes = {}
  ObjectSpace.each_object(Module) do |m|
    name = m.name
    next unless name && name.start_with?('SignalWire')
    # ObjectSpace yields modules and classes; skip anonymous and the top-level
    # SignalWire module itself.
    next if name == 'SignalWire'
    next if seen_classes[name]
    seen_classes[name] = true

    # Skip excluded internal classes (middlewares, nested helpers).
    next if RUBY_EXCLUDED_CLASSES.include?(name)

    # Skip private constants (class name starts with `_`).
    leaf = name.split('::').last
    next if leaf.start_with?('_')

    # Modules (not Classes): if they have singleton methods, those are
    # Ruby module functions. Map them to a Python module's functions[]
    # when we have a mapping; otherwise emit as a class-like entry so
    # port-only modules (Runtime, Logging) still show up.
    unless m.is_a?(Class)
      # Skip pure namespace modules with no functions of their own.
      if m.singleton_methods(false).empty? && m.instance_methods(false).empty?
        next
      end

      if RUBY_MODULE_TO_PYTHON.key?(name)
        target_mod = RUBY_MODULE_TO_PYTHON[name]
        fns = m.singleton_methods(false).map(&:to_s)
              .reject { |meth| meth.start_with?('_') && !meth.start_with?('__') }
              .reject { |meth| meth.end_with?('=') }
              .sort
        modules[target_mod]['functions'] = (modules[target_mod]['functions'] + fns).uniq.sort
        next
      end

      # Port-only module with its own singleton methods: emit as a class-like
      # entry (signalwire.runtime.Runtime etc.). These land in PORT_ADDITIONS.
      mod_path = ruby_fqn_to_port_module(name)
      modules[mod_path]['classes'][leaf] = enumerate_module_methods(m)
      next
    end

    mod, cls = translate_class(name, python_index)
    methods = enumerate_methods(m)
    modules[mod]['classes'][cls] = methods
  end

  # Top-level signalwire functions (Ruby's top-level "def" equivalents). In
  # Ruby, these are typically module-level singleton methods on the SignalWire
  # module. The Python "signalwire" module exposes run_agent, start_agent,
  # etc., which in Ruby don't exist as module functions yet — they're invoked
  # via instance methods on AgentBase. So we emit the empty set for the base
  # "signalwire" module if no functions are found; PORT_OMISSIONS accounts
  # for the missing ones.
  sig_funcs = SignalWire.singleton_methods(false).map(&:to_s).reject { |m| m.start_with?('_') }.sort
  if sig_funcs.any? || modules.key?('signalwire')
    modules['signalwire'] ||= { 'classes' => {}, 'functions' => [] }
    modules['signalwire']['functions'] = sig_funcs
  end

  # Drop modules that ended up completely empty after filtering (no classes,
  # no functions) — matches the Python enumerator's behaviour.
  modules.reject { |_k, v| v['classes'].empty? && v['functions'].empty? }
end

def git_sha
  sha = `git -C #{REPO_ROOT} rev-parse HEAD 2>/dev/null`.strip
  sha.empty? ? 'N/A' : sha
end

def build_snapshot(python_surface_path)
  python_index = load_python_index(python_surface_path)

  # Load all Ruby source files so every class/module is visible to ObjectSpace.
  # We intentionally require each file under lib/signalwire/ so that a missing
  # entry in lib/signalwire.rb doesn't silently shrink the surface.
  $LOAD_PATH.unshift(LIB_DIR.to_s) unless $LOAD_PATH.include?(LIB_DIR.to_s)
  require 'signalwire'
  Dir[LIB_DIR.join('signalwire/**/*.rb').to_s].sort.each { |f| require f }

  mods = collect_modules(python_index)

  # Sort everything for deterministic output: modules by key, classes within
  # each module by key, methods/functions as arrays of sorted strings.
  sorted = {}
  mods.keys.sort.each do |k|
    entry = mods[k]
    sorted_classes = {}
    entry['classes'].keys.sort.each do |cls|
      sorted_classes[cls] = entry['classes'][cls]
    end
    sorted[k] = {
      'classes'   => sorted_classes,
      'functions' => entry['functions'].sort
    }
  end

  {
    'version'        => '1',
    'generated_from' => "signalwire-ruby @ #{git_sha}",
    'ruby_version'   => RUBY_VERSION,
    'modules'        => sorted
  }
end

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------
# Metadata fields that vary across runs/environments (commit SHA, interpreter
# version) and are not part of the structural surface. Excluded from --check.
META_FIELDS = %w[generated_from ruby_version].freeze

def strip_meta(obj)
  obj.reject { |k, _| META_FIELDS.include?(k) }
end

def main(argv)
  options = {
    output:         nil,
    check:          false,
    python_surface: PORTING_SDK_DEFAULT.join('python_surface.json')
  }
  OptionParser.new do |o|
    o.banner = 'Usage: ruby scripts/enumerate_surface.rb [options]'
    o.on('--output PATH', 'Write JSON to this path (default: stdout)') { |v| options[:output] = Pathname.new(v) }
    o.on('--check', 'Compare against --output; exit 1 on drift') { options[:check] = true }
    o.on('--python-surface PATH', 'Path to python_surface.json') { |v| options[:python_surface] = Pathname.new(v) }
    o.on('-h', '--help', 'Show this help') { puts o; exit 0 }
  end.parse!(argv)

  if options[:check] && options[:output].nil?
    warn 'error: --check requires --output'
    return 2
  end

  snapshot = build_snapshot(options[:python_surface])
  rendered = JSON.pretty_generate(deep_sort(snapshot)) + "\n"

  if options[:check]
    unless options[:output].file?
      warn "error: #{options[:output]} does not exist"
      return 1
    end
    existing = JSON.parse(options[:output].read)
    actual   = JSON.parse(rendered)
    if strip_meta(existing) != strip_meta(actual)
      warn 'DRIFT: port_surface.json is stale relative to lib/.'
      warn '  Regenerate: ruby scripts/enumerate_surface.rb --output port_surface.json'
      return 1
    end
    return 0
  end

  if options[:output]
    options[:output].write(rendered)
  else
    $stdout.write(rendered)
  end
  0
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
