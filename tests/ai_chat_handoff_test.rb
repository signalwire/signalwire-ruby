# frozen_string_literal: true

# HandoffRouter: moving one conversation between voice and text.
#
# The browser side of this contract is already shipped — the address widget
# hardcodes /handoff, /escalate and /say against its gateway URL — so these tests
# pin the server half against that fixed shape. Three properties matter more than
# the happy path:
#
# * The nonce is proof of having placed a call. It is never a call id, and an
#   unknown nonce is answered exactly like an expired one.
# * Ordering. A medium never starts until the one it replaces has finished and
#   been recorded.
# * Typing is repeatable but bounded: every injected message is a billable turn.
#
# Ported from signalwire-python tests/unit/ai_chat/test_handoff.py and the typing
# half of tests/unit/ai_chat/test_documented_limits.py.

require 'minitest/autorun'
require 'json'
require 'stringio'
require 'rack'
require 'rack/mock'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/ai_chat'

module HandoffTestHelper
  SECRET = 's' * 32
  Gateway = SignalWire::AIChat::ChatGateway
  Router = SignalWire::AIChat::HandoffRouter
  MAX_MESSAGE_BYTES = Gateway::MAX_MESSAGE_BYTES
  MAX_REQUEST_BODY_BYTES = Gateway::MAX_REQUEST_BODY_BYTES

  def setup
    @events = []
    @gateway = new_gateway
    @handoff = Router.new(gateway: @gateway, **recording_callbacks(@events))
  end

  # capture_leg / end_call / send_message that record each call, in order.
  def recording_callbacks(events)
    { capture_leg: ->(conversation_id, medium) { (events << [:capture, conversation_id, medium]) && true },
      end_call: ->(call_id) { events << [:end_call, call_id] },
      send_message: ->(call_id, text) { (events << [:say, call_id, text]) && true } }
  end

  def new_gateway(**)
    client = SignalWire::AIChatClient.new(project: 'p', token: 't', url: 'https://service.example.invalid/aichat')
    Gateway.new(config_url: 'https://agent.example.com/swml', key: 'pk_test', secret: SECRET, client: client, **)
  end

  # A send_message whose first delivery fails, recording every attempt.
  def failing_once_sender(attempts)
    lambda { |_call_id, text|
      attempts << text
      raise IOError, 'platform unavailable' if attempts.length == 1

      true
    }
  end

  # A send_message that records the text and always succeeds.
  def recording_sender(events)
    lambda { |_call_id, text|
      events << [:say, text]
      true
    }
  end

  def http(router = @handoff)
    app = router.router
    Rack::MockRequest.new(Rack::Builder.new { map('/chat') { run app } }.to_app)
  end

  def post(path, body, router: @handoff)
    http(router).post(path, input: body.is_a?(String) ? body : JSON.generate(body),
                            'CONTENT_TYPE' => 'application/json')
  end

  def nonces(router = @handoff)
    router.instance_variable_get(:@nonces)
  end

  # Move a registration back past the router's nonce_ttl.
  def age_past_ttl(nonce, router = @handoff)
    nonces(router)[nonce].issued_at -= router.nonce_ttl + 1
  end
end

