#!/usr/bin/env ruby
# frozen_string_literal: true

# route_registry.rb -- enumerate the REST routes the Ruby SDK actually IMPLEMENTS.
#
# This is "Set B" for the cross-port SPEC-PARITY gate: the routes the live
# RestClient dispatches, captured from the REAL code path -- not parsed from
# source (a scraper would have to re-implement the CrudResource / base-path
# machinery and would drift) and not read from the test journal (which only
# sees routes that happen to be tested -- the exact spec-vs-implementation blind
# spot this gate exists to close).
#
# How: construct RestClient with a recording HttpClient that overrides the verb
# helpers to capture (method, path) and return {} instead of doing network I/O.
# Every route -- CRUD-base, custom create_token, deprecation-wrapped create,
# anything -- funnels through one of those verb methods. We then walk every
# namespace on the client, every public method on every resource, and invoke
# each with sentinel arguments. The path-param sentinel is normalized back to
# "{id}" so the captured template matches the spec's path_template.
#
# A method that cannot be invoked is NOT silently skipped -- a dropped method is
# a route missing from Set B, which would turn a real divergence into a false
# pass. Methods that do not map to a single canonical route go in REGISTRY_SKIP
# with a reason; anything else that raises on invocation is a hard error
# (recorded in "errors" + non-zero exit), mirroring python_route_registry.py.
#
# Output: pure JSON {"routes":[{method,path_template,via}],"skipped":[...],
# "errors":[...]} on stdout. Exit 1 if any uninvokable, un-skip-listed method
# (Set B incomplete). Run: ruby -Ilib scripts/route_registry.rb

require 'json'
require 'signalwire/rest/rest_client'

# Recording HttpClient: captures (verb, path) instead of doing network I/O.
# Subclasses the real HttpClient so any resource holding an @http behaves
# identically; the verb helpers are the single chokepoint every route hits.
class RecordingHttp < SignalWire::REST::HttpClient
  attr_reader :calls

  def initialize
    super('p', 't', 'example.signalwire.com')
    @calls = []
  end

  def get(path, _params = nil)
    record('GET', path)
  end

  def post(path, _body = nil)
    record('POST', path)
  end

  def put(path, _body = nil)
    record('PUT', path)
  end

  def patch(path, _body = nil)
    record('PATCH', path)
  end

  def delete(path)
    record('DELETE', path)
  end

  private

  def record(method, path)
    @calls << [method, path]
    {}
  end
end

