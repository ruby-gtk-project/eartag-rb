# frozen_string_literal: true

require 'adwaita'
require_relative 'settings'

# PreferencesDialog holds the handful of settings Ear Tag has.
#
# A direct port of upstream's EartagPreferencesDialog (src/window.py) and
# src/ui/settings.blp: one preferences page with a General group holding the
# recursive-folder switch, and a File identification group holding the two
# confidence tresholds and the downloaded cover art size.
#
# Upstream binds each row straight to its GSettings key; here the same binding
# is done by hand against Settings, which writes the key as soon as the row
# changes — so closing the dialog needs no apply step, exactly as upstream.
#
class PreferencesDialog < Adwaita::PreferencesDialog
  def initialize(settings)
    super()
    @settings = settings
  end

  def build
    tap do |dialog|
      dialog.add(page)

      page.tap do |prefs_page|
        prefs_page.add(general_group)
        prefs_page.add(identification_group)

        general_group.tap do |group|
          group.add(open_folders_recursively_row)

          open_folders_recursively_row.tap do |row|
            row.active = @settings.open_folders_recursively?
            row.signal_connect('notify::active') do
              @settings.open_folders_recursively = row.active?
            end
          end
        end

        identification_group.tap do |group|
          group.add(musicbrainz_confidence_row)
          group.add(acoustid_confidence_row)
          group.add(cover_size_row)

          musicbrainz_confidence_row.tap do |row|
            row.value = @settings.musicbrainz_confidence_treshold
            row.signal_connect('notify::value') do
              @settings.musicbrainz_confidence_treshold = row.value.to_i
            end
          end

          acoustid_confidence_row.tap do |row|
            row.value = @settings.acoustid_confidence_treshold
            row.signal_connect('notify::value') do
              @settings.acoustid_confidence_treshold = row.value.to_i
            end
          end

          cover_size_row.tap do |row|
            row.selected = @settings.cover_size_index
            row.signal_connect('notify::selected') do
              @settings.cover_size_index = row.selected
            end
          end
        end
      end
    end
  end

  # Memoized widget methods

  def page = @page ||= Adwaita::PreferencesPage.new

  def general_group
    @general_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'General'
    end
  end

  def identification_group
    @identification_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'File identification'
    end
  end

  def open_folders_recursively_row
    @open_folders_recursively_row ||= Adwaita::SwitchRow.new.tap do |row|
      row.title = 'Search for files in subfolders'
      row.subtitle = 'When opening a folder, include files from its subfolders'
    end
  end

  def musicbrainz_confidence_row
    @musicbrainz_confidence_row ||= confidence_row(
      'MusicBrainz confidence treshold',
      'Minimum confidence percentage required for a MusicBrainz search result to be evaluated',
    )
  end

  def acoustid_confidence_row
    @acoustid_confidence_row ||= confidence_row(
      'AcoustID confidence treshold',
      'Minimum confidence percentage required for an AcoustID lookup result to be evaluated',
    )
  end

  def cover_size_row
    @cover_size_row ||= Adwaita::ComboRow.new.tap do |row|
      row.title = 'Downloaded cover art size'
      row.model = Gtk::StringList.new(DLCoverSize::LABELS)
    end
  end

  private

    # Both treshold rows are percentages, so they share the adjustment upstream
    # gives them: 0 to 100, stepping by one and paging by ten.
    #
    # Positional, not keyword, arguments: Adw.SpinRow takes its adjustment,
    # climb rate and digit count in that order.
    def confidence_row(title, subtitle)
      Adwaita::SpinRow.new(percentage_adjustment, 1, 0).tap do |row|
        row.title = title
        row.subtitle = subtitle
      end
    end

    # Gtk::Adjustment.new(value, lower, upper, step_increment, page_increment,
    # page_size) — positional, and a fresh one per row, because an adjustment
    # shared between two spin rows would keep their values in step.
    def percentage_adjustment = Gtk::Adjustment.new(
      50,
      0,
      100,
      1,
      10,
      0,
    )
end
