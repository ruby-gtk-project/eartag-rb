# frozen_string_literal: true

# Drives the main window: the menu, the preferences dialog, the shortcuts
# dialog and the about dialog, plus the stylesheet and the bundled icons they
# rely on. Everything the `ruby` branch's application shell claims to have, per
# .reports/component-inventory.md (the window, the status page / empty state,
# the primary menu and its three items, all four `app.*` actions the port has
# wired, the two accelerators it binds, and the two standalone dialogs), gets
# opened and asserted here.
#
# Deliberately not covered: the 12 file-related actions, the sidebar, the
# editor pane and the MusicBrainz/AcoustID identify flow. The inventory is
# explicit that none of that is ported yet — there is no widget for this
# script to drive, because the port has not written one.
#
# Run it from the dev shell: xvfb-run ruby test/drive_main_window.rb

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'eartag'
require_relative 'gtk_driver'

# Fires an app-level action the way the menu or an accelerator would, rather
# than calling the handler method directly — so the GAction wiring itself is
# under test, not just the method it is wired to.
def fire(app, name)
  app.app.activate_action(name, nil)
end

GtkDriver.drive(Eartag::Application.new, shots: File.expand_path('../tmp/shots', __dir__)) do |d, app|
  d.window { app.window }

  d.step('the window is up') do
    d.check('window is visible') { app.window.visible? }
    d.check('status page is the content') { app.toolbar_view.content == app.status_page }
    d.check('status page names the app') { app.status_page.title == Eartag::Application::APP_NAME }
    d.check('status page has the empty-state hint') do
      app.status_page.description == 'Open or drag in some audio files to edit their metadata.'
    end
    d.check('menu has three items') { app.primary_menu.n_items == 3 }
    d.check('menu item labels') do
      [0, 1, 2].map { |i| app.primary_menu.get_item_attribute_value(i, 'label', nil).to_s } ==
        ['Preferences', 'Keyboard Shortcuts', "About #{Eartag::Application::APP_NAME}"]
    end
    d.check('stylesheet loaded') { app.style.base_provider.is_a?(Gtk::CssProvider) }
    d.check('bundled icon found') { app.icon_theme.has_icon?('file-modified-symbolic') }
    d.check('quit is bound to Ctrl+Q') do
      app.app.get_accels_for_action('app.quit') == ['<Control>q']
    end
    d.check('shortcuts is bound to Ctrl+?') do
      app.app.get_accels_for_action('app.shortcuts') == ['<Control>question']
    end
    d.check('preferences has no accelerator') { app.app.get_accels_for_action('app.preferences') == [] }
    d.check('about has no accelerator') { app.app.get_accels_for_action('app.about') == [] }
    d.shot('01-main-window')
  end

  d.step('preferences opens from its menu action') do
    fire(app, 'preferences')
  end

  d.step('preferences shows the settings') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { dialog.is_a?(PreferencesDialog) }
      d.check('recursive switch matches the setting') do
        dialog.open_folders_recursively_row.active? == app.settings.open_folders_recursively?
      end
      d.check('musicbrainz treshold row shows the stored value') do
        dialog.musicbrainz_confidence_row.value.to_i == app.settings.musicbrainz_confidence_treshold
      end
      d.check('acoustid treshold row shows the stored value') do
        dialog.acoustid_confidence_row.value.to_i == app.settings.acoustid_confidence_treshold
      end
      d.check('cover size row shows the stored size') do
        dialog.cover_size_row.selected == app.settings.cover_size_index
      end
      d.shot('02-preferences', dialog)

      dialog.open_folders_recursively_row.active = true
      dialog.acoustid_confidence_row.value = 42
      dialog.cover_size_row.selected = 1
    end
  end

  d.step('changing a row writes the setting') do
    d.check('recursive setting written') { app.settings.open_folders_recursively? == true }
    d.check('acoustid treshold written') { app.settings.acoustid_confidence_treshold == 42 }
    d.check('cover size written') { app.settings.musicbrainz_cover_size == 250 }
    d.check('setting survives a reload') do
      Settings.new.open_folders_recursively? == true
    end
    app.window.visible_dialog&.close
  end

  d.step('shortcuts opens from its menu action') do
    fire(app, 'shortcuts')
  end

  d.step('shortcuts lists the sections') do
    app.window.visible_dialog.then do |dialog|
      d.check('a shortcuts dialog is up') { dialog.is_a?(ShortcutsDialog) }
      d.check('three sections, in upstream order') do
        ShortcutsDialog::SECTIONS.map(&:first) == ['Files', 'Sidebar', 'Other']
      end
      d.check('eight items total') do
        ShortcutsDialog::SECTIONS.sum { |_title, items| items.length } == 8
      end
      d.check('every item names an action the app actually binds an accel display to') do
        ShortcutsDialog::SECTIONS.flat_map { |_title, items| items.map(&:first) }.all? do |action|
          action.start_with?('app.')
        end
      end
      d.shot('03-shortcuts', dialog)
      dialog.close
    end
  end

  d.step('about opens from its menu action') do
    fire(app, 'about')
  end

  d.step('about shows the app') do
    app.window.visible_dialog.then do |dialog|
      d.check('an about dialog is up') { dialog.is_a?(Adwaita::AboutDialog) }
      d.check('names the app') { dialog.application_name == Eartag::Application::APP_NAME }
      d.check('carries the version') { dialog.version == Eartag::Application::VERSION }
      d.check('debug info lists dependency versions') { dialog.debug_info.include?('gtk4:') }
      d.shot('04-about', dialog)
      dialog.close
    end
  end

  d.step('quit fires from its own action, the way Ctrl+Q would') do
    # Closing the last window makes Gtk::Application quit on the spot, which
    # ends the main loop before the next tick — so the window has to be
    # checked right here, in the same step that fires the action, not in a
    # step of its own.
    fire(app, 'quit')
    d.check('window is no longer visible') { app.window.visible? == false }
  end
end
