# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'base64'
require 'rack'
require 'webrick'

require_relative '../core/config_loader'
require_relative '../core/security_config'
require_relative '../logging'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Web — the HTTP serving layer shared by the agent and the multi-agent server.
  module Web
    # Static file serving service with an HTTP API.
    #
    # Maps URL route prefixes to local directories and serves their files over
    # HTTP with security headers, extension filtering, and optional basic auth.
    #
    # The server is WEBrick. {#start} launches it in a background thread
    # (non-blocking) so it is
    # safe to start and {#stop} in tests without hanging; pass +block: true+ to
    # {#start} to run in the foreground.
    class WebService
      DEFAULT_BLOCKED_EXTENSIONS = ['.env', '.git', '.gitignore', '.key', '.pem', '.crt',
                                    '.pyc', '__pycache__', '.DS_Store', '.swp'].freeze

      attr_reader :port, :directories, :enable_directory_browsing, :max_file_size,
                  :enable_cors, :allowed_extensions, :blocked_extensions, :security

      # @param port [Integer] the port to bind; 0 binds an ephemeral port
      # @param directories [Hash{String => String}, nil] route to local directory map;
      #   when nil, whatever the config file declared is kept
      # @param basic_auth [Array(String, String), nil] `[user, pass]` required for every
      #   request; falls back to the SecurityConfig's credentials
      # @param config_file [String, nil] explicit config path, or nil to auto-discover
      # @param enable_directory_browsing [Boolean] serve `index.html` for a directory
      #   request instead of refusing it
      # @param allowed_extensions [Array<String>, nil] when set, ONLY these file
      #   extensions are served — an allow-list that overrides the block-list
      # @param blocked_extensions [Array<String>] never-served extensions and names
      #   (defaults to DEFAULT_BLOCKED_EXTENSIONS: .env, .git, .key, .pem, …)
      # @param max_file_size [Integer] refuse to serve a file larger than this, in bytes
      # @param enable_cors [Boolean] whether CORS headers are emitted
      def initialize(port: 8002, directories: nil, basic_auth: nil, config_file: nil,
                     enable_directory_browsing: false, allowed_extensions: nil,
                     blocked_extensions: nil, max_file_size: 100 * 1024 * 1024, enable_cors: true)
        load_config(config_file)
        @port = port
        @enable_directory_browsing = enable_directory_browsing
        @max_file_size = max_file_size
        @enable_cors = enable_cors
        @directories = directories unless directories.nil?
        @allowed_extensions = allowed_extensions
        @blocked_extensions = blocked_extensions || DEFAULT_BLOCKED_EXTENSIONS
        init_security(config_file, basic_auth)
      end

      # @api private — build the SecurityConfig for the `web` service and resolve the
      # basic-auth pair (explicit arg wins over the config's), leaving the server and
      # its thread unstarted.
      def init_security(config_file, basic_auth)
        @security = SignalWire::Core::SecurityConfig.new(config_file: config_file, service_name: 'web')
        @basic_auth = basic_auth || @security.get_basic_auth
        @server = nil
        @thread = nil
      end
      private :init_security

      # Add a directory to serve at +route+. Raises ArgumentError when the
      # directory does not exist or is not a directory. Remounts if running.
      def add_directory(route, directory)
        route = normalize_route(route)
        raise ArgumentError, "Directory does not exist: #{directory}" unless File.exist?(directory)
        raise ArgumentError, "Path is not a directory: #{directory}" unless File.directory?(directory)

        @directories[route] = directory
        mount_directory(route, directory) if @server
      end

      # Remove the directory served at +route+ (no-op when absent).
      def remove_directory(route)
        route = normalize_route(route)
        @directories.delete(route)
      end

      # Start the service. Non-blocking by default (runs WEBrick in a background
      # thread and returns the bound port). Pass +block: true+ to run in the
      # foreground. +port+ 0 binds an ephemeral port.
      #
      # +host+ defaults to '0.0.0.0' -- the INTENDED server default: listen on all
      # interfaces so a containerised or remote-hosted agent is reachable. It is
      # a deliberate choice, not an oversight; do NOT "harden" it back to
      # '127.0.0.1' -- pass +host: '127.0.0.1'+ explicitly for loopback-only binding.
      def start(host: '0.0.0.0', port: nil, ssl_cert: nil, ssl_key: nil, block: false)
        bind_port = port || @port
        @server = build_server(host, bind_port, ssl_cert, ssl_key)
        @directories.each { |route, directory| mount_directory(route, directory) }
        bound = @server.config[:Port]
        return @server.start if block

        started = Queue.new
        @server.config[:StartCallback] = -> { started.push(true) }
        @thread = Thread.new { @server.start }
        started.pop # block until WEBrick is past bind/listen so stop() is race-free
        bound
      end

      # Stop the service and clean up the background thread. Safe to call when
      # not running.
      def stop
        @server&.shutdown
        # Bounded join, then hard-stop as a safety net so tests never hang even
        # if WEBrick#shutdown fails to interrupt a blocking accept().
        if @thread && !@thread.join(3)
          @thread.kill
          @thread.join(1)
        end
        @server = nil
        @thread = nil
      end

      # Whether a file may be served (size + extension/name filters).
      def file_allowed?(path)
        return false unless File.file?(path)
        return false if File.size(path) > @max_file_size
        return false if blocked?(path)
        return @allowed_extensions.include?(File.extname(path).downcase) if @allowed_extensions

        true
      end

      private

      # @api private — construct the WEBrick server with logging silenced (the
      # service does its own) and TLS applied when a cert/key pair was given.
      #
      # @return [WEBrick::HTTPServer]
      def build_server(host, bind_port, ssl_cert, ssl_key)
        opts = {
          BindAddress: host, Port: bind_port,
          Logger: WEBrick::Log.new(File::NULL), AccessLog: []
        }
        apply_ssl(opts, ssl_cert, ssl_key)
        WEBrick::HTTPServer.new(opts)
      end

      # @api private — turn on WEBrick TLS with the given PEM certificate and private
      # key. A missing cert or key leaves the server plain HTTP.
      def apply_ssl(opts, ssl_cert, ssl_key)
        kwargs = if ssl_cert && ssl_key
                   { SSLEnable: true,
                     SSLCertificate: OpenSSL::X509::Certificate.new(File.read(ssl_cert)),
                     SSLPrivateKey: OpenSSL::PKey.read(File.read(ssl_key)) }
                 else
                   @security.get_ssl_context_kwargs
                 end
        opts.merge!(kwargs)
      end

      # @api private — mount +directory+ at +route+ on the running server, routing
      # each request through {#handle_request}.
      def mount_directory(route, directory)
        service = self
        @server.mount_proc(route) do |req, res|
          service.send(:handle_request, req, res, route, directory)
        end
      end

      # @api private — serve one request: enforce basic auth, then resolve the
      # request path INSIDE the mounted directory. The resolved absolute path must be
      # the directory itself or below it — that check is what stops a `../` traversal
      # from escaping the mount — and a path outside it is 403, not 404, so a probe
      # cannot distinguish "escaped" from "absent".
      def handle_request(req, res, route, directory)
        return unless authorized?(req, res)

        rel = req.path.sub(%r{\A#{Regexp.escape(route)}/?}, '')
        full = File.expand_path(File.join(directory, rel))
        base = File.expand_path(directory)
        return deny(res, 403, 'Access denied') unless full == base || full.start_with?("#{base}#{File::SEPARATOR}")
        return deny(res, 404, 'File not found') unless File.exist?(full)

        serve_path(res, full)
      end

      # @api private — resolve a request to a file: a directory request becomes its
      # `index.html`, and anything that is not a servable file is 403 (directory
      # browsing disabled), as is a file rejected by the size/extension filters.
      def serve_path(res, full)
        full = File.join(full, 'index.html') if File.directory?(full)
        return deny(res, 403, 'Directory browsing disabled') unless File.file?(full)
        return deny(res, 403, 'File type not allowed') unless file_allowed?(full)

        write_file(res, full)
      end

      # @api private — write a file to the response with its MIME type, a one-hour
      # public cache header, and the SecurityConfig's security headers.
      def write_file(res, full)
        res.status = 200
        res.body = File.binread(full)
        res['Content-Type'] = mime_type(full)
        res['Cache-Control'] = 'public, max-age=3600'
        @security.get_security_headers.each { |header, value| res[header] = value }
      end

      # @api private — a plain-text refusal at +status+. The body is the only detail
      # given; no path or filesystem information is leaked.
      def deny(res, status, message)
        res.status = status
        res.body = message
      end

      # @api private — enforce basic auth. Returns true when no credentials are
      # configured (auth is off) or the request's match; otherwise sets a 401
      # challenge on the response and returns false.
      #
      # @return [Boolean] true when the request may proceed
      def authorized?(req, res)
        user, pass = @basic_auth
        return true if user.nil? || pass.nil?

        return true if credentials_match?(req, user, pass)

        res.status = 401
        res['WWW-Authenticate'] = 'Basic realm="SignalWire Web Service"'
        res.body = 'Authentication required'
        false
      end

      # @api private — constant-time comparison of the request's `Authorization`
      # header against the configured pair. The scheme is matched case-insensitively
      # (RFC 7235), and a decoded payload with NO colon is rejected outright rather
      # than defaulting the password to the empty string (RFC 7617).
      #
      # @return [Boolean] true when both halves match
      def credentials_match?(req, user, pass)
        # Split on the FIRST space and compare the scheme case-INSENSITIVELY
        # (RFC 7235): "Basic", "basic" and "BASIC" are all accepted.
        scheme, _sep, param = req['Authorization'].to_s.partition(' ')
        return false unless scheme.downcase == 'basic'

        decoded = Base64.decode64(param.strip)
        input_user, separator, input_pass = decoded.partition(':')
        # RFC 7617 -- a payload with NO colon is not a credential pair; reject
        # it rather than defaulting the password to ''.
        return false if separator.empty?

        Rack::Utils.secure_compare(user.to_s, input_user) && Rack::Utils.secure_compare(pass.to_s, input_pass)
      rescue ArgumentError
        false
      end

      # @api private — whether a path is on the block-list. An entry starting with a
      # dot matches the file's extension or its exact name; any other entry matches
      # the exact name or ANY path component, so a directory name like
      # `__pycache__` blocks everything beneath it.
      #
      # @return [Boolean]
      def blocked?(path)
        name = File.basename(path)
        ext = File.extname(path).downcase
        @blocked_extensions.any? do |blocked|
          if blocked.start_with?('.')
            ext == blocked || name == blocked
          else
            name == blocked || path.include?(blocked)
          end
        end
      end

      # @api private — the MIME type WEBrick infers for the file, falling back to
      # `application/octet-stream` for an unknown extension.
      def mime_type(full)
        WEBrick::HTTPUtils.mime_type(full, WEBrick::HTTPUtils::DefaultMimeTypes) || 'application/octet-stream'
      end

      # @api private — ensure a mount route starts with a slash, so `"docs"` and
      # `"/docs"` mount at the same place.
      def normalize_route(route)
        route.start_with?('/') ? route : "/#{route}"
      end

      # @api private — seed the port and directory map from the `service` section of
      # the config file (explicit path, else auto-discovered for the `web` service).
      # Sets the built-in defaults first, so a missing file leaves a usable config.
      def load_config(config_file)
        @directories = {}
        @port = 8002
        config_file ||= SignalWire::Core::ConfigLoader.find_config_file('web')
        return unless config_file

        loader = SignalWire::Core::ConfigLoader.new([config_file])
        return unless loader.has_config

        apply_service_section(loader.get_section('service'))
      end

      # @api private — apply the config's `service` section: `port` and the
      # `directories` route map, then the file filters. A nil or empty section is a
      # no-op.
      def apply_service_section(service)
        return if service.nil? || service.empty?

        @port = service['port'].to_i if service.key?('port')
        @directories = service['directories'] if service['directories'].is_a?(Hash)
        apply_service_filters(service)
      end

      # @api private — apply the config's file-serving filters: `max_file_size`,
      # `allowed_extensions`, `blocked_extensions` and `enable_directory_browsing`
      # (coerced to a real Boolean).
      def apply_service_filters(service)
        @max_file_size = service['max_file_size'].to_i if service.key?('max_file_size')
        @allowed_extensions = service['allowed_extensions'] if service.key?('allowed_extensions')
        @blocked_extensions = service['blocked_extensions'] if service.key?('blocked_extensions')
        return unless service.key?('enable_directory_browsing')

        @enable_directory_browsing = service['enable_directory_browsing'] ? true : false
      end
    end
  end
end
