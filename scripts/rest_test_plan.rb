#!/usr/bin/env ruby
# frozen_string_literal: true

# rest_test_plan.rb -- per-`via` call plan for the REST wire-test generator.
#
# Companion capture to scripts/route_registry.rb. route_registry.rb answers
# "which (method, path) routes does the SDK implement" (deduped, via-merged) for
# the SPEC-PARITY gate; this script answers the sibling question the TEST
# generator (scripts/generate_rest_tests.py) needs: for EVERY `via` accessor
# method, what is the exact Ruby call expression that reaches it AND what
# sentinel arguments must be passed. It is the Ruby realisation of the reflection
# the go/ts/php generators do in their own language (route_registry.php +
# rest_test_plan.php in PHP, buildCallIndex in go, SignatureResolver in ts).
#
# It REUSES route_registry.rb's live-client walk (RecordingHttp, each_resource,
# route_methods, invoke) so the plan can never drift from the registry's route
# set. For each route method it records, per `via`:
#   - via     : "<ns>.<res>.<member>" -- identical to route_registry.rb's via
#               strings, so the generator joins registry routes -> spec
#               operationId -> this plan by via with no ambiguity.
#   - method  : the HTTP verb captured from the recording client.
#   - path    : the captured path template (params already {id}).
#   - chain   : the ordered accessor call chain to reach the method off the
#               client -- ["video","rooms"] for video.rooms.get, or ["calling"]
#               for the flat calling.calling.dial (the leading duplicate
#               namespace segment is collapsed, mirroring go/ts/php attrPath).
#   - member  : the route method name (get, create, list_streams, ...).
#   - args    : the ordered Ruby literal argument tokens for the method's
#               REQUIRED params -- a required positional (:req) becomes 'x'
#               (a valid one-segment path id), a required keyword (:keyreq)
#               becomes `name: 'x'` (a valid closed-param body value). Optional
#               (:key / :opt) and rest (:rest / :keyrest) params are omitted.
#               Ruby is dynamically typed and every closed required field the
#               SDK exposes is string-shaped at the wire (path id or body
#               string), so a single 'x' sentinel is type-faithful for all of
#               them -- proven by route_registry.rb invoking every route with the
#               same string sentinel and reporting zero capture errors.
#
# Output: JSON {"plan":[{via,method,path,chain,member,args}],"errors":[...]} on
# stdout. Exit 1 if any route method could not be reflected (never silently
# dropped -- a dropped via is a hole in the generated suite). Mirrors
# route_registry.rb's fail-loud contract.
#
# Run: ruby -Ilib scripts/route_registry_plan.rb   (via generate_rest_tests.py)

require 'json'
require_relative 'route_registry'

# Build the per-`via` call plan by reusing RouteRegistry's live-client walk.
module RestTestPlan
  # The literal Ruby sentinel for a required string arg -- a valid one-segment
  # path id AND a valid closed-param body string.
  ARG = "'x'"

  module_function

  # Collapse a leading duplicate accessor segment, mirroring go/ts/php attrPath:
  # a flat namespace's chain is [calling, calling] -> [calling]; a container
  # chain [video, rooms] is unchanged.
  def collapse_chain(chain)
    chain.length >= 2 && chain[0] == chain[1] ? chain.drop(1) : chain
  end

  # Ruby literal argument tokens for a method's REQUIRED params. A required
  # positional (:req) -> 'x'; a required keyword (:keyreq) -> `pname: 'x'`.
  # Optional / rest / keyrest params are omitted. Order preserved so the emitted
  # call is `member('x', 'x', kw: 'x')` -- positionals first, then keywords.
  def arg_tokens(method)
    positional = []
    keyword = []
    method.parameters.each do |kind, pname|
      case kind
      when :req then positional << ARG
      when :keyreq then keyword << "#{pname}: #{ARG}"
      end
    end
    positional + keyword
  end

  def build
    rec = RecordingHttp.new
    client = RouteRegistry.build_client(rec)
    acc = { plan: [], errors: [] }
    RouteRegistry.each_resource(client) do |ns_name, res_name, res|
      RouteRegistry.route_methods(res).each do |mname|
        via = "#{ns_name}.#{res_name}.#{mname}"
        # A method route_registry.rb skips (REGISTRY_SKIP) dispatches no single
        # canonical route, so it is not covered -- skip it here too.
        record_via(rec, acc, res, via, ns_name, res_name, mname) unless RouteRegistry.skip_reason(via)
      end
    end
    acc
  end

  # Reflect + invoke one route method; append its plan entry, or an error if it
  # cannot be invoked / issues no request (mirrors route_registry.rb's contract).
  def record_via(rec, acc, res, via, ns_name, res_name, mname)
    rec.calls.clear
    err = RouteRegistry.run_method(res, mname, rec)
    return acc[:errors] << { via: via, error: err } if err

    verb, raw_path = rec.calls.first
    acc[:plan] << {
      via: via, method: verb, path: raw_path.gsub(RouteRegistry::SENTINEL, '{id}'),
      chain: collapse_chain([ns_name, res_name]), member: mname, args: arg_tokens(res.method(mname))
    }
  end
end

if __FILE__ == $PROGRAM_NAME
  result = RestTestPlan.build
  puts JSON.pretty_generate(result)
  exit(result[:errors].empty? ? 0 : 1)
end
