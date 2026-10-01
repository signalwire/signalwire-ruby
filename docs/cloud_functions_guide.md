# SignalWire AI Agents - Cloud Functions Deployment Guide

<!-- snippet-setup: every ruby example on this page assumes the SDK is required -->
```ruby
require 'signalwire'
```

This guide covers deploying SignalWire AI Agents for Ruby to serverless
platforms. The Ruby SDK ships a first-class adapter for AWS Lambda via
`SignalWire::Serverless::LambdaHandler`; deployment to Google Cloud Functions
and Azure Functions is not officially supported (see
[PORT_OMISSIONS.md](../PORT_OMISSIONS.md)).

## AWS Lambda

### Environment Detection

The agent and webhook-URL generator automatically detect the Lambda runtime
through the following environment variables:

- `AWS_LAMBDA_FUNCTION_NAME` — function name, set by Lambda
- `LAMBDA_TASK_ROOT` — Lambda task-root path
- `AWS_LAMBDA_FUNCTION_URL` — Function URL (if configured)
- `AWS_REGION` — AWS region

When any of those is present, the SDK derives webhook URLs using this priority:

1. `SWML_PROXY_URL_BASE` — set this for any custom domain or API Gateway alias.
2. `AWS_LAMBDA_FUNCTION_URL` — Lambda Function URL (common case).
3. `https://{AWS_LAMBDA_FUNCTION_NAME}.lambda-url.{AWS_REGION}.on.aws` — derived fallback.

### Deployment Steps

1. **Create your agent entrypoint** (`lambda_agent.rb`):

```ruby
require "signalwire"

AGENT = SignalWire::AgentBase.new(name: "my-agent", route: "/")

AGENT.add_language("English", "en-US", "elevenlabs.rachel")

AGENT.prompt_add_section(
  "Role",
  "You are a helpful AI assistant running in a serverless environment."
)

HANDLER = SignalWire::Serverless::LambdaHandler.for(AGENT)

def handler(event:, context:)
  HANDLER.call(event, context)
end
```

2. **Bundle the SDK**. Because Lambda Ruby runtimes do not install gems on
   cold start, vendor the dependency tree into the deployment zip:

```bash
bundle config set --local path 'vendor/bundle'
bundle install
zip -r function.zip lambda_agent.rb vendor
```

3. **Create the Lambda function and set the handler**:

```bash
aws lambda create-function \
  --function-name my-agent \
  --runtime ruby3.2 \
  --role arn:aws:iam::123456789012:role/lambda-execution-role \
  --handler lambda_agent.handler \
  --zip-file fileb://function.zip
```

### Environment Variables

Set these on the function configuration:

```bash
# SignalWire basic-auth credentials (used by the agent to verify requests)
SWML_BASIC_AUTH_USER=your-username
SWML_BASIC_AUTH_PASSWORD=your-password

# Custom proxy/domain (optional)
SWML_PROXY_URL_BASE=https://my-domain.example.com
```

### URL Format

Lambda Function URLs follow this pattern:

```
https://{url-id}.lambda-url.{region}.on.aws/
```

With authentication:

```
https://username:password@{url-id}.lambda-url.{region}.on.aws/
```

## Google Cloud Functions / Azure Functions

Google Cloud Functions and Azure Functions are not supported by the Ruby SDK.
The Python SDK ships per-platform detection mixins
(`signalwire.core.mixins.serverless_mixin.ServerlessMixin`) that have not been
ported. If you need to run a SignalWire agent on these platforms, options are:

1. Run the agent inside a containerized service (Cloud Run, App Service)
   using the standard Rack deployment pattern from [web_service
   documentation](../README.md) —
   containers preserve the full `serve` behavior.
2. Write a thin HTTP function that forwards to the agent's `rack_app`.
   Translate the platform-specific request object into a Rack env hash and
   invoke `AGENT.rack_app.call(env)`.

## Authentication

`AgentBase` always requires HTTP Basic Authentication. Configure credentials
via `SWML_BASIC_AUTH_USER` / `SWML_BASIC_AUTH_PASSWORD`, or pass them into the
constructor:

```ruby
agent = SignalWire::AgentBase.new(
  name:       "my-agent",
  basic_auth: ["your-username", "your-password"]
)
```

### Authentication Flow

1. Client sends a request with an `Authorization: Basic <credentials>` header.
2. The agent validates the credentials against the configured values.
3. If invalid, the agent returns `401` with a `WWW-Authenticate` header.
4. If valid, the request is routed to the matching SWAIG handler.

## Testing

The Ruby SDK does not ship a CLI analogue to Python's `swaig-test`. Tests
target the agent's Rack app directly with `Rack::Test` or with raw HTTP
requests:

<!-- snippet: no-run illustrative fragment: references the AGENT/HANDLER globals defined in the entrypoint block earlier on the page -->
```ruby
require "rack/test"
include Rack::Test::Methods

def app
  AGENT.rack_app
end

get "/"
puts last_response.status
puts last_response.body
```

Exercise the Lambda adapter by building a Lambda event hash and calling
`HANDLER.call(event, nil)` directly:

<!-- snippet: no-run illustrative fragment: references the AGENT/HANDLER globals defined in the entrypoint block earlier on the page -->
```ruby
event = {
  "version"        => "2.0",
  "rawPath"        => "/",
  "requestContext" => { "http" => { "method" => "GET", "path" => "/" } },
  "headers"        => {
    "authorization" => "Basic " + ["user:pass"].pack("m0")
  }
}

puts HANDLER.call(event, nil).inspect
```

### Testing Authentication

```bash
# Test without auth (should return 401)
curl https://{url-id}.lambda-url.{region}.on.aws/

# Test with valid auth
curl -u user:pass https://{url-id}.lambda-url.{region}.on.aws/

# Test SWAIG function call
curl -u user:pass \
  -H "Content-Type: application/json" \
  -d '{"call_id": "test", "argument": {"parsed": [{"param": "value"}]}}' \
  https://{url-id}.lambda-url.{region}.on.aws/your_function_name
```

## Best Practices

### Performance

- Keep the agent initialized at file scope so it survives warm invocations.
- Vendor dependencies into the deployment package to avoid cold-start gem install.
- Use `SignalWire::Logging.global_level = :warn` in production to reduce log volume.

### Security

- Always deploy behind HTTPS.
- Keep `SWML_BASIC_AUTH_USER` / `SWML_BASIC_AUTH_PASSWORD` in AWS Secrets Manager
  or Parameter Store.
- Restrict Function URL access to specific IAM principals or API Gateway routes.

### Monitoring

- Enable CloudWatch Logs for your function.
- Monitor function execution time and set alerts for cold-start latency.

## Examples

See [`examples/lambda_agent.rb`](../examples/lambda_agent.rb) for a complete
AWS Lambda deployment example.

## Support

For issues specific to serverless deployment:

1. Check the troubleshooting section above.
2. Verify environment variables are set correctly.
3. Test authentication flow manually with `curl`.
4. Inspect CloudWatch Logs for detailed error messages.
