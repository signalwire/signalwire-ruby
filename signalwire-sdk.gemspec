# frozen_string_literal: true

require_relative 'lib/signalwire/version'

# Published as `signalwire-sdk` on RubyGems because the `signalwire`
# name belongs to the legacy SignalWire Ruby client (last released
# 2023-11-02 at v2.5.0, "Ruby client for Signalwire" — a different
# product from this AI Agents SDK). The library require path stays
# `require 'signalwire'`, so user code is unchanged.
Gem::Specification.new do |s|
  s.name        = 'signalwire-sdk'
  s.version     = SignalWire::VERSION
  s.summary     = 'SignalWire AI Agents SDK'
  s.description = 'A Ruby framework for building, deploying, and managing AI agents ' \
                  'as microservices that interact with the SignalWire platform.'
  s.authors     = ['SignalWire']
  s.email       = 'support@signalwire.com'
  s.homepage    = 'https://github.com/signalwire/signalwire-ruby'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.2'

  # Ship only the library + the one user-facing executable. The other bin/
  # scripts (emit-corpus, emit-skills, *-dump) are porting-audit tooling, not
  # part of the published gem — they stay tracked in-repo but out of the package.
  s.files = Dir['lib/**/*', 'README.md', 'LICENSE'] + ['bin/swaig-test']
  s.require_paths = ['lib']
  s.executables = ['swaig-test']

  # Runtime dependencies — keep minimal
  #
  # base64 + logger are stdlib libraries the SDK requires directly (base64 in the
  # Basic-auth path of every client — rest/http_client.rb, core/auth_handler.rb,
  # security/*, serverless/lambda_handler.rb, web/web_service.rb; logger in
  # server/agent_server.rb's fallback logger). Both were EXTRACTED from Ruby's
  # default gems (base64 since 3.4, logger since 3.5 — Gem::BUNDLED_GEMS::SINCE),
  # so on a modern Ruby under Bundler they are NOT present unless declared. Left
  # undeclared they only load by luck via a transitive dependency (base64 rides in
  # on websocket-client-simple; logger has no such backstop). Declare them so the
  # require resolves cleanly on every supported Ruby without a warning.
  s.add_dependency 'base64', '>= 0.1'
  s.add_dependency 'logger', '>= 1.4'
  s.add_dependency 'rack', '>= 2.0'
  s.add_dependency 'rackup', '>= 1.0'
  # tzinfo powers thread-safe, OS-tzdata-independent timezone resolution in the
  # datetime skill (no process-global ENV['TZ'] mutation).
  s.add_dependency 'tzinfo', '>= 2.0'
  s.add_dependency 'webrick', '>= 1.7'
  s.add_dependency 'websocket-client-simple', '>= 0.8'

  # Development dependencies are declared in the Gemfile (not here), per
  # RuboCop's Gemspec/DevelopmentDependencies: keeping them out of the gemspec
  # avoids imposing the test/lint toolchain on consumers who install the gem.
  s.metadata['rubygems_mfa_required'] = 'true'

  # Metadata URIs surfaced on the RubyGems gem page (source / changelog / docs /
  # bug tracker) — the standard discoverability links an A-grade gem ships so
  # `gem info` and rubygems.org link straight to the right places. homepage_uri
  # is already carried by s.homepage; duplicating it here just shadows itself.
  s.metadata['source_code_uri']   = 'https://github.com/signalwire/signalwire-ruby'
  s.metadata['changelog_uri']     = 'https://github.com/signalwire/signalwire-ruby/blob/main/CHANGELOG.md'
  s.metadata['documentation_uri'] = 'https://github.com/signalwire/signalwire-ruby/tree/main/docs'
  s.metadata['bug_tracker_uri']   = 'https://github.com/signalwire/signalwire-ruby/issues'
end
