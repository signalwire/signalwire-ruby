# Configuration Guide

This guide explains the unified configuration system available in SignalWire AI Agents SDK.

## Overview

All SignalWire services (SWML-based agents, Search, MCP Gateway) now support optional JSON configuration files with environment variable substitution. SWML (SignalWire Markup Language) is the JSON document format that defines agent behavior during calls. Services continue to work without any configuration file, maintaining full backward compatibility.

## Quick Start

### Zero Configuration (Default)
<!-- snippet: no-run starts a blocking server (agent.run) and uses the placeholder MyAgent class -->
```ruby
# Works exactly as before - no config needed
agent = MyAgent.new
agent.run
```

### With Environment-Driven Configuration
<!-- snippet: no-run illustrative fragment: uses the reader's own placeholder MyAgent subclass -->
```ruby
# The Ruby port is configured from environment variables (no ConfigLoader).
# Set the relevant SWML_* vars, then instantiate as usual.
ENV['SWML_SSL_ENABLED']   = 'true'
ENV['SWML_SSL_CERT_PATH'] = '/etc/ssl/cert.pem'

agent = MyAgent.new
```

## Configuration Files

### File Locations

Services look for configuration files in this order:
1. Service-specific: `{service_name}_config.json` (e.g., `search_config.json`)
2. Generic: `config.json`
3. Hidden: `.swml/config.json`
4. User home: `~/.swml/config.json`
5. System: `/etc/swml/config.json`

### Configuration Structure

```json
{
  "service": {
    "name": "my-service",
    "host": "${HOST|0.0.0.0}",
    "port": "${PORT|3000}"
  },
  "security": {
    "ssl_enabled": "${SSL_ENABLED|false}",
    "ssl_cert_path": "${SSL_CERT|/etc/ssl/cert.pem}",
    "ssl_key_path": "${SSL_KEY|/etc/ssl/key.pem}",
    "auth": {
      "basic": {
        "enabled": true,
        "user": "${AUTH_USER|signalwire}",
        "password": "${AUTH_PASSWORD}"
      },
      "bearer": {
        "enabled": "${BEARER_ENABLED|false}",
        "token": "${BEARER_TOKEN}"
      }
    },
    "allowed_hosts": ["${PRIMARY_HOST}", "${SECONDARY_HOST|localhost}"],
    "cors_origins": "${CORS_ORIGINS|*}",
    "rate_limit": "${RATE_LIMIT|60}"
  }
}
```

## Environment Variable Substitution

The configuration system supports `${VAR|default}` syntax:

- `${VAR}` - Use environment variable VAR (error if not set)
- `${VAR|default}` - Use VAR or "default" if not set
- `${VAR|}` - Use VAR or empty string if not set

### Examples

```json
{
  "database": {
    "host": "${DB_HOST|localhost}",
    "port": "${DB_PORT|5432}",
    "password": "${DB_PASSWORD}"
  }
}
```

## Priority Order

Configuration values are applied in this order (highest to lowest):

1. **Constructor parameters** - Explicitly passed to service
2. **Config file values** - From JSON configuration
3. **Environment variables** - Direct env vars (backward compatibility)
4. **Defaults** - Hard-coded defaults

## Service-Specific Configuration

### SWML/Agent Configuration

```json
{
  "service": {
    "name": "my-agent",
    "route": "/agent",
    "port": "${AGENT_PORT|3000}"
  },
  "security": {
    "ssl_enabled": "${SSL_ENABLED|false}",
    "auth": {
      "basic": {
        "user": "${AGENT_USER|agent}",
        "password": "${AGENT_PASSWORD}"
      }
    }
  }
}
```

### MCP Gateway Configuration

```json
{
  "server": {
    "host": "${MCP_HOST|0.0.0.0}",
    "port": "${MCP_PORT|8080}",
    "auth_user": "${MCP_USER|admin}",
    "auth_password": "${MCP_PASSWORD}",
    "auth_token": "${MCP_TOKEN}"
  },
  "services": {
    "example": {
      "command": ["python", "${SERVICE_PATH|./service.py}"],
      "enabled": "${SERVICE_ENABLED|true}"
    }
  },
  "session": {
    "default_timeout": "${SESSION_TIMEOUT|300}",
    "max_sessions_per_service": "${MAX_SESSIONS|100}"
  }
}
```

## Security Configuration

All services share the same security configuration options:

```json
{
  "security": {
    "ssl_enabled": true,
    "ssl_cert_path": "/etc/ssl/cert.pem",
    "ssl_key_path": "/etc/ssl/key.pem",
    "domain": "api.example.com",
    
    "allowed_hosts": ["api.example.com", "app.example.com"],
    "cors_origins": ["https://app.example.com"],
    
    "max_request_size": 5242880,
    "rate_limit": 30,
    "request_timeout": 60,
    
    "use_hsts": true,
    "hsts_max_age": 31536000
  }
}
```

