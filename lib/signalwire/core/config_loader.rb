# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
require 'yaml'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Configuration loader with environment variable substitution.
    #
    # Mirrors Python's ``signalwire.core.config_loader.ConfigLoader``.
    # Supports ``${VAR|default}`` syntax for referencing environment variables
    # within JSON (or YAML) configuration files. This provides a clean pattern
    # for configuration across all SignalWire services.
    class ConfigLoader
      # Pattern matching ``${VAR}`` or ``${VAR|default}``.
      VAR_PATTERN = /\$\{([^}|]+)(?:\|([^}]*))?\}/

      # Default configuration file search paths (first existing file wins).
      DEFAULT_PATHS = ['config.json', 'agent_config.json', 'swml_config.json', '.swml/config.json',
                       File.expand_path('~/.swml/config.json'), '/etc/swml/config.json'].freeze

      # @return [Array<String>] the search paths in use — the caller-supplied
      #   list, or {DEFAULT_PATHS} when none was given. The reference exposes the
      #   same resolved attribute (`self.config_paths = config_paths or
      #   self._get_default_paths()`, core/config_loader.py:37), so which paths a
      #   loader is actually consulting is readable back either way.
      attr_reader :config_paths

      # Initialize the config loader.
      #
      # +config_paths+ is an optional Array of config file paths to check.
      # When not provided, the default search paths are used. The first
      # existing, parseable file wins.
      def initialize(config_paths = nil)
        @config_paths = config_paths || DEFAULT_PATHS
        @config = nil
        @config_file = nil
        load_config
      end

      # Check if a configuration was loaded.
      def has_config
        !@config.nil?
      end

      # Get the path of the loaded config file, or +nil+.
      def get_config_file
        @config_file
      end

      # Get the raw configuration (before substitution) as a Hash.
      def get_config
        @config || {}
      end

      # Recursively substitute environment variables in configuration values.
      # Supports ``${VAR|default}`` syntax. After substitution, string values
      # that look like booleans/integers/floats are coerced to those native
      # types. Raises ArgumentError when +max_depth+ exhausts.
      def substitute_vars(value, max_depth = 10)
        raise ArgumentError, 'Maximum variable substitution depth exceeded' if max_depth <= 0

        case value
        when String then substitute_string(value)
        when Hash   then value.transform_values { |v| substitute_vars(v, max_depth - 1) }
        when Array  then value.map { |item| substitute_vars(item, max_depth - 1) }
        else value
        end
      end

      # Get a configuration value by dot-notation path (e.g.
      # ``"security.ssl_enabled"``), with variables substituted. Returns
      # +default+ when the path is not found.
      def get(key_path, default = nil)
        return default unless @config

        value = @config
        key_path.split('.').each do |key|
          return default unless value.is_a?(Hash) && value.key?(key)

          value = value[key]
        end

        substitute_vars(value)
      end

      # Get an entire configuration section (a Hash) with all variables
      # substituted. Returns an empty Hash when the section is absent.
      def get_section(section)
        return {} unless @config&.key?(section)

        substitute_vars(@config[section])
      end

      # Merge configuration with environment variables. The config file takes
      # precedence (but config can reference env vars via substitution). Env
      # vars beginning with +env_prefix+ (default ``"SWML_"``) are lowercased,
      # the prefix stripped, and folded into the result on underscore
      # boundaries -- only when not already present in the config.
      def merge_with_env(env_prefix = 'SWML_')
        result = @config ? substitute_vars(@config) : {}

        ENV.each do |key, value|
          next unless key.start_with?(env_prefix)

          ckey = key[env_prefix.length..].downcase
          set_nested_key(result, ckey, value) unless has_nested_key?(result, ckey)
        end

        result
      end

      # Find a config file for a service. +service_name+ optionally seeds
      # service-specific config file names, +additional_paths+ are checked
      # next, then the default paths. Returns the first file found, or +nil+.
      def self.find_config_file(service_name = nil, additional_paths = nil)
        paths = []
        paths.push("#{service_name}_config.json", ".swml/#{service_name}_config.json") if service_name
        paths.concat(additional_paths) if additional_paths
        paths.push('config.json', 'agent_config.json', '.swml/config.json',
                   File.expand_path('~/.swml/config.json'), '/etc/swml/config.json')
        paths.find { |path| File.exist?(path) }
      end

      private

      def load_config
        @config_paths.each do |path|
          next unless File.exist?(path)

          @config = parse_file(path)
          @config_file = path
          break
        rescue StandardError
          next
        end
      end

      def parse_file(path)
        contents = File.read(path)
        path.end_with?('.yaml', '.yml') ? YAML.safe_load(contents) : JSON.parse(contents)
      end

      def substitute_string(value)
        result = value.gsub(VAR_PATTERN) { ENV.fetch(Regexp.last_match(1), Regexp.last_match(2) || '') }
        coerce_scalar(result)
      end

      def coerce_scalar(result)
        lowered = result.downcase
        return true if lowered == 'true'
        return false if lowered == 'false'
        return result.to_i if result.match?(/\A\d+\z/)
        return result.to_f if result.sub('.', '').match?(/\A\d+\z/) && result.count('.') == 1

        result
      end

      def has_nested_key?(data, key_path)
        current = data
        key_path.split('_').each do |key|
          return false unless current.is_a?(Hash) && current.key?(key)

          current = current[key]
        end
        true
      end

      def set_nested_key(data, key_path, value)
        keys = key_path.split('_')
        current = data
        keys[0...-1].each { |key| current = (current[key] ||= {}) }
        current[keys[-1]] = value
      end
    end
  end
end
