# frozen_string_literal: true

module Signalwire::Blade
  class Connect < Message
    def initialize
      @payload = {
        method: 'blade.connect',
        params: {
          version: {
            major: 2,
            minor: 1,
            revision: 0
          },
          agent: "Ruby SDK/#{Signalwire::VERSION}"
        }
      }
    end
  end
end
