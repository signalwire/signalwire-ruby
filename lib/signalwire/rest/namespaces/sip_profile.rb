# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # Project SIP profile (singleton resource).
      class SipProfileResource < BaseResource
        def initialize(http)
          super(http, '/api/relay/rest/sip_profile')
        end

        def get
          @http.get(@base_path)
        end

        def update(**kwargs)
          @http.put(@base_path, kwargs)
        end
      end
    end
  end
end
