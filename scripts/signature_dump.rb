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
require 'ripper'
require_relative '../lib/signalwire'

# ---------------------------------------------------------------------------
# DEFAULT-VALUE recovery (source parse, joined to reflection by source_location)
#
# ``Method#parameters`` reports that a default EXISTS (:opt / :key) but never
# what it IS -- the value is compiled away and the reflection API has no accessor
# for it. That is a hard limit of Ruby reflection, not an oversight:
#
#     class T; def m(a, b = 42, c: "hi"); end; end
#     T.instance_method(:m).parameters
#     #=> [[:req, :a], [:opt, :b], [:key, :c]]
#
# So a default VALUE can only come from the SOURCE. This pass parses every
# lib/**/*.rb with ``Ripper`` (stdlib -- deliberately NOT the ``prism`` /
# ``parser`` gems, which are present only transitively as rubocop dependencies
# and would be an undeclared dev dep) and indexes each ``def`` node's parameter
# defaults by ``[realpath, line]``.
#
# That pair is the join key because ``Method#source_location`` returns exactly
# the file and line of the ``def`` keyword, and Ripper's ``def`` node carries the
# same line for its method-name token. The join is therefore EXACT -- it needs no
# class/method name matching, so it cannot mis-attribute an overload, a
# same-named method on another class, or a method reached through include.
#
# LITERALS ONLY. A default that is a non-literal EXPRESSION (``SOME_CONST``,
# ``compute()``, ``other * 2``, an interpolated string) has no static value; this
# pass records ``nil`` for it rather than evaluating it or inventing one. Emitting
# a guessed value would be worse than emitting none -- it makes a correct port
# look defective, and "fixing" the port to match a wrong default can introduce a
# real defect. See DEFAULT_LITERAL_BLIND_SPOTS below for the exact list.
# ---------------------------------------------------------------------------

# Sentinel distinguishing "no static value recoverable" from a literal ``nil``
# default. ``def f(x = nil)`` genuinely defaults to nil and must be recorded as
# such; a default that is neither a literal nor a resolvable CONSTANT must not be
# recorded at all.
NO_STATIC_DEFAULT = Object.new.freeze

# A CONSTANT reference used as a default (``def f(fmt: RecordFormat::WAV)``).
#
# This is NOT a "non-static expression" -- a constant is exactly as fixed as an
# inline literal; writing ``format: RecordFormat::WAV`` instead of
# ``format: 'wav'`` is a readability choice, not a behavioural one. Dropping it
# reported five FunctionResult params (``record_call`` format/direction, ``tap``
# direction/codec, ``pay`` ai_response) as having no default when the reference
# records "wav"/"both"/"PCMU"/the pay prompt -- a correct port reading as drift.
#
# Resolution is DEFERRED rather than done during the source parse because the
# parse walks files with no lexical-scope tracking, so a bare ``WAV`` has no
# namespace to resolve against. The reflection side does: ``Method#owner`` is the
# exact module the ``def`` was written in, which is the lexical scope Ruby itself
# would use. So the parse records the reference and ``resolve_const_refs``
# resolves it against the owner's namespace chain (see ``const_lookup``).
ConstRef = Struct.new(:path)