class HandoffRedemptionTest < Minitest::Test
  include HandoffTestHelper

  def test_returns_a_handle_the_gateway_can_read
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')
    response = post('/chat/handoff', { 'nonce' => 'n1' })

    assert_equal 200, response.status
    assert @gateway.read_handle(JSON.parse(response.body)['handle'])
  end

  # Ending first is what makes the record exist to be captured.
  def test_call_ends_before_the_leg_is_captured
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')
    post('/chat/handoff', { 'nonce' => 'n1' })

    assert_equal [[:end_call, 'call-9'], [:capture, 'conv-root', 'voice']], @events
  end

  # An ended conversation cannot be reopened, so the handle names a new leg.
  def test_new_leg_gets_a_fresh_dotted_id
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')
    response = post('/chat/handoff', { 'nonce' => 'n1' })

    assert_equal 'conv-root.1', @gateway.read_handle(JSON.parse(response.body)['handle'])
  end

  def test_leg_ids_increment
    assert_equal 'root.3', @handoff.next_conversation_id.call('root.2')
    assert_equal 'root.1', @handoff.next_conversation_id.call('root')
    assert_equal 'a.b.1', @handoff.next_conversation_id.call('a.b')
  end

  def test_a_custom_next_conversation_id_is_used
    router = Router.new(gateway: @gateway, next_conversation_id: ->(id) { "#{id}-next" })
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert_equal 'c-next', @gateway.read_handle(router.redeem('n'))
  end

  def test_a_nonce_is_single_use
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')

    assert_equal 200, post('/chat/handoff', { 'nonce' => 'n1' }).status
    assert_equal 404, post('/chat/handoff', { 'nonce' => 'n1' }).status
  end

  # Otherwise this route reports whether a given call is live.
  def test_unknown_and_spent_nonces_are_indistinguishable
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')
    post('/chat/handoff', { 'nonce' => 'n1' })
    spent = post('/chat/handoff', { 'nonce' => 'n1' })
    unknown = post('/chat/handoff', { 'nonce' => 'never-existed' })
    not_found = [404, { 'error' => 'not found' }]

    assert_equal not_found, [spent.status, JSON.parse(spent.body)]
    assert_equal not_found, [unknown.status, JSON.parse(unknown.body)]
  end

  def test_expired_nonces_are_not_redeemable
    expired = Router.new(gateway: @gateway, nonce_ttl: -1)
    expired.register('n1', conversation_id: 'conv-root', call_id: 'call-9')

    assert_nil expired.redeem('n1')
  end

  def test_missing_nonce_is_rejected
    assert_equal 404, post('/chat/handoff', {}).status
    assert_equal 404, post('/chat/handoff', { 'nonce' => 5 }).status
  end

  def test_a_disallowed_origin_is_refused
    r = http.post('/chat/handoff', input: '{"nonce": "n"}', 'HTTP_ORIGIN' => 'https://evil.example')

    assert_equal 403, r.status
    assert_equal({ 'error' => 'origin not allowed' }, JSON.parse(r.body))
  end

  # A path the router does not own cascades, so a ChatGateway can share the
  # prefix through Rack::Cascade.
  def test_an_unknown_path_cascades
    r = post('/chat/', {})

    assert_equal 404, r.status
    assert_equal 'pass', r.headers['x-cascade']
  end

  def test_both_routers_share_one_prefix_through_a_cascade
    apps = [@gateway.router, @handoff.router]
    req = Rack::MockRequest.new(Rack::Builder.new { map('/chat') { run Rack::Cascade.new(apps) } }.to_app)
    @handoff.register('n1', conversation_id: 'conv-root', call_id: 'call-9')

    assert_equal 200, req.post('/chat/handoff', input: '{"nonce": "n1"}').status
    assert_equal 401, req.post('/chat/', input: '{"message": "hi"}').status
  end
end

# The per-call config callback registers the nonce on every SWML request for the
# call, and the browser chooses the nonce, so a repeat registration must not
# reset, move or revive an entry.
class HandoffRegistrationTest < Minitest::Test
  include HandoffTestHelper

  def test_a_repeat_registration_keeps_the_typing_count
    router = Router.new(gateway: @gateway, send_message: recording_sender(@events), max_messages_per_call: 1)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert router.say('n', 'one')
    refute router.say('n', 'two')
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute router.say('n', 'three')
    assert_equal [[:say, 'one']], @events
  end

  def test_a_repeat_registration_keeps_the_registration_time
    @handoff.register('n', conversation_id: 'c', call_id: 'call-1')
    first = nonces['n'].issued_at
    @handoff.register('n', conversation_id: 'c', call_id: 'call-1')

    assert_equal first, nonces['n'].issued_at
  end

  def test_a_live_nonce_cannot_be_moved_to_another_call
    @handoff.register('n', conversation_id: 'conv-a', call_id: 'call-a')
    @handoff.register('n', conversation_id: 'conv-b', call_id: 'call-b')

    assert_equal 200, post('/chat/say', { 'nonce' => 'n', 'text' => 'hi' }).status
    assert_equal [[:say, 'call-a', 'hi']], @events
  end

  def test_a_redeemed_nonce_cannot_be_registered_and_redeemed_again
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')

    assert_equal 200, post('/chat/handoff', { 'nonce' => 'n' }).status
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-10')
    again = post('/chat/handoff', { 'nonce' => 'n' })

    assert_equal 404, again.status
    assert_equal({ 'error' => 'not found' }, JSON.parse(again.body))
  end

  def test_a_redeemed_nonce_cannot_type
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')
    post('/chat/handoff', { 'nonce' => 'n' })
    @events.clear
    said = post('/chat/say', { 'nonce' => 'n', 'text' => 'late' })

    assert_equal 404, said.status
    assert_empty @events
  end

  def test_redemption_is_kept_until_the_ttl_passes
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')

    assert @handoff.redeem('n') && nonces['n'].redeemed
    # Once the entry would have expired it is pruned, and the nonce can be
    # registered afresh.
    age_past_ttl('n')
    @handoff.register('n', conversation_id: 'conv-new', call_id: 'call-11')

    assert_equal ['conv-new', false], nonces['n'].to_h.values_at(:conversation_id, :redeemed)
  end

  # A registry backed by shared storage sees the change only when the entry is
  # assigned back, so redemption must not rely on mutation.
  # Records every assignment as [key, redeemed].
  Recording = Class.new(Hash) do
    def assigned = (@assigned ||= [])

    def []=(key, value)
      assigned << [key, value.redeemed]
      super
    end
  end

  def test_a_shared_registry_stores_the_redemption
    registry = Recording.new
    router = Router.new(gateway: @gateway, registry: registry)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute_nil router.redeem('n')
    assert_equal [['n', false], ['n', true]], registry.assigned
  end

  def test_an_empty_or_non_string_nonce_is_ignored
    @handoff.register('', conversation_id: 'c', call_id: 'call-1')
    @handoff.register(nil, conversation_id: 'c', call_id: 'call-1')

    assert_empty nonces
  end
