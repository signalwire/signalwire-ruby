
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "signalwire/version"

Gem::Specification.new do |spec|
  spec.name          = "signalwire"
  spec.version       = Signalwire::VERSION
  spec.authors       = ["SignalWire Team"]
  spec.email         = ["open.source@signalwire.com"]

  spec.summary       = %q{Ruby client for Signalwire}
  spec.homepage      = "https://github.com/signalwire/signalwire-ruby"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|demos)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "ruby-prof"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "rubocop"

  spec.add_dependency "concurrent-ruby", "~> 1.0.5"
  spec.add_dependency "nio4r", "~> 2.3"
  spec.add_dependency "websocket-driver", "~> 0.7"
  spec.add_dependency "logging"
  spec.add_dependency "has-guarded-handlers"
  spec.add_dependency "twilio-ruby", "~> 5.0"
  spec.add_dependency "dotenv"
end