# Convert a Ripper value sexp to its literal Ruby value, or NO_STATIC_DEFAULT
# when it is not a static literal.
#
# Handled: integers (incl. 0x/0b/underscored), floats, rationals/imaginaries,
# true/false/nil, strings (rejecting interpolation), symbols, and empty
# array/hash literals. Everything else -- constants, method calls, operators,
# ranges, non-empty collections -- is NOT a static value.
def ripper_literal(node)
  return NO_STATIC_DEFAULT unless node.is_a?(Array)

  case node[0]
  when :@int then ripper_integer(node[1])
  when :@float then ripper_float(node[1])
  # ``true``/``false``/``nil`` arrive as :var_ref/:vcall over a :@kw token; a
  # :var_ref over a :@const is a CONSTANT and falls through to the arm below.
  when :vcall then ripper_keyword_literal(node[1])
  when :var_ref
    kw = ripper_keyword_literal(node[1])
    kw.equal?(NO_STATIC_DEFAULT) ? ripper_const_ref(node) : kw
  when :string_literal then ripper_string_literal(node[1])
  when :symbol_literal then ripper_symbol_literal(node[1])
  # A bare word inside a %w[] / %i[] list -- Ripper emits the raw token with
  # no enclosing :string_literal.
  when :@tstring_content then node[1]
  when :array then ripper_array_literal(node[1])
  when :hash then ripper_hash_literal(node[1])
  # A namespaced CONSTANT (``RecordFormat::WAV`` / ``A::B::C`` / ``::A::B``) --
  # recorded as a deferred reference, resolved later against the owning module.
  when :const_path_ref, :top_const_ref then ripper_const_ref(node)
  else NO_STATIC_DEFAULT
  end
end

# Flatten a constant sexp to a dotted path, or NO_STATIC_DEFAULT when the node is
# not a pure constant chain. Only :@const links are accepted -- ``foo::BAR`` (a
# method call on the left) resolves at call time and is not statically known.
def ripper_const_ref(node)
  parts = flatten_const_path(node)
  return NO_STATIC_DEFAULT if parts.nil?

  ConstRef.new(parts)
end

def flatten_const_path(node)
  return nil unless node.is_a?(Array)

  case node[0]
  when :@const then [node[1]]
  when :var_ref, :top_const_ref then flatten_const_path(node[1])
  when :const_path_ref
    left = flatten_const_path(node[1])
    right = flatten_const_path(node[2])
    return nil if left.nil? || right.nil?

    left + right
  end
end

# Integer()/Float() rather than to_i/to_f: they honour 0x/0o/0b radix prefixes
# and ``_`` separators, where a bare to_i would silently turn "0x1f" into 0.
# (Kernel#Integer / Kernel#Float are METHODS, not callable objects -- they cannot
# be passed as a converter argument.)
def ripper_integer(token)
  Integer(token)
rescue ArgumentError, TypeError
  NO_STATIC_DEFAULT
end

def ripper_float(token)
  Float(token)
rescue ArgumentError, TypeError
  NO_STATIC_DEFAULT
end

# Only the true/false/nil KEYWORDS are literals. A :@const (SOME_CONST) or an
# :@ident (a local or method call) is not.
def ripper_keyword_literal(inner)
  return NO_STATIC_DEFAULT unless inner.is_a?(Array) && inner[0] == :@kw

  case inner[1]
  when 'true' then true
  when 'false' then false
  when 'nil' then nil
  else NO_STATIC_DEFAULT
  end
end

def ripper_string_literal(content)
  return NO_STATIC_DEFAULT unless content.is_a?(Array) && content[0] == :string_content

  parts = content[1..] || []
  # Any embedded expression (``"a#{x}b"``) means the value is computed at call
  # time. Ripper would otherwise hand back the concatenated static fragments
  # ("ab"), which is a FABRICATED value -- reject it.
  return NO_STATIC_DEFAULT unless parts.all? { |p| p.is_a?(Array) && p[0] == :@tstring_content }

  parts.map { |p| p[1] }.join
end

def ripper_symbol_literal(sym)
  return NO_STATIC_DEFAULT unless sym.is_a?(Array) && sym[0] == :symbol

  tok = sym[1]
  tok.is_a?(Array) ? tok[1].to_s : NO_STATIC_DEFAULT
end

# Resolve every element; ONE non-literal element makes the whole array
# non-static (a partially-reconstructed collection would be a fabricated value).
def ripper_array_literal(elements)
  return [] if elements.nil?
  return NO_STATIC_DEFAULT unless elements.is_a?(Array)

  out = []
  elements.each do |el|
    val = ripper_literal(el)
    return NO_STATIC_DEFAULT if val.equal?(NO_STATIC_DEFAULT)

    out << val
  end
  out
