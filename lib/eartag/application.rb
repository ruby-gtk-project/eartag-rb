# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative '../logger'
require_relative '../settings'
require_relative '../style'
require_relative '../preferences_dialog'
require_relative '../shortcuts_dialog'

module Eartag
  # The port's application.
  #
  # Ported from upstream's src/main.py: it registers the application, loads
  # the stylesheet and the bundled symbolic icons, builds the window with its
  # primary menu, and holds the application actions the menu and the shortcuts
  # dialog refer to.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = 'org.rubygtkproject.Eartag'

    # Upstream's application name and about-dialog metadata, from
    # src/main.py's on_about_action.
    APP_NAME = 'Ear Tag'
    DEVELOPERS = ['knuxify https://tilde.town/~knuxify'].freeze
    ARTISTS = ['Jakub Steiner', 'Igor Dyatlov'].freeze
    WEBSITE = 'https://gitlab.gnome.org/World/eartag'
    ISSUE_URL = 'https://gitlab.gnome.org/World/eartag/-/issues'
    VERSION = '0.1.0'

    # The accelerators upstream's create_action calls bind. `shortcuts` is the
    # one addition: upstream's shortcuts dialog names the action but binds no
    # key to it, and Ctrl+? is the GNOME-wide binding for it.
    ACCELS = {
      'preferences' => nil,
      'about'       => nil,
      'shortcuts'   => '<Control>question',
      'quit'        => '<Control>q',
    }.freeze

    # The bundled symbolic icons live next to lib/, in the data directory the
    # package installs verbatim.
    ICON_PATH = File.expand_path('../../data/icons', __dir__)

    def build
      app.tap do
        app.signal_connect('activate') do
          icon_theme.add_search_path(ICON_PATH)
          style.build

          ACCELS.each { |name, accel| add_action(name, accel) }

          window.tap do |win|
            win.content = toolbar_view
          end

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = status_page

            header_bar.pack_end(primary_menu_button)
          end

          Log.info("Starting #{APP_NAME} #{VERSION}")
          window.present
        end
      end
    end

    def settings = @settings ||= Settings.new

    def style = @style ||= Style.new

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def window
      @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
        win.title = APP_NAME
        win.set_default_size(800, 600)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def icon_theme = @icon_theme ||= Gtk::IconTheme.get_for_display(Gdk::Display.default)

    def primary_menu_button
      @primary_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
        button.primary = true
        button.menu_model = primary_menu
      end
    end

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append('Preferences', 'app.preferences')
        menu.append('Keyboard Shortcuts', 'app.shortcuts')
        menu.append("About #{APP_NAME}", 'app.about')
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = APP_NAME
        page.description = 'Open or drag in some audio files to edit their metadata.'
        page.icon_name = 'audio-x-generic-symbolic'
        page.add_css_class('nofiles')
      end
    end

    # Window-modal dialogs are built fresh each time, because an Adw.Dialog
    # that has been closed cannot be presented again.
    def show_preferences
      PreferencesDialog.new(settings).build.present(window)
    end

    def show_shortcuts
      ShortcutsDialog.new.build.present(window)
    end

    def show_about
      about_dialog.present(window)
    end

    private

      def add_action(name, accel)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { activate_action(name) }
          app.add_action(action)
          unless accel.nil?
            app.set_accels_for_action("app.#{name}", [accel])
          end
        end
      end

      def activate_action(name)
        case name
        when 'preferences' then show_preferences
        when 'shortcuts' then show_shortcuts
        when 'about' then show_about
        when 'quit' then window.close
        end
      end

      def about_dialog
        Adwaita::AboutDialog.new.tap do |about|
          about.application_name = APP_NAME
          about.application_icon = 'audio-x-generic-symbolic'
          about.developers = DEVELOPERS
          about.artists = ARTISTS
          about.license_type = Gtk::License::MIT_X11
          about.issue_url = ISSUE_URL
          about.website = WEBSITE
          about.version = VERSION
          about.debug_info = debug_info
        end
      end

      # Upstream lists the versions of the libraries it is running against, so
      # a bug report says which ones they were.
      def debug_info
        <<~INFO
          #{APP_NAME} #{VERSION}

          Dependency versions:
           - gtk4: #{Gtk::Version::STRING}
           - libadwaita: #{Adwaita::VERSION_S}
           - ruby: #{RUBY_VERSION}

          Settings file: #{settings.location}
        INFO
      end
  end
end
