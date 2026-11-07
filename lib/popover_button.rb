# frozen_string_literal: true

require 'gtk4'

# PopoverButton is a re-implementation of Gtk::MenuButton that does not share
# its problems: arrow-key navigation still works through it, and it does not
# hit https://gitlab.gnome.org/GNOME/gtk/-/issues/5568.
#
# Ported from upstream's src/utils/widgets.py — EartagPopoverButton. Upstream
# is a Gtk.Box holding a toggle button plus whatever popover is assigned to
# it, with the toggle's `active` state bound bidirectionally to the popover's
# `visible` state so clicking the button opens it and dismissing the popover
# (Escape, a click outside) releases the button again.
#
# One piece of upstream is left out: it also calls `update_relation` to wire
# an ACCESSIBLE_RELATION_LABELLED_BY pointing the toggle button back at this
# box. The Ruby bindings cannot marshal that call yet (GtkAccessibleRelation
# array arguments raise NotImplementedError in gobject-introspection), so the
# accessible role is set but the relation is not; this affects screen-reader
# labelling only, not the button's behavior.
class PopoverButton < Gtk::Box
  def initialize
    super(:horizontal, 0)
    self.accessible_role = :group
    append(toggle_button)
  end

  def toggle_button = @toggle_button ||= Gtk::ToggleButton.new

  def child = toggle_button.child

  def child=(value)
    toggle_button.child = value
  end

  attr_reader :popover

  # The popover to display. Only one can be set at a time; assigning a new
  # one detaches whichever popover was previously attached.
  def popover=(value)
    remove(@popover) if @popover
    @popover = value
    toggle_button.bind_property('active', @popover, 'visible', :bidirectional)
    append(@popover)
  end
end
