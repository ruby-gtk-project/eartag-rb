# frozen_string_literal: true

# Log is the app's logger.
#
# Ported from upstream's src/logger.py, which configures a Python logging
# logger with the format
#
#   [%(asctime)s] eartag {%(pathname)s:%(lineno)d} %(levelname)s: %(message)s
#
# at level INFO (the main binary lowers it to DEBUG in development mode). The
# same format and levels are reproduced here; `caller_locations` stands in for
# Python's pathname/lineno, which the logging module fills in automatically.
#
# Every message is also kept in a bounded in-memory buffer. Upstream's error
# dialog (src/dialogs.py) shows the collected log output in a TextView, so the
# log has to be readable back out of the logger and not just written to stderr.
#
module Log
  LEVELS = {
    debug:   10,
    info:    20,
    warning: 30,
    error:   40,
  }.freeze

  #: How many formatted lines the buffer keeps before dropping the oldest.
  BUFFER_LIMIT = 2048

  class << self
    def level = @level ||= LEVELS.fetch(:info)

    def level=(name)
      @level = LEVELS.fetch(name)
    end

    # The formatted lines logged so far, oldest first.
    def buffer = @buffer ||= []

    # The buffer as one string, which is what the error dialog displays.
    def buffer_text = buffer.join("\n")

    def clear_buffer
      buffer.clear
    end

    LEVELS.each_key do |name|
      define_method(name) do |message|
        log(name, message, caller_locations(1, 1)&.first)
      end
    end

    def log(name, message, location = nil)
      format_line(name, message, location || caller_locations(1, 1)&.first).tap do |line|
        buffer.push(line)
        if buffer.length > BUFFER_LIMIT
          buffer.shift(buffer.length - BUFFER_LIMIT)
        end
        if LEVELS.fetch(name) >= level
          warn(line)
        end
      end
    end

    private

      def format_line(name, message, location)
        [
          "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S,%L')}]",
          "eartag {#{location&.path || '?'}:#{location&.lineno || 0}}",
          "#{name.to_s.upcase}: #{message}",
        ].join(' ')
      end
  end
end
