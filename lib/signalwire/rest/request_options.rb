# frozen_string_literal: true

module SignalWire
  # REST — the synchronous REST client and its per-namespace resources.
  module REST
    # RequestOptions — the REST request-options envelope (plan 4.2).
    #
    # A single value object controlling per-request transport behavior: timeout,
    # retries (with an idempotency-aware retry policy + exponential backoff), and
    # cooperative cancellation. Supplied at two levels:
    #
    # - **Client default**: +RestClient.new(..., request_options: ...)+, stored on
    #   the {HttpClient} and applied to every request.
    # - **Per-request override**: each verb accepts an optional +request_options:+
    #   that *shallow-overrides* the client default for that one call — an unset
    #   (+nil+) field falls back to the client default, then the built-in default.
    #
    # The timeout + retry behavior is wire-observable: the server sees exactly
    # +retries + 1+ attempts and the backoff spacing between them.
    # +abort_signal+ is cooperative cancellation. Ruby's REST client is
    # thread-based/synchronous (net/http), and a blocking socket read cannot be
    # interrupted in-flight without a supervising thread, so the signal is
    # checked *between* attempts. It is any object that responds to +set?+ (a
    # {AbortSignal}, or your own object exposing +set?+); when set, the request
    # raises the transport-error type before the send.
    #
    # All fields are optional; +nil+ means "inherit". They resolve per-request
    # over client-default over the built-in floor at apply-time.
    class RequestOptions
      # The built-in defaults (the contract floor). A +nil+ field on a
      # RequestOptions means "inherit"; these are what an unset field resolves to.
      DEFAULT_TIMEOUT = 30.0
      DEFAULT_RETRIES = 0
      DEFAULT_RETRY_ON_STATUS = [429, 500, 502, 503, 504].freeze
      DEFAULT_RETRY_BACKOFF = 0.5

      attr_reader :timeout, :retries, :retry_on_status, :retry_backoff, :abort_signal

      # Fields (all optional; +nil+ = inherit):
      #
      # - +timeout+: max wall-clock seconds per attempt; on exceed the request
      #   raises the transport-error type. Built-in default +30.0+.
      # - +retries+: number of RETRY attempts (total attempts = +retries + 1+) on
      #   a retryable failure. Built-in default +0+ (opt-in resilience — no retry
      #   stays the default; a caller opts in).
      # - +retry_on_status+: HTTP statuses that trigger a retry for an idempotent
      #   method. Built-in +[429, 500, 502, 503, 504]+.
      # - +retry_backoff+: base seconds for exponential backoff between retries
      #   (+backoff * 2 ** (attempt - 1)+), honoring +Retry-After+ when present.
      #   Built-in +0.5+.
      # - +abort_signal+: a cooperative-cancellation object (responds to +set?+);
      #   checked before each attempt. Built-in +nil+.
      def initialize(timeout: nil, retries: nil, retry_on_status: nil,
                     retry_backoff: nil, abort_signal: nil)
        @timeout         = timeout
        @retries         = retries
        @retry_on_status = retry_on_status
        @retry_backoff   = retry_backoff
        @abort_signal    = abort_signal
      end

      # Return a copy of +self+ with any set (non-+nil+) field of +override+
      # applied — the per-request-over-client-default shallow merge. An unset
      # field on +override+ leaves +self+'s value intact.
      def merge(override)
        return self if override.nil?

        pick = ->(field) { override.public_send(field).nil? ? public_send(field) : override.public_send(field) }
        RequestOptions.new(
          timeout: pick.call(:timeout),
          retries: pick.call(:retries),
          retry_on_status: pick.call(:retry_on_status),
          retry_backoff: pick.call(:retry_backoff),
          abort_signal: pick.call(:abort_signal)
        )
      end

      # Resolve the effective options: per-request over +client_default+ over the
      # built-in floor. +nil+ on any field inherits the next level down; the
      # result has every field concrete. Returns an {EffectiveOptions}.
      #
      # A stateless operation, exposed as a class method so the call site
      # reads +RequestOptions.resolve(...)+.
      def self.resolve(client_default, per_request)
        merged = (client_default || RequestOptions.new).merge(per_request)
        EffectiveOptions.new(
          timeout: merged.timeout.nil? ? DEFAULT_TIMEOUT : merged.timeout,
          retries: merged.retries.nil? ? DEFAULT_RETRIES : merged.retries,
          retry_on_status: merged.retry_on_status.nil? ? DEFAULT_RETRY_ON_STATUS : merged.retry_on_status,
          retry_backoff: merged.retry_backoff.nil? ? DEFAULT_RETRY_BACKOFF : merged.retry_backoff,
          abort_signal: merged.abort_signal
        )
      end

      # Whether an HTTP +status+ for +method+ should trigger a retry, given the
      # resolved +opts+ ({EffectiveOptions}). A stateless operation; delegates
      # to the resolved options so the idempotency asymmetry lives in one
      # place.
      def self.status_is_retryable(method, status, opts)
        opts.status_retryable?(method, status)
      end
    end

    # A {RequestOptions} with every field resolved to a concrete value. Produced
    # by {RequestOptions.resolve} — no +nil+ remains, so the request loop reads
    # concrete values without re-checking defaults on every attempt.
    class EffectiveOptions
      # Methods with no server-side side effect — safe to retry on any retryable
      # status. POST/PATCH are excluded: they may create/mutate, so they retry
      # ONLY on a transport error or 429/503 (throttles), never blindly on
      # 500/502/504, to avoid duplicate side effects. This asymmetry is part of
      # the pinned contract.
      IDEMPOTENT_METHODS = %w[GET PUT DELETE HEAD OPTIONS].freeze

      attr_reader :timeout, :retries, :retry_on_status, :retry_backoff, :abort_signal

      # @param timeout [Numeric, nil] per-attempt wall-clock cap in seconds; nil for no cap
      # @param retries [Integer] retries AFTER the first attempt (total attempts = retries + 1)
      # @param retry_on_status [Array<Integer>, Set<Integer>] statuses eligible for retry,
      #   further narrowed for non-idempotent methods by {#status_retryable?}
      # @param retry_backoff [Numeric] base backoff in seconds, doubled each attempt
      # @param abort_signal [#set?, nil] checked before every attempt for cooperative cancellation
      def initialize(timeout:, retries:, retry_on_status:, retry_backoff:, abort_signal:)
        @timeout         = timeout
        @retries         = retries
        @retry_on_status = retry_on_status
        @retry_backoff   = retry_backoff
        @abort_signal    = abort_signal
      end

      # Whether an HTTP +status+ for +method+ should trigger a retry.
      #
      # Idempotent methods (GET/PUT/DELETE) retry on the full +retry_on_status+
      # set. Non-idempotent methods (POST/PATCH) retry only on 429/503 (the
      # Retry-After-bearing throttles), never on 500/502/504, to avoid replaying
      # a side effect that may have partially applied.
      def status_retryable?(method, status)
        return false unless retry_on_status.include?(status)
        return true if IDEMPOTENT_METHODS.include?(method.upcase)

        # Non-idempotent: only the throttle statuses (which carry Retry-After and
        # mean "the request was NOT processed, back off").
        [429, 503].include?(status)
      end
    end

    # A minimal cooperative-cancellation primitive: an idiomatic Ruby event flag.
    # Thread-safe; the REST client checks +set?+ before each attempt and raises
    # the transport-error type if it is set. Callers may also pass any object of
    # their own that responds to +set?+ (e.g. a wrapper over their app's own
    # cancellation) — this class is a convenience, not a requirement.
    class AbortSignal
      # Create an unset signal.
      def initialize
        @mutex = Mutex.new
        @set = false
      end

      # Set the signal, cancelling any request that checks it from here on. A request
      # already in flight is not interrupted — the check happens between attempts.
      #
      # @return [AbortSignal] self, for chaining
      def set!
        @mutex.synchronize { @set = true }
        self
      end

      # Whether the signal has been set. Thread-safe; the REST client calls this
      # before each attempt.
      #
      # @return [Boolean]
      def set?
        @mutex.synchronize { @set }
      end
    end
  end
end
