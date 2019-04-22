module Signalwire::Blade
  class ConnectRequest < Request
    attr_writer :project, :token

    def initialize(sessionid = nil)
      @id = new_id
      @sessionid = sessionid
      @project = Signalwire::Blade::EnvVars::SIGNALWIRE_API_PROJECT
      @token = Signalwire::Blade::EnvVars::SIGNALWIRE_API_TOKEN
    end

    def method
      'blade.connect'
    end

    def params
      base_params = {
        version: {
          major: 2,
          minor: 1,
          revision: 0,
        }
      }
      base_params[:sessionid] = @sessionid if @sessionid
      base_params.merge(extra_params)
    end

    private

    def extra_params
      return {} if @project.empty? || @token.empty?

      { authentication: { project: @project, token: @token } }
    end

  end
end