end

# The per-call config callback registers nonces in worker threads, and /handoff
# and /say requests overlap, so the table's updates are atomic.
class HandoffConcurrencyTest < Minitest::Test
  include HandoffTestHelper

  # Once the first lookup has found the nonce absent, runs +racer+ in another
  # thread, before the caller inserts its entry — and waits for it only briefly,
  # since it blocks on the router's lock if the update is atomic.
  Racing = Class.new(Hash) do
    attr_accessor :racer, :raced_thread

    def [](key)
      found = super
      if racer && !raced_thread
        self.raced_thread = Thread.new(&racer)
        raced_thread.join(0.5)
      end
      found
    end
  end

  # A router whose registry races a second register + redeem (into +handles+)
  # against the first registration's lookup.
  def racing_router(handles)
    router = Router.new(gateway: @gateway)
    registry = Racing.new
    registry.racer = lambda {
      router.register('n', conversation_id: 'late', call_id: 'call-2')
      handles << router.redeem('n')
    }
    router.instance_variable_set(:@nonces, registry)
    router
  end

  def test_a_registration_racing_a_redemption_cant_revive_the_nonce
    handles = Queue.new
    router = racing_router(handles)
    router.register('n', conversation_id: 'first', call_id: 'call-1')
    nonces(router).raced_thread.join(5)
    # One registration stands, and the nonce redeems once.
    handles << router.redeem('n')

    assert_equal 1, Array.new(handles.size) { handles.pop }.compact.length
  end

  def test_overlapping_says_cant_pass_the_cap
    delivered = Queue.new
    send = ->(_call_id, text) { sleep(0.01) && (delivered << text) } # delivery takes a moment
    router = Router.new(gateway: @gateway, send_message: send, max_messages_per_call: 1)
    router.register('n', conversation_id: 'c', call_id: 'call-1')
    results = Array.new(3) { |i| Thread.new { router.say('n', "m#{i}") } }.map(&:value)

    assert_equal 1, results.count(true)
    assert_equal 1, delivered.size
  end

  def test_a_failed_delivery_gives_its_slot_back
    attempts = []
    router = Router.new(gateway: @gateway, send_message: failing_once_sender(attempts), max_messages_per_call: 1)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute router.say('n', 'first')
    assert router.say('n', 'again')
    refute router.say('n', 'over the cap')
    assert_equal %w[first again], attempts
  end
end

# A shared registry, such as one backed by a cache, returns a copy of an entry
# rather than the stored object.
class HandoffCopyingRegistryTest < Minitest::Test
  include HandoffTestHelper

  Copying = Class.new(Hash) do
    def [](key) = super&.dup

    def []=(key, value)
      super(key, value.dup)
    end
  end

  def test_a_failed_delivery_gives_its_slot_back
    attempts = []
    router = Router.new(gateway: @gateway, send_message: failing_once_sender(attempts), max_messages_per_call: 1,
                        registry: Copying.new)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute router.say('n', 'first')
    assert router.say('n', 'again')
    refute router.say('n', 'over the cap')
    assert_equal %w[first again], attempts
  end

  def test_a_redeemed_nonce_stays_redeemed
    router = Router.new(gateway: @gateway, registry: Copying.new)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute_nil router.redeem('n')
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert_nil router.redeem('n')
  end
end

