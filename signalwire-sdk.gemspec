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
  s.description = 'A Ruby framework for building, deploying, and managing AI agents as microservices that interact with the SignalWire platform.'
  s.authors     = ['SignalWire']
  s.email       = 'support@signalwire.com'
  s.homepage    = 'https://github.com/signalwire/signalwire-ruby'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.2'

  s.files = Dir['lib/**/*', 'bin/*', 'README.md', 'LICENSE']
  s.require_paths = ['lib']
  s.executables = ['swaig-test']

  # Runtime dependencies — keep minimal
  s.add_dependency 'rack', '>= 2.0'
  s.add_dependency 'rackup', '>= 1.0'
  s.add_dependency 'webrick', '>= 1.7'
  s.add_dependency 'websocket-client-simple', '>= 0.8'

  # Development dependencies
  s.add_development_dependency 'minitest', '>= 5.0'
  s.add_development_dependency 'rake', '>= 13.0'
  s.add_development_dependency 'rack-test', '>= 2.0'
end
