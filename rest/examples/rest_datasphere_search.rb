# frozen_string_literal: true

# Example: Upload a document to Datasphere and run a semantic search.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

# 1. Upload a document (a publicly accessible text file). Documents are created
#    from a request body (url + optional tags); the server vectorizes them
#    asynchronously.
puts 'Uploading document to Datasphere...'
doc = client.datasphere.documents.create(
  {
    url:  'https://filesamples.com/samples/document/txt/sample3.txt',
    tags: %w[support demo]
  }
)
doc_id = doc['id']
puts "  Document created: #{doc_id} (status: #{doc['status']})"

# 2. List chunks for the document (populated once vectorization completes).
puts "\nListing chunks for document #{doc_id}..."
chunks = client.datasphere.documents.list_chunks(doc_id)
(chunks['data'] || []).first(5).each do |chunk|
  puts "  - Chunk #{chunk['id']}: #{(chunk['content'] || '')[0, 80]}..."
end

# 3. Semantic search across all documents.
puts "\nSearching Datasphere..."
results = client.datasphere.documents.search(
  query_string: 'lorem ipsum dolor sit amet',
  count:        3
)
(results['chunks'] || []).each do |chunk|
  puts "  - #{(chunk['text'] || '')[0, 100]}..."
end

# 4. Clean up.
puts "\nDeleting document #{doc_id}..."
client.datasphere.documents.delete(doc_id)
puts '  Deleted.'
