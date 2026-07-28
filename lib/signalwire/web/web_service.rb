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

module SignalWire
  module Web
    # Static file serving service with an HTTP API.
    #
    # Mirrors Python's ``signalwire.web.web_service.WebService``. Maps URL route
    # prefixes to local directories and serves their files over HTTP with
    # security headers, extension filtering, and optional basic auth.
    #
    # Ruby idiom note: Python builds a FastAPI/uvicorn app; Ruby uses WEBrick.
    # {#start} launches the server in a background thread (non-blocking) so it is
    # safe to start and {#stop} in tests without hanging; pass +block: true+ to
    # {#start} to run in the foreground.
    class WebService
      DEFAULT_BLOCKED_EXTENSIONS = ['.env', '.git', '.gitignore', '.key', '.pem', '.crt',
                                    '.pyc', '__pycache__', '.DS_Store', '.swp'].freeze

      attr_reader :port, :directories, :enable_directory_browsing, :max_file_size,
                  :enable_cors, :allowed_extensions, :blocked_extensions, :security

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
      # interfaces so a containerised or remote-hosted agent is reachable. This
      # matches the reference (signalwire/web/web_service.py, which carries the same
      # deliberate-choice marker). It is not an oversight; do NOT "harden" it back to
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

      def build_server(host, bind_port, ssl_cert, ssl_key)
        opts = {
          BindAddress: host, Port: bind_port,
          Logger: WEBrick::Log.new(File::NULL), AccessLog: []
        }
        apply_ssl(opts, ssl_cert, ssl_key)
        WEBrick::HTTPServer.new(opts)
      end

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

      def mount_directory(route, directory)
        service = self
        @server.mount_proc(route) do |req, res|
          service.send(:handle_request, req, res, route, directory)
        end
      end

      def handle_request(req, res, route, directory)
        return unless authorized?(req, res)

        rel = req.path.sub(%r{\A#{Regexp.escape(route)}/?}, '')
        full = File.expand_path(File.join(directory, rel))
        base = File.expand_path(directory)
        return deny(res, 403, 'Access denied') unless full == base || full.start_with?("#{base}#{File::SEPARATOR}")
        return deny(res, 404, 'File not found') unless File.exist?(full)

        serve_path(res, full)
      end

      def serve_path(res, full)
        full = File.join(full, 'index.html') if File.directory?(full)
        return deny(res, 403, 'Directory browsing disabled') unless File.file?(full)
        return deny(res, 403, 'File type not allowed') unless file_allowed?(full)

        write_file(res, full)
      end

      def write_file(res, full)
        res.status = 200
        res.body = File.binread(full)
        res['Content-Type'] = mime_type(full)
        res['Cache-Control'] = 'public, max-age=3600'
        @security.get_security_headers.each { |header, value| res[header] = value }
      end

      def deny(res, status, message)
        res.status = status
        res.body = message
      end

      def authorized?(req, res)
        user, pass = @basic_auth
        return true if user.nil? || pass.nil?

        return true if credentials_match?(req, user, pass)

        res.status = 401
        res['WWW-Authenticate'] = 'Basic realm="SignalWire Web Service"'
        res.body = 'Authentication required'
        false
      end

      def credentials_match?(req, user, pass)
        header = req['Authorization'].to_s
        return false unless header.start_with?('Basic ')

        decoded = Base64.decode64(header[6..])
        input_user, _sep, input_pass = decoded.partition(':')
        Rack::Utils.secure_compare(user.to_s, input_user) && Rack::Utils.secure_compare(pass.to_s, input_pass)
      rescue ArgumentError
        false
      end

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

      def mime_type(full)
        WEBrick::HTTPUtils.mime_type(full, WEBrick::HTTPUtils::DefaultMimeTypes) || 'application/octet-stream'
      end

      def normalize_route(route)
        route.start_with?('/') ? route : "/#{route}"
      end

      def load_config(config_file)
        @directories = {}
        @port = 8002
        config_file ||= SignalWire::Core::ConfigLoader.find_config_file('web')
        return unless config_file

        loader = SignalWire::Core::ConfigLoader.new([config_file])
        return unless loader.has_config

        apply_service_section(loader.get_section('service'))
      end

      def apply_service_section(service)
        return if service.nil? || service.empty?

        @port = service['port'].to_i if service.key?('port')
        @directories = service['directories'] if service['directories'].is_a?(Hash)
        apply_service_filters(service)
      end

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