class HandoffEscalateTest < Minitest::Test
  include HandoffTestHelper

  # The browser blocks on this, which is what makes the following dial safe.
  def test_captures_the_chat_leg_before_returning
    handle = @gateway.mint_handle('conv-root.5')
    r = post('/chat/escalate', { 'handle' => handle })

    assert_equal 200, r.status
    assert_equal({ 'ok' => true }, JSON.parse(r.body))
    assert_equal [[:capture, 'conv-root.5', 'chat']], @events
  end

  def test_a_forged_handle_is_refused
    assert_equal 404, post('/chat/escalate', { 'handle' => 'forged' }).status
  end

  def test_a_missing_handle_is_a_bad_request
    r = post('/chat/escalate', {})

    assert_equal 400, r.status
    assert_equal({ 'error' => 'bad request' }, JSON.parse(r.body))
  end
end

class HandoffSayTest < Minitest::Test
  include HandoffTestHelper

  def test_delivers_trimmed_text_to_the_call_the_nonce_names
    @handoff.register('n2', conversation_id: 'conv-root', call_id: 'call-9')
    r = post('/chat/say', { 'nonce' => 'n2', 'text' => '  hello  ' })

    assert_equal 200, r.status
    assert_equal({ 'ok' => true }, JSON.parse(r.body))
    assert_equal [[:say, 'call-9', 'hello']], @events
  end

  # Unlike redemption, typing is repeatable until the nonce is redeemed or expires.
  def test_is_repeatable
    @handoff.register('n2', conversation_id: 'conv-root', call_id: 'call-9')

    3.times { assert_equal 200, post('/chat/say', { 'nonce' => 'n2', 'text' => 'x' }).status }
  end

  # Every injection is a billable turn.
  def test_is_capped_per_call
    router = Router.new(gateway: @gateway, send_message: recording_sender(@events), max_messages_per_call: 2)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert router.say('n', 'one')
    assert router.say('n', 'two')
    refute router.say('n', 'three')
  end

  def test_empty_text_is_refused
    @handoff.register('n2', conversation_id: 'conv-root', call_id: 'call-9')

    assert_equal 404, post('/chat/say', { 'nonce' => 'n2', 'text' => '   ' }).status
  end

  # The whole point: a browser cannot name someone else's call.
  def test_an_unknown_nonce_cannot_inject
    assert_equal 404, post('/chat/say', { 'nonce' => 'guessed', 'text' => 'hello' }).status
  end

  def test_a_nonce_without_a_call_cannot_type
    @handoff.register('n', conversation_id: 'c')

    refute @handoff.say('n', 'hello')
  end

  def test_disabled_when_no_sender_is_configured
    router = Router.new(gateway: @gateway)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute router.say('n', 'hello')
  end
end

class HandoffSizeLimitTest < Minitest::Test
  include HandoffTestHelper

  def test_say_refuses_text_over_the_message_limit
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')
    r = post('/chat/say', { 'nonce' => 'n', 'text' => 'x' * (MAX_MESSAGE_BYTES + 1) })

    assert_equal 413, r.status
    assert_equal({ 'error' => 'message too large' }, JSON.parse(r.body))
    assert_empty @events
  end

  # Checked before the lookup, so it can't be used to probe a nonce.
  def test_the_size_answer_does_not_depend_on_the_nonce
    r = post('/chat/say', { 'nonce' => 'never-existed', 'text' => 'x' * (MAX_MESSAGE_BYTES + 1) })

    assert_equal 413, r.status
    assert_equal({ 'error' => 'message too large' }, JSON.parse(r.body))
  end

  def test_say_accepts_text_at_the_limit
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')
    text = 'x' * MAX_MESSAGE_BYTES

    assert_equal 200, post('/chat/say', { 'nonce' => 'n', 'text' => text }).status
    assert_equal [[:say, 'call-9', text]], @events
  end

  def test_say_called_directly_refuses_oversized_text
    router = Router.new(gateway: @gateway, send_message: recording_sender(@events))
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    refute router.say('n', 'x' * (MAX_MESSAGE_BYTES + 1))
    assert_empty @events
  end

  def test_an_oversized_body_is_refused
    %w[/chat/handoff /chat/escalate /chat/say].each do |path|
      r = post(path, ' ' * (MAX_REQUEST_BODY_BYTES + 1))

      assert_equal 413, r.status, path
      assert_equal({ 'error' => 'request too large' }, JSON.parse(r.body))
    end
  end

  def test_an_oversized_handoff_leaves_the_nonce_redeemable
    @handoff.register('n', conversation_id: 'conv-root', call_id: 'call-9')
    padded = "{\"nonce\": \"n\", \"pad\": \"#{'x' * MAX_REQUEST_BODY_BYTES}\"}"

    assert_equal 413, post('/chat/handoff', padded).status
    assert_equal 200, post('/chat/handoff', { 'nonce' => 'n' }).status
  end
