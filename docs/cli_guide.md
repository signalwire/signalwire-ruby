# CLI Guide

This guide covers `swaig-test`, the command-line tool shipped with the
SignalWire Agents SDK for Ruby (`bin/swaig-test`). It lets you exercise an
agent's SWML document and its SWAIG functions locally, without standing up a
publicly reachable server.

> **Scope note.** This guide documents **only** the flags and modes the Ruby
> `swaig-test` actually implements. The Python reference SDK ships a much larger
> `swaig-test` surface (agent discovery, per-function argument flags, mock-request
> injection, data overrides, and CGI / Cloud Functions / Azure serverless
> simulation). Those are **not** implemented in the Ruby port. See
> [Not implemented in the Ruby port](#not-implemented-in-the-ruby-port) at the
> end of this guide for the full list and follow-up status. Run
> `swaig-test --help` to see the authoritative flag set for your installed
> version.

## Overview

`swaig-test` has three mutually-exclusive **modes**, selected by how you point
it at an agent:

| Mode | How to select | What it does |
|------|---------------|--------------|
| **URL mode** | `--url http://user:pass@host:port/route` | Speaks HTTP to a live, already-running agent endpoint. |
| **Serverless-simulation mode** | `AGENT_FILE --simulate-serverless lambda` | Loads an agent source file and routes invocations through the AWS Lambda handler adapter — no HTTP server, no network. |
| **In-process file mode** | `--file PATH --list-tools` | Loads a `SignalWire::SWML::Service` subclass in the current Ruby process and reads its runtime tool registry directly. This is the only mode that surfaces SWAIG tools registered on a plain (non-`AgentBase`) `SWML::Service`. |

Within a mode you pick exactly one **action**: `--dump-swml`, `--list-tools`,
or `--exec NAME`.

## Installation

The CLI is installed with the gem:

```bash
gem install signalwire-sdk
swaig-test --help
```

When running from a checkout of this repository, invoke it through the local
`lib/` load path:

```bash
ruby -Ilib bin/swaig-test --help
```

## Command reference

The complete flag set (from `swaig-test --help`):

```
Usage: swaig-test [agent_file] [options]
        --url URL                    Agent URL with embedded auth (http://user:pass@host:port/route)
        --simulate-serverless PLATFORM
                                     Simulate the named serverless platform (loads agent file locally). Supported: lambda
        --env KEY=VALUE              Override an environment variable for the serverless simulation (repeatable). Applied after the platform preset.
        --env-file PATH              Load KEY=VALUE environment overrides from a file for the serverless simulation (applied before --env).
        --file, --example PATH       Load a SWML::Service subclass from PATH in-process and read its tool registry directly (no HTTP, no simulator). Required for --list-tools on a non-AgentBase Service.
        --dump-swml                  GET SWML document and pretty-print it
        --list-tools                 List available SWAIG functions
        --exec NAME                  Execute a SWAIG function by name
        --param KEY=VALUE            Set a parameter (repeatable)
        --raw                        Output compact JSON instead of pretty-printed
        --verbose                    Show request/response details
    -h, --help                       Show this help
```

| Flag | Applies to | Description |
|------|------------|-------------|
| `--url URL` | URL mode | Agent URL with embedded basic-auth credentials (`http://user:pass@host:port/route`). |
| `--simulate-serverless PLATFORM` | Serverless mode | Load the positional agent file and simulate the named platform. **Only `lambda` is implemented.** |
| `--file PATH` (alias `--example PATH`) | File mode | Load a `SWML::Service` subclass from `PATH` in-process. Currently supports only `--list-tools`. |
| `--dump-swml` | URL, serverless | Fetch/render the SWML document and print it. |
| `--list-tools` | all three | List the agent's SWAIG functions and their parameters. |
| `--exec NAME` | URL, serverless | Execute the SWAIG function named `NAME`. |
| `--param KEY=VALUE` | with `--exec` | Set one argument for the executed function (repeatable). Values are coerced: `true`/`false` → boolean, `null`/`nil` → nil, integer/float literals → numbers, everything else stays a string. |
| `--env KEY=VALUE` | serverless only | Override an environment variable for the simulation (repeatable). Applied **after** the platform preset. |
| `--env-file PATH` | serverless only | Load `KEY=VALUE` env overrides from a file (applied **before** `--env`). |
| `--raw` | URL, serverless | Emit compact JSON instead of pretty-printed JSON. |
| `--verbose` | all | Show request/response details (and, in serverless mode, the activated environment). |
| `-h`, `--help` | — | Print usage and exit. |

Rules the parser enforces:

- Exactly one action (`--dump-swml`, `--list-tools`, `--exec`) per invocation.
- `--url`, `--simulate-serverless`, and `--file` are mutually exclusive.
- At most one positional argument (the agent file). Function arguments are
  passed with `--param`, never as extra positionals.
- `--env` / `--env-file` are only valid with `--simulate-serverless`.
- `--file` mode currently supports only `--list-tools`.

## URL mode — testing a running agent

Point `swaig-test` at a live agent over HTTP. Credentials are embedded in the
URL (agents auto-generate a basic-auth password unless you set
`SWML_BASIC_AUTH_USER` / `SWML_BASIC_AUTH_PASSWORD`).

```bash
# Fetch and pretty-print the SWML document
swaig-test --url http://user:pass@localhost:3000/ --dump-swml

# List the agent's SWAIG functions
swaig-test --url http://user:pass@localhost:3000/ --list-tools

# Execute a SWAIG function with arguments
swaig-test --url http://user:pass@localhost:3000/ --exec get_weather --param city=Miami

# Compact JSON for piping
swaig-test --url http://user:pass@localhost:3000/ --dump-swml --raw | jq '.sections'

# Verbose request/response logging
swaig-test --url http://user:pass@localhost:3000/ --verbose --list-tools
```

`--exec` sends the standard SWAIG invocation payload
(`{"function": ..., "argument": {"parsed": [ ... ]}}`) as an HTTP POST to
`<route>/swaig` and prints the JSON response.

## Serverless-simulation mode — AWS Lambda

Load an agent **source file** and route invocations through the SDK's AWS Lambda
handler adapter (`SignalWire::Serverless::LambdaHandler`) instead of an HTTP
server. This exercises the exact code path a deployed Lambda would take,
including Lambda-derived webhook URLs — no network, no running server.

The agent file must expose the agent as a top-level `AGENT` constant (or any
top-level `SignalWire::AgentBase` instance). `examples/lambda_agent.rb` is set
up this way.

> **Only `lambda` is supported.** Passing `cgi`, `cloud_function`,
> `azure_function`, etc. is rejected with a clear "not implemented in this SDK
> yet" error — the Ruby port has only shipped the Lambda handler adapter
> (Phase 9). See [Not implemented in the Ruby port](#not-implemented-in-the-ruby-port).

### List an agent's tools under Lambda simulation

```bash
swaig-test examples/lambda_agent.rb --simulate-serverless lambda --list-tools
```

Output:

```
SWAIG Functions:
------------------------------------------------------------
  greet_user
    Greet a user by name
    Parameters:
      - name: string Name to greet

  get_time
    Get the current time
```

### Dump the SWML document under Lambda simulation

```bash
swaig-test examples/lambda_agent.rb --simulate-serverless lambda --dump-swml
```

Output (truncated). Note the `web_hook_url` under `SWAIG.defaults` is derived
from the simulated Lambda environment:

```json
{
  "version": "1.0.0",
  "sections": {
    "main": [
      {
        "answer": {}
      },
      {
        "ai": {
          "prompt": {
            "pom": [
              {
                "title": "Role",
                "body": "You are a helpful AI assistant running in a serverless environment."
              }
            ]
          },
          "SWAIG": {
            "defaults": {
              "web_hook_url": "https://<user>:<pass>@test-agent-function.lambda-url.us-east-1.on.aws/swaig"
            },
            "functions": [
              {
                "function": "greet_user",
                "description": "Greet a user by name",
                "parameters": {
                  "type": "object"
                }
              }
            ]
          }
        }
      }
    ]
  }
}
```

Add `--raw` for compact single-line JSON suitable for piping into `jq`.

### Execute a function under Lambda simulation

Pass arguments with repeatable `--param KEY=VALUE` flags:

```bash
swaig-test examples/lambda_agent.rb --simulate-serverless lambda \
  --exec greet_user --param name=Alice
```

Output:

```json
{
  "response": "Hello Alice! I'm running in serverless mode!"
}
```

### Environment overrides

The simulator applies a Lambda preset (`AWS_LAMBDA_FUNCTION_NAME`,
`LAMBDA_TASK_ROOT`, `AWS_REGION`, `_HANDLER`) and then your overrides. `--env`
and `--env-file` are only meaningful with `--simulate-serverless`; the
originals are snapshotted and restored when the simulation finishes.

```bash
# One-off overrides (repeatable). Applied after the platform preset.
swaig-test examples/lambda_agent.rb --simulate-serverless lambda \
  --env AWS_REGION=eu-west-1 --env DEBUG=1 --dump-swml

# Load overrides from a file, then let an explicit --env win over the file.
cat > prod.env <<'EOF'
AWS_LAMBDA_FUNCTION_NAME=my-production-function
AWS_REGION=us-west-2
EOF

swaig-test examples/lambda_agent.rb --simulate-serverless lambda \
  --env-file prod.env --env AWS_REGION=eu-west-1 --dump-swml
```

Precedence: platform preset, then `--env-file`, then `--env` (later sources
win).

## In-process file mode — listing tools on a plain Service

`--file PATH --list-tools` loads a `SignalWire::SWML::Service` subclass in the
current Ruby process and reads its runtime tool registry **directly** — no HTTP,
no simulator. This is the only mode that surfaces SWAIG tools registered on a
plain `SWML::Service` (for example an `ai_sidecar` host or a standalone SWAIG
service), because those tools are not present in rendered SWML the way an
`AgentBase` agent's are.

```bash
swaig-test --file examples/swmlservice_swaig_standalone.rb --list-tools
```

Output:

```
SWAIG Functions:
------------------------------------------------------------
  lookup_competitor
    Look up competitor pricing by company name. Use this when the user asks how a competitor's price compares to ours.
    Parameters:
      - competitor: string The competitor's company name, e.g. 'ACME'.
```

File mode currently supports only `--list-tools`; use `--url` or
`--simulate-serverless lambda` for `--dump-swml` and `--exec`.

## Logging and output control

- Agent logs go to stderr; the action's result (SWML JSON, function output,
  tool listing) goes to stdout. Redirect stderr (`2>/dev/null`) for clean,
  parseable output.
- `--verbose` adds request/response details (URL mode) and prints the activated
  environment (serverless mode).
- `--raw` emits compact single-line JSON instead of pretty-printed JSON — handy
  for piping into `jq`.

```bash
# Clean SWML JSON only
swaig-test examples/lambda_agent.rb --simulate-serverless lambda --dump-swml --raw 2>/dev/null | jq '.'
```

## Exit codes

- `0` — success.
- `1` — error (invalid arguments, unknown/unimplemented platform, agent file
  not found or failing to load, HTTP error in URL mode, non-2xx from the Lambda
  adapter, invalid JSON response).

## Building search indexes

The Ruby port does **not** ship a search-index-building CLI (Python's
`sw-search`). Document search is provided by the `native_vector_search` skill in
**remote mode only** — it queries a remote search server over HTTP; it does not
build a local index. See the
[Skills System Guide](skills_system.md#native-vector-search-native_vector_search).

## Not implemented in the Ruby port

The Python reference `swaig-test` documents a substantially larger CLI. The
following are **not** implemented in the Ruby port and are intentionally absent
from the flag set above. They are listed here so you don't reach for a Python
recipe that won't parse — and as a follow-up feature backlog.

Serverless platforms beyond Lambda:

- `--simulate-serverless cgi`, `cloud_function` (GCF), `azure_function` —
  only `lambda` has a handler adapter today. Requesting another platform fails
  loud with a "not implemented in this SDK yet" message.
- Platform-config flags that only make sense for those platforms or for a richer
  Lambda simulation: `--aws-function-name`, `--aws-function-url`,
  `--aws-api-gateway-id`, `--aws-region`, `--aws-stage`, `--cgi-host`,
  `--cgi-script-name`, `--cgi-https`, `--cgi-path-info`, `--gcp-project`,
  `--gcp-function-url`, `--gcp-region`, `--gcp-service`, `--azure-env`,
  `--azure-function-url`. (Use `--env` to set the corresponding environment
  variables directly for Lambda.)

Multi-agent selection:

- `--list-agents`, `--agent-class CLASS`, `--route ROUTE`. The Ruby CLI loads a
  single agent per file (the `AGENT` constant, or a discovered `AgentBase`
  instance). To test a specific agent from a multi-agent file, point the CLI at
  a file that exposes just that agent, or run it and use URL mode against its
  route.

Function-argument and request-shaping flags:

- Per-function argument flags such as `--location`, `--query`, `--type`,
  `--name`, `--expression`, and the `--args` separator. **Use `--param KEY=VALUE`
  (repeatable) instead** — it is the only supported way to pass function
  arguments.
- The positional `AGENT_FILE FUNCTION '{json}'` execution form. Use
  `--exec FUNCTION --param k=v` instead.
- SWML fake-data / mock-request overrides: `--call-type`, `--call-direction`,
  `--call-state`, `--call-id`, `--project-id`, `--space-id`, `--from-number`,
  `--to-extension`, `--override`, `--override-json`, `--user-vars`,
  `--query-params`, `--header`, `--method`, `--body`.
- Post-data mode flags: `--fake-full-data`, `--minimal`, `--custom-data`.
- Output/format flags that don't exist here: `--format-json` (use the default
  pretty output or `--raw`), `--full-request`, and the legacy
  `--serverless-mode` alias (use `--simulate-serverless`).

If your workflow needs one of these, please open a feature request rather than
scripting against a flag the CLI will reject.

## Getting help

```bash
swaig-test --help
```