end

def ripper_hash_literal(assoclist)
  return {} if assoclist.nil?
  return NO_STATIC_DEFAULT unless assoclist.is_a?(Array) && assoclist[0] == :assoclist_from_args

  pairs = assoclist[1]
  return NO_STATIC_DEFAULT unless pairs.is_a?(Array)

  out = {}
  pairs.each do |pair|
    key, val = ripper_hash_pair(pair)
    return NO_STATIC_DEFAULT if key.equal?(NO_STATIC_DEFAULT) || val.equal?(NO_STATIC_DEFAULT)

    out[key] = val
  end
  out
end

# [key, value] for one ``k => v`` / ``k: v`` pair, either being
# NO_STATIC_DEFAULT when unresolvable. A ``**splat`` (:assoc_splat) is not a
# plain pair and makes the hash non-static.
def ripper_hash_pair(pair)
  return [NO_STATIC_DEFAULT, nil] unless pair.is_a?(Array) && pair[0] == :assoc_new

  key_node = pair[1]
  key =
    if key_node.is_a?(Array) && key_node[0] == :@label
      # ``k:`` shorthand -- the key is the SYMBOL :k, recorded as the bare name
      # to match how a symbol default is recorded above.
      key_node[1].to_s.chomp(':')
    else
      ripper_literal(key_node)
    end
  [key, ripper_literal(pair[2])]
end

# Extract {param_name => literal_value} for one Ripper ``params`` node.
# Only params that HAVE a recoverable literal default appear in the result.
def ripper_param_defaults(params_node)
  # ``def m(...)`` with parens wraps params in a :paren node.
  params_node = params_node[1] if params_node.is_a?(Array) && params_node[0] == :paren
  return {} unless params_node.is_a?(Array) && params_node[0] == :params

  # [:params, reqs, optionals, rest, post_reqs, keywords, kwrest, block]
  out = collect_defaults(params_node[2]) { |name_node| name_node[1].to_s }
  # Keyword label tokens are "name:" -- strip the trailing colon.
  out.merge(collect_defaults(params_node[5]) { |label_node| label_node[1].to_s.chomp(':') })
end

# Shared walk over an optionals/keywords list of [name_node, value_node] pairs.
# Only entries whose default resolves to a literal are returned.
def collect_defaults(entries)
  out = {}
  (entries || []).each do |name_node, value_node|
    next unless name_node.is_a?(Array)
    # A REQUIRED keyword (``f:``) has value_node == false -- no default at all.
    next if value_node == false || value_node.nil?

    val = ripper_literal(value_node)
    out[yield(name_node)] = val unless val.equal?(NO_STATIC_DEFAULT)
  end
  out
end

# [realpath, def_line] => {param_name => literal_default}, for every ``def`` in
# lib/. Built once; consulted per reflected method via #source_location.
def build_default_index
  index = {}
  Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].each do |path|
    sexp = parse_file(path)
    # A file Ripper cannot parse contributes no defaults; its params then stay
    # null, i.e. honestly unrecovered rather than wrong.
    next if sexp.nil?

    real = File.realpath(path)
    walk_sexp(sexp) do |node|
      line, params_node = def_node_parts(node)
      next if line.nil?

      defaults = ripper_param_defaults(params_node)
      index[[real, line]] = defaults unless defaults.empty?
    end
  end
  index
end

def parse_file(path)
  Ripper.sexp(File.read(path))
rescue StandardError
  nil
end

# [def_line, params_node] for a ``def``/``def self.`` node, or [nil, nil].
#   :def  => [:def, name_token, params, body]
#   :defs => [:defs, target, op, name_token, params, body]
def def_node_parts(node)
  name_tok, params_node =
    case node[0]
    when :def then [node[1], node[2]]
    when :defs then [node[3], node[4]]
    else return [nil, nil]
    end
  return [nil, nil] unless name_tok.is_a?(Array) && name_tok[2].is_a?(Array)

  [name_tok[2][0], params_node]