# Enumerate the REST routes the Ruby SDK implements (Set B for SPEC-PARITY).
module RouteRegistry # rubocop:disable Metrics/ModuleLength
  # Sentinel for any path parameter -- one segment, no slash; normalized to {id}.
  SENTINEL = '__ID__'

  # Client ivars that are not walkable namespaces (credentials / the http itself).
  NON_NAMESPACE_IVARS = %w[project_id http].freeze

  # Methods that do NOT map to a single canonical REST route, keyed by
  # "<namespace>.<resource>.<method>" or a "<namespace>.<resource>.*" wildcard.
  # Every entry needs a reason; a method that merely raises is an ERROR, not an
  # implicit skip -- add it here (justified) or fix the harness so it invokes.
  # The generated CxmlApplications resource (base BaseResource, no create) omits
  # create entirely — there is no POST /cxml_applications canonical route
  # (mirrors python + typescript). The old raising-create scaffold that needed a
  # skip entry here is gone with the generated adoption, so no skips remain.
  REGISTRY_SKIP = {}.freeze

  # Client-side helper method names on any resource (no HTTP request; not wire
  # routes). `paginate` follows the cursor via the covered `list` route. Mirrors
  # python's SKIP_METHODS in porting-sdk/scripts/python_route_registry.py.
  SKIP_METHODS = { 'paginate' => 'client-side pagination helper over the covered list route (no HTTP itself)' }.freeze

  module_function

  # Build the live client with the recording http swapped onto every resource.
  # RestClient.new constructs its own HttpClient; we re-point each resource's
  # @http at the recorder afterwards (faithful + simpler than monkeypatching the
  # constructor).
  def build_client(rec)
    client = SignalWire::REST::RestClient.new(
      project: 'p', token: 't', host: 'example.signalwire.com'
    )
    each_resource(client) { |_ns, _name, res| res.instance_variable_set(:@http, rec) }
    client
  end

  # Yield [namespace_name, resource_name, resource] for every walkable resource
  # hanging off the client: flat resources exposed directly (phone_numbers,
  # calling, ...) and sub-resources nested inside namespace containers (fabric,
  # video, compat, ...).
  def each_resource(client)
    namespaces(client).each do |ns_name, ns|
      if resource?(ns)
        yield ns_name, ns_name, ns
      else
        sub_resources(ns).each { |res_name, res| yield ns_name, res_name, res }
      end
    end
  end

  # Public namespace attributes on the client: its non-internal ivars that hold
  # an object (a namespace container or a flat resource), not a credential.
  def namespaces(client)
    client.instance_variables.filter_map do |ivar|
      name = ivar.to_s.delete_prefix('@')
      val = client.instance_variable_get(ivar)
      [name, val] unless NON_NAMESPACE_IVARS.include?(name) || val.is_a?(String)
    end
  end

  # Resource instances nested inside a namespace container (its ivars).
  def sub_resources(namespace)
    namespace.instance_variables.filter_map do |ivar|
      val = namespace.instance_variable_get(ivar)
      [ivar.to_s.delete_prefix('@'), val] if resource?(val)
    end
  end

  def resource?(obj)
    obj.is_a?(SignalWire::REST::BaseResource)
  end

  # Public route methods on a resource: the methods its class hierarchy defines
  # down to (but not including) BaseResource. BaseResource itself only defines
  # initialize/_path (plumbing, not routes), so stopping there keeps the CRUD
  # mixins (CrudResource/CrudWithAddresses define list/create/get/update/delete)
  # and every concrete subclass method while dropping Object/Kernel noise.
  def route_methods(res)
    names = []
    res.class.ancestors.each do |mod|
      break if mod == SignalWire::REST::BaseResource

      names.concat(mod.public_instance_methods(false))
    end
    names.uniq.sort
  end

  # Invoke a method with sentinel args derived from its parameter list: each
  # required positional and each required keyword gets the path sentinel; opt /
  # rest / keyrest / optional-keyword params get nothing. Required keywords
  # (e.g. set_swml_webhook(sid, url:)) MUST be supplied or Ruby raises.
  def invoke(res, mname)
    method = res.method(mname)
    args = []
    kwargs = {}
    method.parameters.each do |kind, pname|
      case kind
      when :req then args << SENTINEL
      when :keyreq then kwargs[pname] = SENTINEL
      end
    end
    kwargs.empty? ? method.call(*args) : method.call(*args, **kwargs)
  end

  # A route's REGISTRY_SKIP reason: exact "<ns>.<res>.<method>" or the
  # "<ns>.<res>.*" wildcard; nil if the method is not skip-listed.
  def skip_reason(key)
    REGISTRY_SKIP[key] ||
      REGISTRY_SKIP["#{key.rpartition('.').first}.*"] ||
      SKIP_METHODS[key.rpartition('.').last]
  end

  def build
    rec = RecordingHttp.new
    client = build_client(rec)
    acc = { routes: [], skipped: [], errors: [] }
    each_resource(client) do |ns_name, res_name, res|
      route_methods(res).each do |mname|
        capture_method(rec, acc, res, "#{ns_name}.#{res_name}.#{mname}", mname)
      end
    end
    finalize(acc[:routes], acc[:skipped], acc[:errors])
  end

  # Invoke one resource method and fold its outcome into the accumulator: a
  # declared skip, a captured route per HTTP call, or an error (raised, or
  # ran-but-issued-no-request -- both mean Set B can't trust this method).
  def capture_method(rec, acc, res, key, mname)
    reason = skip_reason(key)
    return acc[:skipped] << { key: key, reason: reason } if reason

    rec.calls.clear
    err = run_method(res, mname, rec)
    return acc[:errors] << { key: key, error: err } if err

    rec.calls.each do |verb, raw_path|
      acc[:routes] << { method: verb, path_template: raw_path.gsub(SENTINEL, '{id}'), via: key }
    end
  end

  # Invoke the method; return nil on success, else an error string. A method
  # that ran but issued no HTTP request is also an error (a public route method
  # that hits no chokepoint is a client-side helper that belongs in REGISTRY_SKIP).
  def run_method(res, mname, rec)
    invoke(res, mname)
    return nil unless rec.calls.empty?

    'invoked but issued no HTTP request (client-side helper? add to REGISTRY_SKIP with a reason)'
  rescue StandardError, NotImplementedError => e
    "#{e.class}: #{e.message}"
  end

  # De-dup identical (method, path) -- several accessors can reach the same
  # canonical route; record the route once with all its `via` accessors.
  def finalize(routes, skipped, errors)
    by_route = {}
    routes.each do |r|
      key = "#{r[:method]} #{r[:path_template]}"
      existing = by_route[key]
      existing ? (existing[:via] << r[:via]) : (by_route[key] = { **r, via: [r[:via]] })
    end
    deduped = by_route.values.sort_by { |r| [r[:path_template], r[:method]] }
    { routes: deduped, skipped: skipped, errors: errors }
  end
end

if __FILE__ == $PROGRAM_NAME
  result = RouteRegistry.build
  puts JSON.pretty_generate(result)
  exit(result[:errors].empty? ? 0 : 1)
end
