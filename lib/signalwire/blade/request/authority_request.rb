module Signalwire::Blade
  class AuthorityRequest < Request
    def initialize
      # TODO: handle "remove" request
      super(method, { command: "add" })
    end

    def method
      "blade.authority"
    end
  end
end