end

def walk_sexp(node, &block)
  return unless node.is_a?(Array)

  yield(node) if node[0].is_a?(Symbol)
  node.each { |child| walk_sexp(child, &block) }
end

DEFAULT_INDEX = build_default_index

# Literal defaults for this method, keyed by param name. Empty when the method
# has no source location (C-defined / dynamically defined via define_method) or
# no literal-valued defaults.
def defaults_for(meth)
  loc = begin
    meth.source_location
  rescue StandardError
    nil
  end
  return {} if loc.nil?

  DEFAULT_INDEX[[realpath_or_self(loc[0]), loc[1]]] || {}
end

def realpath_or_self(path)
  File.realpath(path)
rescue StandardError
  path
end

# Replace every deferred ConstRef with the constant's VALUE, resolved against the
# module the method was defined in. A reference that does not resolve, or that
# resolves to something that is not a JSON-representable scalar/collection (a
# Class, a Proc, an arbitrary object), is dropped back to NO_STATIC_DEFAULT --
# unrecovered rather than fabricated.
def resolve_const_refs(defaults, owner)
  out = {}
  defaults.each do |pname, val|
    resolved = val.is_a?(ConstRef) ? const_lookup(val.path, owner) : val
    out[pname] = resolved unless resolved.equal?(NO_STATIC_DEFAULT)
  end
  out
end

# Resolve a dotted constant path the way Ruby's own lexical lookup would: try the
# owning module first, then each enclosing namespace, then top level.
#
# ``Module#const_get`` with inherit:true already walks the ancestry, so the extra
# work here is walking OUTWARD through the enclosing namespaces -- which is what
# makes a bare ``WAV`` written inside ``SignalWire::Swaig::FunctionResult``
# resolve to ``SignalWire::Swaig::RecordFormat::WAV``'s sibling scope.
def const_lookup(path, owner)
  joined = path.join('::')
  namespaces_for(owner).each do |ns|
    return json_scalar(ns.const_get(joined))
  rescue NameError, TypeError
    next
  end
  NO_STATIC_DEFAULT
end

# [owner, each enclosing namespace ..., Object] for a module, by name.
def namespaces_for(owner)
  out = []
  name = owner.is_a?(Module) ? owner.name : nil
  if name
    parts = name.split('::')
    parts.length.downto(1) do |i|
      out << Object.const_get(parts[0, i].join('::'))
    rescue NameError, TypeError
      next
    end
  end
  out << Object
  out
end

# A constant's value, only when it is a plain JSON-representable value. Anything
# else (Class, Module, Proc, Struct, arbitrary object) has no meaningful default
# representation and is rejected rather than stringified.
def json_scalar(val)
  case val
  when String, Integer, Float, true, false, nil then val
  when Symbol then val.to_s
  when Array then if val.all? { |v| json_scalar(v) != NO_STATIC_DEFAULT }
                    val.map do |v|
                      json_scalar(v)
                    end
                  else
                    NO_STATIC_DEFAULT
                  end
  else NO_STATIC_DEFAULT
  end
end

def method_entry(meth, name, is_constructor:, is_static:)
  defaults = resolve_const_refs(defaults_for(meth), meth.owner)
  parameters = meth.parameters.map do |kind, pname|
    entry = { kind: kind.to_s, name: pname.to_s }
    # Emit ``default`` ONLY when a literal was actually recovered. Its ABSENCE
    # means "not recoverable", which the wrapper keeps as null -- distinct from a
    # recovered literal ``nil`` default, which is present with a nil value.
    entry[:default] = defaults[pname.to_s] if defaults.key?(pname.to_s)
    entry[:has_default] = defaults.key?(pname.to_s)
    entry
  end
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
