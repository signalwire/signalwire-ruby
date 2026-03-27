# frozen_string_literal: true

# Example: Upload a document to Datasphere and run a semantic search.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'

client = SignalWire::REST::RestClient.new

# 1. Upload a document (a publicly accessible text file)
puts 'Uploading document to Datasphere...'
doc = client.datasphere.documents.create(
  url:  'https://filesamples.com/samples/document/txt/sample3.txt',
  tags: %w[support demo]
)
doc_id = doc['id']
puts "  Document created: #{doc_id} (status: #{doc['status']})"

# 2. Wait for vectorization to complete
puts "\nWaiting for document to be vectorized..."
30.times do |i|
  sleep 2
  doc_status = client.datasphere.documents.get(doc_id)
  status = doc_status.fetch('status', 'unknown')
  puts "  Poll #{i + 1}: status=#{status}"

  if status == 'completed'
    puts "  Vectorized! Chunks: #{doc_status.fetch('number_of_chunks', 0)}"
    break
  end

  if %w[error failed].include?(status)
    puts "  Document processing failed: #{status}"
    client.datasphere.documents.delete(doc_id)
    exit 1
  end

  if i == 29
    puts '  Timed out waiting for vectorization.'
    client.datasphere.documents.delete(doc_id)
    exit 1
  end
end

# 3. List chunks
puts "\nListing chunks for document #{doc_id}..."
chunks = client.datasphere.documents.list_chunks(doc_id)
(chunks['data'] || []).first(5).each do |chunk|
  puts "  - Chunk #{chunk['id']}: #{(chunk['content'] || '')[0, 80]}..."
end

# 4. Semantic search across all documents
puts "\nSearching Datasphere..."
results = client.datasphere.documents.search(
  query_string: 'lorem ipsum dolor sit amet',
  count:        3
)
(results['chunks'] || []).each do |chunk|
  puts "  - #{(chunk['text'] || '')[0, 100]}..."
end

# 5. Clean up
puts "\nDeleting document #{doc_id}..."
client.datasphere.documents.delete(doc_id)
puts '  Deleted.'
