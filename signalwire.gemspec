# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'signalwire/version'

Gem::Specification.new do |spec|
  spec.name          = 'signalwire'
  spec.version       = Signalwire::VERSION
  spec.authors       = ['SignalWire Team']
  spec.email         = ['open.source@signalwire.com']

  spec.summary       = 'Ruby client for Signalwire'
  spec.homepage      = 'https://github.com/signalwire/signalwire-ruby'

  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|demos)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'bundler-audit', '~> 0.6.1'
  spec.add_development_dependency 'guard-rspec', '~> 4.7.3'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rdoc', '~> 6.1.1'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.67.2'
  spec.add_development_dependency 'ruby-prof', '~> 0.17.0'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'vcr', '~> 4.0.0'
  spec.add_development_dependency 'webmock', '~> 3.5.1'

  spec.add_dependency 'twilio-ruby', '~> 5.0'
  spec.add_dependency 'faye-websocket', '~> 0.10.9'
  spec.add_dependency 'concurrent-ruby', '~> 1.1.5'
  spec.add_dependency 'has-guarded-handlers', '~> 1.6.3'
  spec.add_dependency 'logger', '~> 1.3.0'
end
