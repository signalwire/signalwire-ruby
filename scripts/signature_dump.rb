#!/usr/bin/env ruby
# frozen_string_literal: true

# signature_dump.rb -- dump every public method's parameter list from the
# SignalWire Ruby SDK as JSON. Pipes into enumerate_signatures.py which
# applies the existing translation tables and emits port_signatures.json.
#
# Ruby is dynamically typed; Method#parameters gives us names + parameter
# kinds (req, opt, key, keyreq, rest, keyrest, block). We do NOT introspect
# YARD/.rbs metadata in v1 — the canonical type for every parameter is
# `any`, and the diff against Python is structural (param name + kind +
# count) rather than typed. PORT_SIGNATURE_OMISSIONS.md captures the
# typed divergence.

require 'json'
require_relative '../lib/signalwire'

def method_entry(meth, name, is_constructor:, is_static:)
  parameters = meth.parameters.map { |kind, pname| { kind: kind.to_s, name: pname.to_s } }
  { name: name, is_constructor: is_constructor, is_static: is_static, parameters: parameters }
end

# The explicit Class arm and the else fallback both yield 'class'; keeping the
# Class check separate documents the primary case (anything not a plain Module).
def module_kind(mod)
  if mod.is_a?(Class) && mod.instance_of?(Class)
    'class'
  elsif mod.is_a?(Module)
    'module'
  else
    'class'
  end
end

# Public instance methods declared on this class (not inherited).
def instance_method_entries(mod)
  return [] unless mod.is_a?(Class)

  entries = constructor_entry(mod)
  (mod.instance_methods(false).sort + composed_module_methods(mod)).each do |meth_name|
    next if meth_name == :initialize
    next if meth_name.to_s.start_with?('_')

    meth = mod.instance_method(meth_name)
    entries << method_entry(meth, meth_name.to_s, is_constructor: false, is_static: false)
  end
  entries
end

# Ruby LANGUAGE-PROTOCOL hooks — methods the interpreter or a core protocol
# (JSON, equality/Hash keying, Ruby-3 pattern matching, object printing) calls,
# not methods a caller invokes for a SignalWire capability. Never port surface.
# Kept in lockstep with RUBY_PROTOCOL_METHODS in scripts/enumerate_surface.rb.
RUBY_PROTOCOL_METHODS = %i[
  to_s to_json inspect hash eql? deconstruct deconstruct_keys
].freeze

# Modules that are pure INTERNAL COMPOSITION: a class `include`s them to reach
# their methods, but they are not themselves audited surface. Their members must
# therefore be attributed to the INCLUDING class, which is how a caller sees them.
# This is an EXPLICIT list rather than a reference to the surface enumerator's
# RUBY_EXCLUDED_CLASSES because this dump is a standalone Ruby script that shares
# no constants with it. Every entry must also be excluded there (and in
# enumerate_signatures.py's EXCLUDED_RUBY_CLASSES) — otherwise the module is BOTH
# its own audited symbol and lifted onto its includers, double-counting its
# members. Both current entries satisfy that. Adding an entry here means checking
# the other two tables.
COMPOSED_MODULES = %w[
  SignalWire::REST::Namespaces::Generated::ResourceTree
  SignalWire::Relay::MessageSerialization
].freeze

# Public instance methods a class reaches through `include` from a
# COMPOSED_MODULES module.
#
# The blind spot this closes: `instance_methods(false)` is DECLARED-ONLY.
# `RestClient` composes its 22 flat-resource / namespace-container accessors by
# including the generated `Namespaces::Generated::ResourceTree`
# (lib/signalwire/rest/rest_client.rb:42) rather than writing 22 `def`s, so all 22
# were invisible here — recorded as 1 of 23 members and reported as 22 missing
# symbols against a reference that records them all on `RestClient`. They were
# never missing; `client.calling` / `client.fabric` / `client.video` have always
# worked (pinned by tests/rest/resource_tree_accessors_mock_test.rb). This is the
# Ruby analog of `_wired_base_attributes` in porting-sdk's reference enumerator,
# which lifts members off a base the walker would otherwise miss.
#
# Scoped deliberately narrow, mirroring that precedent: only the explicitly listed
# non-surface modules are lifted (a module that is its own audited symbol would be
# double-counted), and language-protocol hooks are skipped.
def composed_module_methods(klass)
  klass.included_modules.flat_map do |mod|
    next [] unless COMPOSED_MODULES.include?(mod.name)

    mod.public_instance_methods(false).reject { |m| RUBY_PROTOCOL_METHODS.include?(m) }.sort
  end
end

def constructor_entry(mod)
  entries = []
  has_init = mod.method_defined?(:initialize, false) || mod.private_method_defined?(:initialize, false)
  return entries unless has_init

  begin
    meth = mod.instance_method(:initialize)
    entries << method_entry(meth, '<init>', is_constructor: true, is_static: false)
  rescue NameError
    # No initialize visible
  end
  entries
end

# Public singleton methods (class methods).
def singleton_method_entries(mod)
  mod.methods(false).sort.filter_map do |meth_name|
    next if meth_name.to_s.start_with?('_')

    method_entry(mod.method(meth_name), meth_name.to_s, is_constructor: false, is_static: true)
  end
end

# The SDK-internal superclass, when the class has one. Recorded so the
# construction contract (porting-sdk ALLOWLIST_DISCIPLINE.md §10) can follow a
# ``**opts``-to-``super`` forward: a Ruby subclass that splats the inherited
# keyword args accepts every one of them by name, but Method#parameters shows
# only the splat. Nil for non-classes and for anything outside SignalWire::.
def sdk_superclass(mod)
  return nil unless mod.is_a?(Class)

  sup = mod.superclass
  return nil if sup.nil?

  sup_name = sup.name
  return nil if sup_name.nil? || !sup_name.start_with?('SignalWire')

  sup_name
end

def type_entry(mod, name)
  methods = instance_method_entries(mod) + singleton_method_entries(mod)
  return nil if methods.empty?

  { full_name: name, short_name: name.split('::').last, kind: module_kind(mod),
    superclass: sdk_superclass(mod), methods: methods }
end

# Pre-load every .rb file under lib/ so reflection sees every class.
Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].each { |f| require f }

types = []
ObjectSpace.each_object(Module).each do |mod|
  name = mod.name
  next if name.nil?
  next unless name.start_with?('SignalWire')

  entry = type_entry(mod, name)
  types << entry if entry
end

# Stable sort
types.sort_by! { |t| t[:full_name] }
puts JSON.pretty_generate({ types: types })
