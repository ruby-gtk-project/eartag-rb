# frozen_string_literal: true

require 'gtk4'

# EditableLabel is a label that becomes an entry while it has focus.
#
# Ported from upstream's src/utils/widgets.py — EartagEditableLabel. Upstream
# is a Gtk.Overlay that also implements the Gtk.Editable interface, so it can
# be dropped in anywhere an entry is expected and proxies cursor-position,
# selection-bound, enable-undo and friends to the entry it wraps underneath.
# The Ruby bindings have no supported way to implement a GTK interface from
# pure Ruby (no vfunc hooks for Gtk::Editable), so this port keeps the visible
# behavior — an entry overlaid with a centered label that shows the current
# text (or a dimmed placeholder) and swaps to the entry on focus — and drops
# the Editable-interface proxying, since nothing outside this class needs to
# treat it as a Gtk::Editable.
class EditableLabel < Gtk::Overlay
  def initialize
    super()
    self.add_css_class('editablelabel')
    self.accessible_role = :group
  end

  def build
    tap do |overlay|
      overlay.child = entry
      overlay.add_overlay(label)
      overlay.add_overlay(icon)
      overlay.set_measure_overlay(label, true)

      entry.tap do |e|
        e.signal_connect('notify::text') { update_label }
        e.signal_connect('notify::has-focus') { update_editing }
      end

      update_editing
    end
  end

  def entry
    @entry ||= Gtk::Entry.new.tap do |e|
      e.valign = :center
      e.set_alignment(0.5)
    end
  end

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.can_focus = false
      l.can_target = false
      l.wrap = true
      l.valign = :center
      l.lines = 3
      l.wrap_mode = :word_char
      l.ellipsize = :middle
      l.max_width_chars = 128
      l.justify = :center
      l.halign = :center
      l.set_cursor(Gdk::Cursor.new_from_name('text'))
    end
  end

  def icon
    @icon ||= Gtk::Image.new.tap do |i|
      i.icon_name = 'document-edit-symbolic'
      i.can_focus = false
      i.can_target = false
      i.receives_default = false
      i.halign = :end
      i.valign = :center
      i.accessible_role = :presentation
    end
  end

  # -- Public interface --------------------------------------------------

  def text = entry.text

  def text=(value)
    entry.text = value.to_s
  end

  def placeholder_text=(value)
    entry.placeholder_text = value
  end

  def editing? = entry.has_focus?

  # Registers a block to run whenever the entry's text changes.
  def on_changed(&block)
    entry.signal_connect('notify::text') { block.call(text) }
  end

  private

    def update_editing
      if editing?
        label.visible = false
        entry.opacity = 1
      else
        label.visible = true
        entry.opacity = 0
      end
      update_label
    end

    def update_label
      if entry.text && !entry.text.empty?
        label.label = entry.text
        label.remove_css_class('dimmed')
      else
        label.label = entry.placeholder_text || ''
        label.add_css_class('dimmed')
      end
    end
end
