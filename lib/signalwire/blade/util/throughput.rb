module Signalwire::Blade::Util

  # The throughput class is a rolling window averaging rate
  # calculator capable of calculating a throughput or a basic
  # per second rate.
  class Throughput

    class PatchedMutex < ::Thread::Mutex
      def synchronize_r
        if owned?
          yield
        else
          begin
            lock
            yield
            unlock
          rescue Exception => e
            unlock
            raise
          end
        end
      end
    end


    # Declare our bucket entry, this describes a point in time
    # with a max and min amount of entries
    BUCKET_ENTRY = OpenStruct.new({
      size: 0,
      count: 0,
    })

    # The stats entry gets returned to snapshot the
    # current state of the throughput during a run
    STATS = OpenStruct.new({
      size: 0,
      count: 0,
      rate_size: 0,
      rate_count: 0,
      run_time: 0,
    })

    # The interval for the bucket calculator, anytime we get
    # called to update we'll figure out how long its been since the
    # last and roll the buckets forward
    @interval

    # This flag indicates whether we are started or not
    @started
    attr_reader :started

    # Timestamps for calls to start and stop.
    @start_time
    @stop_time
    attr_reader :start_time
    attr_reader :stop_time

    # Totals kept between start/stop runs.
    @total_size

    def total_size
      size = 0
      @mutex.synchronize_r {
        size = @total_size
      }
      size
    end

    @total_count

    def total_count
      count = 0
      @mutex.synchronize_r {
        count = @total_count
      }
      count
    end

    # This is our 'current position' in time.
    @last_update_time = 0

    # Since ruby is threaded, this class is locked
    @mutex

    # Our fixed queu, where each bucket lives
    @buckets
    attr_reader :buckets

    # Sets up the throughput for use, sets the bucket count
    # on the rolling window.
    def initialize(max_buckets = 23, interval = 1)
      # Setup the mutex
      @mutex = PatchedMutex.new
      @started = false

      # Initialize our buckets with our bucket entry template
      # we add 1 since one is always the current bucket being
      # aggregated, which is not used in computations of stats
      @buckets = FixedQueue.new(max_buckets + 1, BUCKET_ENTRY)
      @interval = interval

      # Initialize our state
      @start_time = 0
      @stop_time = 0
      @started = false
      @total_size = 0
      @total_count = 0
      @last_update_time = 0
    end

    # We provide a now call mostly so unit testst can mock this so we can
    # manually be in control of the clock.
    def current_timestamp
      Time.now.to_i
    end

    # Starts the throughput virtual timer (no actual thread is allocated)
    # and initializes our state.
    def start
      @mutex.synchronize_r {
        raise 'Throughput has already been started' unless @started == false

        initialize_buckets

        # Initialize our state
        @start_time = current_timestamp
        @stop_time = 0
        @started = true
        @total_size = 0
        @total_count = 0
        @last_update_time = @start_time
      }
    end

    # Stops the virtual timer and sets the final stop time for final
    # summary rate calculations.
    def stop
      @mutex.synchronize_r {
        if @started
          @started = false
          @stop_time = current_timestamp
        end
      }
    end

    # Clears out all the buckets with default values.
    private def initialize_buckets
      @buckets.clear

      # Create our 'current' entry at the front
      @buckets.unshift
    end

    # Stops/starts the virtual rate timer.
    def restart
      @mutex.synchronize_r {
        stop
        start
      }
    end

    # Returns the total size processed till now.
    def current_size
      size = 0

      @mutex.synchronize_r {
        # If we've stopped, return total count
        if @started == false && @stop_time != 0
          size = @total_size
        else
          # Update while we're here
          update

          # Add up all the buckets sizes
          iterate_buckets { |bucket|
            size += bucket.size
          }
        end
      }

      size
    end

    # Returns the total count of processed items till now.
    def current_count
      count = 0

      @mutex.synchronize_r {
        # If we've stopped, return total count
        if @started == false && @stop_time != 0
          count = @total_count
        else
          # Update while we're here
          update

          # Add up all the buckets sizes
          iterate_buckets { |bucket|
            count += bucket.count
          }
        end
      }

      count
    end

    # Visits all "past" or "used" buckets, never the current one.
    private def iterate_buckets
      @mutex.synchronize_r {
        # Walk the buckets starting at index 1 (our current, un-completed one)
        @buckets.each { |bucket, index|
          if index > 0
            yield bucket, index
          end
        }
      }
    end

    # This function is what gets called by the user as they complete work.
    # It will populate the current bucket or roll to the next bucket as needed.
    def report(size = 0, implicit_start = true)
      @mutex.synchronize_r {
        # Start implicitly if need be
        if (@started == false && implicit_start == true)
          start
        end

        # Roll our windows forward if needed
        update

        # Update the current bucket (the first one)
        bucket = @buckets.front

        bucket.count += 1
        bucket.size += size

        @total_size += size
        @total_count += 1
      }
    end

    # Moves time forward based on the current time distance from
    # next interval. Once we cross that threshold we move new buckets
    # in front, expiring old ones off the end as we go. This is the 'tick'
    # function of this class and its what drives our sliding window forward.
    def update
      @mutex.synchronize_r {
        # If we've been stopped, keep the buckets exactly as they are
        if (@started == false)
          return
        end

        # Compare that to our last update, and divide that by our interval, thats how many
        # buckets we have to move forward
        elapsed_time = current_timestamp - @last_update_time
        elapsed_buckets = elapsed_time / @interval

        # If we've gone beyond the current one, push as many in as we've elapsed
        if elapsed_buckets != 0
          # We'll progress in fixed chunks of our interval time
          @last_update_time += @interval * elapsed_buckets

          # Roll our buckets forward x times
          @buckets.unshift_count(elapsed_buckets)
        end
      }
    end

    # Calculates an average throughput.
    def self.calculate_average(size, time)
      if time == 0
        0.to_f
      else
        size.to_f / time.to_f
      end
    end

    # Returns the duration of the total time ran between start and now
    # or start and stop.
    def run_time
      if @started == true
        return current_timestamp - @start_time
      elsif @stop_time != 0
        return @stop_time - @start_time
      else
        return 0
      end
    end

    # Returns a summarized stats structure of all possible
    # stored statistics, it is with this api that we allow for a
    # custom bucket limit, allowing the caller to get stats for
    # portions of the window.
    def stats()
      stats = STATS.clone

      @mutex.synchronize_r {
        update

        stats.run_time = run_time
        stats.size = @total_size
        stats.count = @total_count

        if @started == false && stats.run_time != 0
          stats.rate_size = Throughput::calculate_average(stats.size, stats.run_time)
          stats.rate_count = Throughput::calculate_average(stats.count, stats.run_time)
        elsif completed_bucket_count != 0
          # If we're active and something got completed, report the current rate up till now
          stats.rate_size = calculate_rate(current_size)
          stats.rate_count = calculate_rate(current_count)
        end
      }

      stats
    end

    # Returns the number of buckets if we are started, otherwise we
    # return 0 since the buckets are inactive when stopped.
    private def completed_bucket_count
      completed_buckets = 0

      @mutex.synchronize_r {
        if @started
          completed_buckets = @buckets.size - 1
        end
      }

      completed_buckets
    end

    # Internal function for calculating rates based on our interval limit.
    private def calculate_rate(amount)
      completed_seconds = @interval * completed_bucket_count

      if completed_seconds != 0
        return amount.to_f / completed_seconds.to_f
      end

      0.to_f
    end

    # Renders a stats hash to a summary string in the form of:
    # rate_count:total_count(rate_size:total_size)[duration]
    def self.render_stats(stats)
      "#{stats[:rate_count].to_rate_count}:#{stats[:count].to_human_count}" +
          "(#{stats[:rate_size].to_rate_size}:#{stats[:size].to_human_size(1)})" +
          "[#{stats[:run_time].to_human_count}s]"
    end
  end

end

