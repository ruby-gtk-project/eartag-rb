# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of upstream's src/ui/shortcuts.blp: an Adw.ShortcutsDialog
# with the Files, Sidebar and Other sections, in that order, holding the same
# eight items.
#
# Upstream names an action rather than an accelerator on every item, which is
# what makes the dialog show whatever accelerator the application has bound to
# that action; the same is done here, so the accelerators in the list come
# from Application's ACCELS table and cannot drift away from the real bindings.
#
# The section titles carry upstream's "shortcut window" message context, which
# is why they are listed with it here: translators see the same context.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  # Section title => items, each item being its action name, title and the
  # optional subtitle upstream gives it.
  SECTIONS = [
    [
      'Files',
      [
        ['app.open_file', 'Open files', nil],
        ['app.open_folder', 'Open folder', nil],
        ['app.save', 'Save all modified files', nil],
      ],
    ],
    [
      'Sidebar',
      [
        ['app.previous_file', 'Select previous file in sidebar', nil],
        ['app.next_file', 'Select next file in sidebar', nil],
        ['app.select_all', 'Select all files in sidebar', nil],
        [
          'app.close_selected',
          'Remove selected files from sidebar',
          'Closes the window if no files are present.',
        ],
      ],
    ],
    [
      'Other',
      [
        ['app.shortcuts', 'Keyboard shortcuts', nil],
      ],
    ],
  ].freeze

  def build
    tap do |dialog|
      SECTIONS.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |action, item_title, subtitle| section.add(item(action, item_title, subtitle)) }
      end
    end

    # Positional, not keyword, arguments: the constructor takes the title and
    # the accelerator. The accelerator is left empty, because the action name
    # set right after is what the dialog resolves the displayed keys from.
    def item(action, title, subtitle)
      Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
        shortcut.action_name = action
        unless subtitle.nil?
          shortcut.subtitle = subtitle
        end
      end
    end
end
