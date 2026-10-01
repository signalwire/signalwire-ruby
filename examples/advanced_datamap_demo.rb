# frozen_string_literal: true

# Example: Advanced DataMap patterns.
#
# Demonstrates expressions with pattern matching, advanced webhook features,
# form parameter encoding, array processing, and conditional logic --
# all using the server-side DataMap builder.

require 'signalwire'
require 'json'

# --- Expression-based command processor ---

command_processor = SignalWire::DataMap.new('command_processor')
command_processor
  .purpose('Process user commands with pattern matching')
  .parameter('command', 'string', 'User command to process', required: true)
  .parameter('target', 'string', 'Optional target for the command', required: false)

command_processor.expression(
  '${args.command}', '^start',
  SignalWire::Swaig::FunctionResult.new('Starting process: ${args.target}')
)
command_processor.expression(
  '${args.command}', '^stop',
  SignalWire::Swaig::FunctionResult.new('Stopping process: ${args.target}')
)
command_processor.expression(
  '${args.command}', '^status',
  SignalWire::Swaig::FunctionResult.new('Checking status of: ${args.target}'),
  nomatch_output: SignalWire::Swaig::FunctionResult.new(
    'Unknown command: ${args.command}. Try start, stop, or status.'
  )
)

# --- Advanced webhook tool ---

advanced_api = SignalWire::DataMap.new('advanced_api_tool')
advanced_api
  .purpose('API tool with advanced webhook features')
  .parameter('action', 'string', 'Action to perform', required: true)
  .parameter('data', 'string', 'Data to send', required: false)
  .webhook(
    'POST', 'https://api.example.com/advanced',
    headers: {
      'Authorization' => 'Bearer ${token}',
      'User-Agent' => 'SignalWire-Agent/1.0'
    },
    input_args_as_params: true,
    require_args: ['action'],
    form_param: 'payload'
  )
  .webhook_expressions([
                         {
                           'string' => '${response.status}',
                           'pattern' => '^success$',
                           'output' => { 'response' => 'Operation completed successfully' }
                         },
                         {
                           'string' => '${response.error_code}',
                           'pattern' => '^(404|500)$',
                           'output' => { 'response' => 'API Error: ${response.error_message}' }
                         }
                       ])

# Fallback webhook
advanced_api.webhook(
  'GET', 'https://backup-api.example.com/simple',
  headers: { 'Accept' => 'application/json' }
)
advanced_api.params('q' => '${args.action}')
advanced_api.output(
  SignalWire::Swaig::FunctionResult.new('Backup result: ${response.data}')
)
advanced_api.fallback_output(
  SignalWire::Swaig::FunctionResult.new('All APIs are currently unavailable')
)
advanced_api.global_error_keys(%w[error fault exception])

# --- Form-encoded submission ---

form_tool = SignalWire::DataMap.new('form_submission_tool')
                               .purpose('Submit form data using form encoding')
                               .parameter('name', 'string', 'User name', required: true)
                               .parameter('email', 'string', 'User email', required: true)
                               .parameter('message', 'string', 'Message content', required: true)
                               .webhook(
                                 'POST', 'https://forms.example.com/submit',
                                 headers: {
                                   'Content-Type' => 'application/x-www-form-urlencoded',
                                   'X-API-Key' => '${api_key}'
                                 },
                                 form_param: 'form_data'
                               )
                               .params(
                                 'name' => '${args.name}',
                                 'email' => '${args.email}',
                                 'message' => '${args.message}'
                               )
                               .output(
                                 SignalWire::Swaig::FunctionResult.new(
                                   'Form submitted successfully for ${args.name}'
                                 )
                               )

# --- Array processing with foreach ---

search_tool = SignalWire::DataMap.new('search_results_tool')
                                 .purpose('Search and format results from API')
                                 .parameter('query', 'string', 'Search query', required: true)
                                 .parameter('limit', 'string', 'Maximum results', required: false)
                                 .webhook(
                                   'GET', 'https://search-api.example.com/search',
                                   headers: { 'Authorization' => 'Bearer ${search_token}' }
                                 )
                                 .params('q' => '${args.query}')
                                 .foreach(
                                   'input_key' => 'results',
                                   'output_key' => 'formatted_results',
                                   'max' => 5,
                                   'append' => "Title: ${this.title}\n${this.summary}\nURL: ${this.url}\n\n"
                                 )
                                 .output(
                                   SignalWire::Swaig::FunctionResult.new(
                                     'Found results for "${args.query}":\n\n${formatted_results}'
                                   )
                                 )

# --- Print all definitions ---

demos = {
  'Expression Demo' => command_processor,
  'Advanced Webhook Demo' => advanced_api,
  'Form Encoding Demo' => form_tool,
  'Array Processing Demo' => search_tool
}

demos.each do |label, dm|
  puts "\n#{'=' * 50}"
  puts label
  puts '=' * 50
  puts JSON.pretty_generate(dm.to_swaig_function)
end
