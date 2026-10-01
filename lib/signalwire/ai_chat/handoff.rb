# frozen_string_literal: true

# Copyright (c) 2026 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
require_relative '../logging'
require_relative '../core/logging_config'
require_relative 'gateway'
require_relative 'rack_support'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Namespace holding the AI Chat client's error family, response models and
  # the browser-facing gateway.
  module AIChat
    # What a handoff nonce is a capability for: the conversation, the call it
    # was registered against, when, how many typed messages it has carried, and
    # whether +/handoff+ has exchanged it for a handle.
    #
    # A redeemed entry is kept until its TTL passes, so the nonce can be neither
    # redeemed nor registered again. A value object: two entries with the same
    # fields are +==+.
    NonceEntry = Struct.new(:conversation_id, :call_id, :issued_at, :messages, :redeemed, keyword_init: true) do
      # @param conversation_id [String] the conversation the nonce continues
      # @param call_id [String, nil] the call it was registered against
      # @param issued_at [Float] monotonic seconds of the first registration
      # @param messages [Integer] typed messages delivered (or reserved) so far
      # @param redeemed [Boolean] whether +/handoff+ has exchanged it
      def initialize(conversation_id:, call_id: nil, issued_at: Process.clock_gettime(Process::CLOCK_MONOTONIC),
                     messages: 0, redeemed: false)
        super
      end
    end

    # The three routes a browser client needs beside a {ChatGateway}: moving one
    # conversation to a phone call and back, and typing into a live call.
    #
    # The SignalWire address widget hardcodes +{gateway-url}/handoff+,
    # +{gateway-url}/escalate+ and +{gateway-url}/say+ against the same URL that
    # points at a ChatGateway, and sends +handoff_nonce+ and +chat_handle+ as
    # user variables. Mount both under one prefix:
    #
    #   handoff = SignalWire::AIChat::HandoffRouter.new(gateway: gateway, ...)
    #   map('/chat') { run Rack::Cascade.new([gateway.router, handoff.router]) }
    #
    # == Mechanism vs policy
    #
    # This class owns the wire contract only: the routes, the nonce, the
    # ordering guarantee and the spend guards. Where a leg's transcript is
    # written, what a resumed greeting says, how much history to carry — all of
    # that is the application's, injected as callables.
    #
    # == The nonce
    #
    # A browser cannot be trusted to name a call, so it proves which call it is
    # on instead: the application puts a random +handoff_nonce+ in the user
    # variables of one dial, {#register}s it here against that call's ids, and the
    # browser presents it later. A nonce is registered once (the first
    # registration stands); redemption for a handle is single use; typing is
    # repeatable, bounded by +max_messages_per_call+, until the nonce is redeemed
    # or +nonce_ttl+ seconds pass after it was registered. An unknown nonce is
    # answered exactly like an expired or redeemed one.
    #
    # == The ordering guarantee
    #
    # A medium never starts until the one it replaces has finished and its record
    # is durable: +/handoff+ ends the call and waits for +capture_leg+ before
    # minting a handle; +/escalate+ waits for it before returning.
    #
    # == Deployment
    #
    # The nonce registry lives in this process. A redemption must reach the
    # replica that served the dial: run one replica, use sticky routing, or
    # supply a shared +registry+. Registration, redemption and the typing count
    # are atomic within one router (a Mutex); across routers sharing a registry
    # they are not, since the registry is a plain mapping.
    class HandoffRouter
      include RackSupport

      # Seconds a nonce stays usable after its first registration.
      DEFAULT_NONCE_TTL = 3600

      # Ceiling on typed messages for one call.
      DEFAULT_MAX_MESSAGES_PER_CALL = 200

      # Seconds to wait for +capture_leg+.
      DEFAULT_CAPTURE_TIMEOUT = 8.0

      ROUTES = { '/handoff' => :handoff_route, '/escalate' => :escalate_route, '/say' => :say_route }.freeze
      private_constant :ROUTES

      # The gateway that owns the conversations; mints handles and checks origins.
      attr_reader :gateway

      # +capture_leg.call(conversation_id, medium)+: end a leg and write its
      # record, returning truthy once it is durable. +nil+ = no wait.
      attr_reader :capture_leg

      # +end_call.call(call_id)+: hang the call up server-side.
      attr_reader :end_call

      # +send_message.call(call_id, text)+: inject typed text into a live call.
      # +nil+ leaves typing disabled.
      attr_reader :send_message

      # +next_conversation_id.call(conversation_id)+: the id for the NEW leg.
      attr_reader :next_conversation_id

      # Seconds a nonce stays usable after its first registration.
      attr_reader :nonce_ttl

      # Ceiling on typed messages for one call — each is a billable turn.
      attr_reader :max_messages_per_call

      # Seconds to wait for +capture_leg+ — a ceiling, not a budget.
      attr_reader :capture_timeout

      # Configure the handoff.
      #
      # @param gateway [ChatGateway] mints handles and checks origins, so both
      #   halves of the URL enforce the same origin policy
      # @param capture_leg [#call, nil] +(conversation_id, medium) -> truthy+ once
      #   the leg's record is durable. Omit and no wait happens, so the ordering
      #   guarantee is not provided. Runs on its own thread, bounded by
      #   +capture_timeout+; a capture still running at the deadline is left to
      #   finish and its result is ignored.
      # @param end_call [#call, nil] +(call_id)+ hangs up server-side
      # @param send_message [#call, nil] +(call_id, text)+ for +/say+; omit to
      #   leave typing disabled
      # @param next_conversation_id [#call, nil] +(conversation_id) -> String+ for
      #   the new leg; defaults to appending +.N+ (+.+ is the one separator the
      #   service preserves and no generated id contains)
      # @param nonce_ttl [Integer] seconds a nonce stays usable after its first
      #   registration; a redeemed nonce is kept as long
      # @param max_messages_per_call [Integer] ceiling on typed messages per call
      # @param capture_timeout [Float] seconds to wait for +capture_leg+
      # @param registry [Hash, nil] shared nonce table (anything answering +[]+,
      #   +[]=+, +delete+ and +each_pair+). Changes are written back by
      #   assignment, so a registry that returns copies works.
      def initialize(gateway:, capture_leg: nil, end_call: nil, send_message: nil, next_conversation_id: nil,
                     nonce_ttl: DEFAULT_NONCE_TTL, max_messages_per_call: DEFAULT_MAX_MESSAGES_PER_CALL,
                     capture_timeout: DEFAULT_CAPTURE_TIMEOUT, registry: nil)
        @gateway = gateway
        @capture_leg = capture_leg
        @end_call = end_call
        @send_message = send_message
        @next_conversation_id = next_conversation_id || method(:default_next_id)
        @nonce_ttl = nonce_ttl
        @max_messages_per_call = max_messages_per_call
        @capture_timeout = capture_timeout
        @nonces = registry.nil? ? {} : registry
        @lock = Mutex.new
      end

      # Record what a nonce is a capability for.
      #
      # Call this from the dynamic-config callback of the dial that carried the
      # nonce, reading +call_id+ from the request the platform sent — never from
      # anything the browser supplied. The first registration stands: a repeat
      # keeps its call, registration time and typed-message count, and a
      # redeemed nonce stays redeemed (a mismatch is logged as a warning). Once
      # the entry's +nonce_ttl+ has passed the nonce can be registered again.
      #
      # @param nonce [String]
      # @param conversation_id [String]
      # @param call_id [String, nil]
      # @return [nil]
      def register(nonce, conversation_id:, call_id: nil)
        return unless nonce.is_a?(String) && !nonce.empty?

        existing = @lock.synchronize do
          prune
          found = @nonces[nonce]
          @nonces[nonce] = NonceEntry.new(conversation_id: conversation_id, call_id: call_id) if found.nil?
          found
        end
        log_registration(existing, conversation_id, call_id)
        nil
      end

      # Exchange a nonce for a chat handle. Single use.
      #
      # Ends the call, waits for its record, and only then mints a handle for a
      # new leg of the same conversation.
      #
      # @param nonce [String]
      # @return [String, nil] the signed handle, or +nil+ for an unknown, expired
      #   or already redeemed nonce — deliberately indistinguishable
      def redeem(nonce)
        entry = claim(nonce)
        return nil if entry.nil?

        hang_up(entry.call_id)
        capture(entry.conversation_id, 'voice')
        handle = mint_next(entry.conversation_id)
        logger.info("handoff_redeemed conversation_id=#{entry.conversation_id}") if handle
        handle
      end

      # End a chat leg and wait for its record, before a call is placed. The
      # browser waits on this, so a voice leg started immediately afterwards is
      # guaranteed to find the text leg already recorded.
      #
      # @param handle [String] a handle the gateway issued
      # @return [Boolean] +false+ when the handle doesn't verify
      def escalate(handle)
        conversation_id = handle_conversation(handle)
        return false if conversation_id.nil?

        capture(conversation_id, 'chat')
        logger.info("handoff_escalated conversation_id=#{conversation_id}")
        true
      end

      # Deliver typed text into the live call the nonce names.
      #
      # Does NOT consume the nonce: typing is repeatable until the nonce is
      # redeemed or its +nonce_ttl+ passes, up to +max_messages_per_call+
      # messages. Addressed by nonce rather than by any browser-supplied call id,
      # and no other request field is forwarded. Text over
      # {ChatGateway::MAX_MESSAGE_BYTES} (UTF-8) is refused.
      #
      # @param nonce [String]
      # @param text [String]
      # @return [Boolean] whether the text was delivered
      def say(nonce, text)
        return false if send_message.nil?

        cleaned = text.to_s.strip
        return false if cleaned.empty? || utf8_len(cleaned) > ChatGateway::MAX_MESSAGE_BYTES

        entry = reserve_slot(nonce)
        return false if entry.nil?

        deliver(nonce, entry, cleaned)
      end

      # A Rack app with the three routes. Mount it at the SAME prefix as the
      # gateway's router (through +Rack::Cascade+); the browser derives all three
      # paths from one configured URL.
      #
      # * +POST /handoff+ takes +{nonce}+ and returns +{handle}+.
      # * +POST /escalate+ takes +{handle}+ and returns +{ok: true}+.
      # * +POST /say+ takes +{nonce, text}+ and returns +{ok: true}+.
      #
      # Each returns 403 for a refused origin and 404 +{"error": "not found"}+
      # when the nonce or handle doesn't verify. Each returns 413 for a body over
      # {ChatGateway::MAX_REQUEST_BODY_BYTES}, and +/say+ for text over
      # {ChatGateway::MAX_MESSAGE_BYTES}; both are checked before the nonce is
      # looked up. Any other path answers 404 with +X-Cascade: pass+.
      #
      # @return [#call] the Rack application
      def router
        ->(env) { route(env) }
      end

      private

      # The handoff logger.
      def logger
        Logging.logger('signalwire.ai_chat.handoff')
      end

      # Monotonic clock seconds, for nonce lifetimes.
      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # +root+ -> +root.1+; +root.2+ -> +root.3+.
      def default_next_id(conversation_id)
        root, sep, tail = conversation_id.rpartition('.')
        return "#{root}.#{Integer(tail, 10) + 1}" if !sep.empty? && !root.empty? && tail.match?(/\A[0-9]+\z/)

        "#{conversation_id}.1"
      end

      # Log a first registration, or a repeat that tried to change an entry.
      def log_registration(existing, conversation_id, call_id)
        if existing.nil?
          logger.info("handoff_nonce_registered conversation_id=#{conversation_id} call_id=#{call_id}")
        elsif existing.redeemed || existing.conversation_id != conversation_id || existing.call_id != call_id
          logger.warn("handoff_nonce_already_registered conversation_id=#{existing.conversation_id} " \
                      "call_id=#{existing.call_id} redeemed=#{existing.redeemed}")
        end
      end

      # Drop entries, redeemed ones included, whose TTL has passed. Lock held.
      def prune
        cutoff = monotonic - nonce_ttl
        stale = []
        @nonces.each_pair { |nonce, entry| stale << nonce if entry.issued_at < cutoff }
        stale.each { |nonce| @nonces.delete(nonce) }
      end

      # The live entry for +nonce+: nil if unknown, expired or redeemed. Lock held.
      def lookup(nonce)
        return nil unless nonce.is_a?(String) && !nonce.empty?

        prune
        entry = @nonces[nonce]
        entry.nil? || entry.redeemed ? nil : entry
      end

      # Mark a live nonce redeemed — consumed even if what follows fails — and
      # write it back so a shared registry stores the change.
      def claim(nonce)
        @lock.synchronize do
          entry = lookup(nonce)
          next nil if entry.nil?

          entry.redeemed = true
          @nonces[nonce] = entry
          entry
        end
      end

      # The conversation a handle names, or nil when it doesn't verify.
      def handle_conversation(handle)
        gateway.read_handle(handle)
      rescue StandardError
        nil
      end

      # Hang the call up through end_call; a failure is logged, never raised.
      def hang_up(call_id)
        return if call_id.nil? || call_id.empty? || end_call.nil?

        end_call.call(call_id)
      rescue StandardError => e
        logger.warn("handoff_end_call_failed error=#{e.message}")
      end

      # A handle for the next leg of +conversation_id+, or nil if minting fails.
      def mint_next(conversation_id)
        gateway.mint_handle(next_conversation_id.call(conversation_id))
      rescue StandardError => e
        logger.error("handoff_mint_failed error=#{e.message}")
        nil
      end

      # Run the application's capture, bounded by capture_timeout. Never raises.
      def capture(conversation_id, medium)
        return false if capture_leg.nil?

        worker = capture_thread(conversation_id, medium)
        return worker.value ? true : false if worker.join(capture_timeout)

        logger.warn("handoff_capture_timeout conversation_id=#{conversation_id} medium=#{medium} " \
                    "note=starting the next medium without this leg's record")
        false
      rescue StandardError => e
        logger.error("handoff_capture_failed conversation_id=#{conversation_id} error=#{e.message}")
        false
      end

      # The capture callback on its own thread, so the wait can be bounded. Its
      # exception (if any) is re-raised by Thread#value, not reported.
      def capture_thread(conversation_id, medium)
        Thread.new do
          Thread.current.report_on_exception = false
          capture_leg.call(conversation_id, medium)
        end
      end

      # Take one message slot before delivering, so overlapping requests can't
      # all pass the cap. Returns the entry, or nil when typing isn't allowed.
      def reserve_slot(nonce)
        @lock.synchronize do
          entry = lookup(nonce)
          next nil if entry.nil? || entry.call_id.nil? || entry.call_id.empty? || at_cap?(entry)

          entry.messages += 1
          @nonces[nonce] = entry
          entry
        end
      end

      # Whether the entry has used its typed-message allowance (logged when it has).
      def at_cap?(entry)
        return false if entry.messages < max_messages_per_call

        logger.warn("handoff_say_cap_reached call_id=#{entry.call_id}")
        true
      end

      # Hand reserved text to send_message; on failure give the slot back.
      def deliver(nonce, entry, text)
        send_message.call(entry.call_id, text)
        true
      rescue StandardError => e
        logger.error("handoff_say_failed error=#{e.message}")
        release_slot(nonce, entry)
        false
      end

      # Not delivered: give the slot back if the table still holds this
      # registration. A shared registry may return a copy, so it's matched by
      # value and the STORED count is decremented, keeping other reservations.
      def release_slot(nonce, entry)
        @lock.synchronize do
          current = @nonces[nonce]
          next unless current&.messages&.positive? && same_registration?(current, entry)

          current.messages -= 1
          @nonces[nonce] = current
        end
      end

      # Whether two entries are the same registration, compared by value.
      def same_registration?(one, other)
        [one.conversation_id, one.call_id, one.issued_at] == [other.conversation_id, other.call_id, other.issued_at]
      end

      # ── Rack dispatch ────────────────────────────────────────────────

      def route(env)
        handler = ROUTES[route_path(env)]
        return cascade_response if handler.nil?
        return json_response(405, { 'error' => 'method not allowed' }) unless env['REQUEST_METHOD'] == 'POST'
        return json_response(403, { 'error' => 'origin not allowed' }) unless origin_allowed?(env['HTTP_ORIGIN'])

        send(handler, request_body(env))
      rescue GatewayRejection => e
        json_response(e.status, { 'error' => e.reason })
      end

      # Whether the gateway's origin policy admits +origin+.
      def origin_allowed?(origin)
        gateway.check_origin(origin)
        true
      rescue StandardError
        false
      end

      # The JSON object sent, or {} for anything else. A body over the size
      # limit raises GatewayRejection (413).
      def request_body(env)
        data = begin
          read_json_body(env)
        rescue GatewayRejection
          raise
        rescue StandardError
          {}
        end
        data.is_a?(Hash) ? data : {}
      end

      # The one answer for an unknown, expired, redeemed or unverifiable nonce/handle.
      def not_found
        json_response(404, { 'error' => 'not found' })
      end

      # POST /handoff: redeem +{nonce}+ for +{handle}+.
      def handoff_route(body)
        nonce = body['nonce']
        handle = nonce.is_a?(String) ? redeem(nonce) : nil
        # The same answer for unknown, expired and already redeemed.
        handle ? json_response(200, { 'handle' => handle }) : not_found
      end

      # POST /escalate: capture the chat leg named by +{handle}+.
      def escalate_route(body)
        handle = body['handle']
        return json_response(400, { 'error' => 'bad request' }) unless handle.is_a?(String) && !handle.empty?

        escalate(handle) ? json_response(200, { 'ok' => true }) : not_found
      end

      # POST /say: deliver +{text}+ into the call +{nonce}+ names.
      def say_route(body)
        nonce = body['nonce']
        text = body.fetch('text', '')
        return not_found unless nonce.is_a?(String) && text.is_a?(String)
        # Before the lookup, so the answer doesn't depend on the nonce.
        return json_response(413, { 'error' => 'message too large' }) if utf8_len(text) > ChatGateway::MAX_MESSAGE_BYTES

        say(nonce, text) ? json_response(200, { 'ok' => true }) : not_found
      end
    end
  end
end
