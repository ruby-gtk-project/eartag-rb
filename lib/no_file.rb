# frozen_string_literal: true

require 'adwaita'
require_relative 'settings'

# NoFile is the empty-state view shown in place of the file list/view when
# no files are open: a status page with "Open File"/"Open Folder" buttons
# and a checkbox for whether opening a folder should recurse into
# subfolders.
#
# Ported from upstream's src/window.py (EartagNoFile) and src/ui/nofile.blp.
# Upstream reaches the window through `self.get_native()` to call
# `show_file_chooser`; this port takes the two file-chooser callbacks in the
# constructor instead, following the house pattern of callback injection
# rather than reaching up to a parent through the widget tree. The recursive-
# open checkbox is bound straight to Settings, the same way the preferences
# dialog binds its own copy of the same key.
class NoFile < Adwaita::Bin
  def initialize(settings, on_add_file:, on_add_folder:)
    super()
    @settings = settings
    @on_add_file = on_add_file
    @on_add_folder = on_add_folder
  end

  def build
    tap do |bin|
      bin.child = window_handle

      window_handle.tap do |wh|
        wh.hexpand = true
        wh.vexpand = true
        wh.child = status_page

        status_page.tap do |page|
          page.icon_name = 'app.drey.EarTag'
          page.title = 'Ear Tag'
          page.description = 'Open or drag in some audio files to edit their metadata.'
          page.add_css_class('nofiles')
          page.child = box

          box.tap do |b|
            b.append(open_file_button)
            b.append(open_folder_button)
            b.append(open_recursive_check)

            size_group.add_widget(open_file_button)
            size_group.add_widget(open_folder_button)

            open_file_button.signal_connect('clicked') { @on_add_file.call }
            open_folder_button.signal_connect('clicked') { @on_add_folder.call }
            open_recursive_check.active = @settings.open_folders_recursively?
            open_recursive_check.signal_connect('notify::active') do
              @settings.open_folders_recursively = open_recursive_check.active?
            end
          end
        end
      end
    end
  end

  def grab_button_focus = open_file_button.grab_focus

  # Memoized widget methods

  def window_handle = @window_handle ||= Gtk::WindowHandle.new

  def status_page = @status_page ||= Adwaita::StatusPage.new

  def box
    @box ||= Gtk::Box.new(:vertical, 12).tap do |b|
      b.halign = :center
    end
  end

  def open_file_button
    @open_file_button ||= Gtk::Button.new.tap do |btn|
      btn.label = 'Open File'
      btn.halign = :center
      btn.focusable = true
      btn.add_css_class('suggested-action')
      btn.add_css_class('pill')
    end
  end

  def open_folder_button
    @open_folder_button ||= Gtk::Button.new.tap do |btn|
      btn.label = 'Open Folder'
      btn.halign = :center
      btn.add_css_class('pill')
    end
  end

  def open_recursive_check
    @open_recursive_check ||= Gtk::CheckButton.new.tap do |check|
      check.label = 'Include Files from Subfolders'
      check.tooltip_text = 'When opening a folder, include files from its subfolders'
      check.add_css_class('subtitle')
    end
  end

  def size_group = @size_group ||= Gtk::SizeGroup.new(:horizontal)
end
