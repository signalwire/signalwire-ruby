module Signalwire::Blade
  module EnvVars
    BLADE_ADDRESS = ENV.fetch("BLADE_ADDRESS", nil).to_s
    BLADE_SSL_KEY = ENV.fetch("BLADE_SSL_KEY", nil).to_s
    BLADE_SSL_CHAIN = ENV.fetch("BLADE_SSL_CHAIN", nil).to_s
    CERTIFIED = !BLADE_SSL_KEY.empty? && !BLADE_SSL_KEY.empty?
    SIGNALWIRE_API_PROJECT = ENV.fetch("SIGNALWIRE_API_PROJECT", nil).to_s
    SIGNALWIRE_API_TOKEN = ENV.fetch("SIGNALWIRE_API_TOKEN", nil).to_s
  end
end
