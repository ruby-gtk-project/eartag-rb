# frozen_string_literal: true

require 'adwaita'
require_relative 'logger'

# AsyncTask runs a long operation off the main loop and reports its progress.
#
# Ported from upstream's src/utils/asynctask.py (EartagAsyncTask and
# EartagAsyncMultitasker). Upstream builds on asyncio, with PyGObject's GLib
# event loop policy making the loop and the main loop one and the same; Ruby
# has no such policy, so the work runs in a thread and every signal is handed
# back to the main loop through GLib::Idle. Callers see the same surface:
#
#   - a `progress` value from 0 to 1, which the target sets and which resets to
#     0 when the task finishes, suitable for handing straight to a progress bar
#   - a `progress-pulse` signal for operations whose progress is not known
#   - `task-started` and `task-done` signals
#   - `running?`, `stop` and `wait_for_completion`
#
# The target is a block, and it is passed the task itself, which is how it
# reports progress back (upstream's targets close over the task object).
#
class AsyncTask
  SIGNALS = %i[task_started task_done progress_pulse progress_changed].freeze

  attr_reader :args

  def initialize(*args, &target)
    @target = target
    @args = args
    @progress = 0.0
    @handlers = SIGNALS.to_h { |signal| [signal, []] }
    @lock = Mutex.new
    @thread = nil
  end

  def set_args(*args)
    @args = args
  end

  # Connects a block to one of this object's signals.
  def connect(signal, &block)
    @handlers.fetch(signal.to_s.tr('-', '_').to_sym).push(block)
    self
  end

  # Float from 0 to 1 signifying the current progress of the operation. When
  # the task is done, this automatically resets to 0. This value is set by the
  # target.
  def progress = @lock.synchronize { @progress }

  def progress=(value)
    @lock.synchronize { @progress = value.to_f.clamp(0.0, 1.0) }
    emit(:progress_changed)
    value
  end

  def increment_progress(value)
    @lock.synchronize { @progress = (@progress + value.to_f).clamp(0.0, 1.0) }
    emit(:progress_changed)
  end

  def reset_progress
    self.progress = 0.0
  end

  # Send a progress pulse, for processes where the exact progress isn't known.
  def emit_progress_pulse
    emit(:progress_pulse)
  end

  def running? = !@thread.nil? && @thread.alive?

  def run
    @thread = Thread.new do
      begin
        @target.call(self, *@args)
      rescue StandardError => e
        Log.error("#{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}")
      end
      finish
    end
    emit(:task_started)
    self
  end

  def stop
    @thread&.kill
    @thread = nil
    reset_progress
  end

  def wait_for_completion
    @thread&.join
  end

  # Signals are emitted on the main loop, because the handlers touch widgets
  # and a thread must not do that.
  def emit(signal, *args)
    @handlers.fetch(signal).each do |handler|
      GLib::Idle.add do
        handler.call(self, *args)
        # Returning false removes the idle source, so the handler runs once.
        false
      end
    end
  end

  private

    def finish
      @thread = nil
      reset_progress
      emit(:task_done)
    end
end

# AsyncMultitasker runs one target over a queue of items, with several workers.
#
# Ported from upstream's EartagAsyncMultitasker. The loop of operations is the
# same as upstream describes: create the multitasker with a worker count and a
# target, call `run` to spawn the workers, fill the queue with `queue_put`, and
# call `queue_done` once everything is in. Each worker calls the target with
# one item. `task-done` fires once every worker has finished.
#
# While the queue is still being filled the item count is not yet known, so
# each finished item sends a progress pulse; once the queue is closed, progress
# is the fraction of items done, exactly as upstream does it.
#
class AsyncMultitasker < AsyncTask
  attr_reader :errors, :workers

  def initialize(workers, *args, &target)
    super(*args, &target)
    @workers = workers
    @queue = Thread::Queue.new
    @queue_done = false
    @errors = []
    @threads = []
    @counts = Mutex.new
    @n_items = 0
    @n_done = 0
  end

  def n_items = @counts.synchronize { @n_items }
  def n_done = @counts.synchronize { @n_done }

  def running? = @threads.any?(&:alive?)

  # Start the task by spawning workers.
  def run
    @counts.synchronize do
      @n_items = 0
      @n_done = 0
    end
    @queue = Thread::Queue.new
    @queue_done = false
    clear_errors
    @threads = Array.new(@workers) { Thread.new { work } }
    emit(:task_started)
    Thread.new { wait_for_workers }
    self
  end

  def stop
    @threads.each(&:kill)
    @threads = []
    @queue_done = true
    @queue.close
    reset_progress
  end

  def wait_for_completion
    @threads.each(&:join)
  end

  # Put an item in the queue.
  def queue_put(item)
    @counts.synchronize { @n_items += 1 }
    @queue.push(item)
    self
  end

  # Put all items from the list in the queue.
  def queue_put_multiple(items, mark_as_done: false)
    items.each { |item| queue_put(item) }
    if mark_as_done
      queue_done
    end
    self
  end

  # Indicate to the workers that the queue is done being filled.
  def queue_done
    @queue_done = true
    @queue.close
    self
  end

  def queue_done? = @queue_done

  # Clear error information from the tasker.
  def clear_errors
    @errors = []
  end

  private

    def work
      while (item = @queue.pop)
        run_target(item)
        report_item_done
      end
    end

    def run_target(item)
      @target.call(item, self, *@args)
    rescue StandardError => e
      @errors.push("Error while processing #{item}:\n\n#{e.class}: #{e.message}")
      Log.error(@errors.last)
    end

    def report_item_done
      @counts.synchronize { @n_done += 1 }
      if @queue_done
        self.progress = n_done.to_f / n_items
      else
        emit_progress_pulse
      end
    end

    def wait_for_workers
      @threads.each(&:join)
      @threads = []
      reset_progress
      emit(:task_done)
    end
end