end

class HandoffCaptureFailureTest < Minitest::Test
  include HandoffTestHelper

  # Thin context beats refusing a switch the visitor asked for.
  def test_a_capture_timeout_does_not_block_the_switch
    never_finishes = ->(_id, _medium) { sleep(10) || true }
    router = Router.new(gateway: @gateway, capture_leg: never_finishes, capture_timeout: 0.05)
    router.register('n', conversation_id: 'c', call_id: 'call-1')
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    handle = router.redeem('n')

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
    refute_nil handle
    assert_equal 'c.1', @gateway.read_handle(handle)
  end

  def test_a_raising_capture_does_not_block_the_switch
    router = Router.new(gateway: @gateway, capture_leg: ->(_id, _medium) { raise 'storage down' })
    router.register('n', conversation_id: 'c', call_id: 'call-1')
    handle = router.redeem('n')

    refute_nil handle
    assert_equal 'c.1', @gateway.read_handle(handle)
  end

  def test_a_raising_end_call_does_not_block_the_switch
    router = Router.new(gateway: @gateway, end_call: ->(_call_id) { raise IOError, 'hangup failed' })
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert_equal 'c.1', @gateway.read_handle(router.redeem('n'))
  end
end

# The typing lifetime the documentation promises (test_documented_limits.py).
class HandoffTypingLifetimeTest < Minitest::Test
  include HandoffTestHelper

  def test_typing_stops_when_the_nonce_expires
    sent = []
    router = Router.new(gateway: @gateway, send_message: recording_sender(sent), nonce_ttl: 600)
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert router.say('n', 'before')
    # Move the registration back past nonce_ttl, as if the call had run longer.
    nonces(router)['n'].issued_at -= 601

    refute router.say('n', 'after')
    assert_equal [[:say, 'before']], sent
  end

  def test_typing_stops_once_the_nonce_is_redeemed
    sent = []
    router = Router.new(gateway: @gateway, send_message: recording_sender(sent))
    router.register('n', conversation_id: 'c', call_id: 'call-1')

    assert router.say('n', 'before')
    refute_nil router.redeem('n')
    refute router.say('n', 'after')
    assert_equal [[:say, 'before']], sent
  end
end

class NonceEntryTest < Minitest::Test
  def test_defaults
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    entry = SignalWire::AIChat::NonceEntry.new(conversation_id: 'c')

    assert_equal ['c', nil, 0, false], [entry.conversation_id, entry.call_id, entry.messages, entry.redeemed]
    assert_operator entry.issued_at, :>=, before
  end

  def test_is_a_value
    a = SignalWire::AIChat::NonceEntry.new(conversation_id: 'c', call_id: 'x', issued_at: 1.0)
    b = SignalWire::AIChat::NonceEntry.new(conversation_id: 'c', call_id: 'x', issued_at: 1.0)

    assert_equal a, b
    b.messages += 1

    refute_equal a, b
  end
end

# The service strips disallowed characters silently, so an id composed with the
# wrong separator is stored under a different, valid-looking id.
class ConversationIdSanitizationTest < Minitest::Test
  def setup
    @client = SignalWire::AIChatClient.new(project: 'p', token: 't', url: 'https://service.example.invalid/aichat')
    @saved_stderr = $stderr
    $stderr = StringIO.new
    SignalWire::Logging.global_level = :warn
  end

  def teardown
    $stderr = @saved_stderr
    SignalWire::Logging.reset!
  end

  def warn_for(id)
    @client.send(:warn_if_id_will_be_altered, id)
    $stderr.string
  end

  def test_safe_ids_are_quiet
    ['conv-abc', 'root.2', 'a_b-c.d:e'].each { |safe| assert_empty warn_for(safe) }
  end

  # The warning names the id the service will really use.
  def test_unsafe_ids_warn_with_what_will_actually_be_stored
    { 'root~2' => 'root2', 'conv id' => 'convid', 'x!' => 'x' }.each do |unsafe, stored_as|
      $stderr = StringIO.new
      out = warn_for(unsafe)

      assert_equal 1, out.lines.length, out
      assert_includes out, 'conversation_id_will_be_sanitized'
      assert_includes out, "stored_as=#{stored_as}"
    end
  end

  def test_junk_is_ignored_rather_than_warned_about
    [nil, '', 123, []].each { |junk| assert_empty warn_for(junk) }
  end
end
