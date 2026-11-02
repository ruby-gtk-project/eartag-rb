# frozen_string_literal: true

require 'adwaita'
require_relative 'misc'

# EntryLimiters are the common input validators for entries: they refuse the
# keystrokes that would make a value invalid, rather than letting the value go
# wrong and reporting it afterwards.
#
# Ported from upstream's src/utils/limiters.py. Mix it into any widget that is
# a GtkEditable (so it has a delegate and an insert-text signal) and call
# `setup_limiters` after the constructor; then switch a limiter on with
# `entry.numeric = true`, `entry.float = true` or `entry.date = true`.
#
# Upstream has to re-declare three GObject properties in every subclass because
# of a PyGObject limitation (pygobject#577); a Ruby mixin has no such problem,
# so the accessors live here and here only.
#
# Each setter overrides the entry's input purpose, so, as upstream warns, using
# two limiters at once means setting the purpose again by hand.
#
module EntryLimiters
  # The input purpose each limiter asks for, which is what decides the on-screen
  # keyboard a touch device offers.
  INPUT_PURPOSES = {
    numeric: :digits,
    float:   :number,
    date:    :free_form,
  }.freeze

  # Call this **AFTER** the constructor of the including widget.
  def setup_limiters
    @limiters = {}
    @limiter_connections = {}
    @limiter_destroy_connection = signal_connect('destroy') { break_limiter_connections }
  end

  def numeric? = limiter_enabled?(:numeric)
  def float? = limiter_enabled?(:float)
  def date? = limiter_enabled?(:date)

  # Numeric validator: allows only digits ([0-9]).
  def numeric=(value)
    set_limiter(:numeric, value)
  end

  # Float validator: allows digits and one dot.
  def float=(value)
    set_limiter(:float, value)
  end

  # Date validator: allows YYYYYYYYY..., YYYY-MM or YYYY-MM-DD dates.
  def date=(value)
    set_limiter(:date, value)
  end

  def limiter_enabled?(kind) = limiters[kind] == true

  def limiters = @limiters ||= {}

  def limiter_connections = @limiter_connections ||= {}

  def set_limiter(kind, enabled)
    unless limiter_enabled?(kind) == !!enabled
      limiters[kind] = !!enabled
      if enabled
        connect_limiter(kind)
      else
        disconnect_limiter(kind)
      end
    end
  end

  def connect_limiter(kind)
    set_input_purpose(INPUT_PURPOSES.fetch(kind))
    limiter_connections[kind] = delegate.signal_connect('insert-text') do |entry, text, length|
      EntryLimiters.check(
        kind,
        entry,
        text.to_s,
        length.to_i,
      )
    end
  end

  def disconnect_limiter(kind)
    set_input_purpose(:free_form)
    if limiter_connections.key?(kind)
      delegate.signal_handler_disconnect(limiter_connections.delete(kind))
    end
  end

  def break_limiter_connections
    limiter_connections.each_key { |kind| disconnect_limiter(kind) }
    if @limiter_destroy_connection
      signal_handler_disconnect(@limiter_destroy_connection)
      @limiter_destroy_connection = nil
    end
    @limiters = {}
  end

  # The validators themselves. They are module functions because they only
  # need the entry the text is being inserted into, which the signal hands
  # them — upstream makes them static methods for the same reason.
  module_function

  def check(kind, entry, text, length)
    if text.empty?
      false
    else
      disallowed = send(
        :"disallowed_#{kind}?",
        entry,
        text,
        length,
      )
      if disallowed
        entry.signal_emit_stop('insert-text')
      end
      disallowed
    end
  end

  def disallowed_numeric?(_entry, text, _length)
    !text.match?(/\A[0-9]+\z/)
  end

  def disallowed_float?(entry, text, _length)
    (text.include?('.') && entry.text.to_s.include?('.')) ||
      (text != '.' && !Misc.float?(text))
  end

  def disallowed_date?(entry, text, length)
    current_text = entry.buffer.text.to_s
    !text.match?(/\A[0-9-]*\z/) ||
      current_text.length + length > 10 ||
      (current_text + text).count('-') > 2
  end
end
