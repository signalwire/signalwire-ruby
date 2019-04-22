module Signalwire::Blade::Util

# The fixed queue class is an FIFO queue of a fixed size. Items
# get added to the front, and entries that exceed the max capacity
# get dropped off the end. Items in the queue are
# pre-defined with a default object, allowing default entries
# to be created.
class FixedQueue

  # We stash the max number of entries allowed in the entries array
  @capacity
  attr_reader :capacity

  # Our entries array, where the things live that get added to this queue
  @entries

  # Our current virtual size
  @size
  attr_reader :size

  # Our default entry which we clone into places as we grow
  @default_entry

  # Initializes the rolling queue with the max number of entries and the
  # default entry to be placed into each slot.
  def initialize(capacity, default_entry)
    raise "Invalid argument for capacity: #{capacity.inspect}" unless capacity > 0
    raise "Invalid argument for default_entry: #{default_entry.inspect}" unless default_entry != nil

    @capacity = capacity
    @default_entry = default_entry.clone
    @size = 0
    @entries = Array.new(@capacity)
  end

  # Resets this class to its initial state
  def clear
    @size = 0
    @entries.each do |entry|
      entry = nil
    end
  end

  # Inserts a entry to the front of the array, drops off any entries
  # that exceed our max allowance from the back. If nil is
  # passed for the entry argument, the default entry will be cloned
  # into place and added.
  def unshift(entry = nil)
    unshift_count(1, entry)
  end

  # Inserts x number of items to the queue at the front.
  def unshift_count(count = 1, entry = nil)
    if entry == nil
      entry = @default_entry
    end

    # Cap the additions to our capacity
    if count > @capacity

      # Shortcut, just set all the entries
      @entries.size.times do |index|
        @entries[index] = entry.clone
      end

      return
    end

    # Now add the new items up front
    count.times do
      @entries.unshift(entry.clone)

      # Keep bumping size until we hit capacity
      @size += 1 unless @size == @capacity
    end

    # Finally, cap our array to max
    if @entries.size > @capacity
      @entries.pop(@entries.size - @capacity)
    end
  end

  # Iterates all entries in the array, will pass the entry as well
  # as the index as the yield arguments.
  def each
    index = 0
    @entries.each { |entry|
      if index < @size
        yield entry, index
        index += 1
      end
    }
  end

  # Accesses an element in the queue
  def [](index)
    if index < 0
      # Handle negative subscripts
      index = @size + index
    end

    if index >= 0
      raise "Invalid offset #{index}, size: #{@size}" unless index < @size
    end

    @entries[index]
  end

  # Returns the last entry in this array.
  def back
    raise 'No elements' unless @size != 0
    @entries[@size - 1]
  end

  # Returns the first entry in this array.
  def front
    raise 'No elements' unless @size != 0
    @entries[0]
  end
end

end


