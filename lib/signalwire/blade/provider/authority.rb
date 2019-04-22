module Signalwire::Blade::Provider
  class Authority
    def self.start(klass)
      command = Signalwire::Blade::AuthorityRequest.new
      klass.session.execute(command) do
        klass.session.on :incomingcommand, method: "blade.authenticate" do |payload|
          klass.dispatch(id: payload.id, method: payload.method, params: payload.params)
        end
      end
    end
  end
end
