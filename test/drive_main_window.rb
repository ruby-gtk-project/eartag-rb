# frozen_string_literal: true

# Drives the main window: the menu, the preferences dialog and the shortcuts
# dialog, plus the stylesheet and the bundled icons they rely on.
#
# Run it from the dev shell: xvfb-run ruby test/drive_main_window.rb

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'eartag'
require_relative 'gtk_driver'

GtkDriver.drive(Eartag::Application.new, shots: File.expand_path('../tmp/shots', __dir__)) do |d, app|
  d.window { app.window }

  d.step('the window is up') do
    d.check('window is visible') { app.window.visible? }
    d.check('status page is the content') { app.toolbar_view.content == app.status_page }
    d.check('menu has three items') { app.primary_menu.n_items == 3 }
    d.check('stylesheet loaded') { app.style.base_provider.is_a?(Gtk::CssProvider) }
    d.check('bundled icon found') { app.icon_theme.has_icon?('file-modified-symbolic') }
    d.check('quit is bound to Ctrl+Q') do
      app.app.get_accels_for_action('app.quit') == ['<Control>q']
    end
    d.shot('01-main-window')
  end

  d.step('preferences opens') do
    app.show_preferences
  end

  d.step('preferences shows the settings') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { dialog.is_a?(PreferencesDialog) }
      d.check('recursive switch matches the setting') do
        dialog.open_folders_recursively_row.active? == app.settings.open_folders_recursively?
      end
      d.check('treshold row shows the stored value') do
        dialog.musicbrainz_confidence_row.value.to_i == app.settings.musicbrainz_confidence_treshold
      end
      d.check('cover size row shows the stored size') do
        dialog.cover_size_row.selected == app.settings.cover_size_index
      end
      d.shot('02-preferences', dialog)

      dialog.open_folders_recursively_row.active = true
      dialog.cover_size_row.selected = 1
    end
  end

  d.step('changing a row writes the setting') do
    d.check('recursive setting written') { app.settings.open_folders_recursively? == true }
    d.check('cover size written') { app.settings.musicbrainz_cover_size == 250 }
    d.check('setting survives a reload') do
      Settings.new.open_folders_recursively? == true
    end
    app.window.visible_dialog&.close
  end

  d.step('shortcuts opens') do
    app.show_shortcuts
  end

  d.step('shortcuts lists the sections') do
    app.window.visible_dialog.then do |dialog|
      d.check('a shortcuts dialog is up') { dialog.is_a?(ShortcutsDialog) }
      d.shot('03-shortcuts', dialog)
      dialog.close
    end
  end

  d.step('about opens') do
    app.show_about
  end

  d.step('about shows the app') do
    app.window.visible_dialog.then do |dialog|
      d.check('an about dialog is up') { dialog.is_a?(Adwaita::AboutDialog) }
      d.check('names the app') { dialog.application_name == Eartag::Application::APP_NAME }
      d.shot('04-about', dialog)
      dialog.close
    end
  end
end
