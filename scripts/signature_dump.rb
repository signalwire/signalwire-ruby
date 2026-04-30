#!/usr/bin/env ruby
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
require 'set'
require_relative '../lib/signalwire'

# Pre-load every .rb file under lib/ so reflection sees every class.
Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].sort.each { |f| require f }

types = []
ObjectSpace.each_object(Module).each do |mod|
  name = mod.name
  next if name.nil?
  next unless name.start_with?('SignalWire')

  kind = if mod.is_a?(Class) && mod.instance_of?(Class)
           'class'
         elsif mod.is_a?(Module)
           'module'
         else
           'class'
         end

  methods = []

  # Public instance methods declared on this class (not inherited).
  if mod.is_a?(Class)
    # Constructor (the `initialize` method)
    if mod.instance_methods(false).include?(:initialize) ||
       mod.private_instance_methods(false).include?(:initialize)
      begin
        m = mod.instance_method(:initialize)
        methods << method_entry(m, '<init>', is_constructor: true, is_static: false)
      rescue NameError
        # No initialize visible
      end
    end
    mod.instance_methods(false).sort.each do |meth_name|
      next if meth_name == :initialize
      next if meth_name.to_s.start_with?('_')
      m = mod.instance_method(meth_name)
      methods << method_entry(m, meth_name.to_s, is_constructor: false, is_static: false)
    end
  end

  # Public singleton methods (class methods)
  mod.methods(false).sort.each do |meth_name|
    next if meth_name.to_s.start_with?('_')
    m = mod.method(meth_name)
    methods << method_entry(m, meth_name.to_s, is_constructor: false, is_static: true)
  end

  next if methods.empty?

  types << {
    full_name: name,
    short_name: name.split('::').last,
    kind: kind,
    methods: methods,
  }
end

# Stable sort
types.sort_by! { |t| t[:full_name] }
puts JSON.pretty_generate({ types: types })

BEGIN {
  def method_entry(m, name, is_constructor:, is_static:)
    parameters = m.parameters.map do |kind, pname|
      {
        kind: kind.to_s,
        name: pname.to_s,
      }
    end
    {
      name: name,
      is_constructor: is_constructor,
      is_static: is_static,
      parameters: parameters,
    }
  end
}
