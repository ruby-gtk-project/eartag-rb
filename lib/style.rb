# frozen_string_literal: true

require 'adwaita'

# Style is the app's stylesheet.
#
# Ported from upstream's src/style.css, src/style-dark.css and
# src/style-hc.css. Upstream loads the three sheets through
# Adw.StyleManager's colour-scheme machinery (the base sheet always, the dark
# one when the dark scheme is active, the high-contrast one when that is);
# here the same split is done by adding and removing CSS providers as the
# style manager's dark and high-contrast properties change.
#
# The CSS is upstream's, comments included: the rules refer to widget
# structure (the placeholder inside a title-N entry, the header inside a row
# inside a row) that is not obvious from the Ruby side, and the comments are
# what explain why each rule exists.
#
class Style
  BASE_CSS = <<~'CSS'
    /* WORKAROUND: Setting the title class overrides the opacity in the placeholder,
       this fixes it */
    .editing.title-1 placeholder,
    .editing.title-2 placeholder,
    .editing.title-3 placeholder,
    .editing.title-4 placeholder,
    .editing.title-5 placeholder
    {
    	opacity: 0.5;
    }

    .artist {
    	font-weight: normal;
    }

    .album-cover {
    	box-shadow: 0px 1px 6px rgba(0,0,0,0.3),
    	      0px 2px 12px rgba(0,0,0,0.15),
    	      0px 6px 32px rgba(0,0,0,0.1);
    	border-radius: 12px;
    }

    .album-cover button {
    	padding: 0;
    	margin: 0;
    	outline-offset: 3px;
    }

    .album-cover * {
    	border-radius: 12px;
    }

    .drag-target {
    	background-color: hsl(from var(--accent-bg-color) h calc(s * 0.7) calc(l * 0.7));
    	opacity: 0.85;
    }

    .album-cover .drag-target {
    	border: 1px solid var(--accent-bg-color);
    }

    .album-cover .hover-highlight {
    	background-color: rgba(56, 56, 56, 0.5);
    	color: #fff;
    }

    .sidebar {
    	border-left: @border;
    }

    .filelist-item {
    	padding: 6px 0;
    }

    .filelist-item .cover-image {
    	background-color: rgba(24, 24, 24, 0.5);
    	border-radius: 6px;
    }

    .filelist-item * { border-radius: 6px; }

    .nofiles .icon {
      -gtk-icon-shadow: 0 1px 12px rgba(0,0,0,0.05),
          0 -1px rgba(0,0,0,0.05),
          1px 0 rgba(0,0,0,0.1),
          0 1px rgba(0,0,0,0.3),
          -1px 0 rgba(0,0,0,0.1);
    }

    .identify-dialog .cover-image, .identify-dialog .cover-image image {
    	border-radius: 6px;
    }

    .identify-dialog row row .header { margin-top: 3px; margin-bottom: 3px; }
    .identify-dialog row row:not(.identify-recording-row) .header:dir(ltr) { margin-left: 6px; }
    .identify-dialog row row:not(.identify-recording-row) .header:dir(rtl) { margin-right: 6px; }

    .unidentified-status box.vertical { margin: 0; }
    .unidentified-status image { margin-bottom: 0; -gtk-icon-size: 72px; }
    .unidentified-status .title { font-size: 1.5em; }

    /* Required to make the OSD button outline show up */
    .prev-next-button-container { padding: 6px; margin: -6px; }
    .prev-next-button-container button { outline-color: rgb(from var(--accent-color) r g b / calc(alpha * 0.5)); }

    /* Apply focus colors to editable labels */
    .editablelabel {
    	border-radius: 6px;
    }

    .editablelabel:hover {
    	background-color: rgb(from var(--window-fg-color) r g b / calc(alpha * 0.02));
    }

    .editablelabel entry {
    	background-color: transparent;
    	padding-top: 1px;
    }

    .editablelabel .edit-icon {
    	min-width: 24px;
    	min-height: 24px;
    	padding: 0 5px;
    	opacity: 0.55;
    }

    .editablelabel label {
    	padding: 0 40px;
    }

    /* For some reason, the icon in the smaller entries is 2px off from the main one. Here's a manual fix: */
    .tagentry-small {
    	padding: 0 2px;
    }

    .cover-switch-box checkbutton { margin: 3px 5px; }

    /* Tweaks for "compact" "more item" entries */
    .more-item.compact .header {
    	margin-top: 6px;
    	margin-bottom: 6px;
    }

    .more-item.compact .title {
    	margin-top: 0;
    	margin-bottom: 0;
    }

    .more-item.compact .prefixes {
    	margin-right: 0;
    }

    .more-item.compact .suffixes {
    	margin-left: 0;
    }
  CSS

  DARK_CSS = <<~'CSS'
    .listview-boxed-list > row { border-bottom: 1px solid alpha(@card_shade_color, 0.05); }
  CSS

  HIGH_CONTRAST_CSS = <<~'CSS'
    .editablelabel {
    	border: 1px solid @borders;
    }

    .editablelabel .edit-icon {
    	opacity: 0.9;
    }
  CSS

  # The variant sheets sit above the base one, so a dark or high-contrast rule
  # wins over the rule it refines.
  BASE_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION
  VARIANT_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION + 1

  def build
    tap do
      add_provider(base_provider, BASE_PRIORITY)

      style_manager.tap do |manager|
        manager.signal_connect('notify::dark') { update_variants }
        manager.signal_connect('notify::high-contrast') { update_variants }
      end

      update_variants
    end
  end

  # Adds the variant sheets the current colour scheme asks for, and takes away
  # the ones it does not.
  def update_variants
    set_variant(dark_provider, style_manager.dark?)
    set_variant(high_contrast_provider, style_manager.high_contrast?)
  end

  def base_provider = @base_provider ||= provider_for(BASE_CSS)
  def dark_provider = @dark_provider ||= provider_for(DARK_CSS)
  def high_contrast_provider = @high_contrast_provider ||= provider_for(HIGH_CONTRAST_CSS)

  private

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def display = @display ||= Gdk::Display.default

    def added = @added ||= []

    def provider_for(css)
      Gtk::CssProvider.new.tap { |provider| provider.load_from_string(css) }
    end

    def set_variant(provider, wanted)
      if wanted
        add_provider(provider, VARIANT_PRIORITY)
      else
        remove_provider(provider)
      end
    end

    def add_provider(provider, priority)
      unless display.nil? || added.include?(provider)
        Gtk::StyleContext.add_provider_for_display(display, provider, priority)
        added.push(provider)
      end
    end

    def remove_provider(provider)
      if !display.nil? && added.include?(provider)
        Gtk::StyleContext.remove_provider_for_display(display, provider)
        added.delete(provider)
      end
    end
end
