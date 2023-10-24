# frozen_string_literal: true

require 'rack/media_type'

module Rack

  class SwWebhookAuthentication

    FORM_URLENCODED_MEDIA_TYPE = Rack::MediaType.type('application/x-www-form-urlencoded')

    def initialize(app, private_key, *paths, &private_key_lookup)
      @app = app
      @private_key = private_key
      define_singleton_method(:get_private_key, private_key_lookup) if block_given?
      @path_regex = Regexp.union(paths)
    end

    def call(env)
      return @app.call(env) unless env['PATH_INFO'].match(@path_regex)
      request = Rack::Request.new(env)
      original_url = request.url
      params = extract_params!(request)
      private_key = @private_key || get_private_key(params['AccountSid'])
      validator = Signalwire::Webhook::ValidateRequest.new(private_key)
      signature = env['HTTP_X_SIGNALWIRE_SIGNATURE'] || env['HTTP_X_TWILIO_SIGNATURE'] || ''
      if validator.validate(original_url, params, signature)
        @app.call(env)
      else
        [
          403,
          { 'Content-Type' => 'text/plain' },
          ['Signalwire Request Validation Failed.']
        ]
      end
    end

    def extract_params!(request)
      return {} unless request.post?

      if request.media_type == FORM_URLENCODED_MEDIA_TYPE
        request.POST
      else
        request.body.rewind
        body = request.body.read
        request.body.rewind
        body
      end
    end

    private :extract_params!

  end
end