## RELAY Client Environment Variables

The RELAY WebSocket client reads a few environment variables that tune the
transport endpoint and its TLS trust. They are consumed automatically at
connect time — no code changes required.

| Variable | Purpose | Default |
|---|---|---|
| `SIGNALWIRE_RELAY_HOST` | Override the RELAY endpoint host the client connects to. Used to point the client at a non-production endpoint (e.g. a loopback audit fixture) without touching credential resolution. | derived from the space/host |
| `SIGNALWIRE_RELAY_SCHEME` | URL scheme for the RELAY WebSocket connection. Set to `ws` to connect over plain (non-TLS) WebSocket — e.g. for a loopback test/audit fixture — instead of the production `wss`. Any other value is used verbatim as the scheme. | `wss` |
| `SIGNALWIRE_RELAY_CA_FILE` | Path to an additional PEM CA-bundle file to trust when verifying the RELAY server certificate on a `wss://` connection. The named file is added to the certificate store alongside the OpenSSL default paths (which themselves honor `SSL_CERT_FILE` / `SSL_CERT_DIR`). Use it to trust a private/custom CA. Ignored for non-`wss` schemes. | _unset_ (system trust store only) |
| `SIGNALWIRE_REST_CA_FILE` | Path to an additional PEM CA-bundle file to trust when verifying the REST server certificate over HTTPS. The named file is added to a certificate store seeded from the OpenSSL defaults (which honor `SSL_CERT_FILE`). Used when no explicit `ca_file:` is passed to the REST client. Use it to trust a private/custom CA. | _unset_ (system trust store only) |

Both are read at connection time, so setting them before `RelayClient#connect`
is sufficient. `SIGNALWIRE_RELAY_SCHEME=ws` disables TLS entirely, so use it
only against trusted loopback endpoints.

## Migration Guide

### From Environment Variables Only

Before:
```bash
export SWML_SSL_ENABLED=true
export SWML_SSL_CERT_PATH=/etc/ssl/cert.pem
python my_agent.py
```

After (Option 1 - Keep using env vars):
```bash
# Still works exactly the same
export SWML_SSL_ENABLED=true
export SWML_SSL_CERT_PATH=/etc/ssl/cert.pem
python my_agent.py
```

After (Option 2 - Use config file):
```json
// config.json
{
  "security": {
    "ssl_enabled": true,
    "ssl_cert_path": "/etc/ssl/cert.pem"
  }
}
```

After (Option 3 - Mix config and env vars):
```json
// config.json
{
  "security": {
    "ssl_enabled": true,
    "ssl_cert_path": "${SSL_CERT|/etc/ssl/cert.pem}"
  }
}
```

## Best Practices

1. **Keep secrets in environment variables**
   ```json
   {
     "security": {
       "auth": {
         "basic": {
           "user": "admin",
           "password": "${ADMIN_PASSWORD}"
         }
       }
     }
   }
   ```

2. **Use defaults for development**
   ```json
   {
     "service": {
       "port": "${PORT|3000}",
       "host": "${HOST|localhost}"
     }
   }
   ```

3. **Environment-specific configs**
   - `dev_config.json` - Development settings
   - `prod_config.json` - Production settings
   - Use `${ENV}` to switch between them

4. **Version control**
   - Commit config files WITHOUT secrets
   - Use `.gitignore` for local overrides
   - Document required environment variables

## Programmatic Usage

The Ruby port does not ship a dedicated `ConfigLoader` class; configuration is
driven entirely from environment variables (see
[PORT_OMISSIONS.md](../PORT_OMISSIONS.md)). Set the relevant `SWML_*` and
agent-specific environment variables before instantiating your agent:

<!-- snippet: no-run starts a blocking server via MyAgent.new.serve -->
```ruby
require 'signalwire'

ENV['SWML_BASIC_AUTH_USER']     = 'admin'
ENV['SWML_BASIC_AUTH_PASSWORD'] = 'secret'
ENV['PORT']                     = '3000'

class MyAgent < SignalWire::AgentBase
  def initialize
    super(name: 'my-agent')
  end
end

MyAgent.new.serve
```

If you need JSON- or YAML-based configuration, load the file in your own code
(with the stdlib `JSON` or `YAML` module) and pass the values into the agent
constructor explicitly.

## Troubleshooting

### Config Not Loading

1. Check file exists and is valid JSON:
   ```bash
   python -m json.tool config.json
   ```

2. Enable debug logging:
   ```ruby
   require 'signalwire'
   SignalWire::Logging.global_level = :debug
   ```

3. Check for syntax errors in variable substitution

### Environment Variables Not Substituting

1. Ensure correct syntax: `${VAR}` or `${VAR|default}`
2. Check environment variable is exported:
   ```bash
   echo $MY_VAR
   ```

3. Remember config file values override env vars

### Authentication Issues

1. Config file auth settings override env vars
2. Check which auth method is enabled
3. Verify credentials match
