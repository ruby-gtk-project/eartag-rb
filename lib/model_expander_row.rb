# frozen_string_literal: true

require 'adwaita'

# ModelExpanderRow is an Adw.ExpanderRow that fills its rows from a list
# model, the way Gtk::ListBox does, instead of requiring each row to be
# appended by hand.
#
# Ported from upstream's src/utils/widgets.py — EartagModelExpanderRow.
# Upstream's docstring explains the trick: an AdwExpanderRow is built out of
# two listboxes internally (the row itself, and a second listbox named "list"
# inside the revealer that drops down below it), and that inner listbox is
# reachable through the template-child machinery even though it is private.
# `get_template_child` turns out to work the same way from the Ruby bindings,
# so this port keeps upstream's approach rather than reimplementing the
# fill-from-model logic by hand.
class ModelExpanderRow < Adwaita::ExpanderRow
  def initialize
    super()
    @list = get_template_child(Adwaita::ExpanderRow, 'list')
  end

  # See Gtk::ListBox#bind_model.
  def bind_model(*args, **kwargs, &block) = @list.bind_model(*args, **kwargs, &block)

  # See Gtk::ListBox#get_row_at_index.
  def get_row_at_index(*args, **kwargs) = @list.get_row_at_index(*args, **kwargs)

  # See Gtk::ListBox#placeholder=.
  def set_placeholder(*args, **kwargs) = @list.set_placeholder(*args, **kwargs)
end
