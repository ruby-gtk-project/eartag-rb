# eartag-rb — upstream component inventory

Survey of every user-facing component on `origin/main` (Ear Tag, Python +
blueprint + GTK4/libadwaita), and what the `ruby` branch has today.

Read with `git show origin/main:<path>`. Upstream splits almost every component
across a `.py` class and a `.blp` template; the two halves are one component and
become one `lib/*.rb` file, per the `component-identification` skill and the
house shape of `gnome-contacts-rb` (flat `lib/<thing>.rb`, one class per file,
memoized widget accessors, `.tap` assembly).

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| Widget classes (`__gtype_name__` on a `Gtk.Widget` subclass) | 24 | 1 |
| Blueprint templates / standalone roots | 23 `.blp` + 1 `.ui` | 0 (none by design) |
| Alert dialogs | 5 live, 3 orphaned `.blp` | 0 |
| `app.*` actions | 16 | 0 |
| `win.*` actions | 1 | 0 |
| Widget-local action groups | 1 (`albumcoverbutton.*`, 3 items) | 0 |
| Keyboard accelerators | 9 | 0 |
| GSettings keys | 7 (+1 enum) | 0 |
| Distinct CSS classes defined in `src/style*.css` | 27 | 0 |
| `po/` catalogue | 36 locales, 50 POTFILES entries | none |

The port is at its scaffold: `lib/eartag.rb` requires
`lib/eartag/application.rb`, which is a `Gtk::Application` plus an
`Adwaita::ApplicationWindow` holding one `Adwaita::StatusPage` reading "The Ruby
port has not been written yet." Every component below except the application
shell is absent.

---

## 1. `src/main.py` — the application: actions, accelerators, About

→ `lib/eartag/application.rb` — **exists as a placeholder**, carries none of this.

`Application(Adw.Application)` with `HANDLES_OPEN`, `resource_base_path`, an
`open` handler that loads paths (expanding a directory argument) and a
`do_activate` that builds the window and installs every action. Actions are
created in a loop-free but repetitive block via `create_action(name, cb, accel)`
— the scan cannot see the names, so they are listed here in full:

| Action | Accel | Enabled at start | Does |
|---|---|---|---|
| `app.open_file` | `<Ctrl>o` | yes | file chooser, TYPE_FILE \| MODE_OVERWRITE |
| `app.open_folder` | `<Ctrl>d` | yes | folder chooser, MODE_OVERWRITE |
| `app.save` | `<Ctrl>s` | yes | `file_manager.save` |
| `app.next_file` | `<Alt>Right` | yes | `win.select_next` |
| `app.previous_file` | `<Alt>Left` | yes | `win.select_previous` |
| `app.close_selected` | `<Ctrl>w` | yes | removes selection, or closes the window when no files |
| `app.select_all` | `<Ctrl><Shift>a` | yes | three-state: enter selection mode → select all → unselect and leave |
| `app.toggle_sidebar` | `F9` | yes | collapsed: show/hide sidebar; expanded: focus the list |
| `app.open_menu` | `F10` | yes | activates whichever primary menu button is on screen |
| `app.quit` | `<Ctrl>q` | yes | `win.close` |
| `app.preferences` | — | yes | preferences dialog |
| `app.about` | — | yes | About dialog |
| `app.rename` | — | **no** | rename dialog |
| `app.extract` | — | **no** | extract-tags dialog |
| `app.identify` | — | **no** | identify dialog |
| `app.undo_all` | — | **no** | `win.undo_all` |
| `app.delete_all_tags` | — | **no** | tag-delete warning dialog |

`app.shortcuts` is never created in Python: libadwaita auto-installs it from the
`shortcuts-dialog.ui` alias in the GResource (see §5). The primary menu and the
shortcuts window both reference it, so the port must install it explicitly.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | app name, icon, developers, artists (`Jakub Steiner`, `Igor Dyatlov`), MIT_X11, issue URL, website, `translator_credits` only when translated, and a `set_debug_info` block listing flatpak state, library versions and every opened file |

Also from `data/app.drey.EarTag.desktop.in`: name, generic name, comment,
categories, keywords, `DBusActivatable`, and 20 MIME types — the port needs the
MIME list for its own file filter either way.

## 2. `src/window.py` + `src/ui/window.blp` — the main window

→ `lib/window.rb` — **absent**.

`EartagWindow(Adw.ApplicationWindow)`, 1000×700, min 360×200, 34 template
children. Three `Adw.Breakpoint`s, the third existing only because libadwaita
will not run two at once:

| Condition | Setters |
|---|---|
| `max-width: 620sp` | `split_view.collapsed = true` |
| `max-height: 360sp` | `file_view.height_below_360 = true` |
| both | both |

| Widget | × | CSS | Signals / handler | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only when `DEVEL`) | `close-request` → `on_close_request` | presents the close-warning dialog and returns true when files are modified |
| `Gtk.Overlay` | 1 | — | — | holds the drop highlight over everything |
| `Gtk.Revealer` (drop highlight) | 1 | — | `notify::child-revealed` → `drop_highlight_autohide` | crossfade; starts invisible |
| `Adw.Bin` inside it | 1 | `drag-target` | — | with a 96px `document-send-symbolic` `Gtk.Image` and a `title-1` `Gtk.Label` "Drop a file to add it to the opened file list" |
| `Gtk.DropTarget` (controller) | 1 | — | `accept`, `enter`, `leave`, `drop` | `Gdk.FileList`, COPY; loads with `overwrite=False` |
| `Adw.ToastOverlay` | 1 | — | — | every window toast lands here |
| `Gtk.Stack container_stack` | 1 | — | — | crossfade between `no_file` and `split_view` |
| `Adw.HeaderBar empty_headerbar` | 1 | `flat` | — | empty-state header, empty `Gtk.Label` as title widget |
| `Gtk.MenuButton empty_primary_menu_button` | 1 | — | — | `open-menu-symbolic`, tooltip "Menu", `primary_menu` |
| `Adw.OverlaySplitView split_view` | 1 | — | — | sidebar 300px |
| `Adw.ToolbarView sidebar_view` | 1 | — | — | |
| `Adw.HeaderBar sidebar_headerbar` | 1 | — | — | no end title buttons |
| `Gtk.Button save_button` | 1 | `suggested-action` | `clicked` → `on_save` | insensitive until modified; tooltip switches to "Some of the opened files have invalid values; cannot save" when `has_error` |
| `Gtk.Button hide_sidebar_button` | 1 | — | `clicked` → `hide_sidebar` | `visible` bound to `split_view.collapsed` |
| `Gtk.MenuButton primary_menu_button` | 1 | — | — | `primary_menu` |
| `Gtk.Button insert_button` | 1 | — | `clicked` → `insert_file` | TYPE_FILE \| MODE_INSERT |
| `Gtk.ToggleButton select_multiple_button` | 1 | — | — | `selection-mode-symbolic` (bundled icon) |
| `Gtk.ToggleButton sidebar_search_button` | 1 | — | — | drives the search bar |
| `Gtk.SearchBar` + `Gtk.SearchEntry` | 1 + 1 | — | — | placeholder "Search by title, artist, filename…" |
| `Gtk.Revealer` + `Gtk.ProgressBar loading_progressbar` | 1 + 1 | `osd` | — | pulsed from `file_manager.load_task` |
| `Gtk.Stack sidebar_list_stack` | 1 | — | — | crossfades list / empty box / no-results |
| `Gtk.ScrolledWindow sidebar_list_scroll` | 1 | — | — | min 300 max 400 content width |
| `$EartagFileList sidebar_file_list` | 1 | `navigation-sidebar` | — | see §6 |
| `Gtk.Box sidebar_no_files` | 1 | — | — | blank filler |
| `Adw.StatusPage no_results` | 1 | `compact` | — | "No Results Found" / "Try a different search query." |
| `Gtk.ActionBar sidebar_action_bar` | 1 | — | — | revealed only in selection mode with files |
| `Gtk.Button select_all_button` | 1 | — | `clicked` → `select_all` | |
| `Gtk.Label selected_message_label` | 1 | `dim-label` | — | "" / "No files selected" / ngettext "1 file selected" / "{n} files selected" |
| `Gtk.Button remove_selected_button` | 1 | — | `clicked` → `remove_selected` | insensitive at zero selected |
| `Adw.ToolbarView container` | 1 | — | — | content side |
| `Adw.HeaderBar headerbar` | 1 | — | — | no start title buttons |
| `Gtk.Button show_sidebar_button` | 1 | — | `clicked` → `show_sidebar` | `view-queue-symbolic` (bundled, with an RTL variant); `visible` bound to `split_view.collapsed` |
| `Adw.WindowTitle window_title` | 1 | — | — | "Ear Tag" |
| `$EartagFileView file_view` | 1 | — | `notify::bind-in-progress` → `update_busy` | see §8 |
| `Gtk.FileDialog` | 1 | — | — | built in code; title switches between "Open File" / "Add File" / "Open Folder" |
| `Gtk.FileFilter` | 1 | — | — | "All supported audio files", built from `VALID_AUDIO_MIMES` |

Window-local action: **`win.show-error-dialog`** with parameter type `(is)` —
an error-type int and a log string; wired to `EartagErrorDialog`. Toasts raised
here: "Some files failed to load" (with a button that activates
`win.show-error-dialog`), "No supported files found in opened folder", a save
message, an unwritable-files message, a max-recursion-depth message, ngettext
"Undid changes in 1/{n} file(s)" with a **Redo** button, "Redid changes in …",
ngettext "Removed tags from 1/{n} file(s)" with an **Undo** button, and "Undid
tag removal in …".

Repeaters: the sidebar list (one row per file). Conditional: the action bar, the
no-results page, the two collapsed-only sidebar buttons, the `devel` class.

### `menu primary_menu` — 4 sections, 11 items

`_Open File`, `O_pen Folder` | `_Rename Selected Files`, `_Extract Tags from
Filename`, `_Identify Selected Files` | `_Undo Changes in Selected Files`,
`_Remove All Tags in Selected Files` | `_Keyboard Shortcuts`, `_Preferences`,
`_About Ear Tag`. Used by both menu buttons, so it is one component.

## 3. `src/window.py` (`EartagNoFile`) + `src/ui/nofile.blp` — the empty state

→ `lib/no_file.rb` — **absent**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | |
| `Gtk.WindowHandle` | 1 | — | — | drag the window by the empty page |
| `Adw.StatusPage nofile_status` | 1 | `nofiles` | — | icon `app.drey.EarTag`, swapped to `app.drey.EarTag.Devel` when `DEVEL`; title "Ear Tag"; description "Open or drag in some audio files to edit their metadata." |
| `Gtk.Button open_file` | 1 | `suggested-action`, `pill` | `clicked` → `on_add_file` | focus grabbed by `grab_button_focus` |
| `Gtk.Button open_folder` | 1 | `pill` | `clicked` → `on_add_folder` | |
| `Gtk.CheckButton open_recursive` | 1 | `subtitle` | — | two-way bound to GSettings `open-folders-recursively` |
| `Gtk.SizeGroup` | 1 | — | — | standalone root object equalising the two buttons |

Note the `.nofiles .icon` rule in `style.css` — the status page icon is resized
by CSS, not by a property.

## 4. `src/window.py` (`EartagPreferencesDialog`) + `src/ui/settings.blp` — preferences

→ `lib/preferences_dialog.rb` — **absent**.

One `Adw.PreferencesPage`, two groups.

| Widget | × | CSS | Bound to | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | template root |
| `Adw.PreferencesGroup` | 2 | — | — | "General", "File identification" |
| `Adw.SwitchRow open_folders_recursively_toggle` | 1 | — | `open-folders-recursively` | "Search for files in subfolders" |
| `Adw.SpinRow mb_confidence_spinbutton` | 1 | — | `musicbrainz-confidence-treshold` | adjustment 0–100, step 1, page 10 |
| `Adw.SpinRow aid_confidence_spinbutton` | 1 | — | `acoustid-confidence-treshold` | adjustment 0–100 |
| `Adw.ComboRow cover_size_comborow` | 1 | — | `musicbrainz-cover-size` via a bidirectional `cover-size-setting` int property | `Gtk.StringList`: "Do not download covers", "250 px", "500 px", "1200 px", "Maximum size" |

The enum↔index mapping lives in `src/config.py` (`DLCoverSize`), which the port
needs as well: nicks are `0 / 250 / 500 / 1200 / 2000`, default "1200 px".

## 5. `src/ui/shortcuts.blp` — keyboard shortcuts window

→ `lib/shortcuts_dialog.rb` — **absent**.

A standalone `Adw.ShortcutsDialog` root (no backing Python class; loaded by
libadwaita from the `shortcuts-dialog.ui` GResource alias). Three
`Adw.ShortcutsSection`s, 8 `Adw.ShortcutsItem`s, all `C_("shortcut window", …)`:

- **Files** — `app.open_file` "Open files", `app.open_folder` "Open folder", `app.save` "Save all modified files"
- **Sidebar** — `app.previous_file`, `app.next_file`, `app.select_all`, `app.close_selected` ("Remove selected files from sidebar" / subtitle "Closes the window if no files are present.")
- **Other** — `app.shortcuts` "Keyboard shortcuts"

`app.toggle_sidebar` (F9), `app.open_menu` (F10) and `app.quit` (Ctrl+Q) have
accelerators but no entry here — reproduce the omission, it is upstream's shape.

## 6. `src/filelist.py` (`EartagFileList`) — the sidebar list

→ `lib/file_list.rb` — **absent**.

`EartagFileList(Gtk.ListView)` built entirely in code: a
`Gtk.SignalListItemFactory` (`setup`/`bind`/`unbind`/`teardown`) producing
`EartagFileListItem`s, a `Gtk.MultiSelection` over the file manager's model with
a hand-rolled click-to-toggle workaround, a `Gtk.EventControllerKey` for
keyboard navigation, `tab-behavior: item`, the `navigation-sidebar` CSS class
(set in `window.blp`), and `toggle_selection_mode` / `remove_selected`.

Controllers: `Gtk.EventControllerKey` ×1 (on the list), `Gtk.GestureLongPress`
×1 (on each item — see §7).

## 7. `src/filelist.py` (`EartagFileListItem`) + `src/ui/filelistitem.blp` — one sidebar row

→ `lib/file_list_item.rb` — **absent**. Repeater: one per opened file.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (root) | 1 | `filelist-item` | — | spacing 12 |
| `Gtk.Stack cover_edit_stack` | 1 | — | — | crossfade cover ↔ checkbox |
| `$EartagAlbumCoverImage coverart_image` | 1 | `cover-image` (from §10) | — | 48px; `.filelist-item .cover-image` sizes it |
| `Gtk.CheckButton select_button` | 1 | `selection-mode`, `circular` | — | |
| `Gtk.Stack status_icon_stack` | 1 | — | — | |
| `Gtk.Image error_icon` | 1 | — | — | `dialog-warning-symbolic`, "File has invalid values", hidden by default |
| `Gtk.Image modified_icon` | 1 | — | — | bundled `file-modified-symbolic`, "File has unsaved changes", hidden by default |
| `Gtk.Label title_label` | 1 | `heading` | — | ellipsize middle |
| `Gtk.Label filename_label` | 1 | `subtitle` | — | ellipsize middle |
| `Gtk.Button remove_button` | 1 | `flat`, `circular` | `clicked` → `remove_item` | "Remove from list" |
| `Gtk.GestureLongPress` (controller) | 1 | — | — | long press enters selection mode |

## 8. `src/fileview.py` (`EartagFileView`) + `src/ui/fileview.blp` — the editor pane

→ `lib/file_view.rb` — **absent**.

`EartagFileView(Gtk.Stack)`, `transition-type: none`, with a `bind-in-progress`
property the window watches and a `height_below_360` property a breakpoint sets.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Stack` (root) + `Gtk.Stack content_stack` | 2 | — | — | loading / content, then select-a-file / scrolled content |
| `Adw.StatusPage loading` | 1 | — | — | `content-loading-symbolic`, "Loading Files…" |
| `Adw.StatusPage select_file` | 1 | — | — | "Select a File" / "Select the files you want to edit from the list of opened files." |
| `Gtk.ScrolledWindow content_scroll` | 1 | — | — | vertical only |
| `Adw.Clamp content_clamp` | 1 | — | — | max 576 |
| `Gtk.Overlay cover_overlay` | 1 | — | — | cover plus prev/next |
| `$EartagAlbumCoverButton album_cover` | 1 | `album-cover` | — | §9 |
| `Gtk.Revealer` ×2 | 2 | `prev-next-button-container` | — | crossfade, hidden by default |
| `Gtk.Button previous_file_button` | 1 | `osd`, `prev-next-button` | — | "Previous file", `go-previous-symbolic` |
| `Gtk.Button next_file_button` | 1 | `osd` | — | "Next file", `go-next-symbolic`; **no `prev-next-button` class upstream — an upstream asymmetry, keep it** |
| `$EartagTagEditableLabel title_entry` | 1 | `title-1` | — | bound property `title` |
| `$EartagTagEditableLabel artist_entry` | 1 | `title-3`, `artist` | — | bound property `artist` |
| `$EartagFileInfoLabel file_info` | 1 | `caption-header`, plus `dim-label` + `numeric` added in code | — | §13 |
| `Gtk.Box tracknumber_box` | 1 | — | — | `accessible-role: list` |
| `$EartagTagEntryRow` | 7 | `card` + `tagentry-small` on the two numeric ones; `error` added dynamically on `releasedate_entry` | `changed` via the manager | tracknumber, totaltracknumber (numeric, 4 chars), album, albumartist, genre, releasedate (`is-date`), comment |
| `Gtk.ListBox` | 3 | `boxed-list` | — | tag list, filename list, (more-tags group has its own) |
| `$EartagFilenameRow filename_entry` | 1 | — | — | §14 |
| `$EartagMoreTagsGroup more_tags_group` | 1 | — | — | §11 |

Conditional: the prev/next revealers (more than one file), the `error` class on
the release-date row (invalid date), the whole content stack.

## 9. `src/fileview.py` (`EartagAlbumCoverButton`) + `src/ui/albumcoverbutton.blp` — the cover button

→ `lib/album_cover_button.rb` — **absent**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (root) | 1 | `album-cover` | — | 196×196, `accessible-role: group` |
| `Gtk.Overlay drag_overlay` | 1 | — | — | |
| `Gtk.Revealer highlight_revealer` | 1 | — | — | crossfade, not targetable |
| `Gtk.Stack highlight_stack` | 1 | — | — | hover ↔ drop |
| `Gtk.Box hover_highlight` | 1 | `hover-highlight` | — | 48px `document-edit-symbolic` |
| `Gtk.Box drop_highlight` | 1 | `drag-target` | — | 48px `document-send-symbolic` |
| `$EartagPopoverButton button` | 1 | — | — | §17; GtkMenuButton replacement |
| `$EartagAlbumCoverImage cover_image` | 1 | `cover-image` | — | 196px |
| `Gtk.PopoverMenu menu_popover` | 1 | — | — | model `options_menu` |
| `Gtk.Box cover_switch_box` | 1 | `cover-switch-box` | — | fills the menu's `custom: "type_switcher"` slot |
| `Gtk.CheckButton front_toggle` / `back_toggle` | 2 | — | — | "Front" / "Back", radio-grouped |
| `Gtk.FileFilter image_file_filter` | 1 | — | — | standalone root; "All supported image files"; jpg, jpeg, png, bmp, jp2, webp |

Widget-local action group **`albumcoverbutton`**, 3 items in `options_menu`:
`.load` "_Choose Image…" (`insert-image-symbolic`), `.save` "_Save Image…",
`.remove` "_Remove Cover" (`user-trash-symbolic`) — note upstream gives
"_Save Image…" the trash icon too; that is a bug, not a thing to copy.

## 10. `src/utils/widgets.py` (`EartagAlbumCoverImage`) + `src/ui/albumcoverimage.blp`

→ `lib/album_cover_image.rb` — **absent**. Used by §7, §8/§9 and §28.

`Gtk.Stack` with class `cover-image`, `accessible-role: presentation`: a
`folder-music-symbolic` 96px `Gtk.Image no_cover` and a 196px `Gtk.Image
cover_image` with `overflow: hidden`. Binds to a file's `cover-updated` signal
and switches the visible child; honours a `CoverType` (FRONT/BACK) property.

## 11. `src/fileview.py` (`EartagMoreTagsGroup`) + `src/ui/moretagsgroup.blp` + `src/ui/moretagsgroupfactory.ui`

→ `lib/more_tags_group.rb` — **absent**.

`Gtk.Box` (vertical, spacing 6) with a `boxed-list` `Gtk.ListBox
tag_entry_listbox` and a `$EartagTagSelectorButton tag_selector` labelled
"Add tag" with classes `raised`, `pill`, `tag-selected` → `add_row_from_selector`,
whose arrow direction flips with a property. Repeater: one `EartagExtraTagRow`
per extra tag present, filtered per filetype via
`allowed_tags_for_filetype` built from `FILE_CLASSES`.
`moretagsgroupfactory.ui` is a plain `GtkListItem` template binding a
`GtkStringObject`'s `string` to a left-aligned `GtkLabel` — the list-item
factory shared with the tag selector.

## 12. `src/fileview.py` (`EartagExtraTagRow`)

→ `lib/extra_tag_row.rb` — **absent**. Repeater, built in code, no `.blp`.

`EartagTagEntryRow` subclass, starts invisible, title taken from `TAG_NAMES`,
`is_numeric`/`is_float` derived from the backend's property lists, plus a
suffix `Gtk.Button` (`edit-delete-symbolic`, `flat`, valign center, "Remove tag",
`clicked` → `remove_button_pressed`).

## 13. `src/fileview.py` (`EartagFileInfoLabel`)

→ `lib/file_info_label.rb` — **absent**.

`Gtk.Label` adding `dim-label` and `numeric` in its constructor. Renders
`"{length} • {bitrate} kbps • {channels} • {filetype}"`, or "" for no files, or
"(Multiple files selected)". Channels resolve to "N/A" / "Mono" / "Stereo" /
ngettext "1 channel" / "{n} channels".

## 14. `src/fileview.py` (`EartagFilenameRow`) + `src/ui/filenamerow.blp`

→ `lib/filename_row.rb` — **absent**.

`Adw.EntryRow`, title "Filename", `show-apply-button: true`, `apply` →
`set_filename`, plus an `error` boolean property.

## 15. `src/tagentry.py` — tag entries and their manager

→ `lib/tag_entry.rb` — **absent**. No `.blp`; four classes, one file.

- `EartagTagEntryManager` — not a widget, but the whole editing behaviour: binds a set of files to a set of entries, tracks per-property inconsistency, writes "(multiple values)" into the placeholder, coerces int/float properties, suppresses feedback loops. Without it the editor is a set of dead boxes.
- `EartagTagEntry(Gtk.Entry)` — `tagentry_placeholder` property; overrides the placeholder to `"..."` for `tracknumber`/`totaltracknumber` so the window cannot be widened by it.
- `EartagTagEntryRow(Adw.EntryRow)` — `AdwEntryRow` has no placeholder, so the placeholder is appended to the title and stripped again.
- `EartagTagEditableLabel(EartagEditableLabel)` — title drives `Gtk.Accessible` LABEL on both itself and its entry.

All three carry `bound_property`, `is_numeric`, `is_float`, `is_date`, and mix in
`EartagEntryLimiters` (`src/utils/limiters.py`) for input filtering.

## 16. `src/utils/widgets.py` (`EartagEditableLabel`)

→ `lib/editable_label.rb` — **absent**.

`Gtk.Overlay` + `Gtk.Editable`, class `editablelabel`, `accessible-role: group`.
A centred `Gtk.Entry` as child, a wrapped 3-line centre-justified `Gtk.Label`
overlay with a text cursor, and a `document-edit-symbolic` `Gtk.Image` overlay
with class `edit-icon` whose visibility is the inverse of `editing`. The label
gains and loses the `dimmed` class as the text empties. Proxies eight editable
properties through the entry's delegate. `style.css` styles
`.editablelabel entry`, `.editablelabel .edit-icon`, `.editablelabel label`, and
`style-hc.css` gives it a border in high contrast.

## 17. `src/utils/widgets.py` (`EartagPopoverButton`)

→ `lib/popover_button.rb` — **absent**.

`Gtk.Box` holding a `Gtk.ToggleButton` whose `active` is bidirectionally bound to
the popover's `visible`; a `GtkMenuButton` replacement that keeps arrow
navigation working. `accessible-role: group` with a LABELLED_BY relation.

## 18. `src/utils/widgets.py` (`EartagModelExpanderRow`)

→ `lib/model_expander_row.rb` — **absent**.

`Adw.ExpanderRow` subclass that reaches for the internal template child named
`list` (the second, revealed `GtkListBox`) and re-exports `bind_model`,
`get_row_at_index` and `set_placeholder`. Used by §24 and §26. In the Ruby
bindings this internal-child trick is the risky part of the port.

## 19. `src/utils/tagselector.py` + `src/ui/tagselectorbutton.blp`

→ `lib/tag_selector_button.rb` — **absent**.

`Gtk.MenuButton` (`list-add-symbolic`, valign center) with a `menu`-classed
`Gtk.Popover`: a `Gtk.SearchEntry tag_list_search_entry` ("Search tags…",
`search-changed` → `refresh_tag_filter`) over a `Gtk.ScrolledWindow`
(max-content-height 300) holding a single-click-activate `Gtk.ListView tag_list`.
Emits `tag-selected`. Used by §11, §22 and §23 — three call sites, one component.

## 20. `src/utils/previewselector.py` (`EartagPreviewSelectorButton`) + `src/ui/previewselectorbutton.blp`

→ `lib/preview_selector_button.rb` — **absent**.

`Gtk.MenuButton`, `flat`, "Select file to preview", with a `menu`-classed
popover: `Gtk.SearchEntry` ("Search by title, artist, filename…"), a
`Gtk.ScrolledWindow` propagating natural size, and a single-click-activate
`Gtk.ListView list`. Behaviour: a `Gio.ListStore` → `Gtk.FilterListModel` +
`Gtk.CustomFilter` → `Gtk.NoSelection`, a `Gtk.SignalListItemFactory` with all
four signals, a `formatting-changed` signal, and a `Gtk.ShortcutController` with
a `Gtk.KeyvalTrigger` on Escape that closes the popover.

## 21. `src/utils/previewselector.py` (`EartagPreviewSelectorItem`) + `src/ui/previewselectoritem.blp`

→ `lib/preview_selector_item.rb` — **absent**. Repeater.

Vertical `Gtk.Box`: a `formatted_path_label` taking both a label and a
`Pango.AttrList` from a formatting function, and a `subtitle`-classed
`filename_label`.

## 22. `src/rename.py` + `src/ui/rename.blp` — Rename Selected Files

→ `lib/rename_dialog.rb` — **absent**.

`Adw.Dialog`, 600×300, title "Rename Selected Files".

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 + 1 | — | — | no title buttons on either side |
| `Gtk.Button cancel_button` | 1 | — | `clicked` → `on_cancel` | |
| `Gtk.Button rename_button` | 1 | `suggested-action` | `clicked` → `do_rename` | |
| `Adw.ToastOverlay toast_overlay` | 1 | — | — | "Selected folder does not exist", "Selected folder is read-only", plus a rename-result toast |
| `Gtk.Overlay` + `Gtk.ProgressBar rename_progress` | 1 + 1 | `osd` | — | valign start |
| `Adw.Banner sandbox_warning_banner` | 1 | `warning` | `button-clicked` → `on_sandbox_warning_learn_more` | "Ear Tag needs additional permissions to rename files in-place." / "Learn More" |
| `Adw.Banner error_banner` | 1 | `error` | — | "Failed to rename files. Check the logs for more information." |
| `Adw.EntryRow preview_entry` | 1 | — | — | "Preview", not editable, suffix `$EartagPreviewSelectorButton` |
| `Adw.EntryRow filename_entry` | 1 | `error` added dynamically | `changed` → `update_preview`, `entry-activated` → `do_rename` | "Filename pattern", suffix `$EartagTagSelectorButton` (`flat`, `list-add-symbolic`, "Insert tag placeholder") |
| `Adw.ActionRow folder_selector_row` | 1 | — | — | "Move to folder" |
| `Gtk.Button folder_selector_button` | 1 | `flat` | `clicked` → `show_folder_selector` | `folder-open-symbolic`, "Select a folder…" |
| `Gtk.Button folder_remove_button` | 1 | `flat` | `clicked` → `remove_folder` | insensitive until a folder is set |
| `Gtk.Label` (help) | 1 | `dim-label` | — | markup link to the backends README tag list |
| `Gtk.FileDialog folder_chooser` | 1 | — | — | built in code |
| `Gtk.ListBox` / `Adw.Clamp` / `Adw.PreferencesGroup` | 1 each | `boxed-list` on the ListBox | — | layout |

Persists `rename-placeholder` and `rename-base-folder` in GSettings, and runs
`EartagPlaceholderSyntaxHighlighter` over the pattern entry (§31).

## 23. `src/extract.py` + `src/ui/extract.blp` — Extract Tags from Filename

→ `lib/extract_tags_dialog.rb` — **absent**.

`Adw.Dialog`, 600×300, title "Extract Tags from Filename". Header bar with
`cancel_button` and a `suggested-action` `apply_button` → `do_apply`. Body: an
`osd` `Gtk.ProgressBar rename_progress` over a `Gtk.ScrolledWindow` →
`Adw.Clamp content_clamp` → vertical box with two `boxed-list` `Gtk.ListBox`es:

- `Adw.EntryRow preview_entry` "Preview", not editable, suffix `$EartagPreviewSelectorButton`
- `Adw.EntryRow pattern_entry` "Filename pattern", `entry-activated` → `do_apply`, suffix `$EartagTagSelectorButton` (`flat`), gains/loses the `error` class as the pattern validates
- `Adw.SwitchRow toggle_strip_common_suffixes` "Ignore common suffixes" with a two-line subtitle

Persists `extract-pattern` and `extract-strip-common-suffixes`; filters the tag
selector's model with a `Gtk.CustomFilter`; shows a result toast; uses the
syntax highlighter (§31).

## 24. `src/identify.py` (`EartagIdentifyDialog`) + `src/ui/identify/identify.blp`

→ `lib/identify_dialog.rb` — **absent**.

`Adw.Dialog`, 700×550, class `identify-dialog`, title "Identify Selected Files",
`close-attempt` → `on_cancel`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.WindowHandle` | 1 | — | — | |
| `Adw.ToastOverlay toast_overlay` | 1 | — | — | identify/apply result toasts, ngettext over identified counts |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 + 1 | — | — | no title buttons |
| `Gtk.Button cancel_button` | 1 | — | `clicked` → `on_cancel` | stops the running task |
| `Gtk.Stack end_button_stack` | 1 | — | — | Identify → Apply |
| `Gtk.Button identify_button` | 1 | `suggested-action` | `clicked` → `do_identify` | |
| `Gtk.Button apply_button` | 1 | `suggested-action` | `clicked` → `do_apply` | |
| `Gtk.Overlay` + `Gtk.ProgressBar id_progress` | 1 + 1 | `osd` | — | `fraction` bound to the task's `progress` |
| `Adw.PreferencesGroup content_row_group` | 1 | — | — | description with MusicBrainz and AcoustID links |
| `Gtk.ListBox content_listbox` | 1 | `boxed-list` | — | holds one release row per release plus the unidentified row |
| `EartagModelExpanderRow unidentified_row` | 1 | — | — | built in code: "Unidentified Files", expanded, a dummy `EartagIdentifyCoverImage` prefix, model-bound to a `Gtk.FilterListModel` of unidentified files |

Repeaters: one `EartagIdentifyReleaseRow` per release (`release_rows`), one
`EartagIdentifyFileRow` per unidentified file. `style.css` also carries
`.identify-dialog row row .header` and `.identify-dialog .cover-image` rules.

## 25. `src/identify.py` (`EartagIdentifyCoverImage`) + `src/ui/identify/coverimage.blp`

→ `lib/identify_cover_image.rb` — **absent**.

`Gtk.Stack` class `cover-image`: 28px `folder-music-symbolic` `no_cover`, 48px
`cover_image` with `overflow: hidden`, and a 24×24 `Adw.Spinner loading_icon`.
Exposes `cover_path` and `loading` properties the release rows bind to.

## 26. `src/identify.py` (`EartagIdentifyReleaseRow`) — built in code, no `.blp`

→ `lib/identify_release_row.rb` — **absent**. Repeater.

`EartagModelExpanderRow` subclass, class `identify-release-row`. Prefix:
`EartagIdentifyCoverImage`. Suffixes, in order: a `Gtk.CheckButton apply_checkbox`
(active, insensitive, `selection-mode`, "Apply identified data",
`notify::active` → `toggle_row_checkboxes`); a `Gtk.Button release_url_button`
(`external-link-symbolic`, `flat`, "See release on MusicBrainz", `clicked` →
`open_release_url` via a `Gtk.UriLauncher`); a `Gtk.MenuButton
release_popover_toggle` (`view-more-symbolic`, `flat`, "Other releases", hidden
until alternates exist, `notify::active` → `download_alt_release_thumbnails`).
Its popover is a code-built `Gtk.Popover` → `Gtk.ScrolledWindow` →
`boxed-list` `Gtk.ListBox` model-bound to alternate releases. Children come from
a `Gtk.CustomFilter` → `Gtk.FilterListModel` → `Gtk.CustomSorter` →
`Gtk.SortListModel` chain over the dialog's recordings. Title and subtitle are
Pango markup, with a high-contrast branch (`Adw.StyleManager.get_high_contrast`)
changing the disambiguation opacity.

## 27. `src/identify.py` (`EartagIdentifyAltReleaseRow`) + `src/ui/identify/altreleaserow.blp`

→ `lib/identify_alt_release_row.rb` — **absent**. Repeater.

`Adw.ActionRow`, class `identify-recording-row`, `activatable-widget` the
checkbox: an `$EartagIdentifyCoverImage` prefix and a `Gtk.CheckButton
apply_checkbox` (`selection-mode`, `circular`, inactive). Same high-contrast
markup branch.

## 28. `src/identify.py` (`EartagIdentifyFileRow`) + `src/ui/identify/filerow.blp`

→ `lib/identify_file_row.rb` — **absent**. Repeater (unidentified files).

`Adw.ActionRow`, class `identify-file-row`, with a 48px
`$EartagAlbumCoverImage` prefix. Suffix 1: `Gtk.MenuButton
recording_override_button` (`document-edit-symbolic`, `flat`, "Set recording
manually") whose popover is an `Adw.Clamp` (max 300) → `Adw.PreferencesGroup`
with a MusicBrainz-link description, an `Adw.EntryRow recording_override_entry`
("Recording ID or URL", `changed` → `validate_recording_override_entry` which
toggles the `error` class, `entry-activated` →
`set_recording_override_from_entry`) and a `pill suggested-action`
`Gtk.Button recording_override_apply_button` "Apply". Suffix 2: `Gtk.Stack
suffix_stack` (hidden) with an `Adw.Spinner loading_icon` and a
`dialog-question-symbolic` `Gtk.Image not_found_icon` ("File could not be
identified"). `mark_as_unidentified` switches that stack.

## 29. `src/identify.py` (`EartagIdentifyRecordingRow`) + `src/ui/identify/recordingrow.blp`

→ `lib/identify_recording_row.rb` — **absent**. Repeater (per recording).

`Adw.ActionRow`, class `identify-recording-row`, `activatable-widget` the
checkbox. Prefix: `Gtk.CheckButton apply_checkbox` (active, insensitive,
`selection-mode`, "Apply identified data", `notify::active` → `toggle_apply`).
Suffixes: the same recording-override `Gtk.MenuButton` + popover as §28, and a
`Gtk.Button recording_url_button` (`external-link-symbolic`, `flat`, "See
recording on MusicBrainz", `clicked` → `open_recording_url`).

## 30. `src/dialogs.py` + `src/ui/dialogs/*.blp` — the alert dialogs

→ `lib/dialogs.rb` — **absent**. Five live `Adw.AlertDialog`s:

| Class | `.blp` | Heading | Responses |
|---|---|---|---|
| `EartagCloseWarningDialog` | `closewarning.blp` | "Save Changes?" | `cancel` "_Cancel", `discard` "_Discard and Close" *destructive*, `save` "_Save and Close" (default) |
| `EartagDiscardWarningDialog` | `discardwarning.blp` | "Save Changes?" | `cancel`, `discard` "_Discard and Open" *destructive*, `save` "_Save and Open" (default) — awaited via an asyncio event |
| `EartagRemovalDiscardWarningDialog` | `removaldiscardwarning.blp` | "Save Changes?" | same wording as close warning |
| `EartagTagDeleteWarningDialog` | `tagdeletewarning.blp` | "Delete All Tags?" | `cancel`, `discard` "_Delete" *destructive*; default-response is `save`, which **does not exist** — an upstream bug |
| `EartagErrorDialog` | `error.blp` | one of four headings by `EartagErrorType` | `close` "_Close", `copy` "_Copy to clipboard" |

`EartagErrorDialog` is the only one with content: a `Gtk.ScrolledWindow
logs_scroll` (max-content-height 300, natural height) around a monospace,
non-editable, word-char-wrapping `Gtk.TextView logs_view` with 6px margins. The
`copy` response puts the logs on the clipboard and raises a "Copied error log to
clipboard" toast on the parent.

**Three `.blp` files are orphaned**: `savefailure.blp`, `loadingfailure.blp`
and `renamefailure.blp` are listed in `po/POTFILES.in` but appear in neither
`eartag.gresource.xml.in` nor any Python file — superseded by
`EartagErrorDialog`. Do not port them; their strings are only in the catalogue.

## 31. `src/utils/tagsyntaxhighlight.py`

→ `lib/placeholder_syntax_highlighter.rb` — **absent**.

`EartagPlaceholderSyntaxHighlighter` — not a widget, but it is what the pattern
entries in §22 and §23 look like: it applies `Pango` attributes to `{tag}`
placeholders inside a `Gtk.Editable` and reports invalid placeholders, which is
what drives the `error` class on both entries.

## 32. `src/style.css`, `src/style-dark.css`, `src/style-hc.css`

→ `lib/style.rb` (or a `data/` asset loaded by a `Gtk::CssProvider`) — **absent**.

27 classes. Applied somewhere: `artist`, `album-cover`, `drag-target`,
`hover-highlight`, `filelist-item`, `cover-image`, `nofiles`,
`identify-dialog`, `identify-release-row`, `identify-recording-row`,
`identify-file-row`, `prev-next-button-container`, `prev-next-button`,
`editablelabel`, `edit-icon`, `dimmed`, `tagentry-small`, `cover-switch-box`,
`selection-mode`, `subtitle`, `devel`. Dark sheet adds
`listview-boxed-list`; high-contrast sheet restyles `editablelabel`.

**Defined and never applied** (dead upstream, do not invent appliers):
`.unidentified-status` and `.more-item.compact`. `.listview-boxed-list` also has
no applier in the tree.

## 33. `src/filemanager.py`

→ `lib/file_manager.rb` — **absent**.

Not a widget, but every empty state, every sensitivity rule and every toast in
§2 is a property or signal on it: `is-modified`, `has-error`,
`is-selected-modified`, `is-busy`, `files` (a list model), `selection-changed`,
`refresh-needed`, `select-first`, `has-unwritable`,
`max-recursion-depth-reached`, and the `load_task` / `save_task` /
`rename_task` progress sources. Nothing in the window can be ported
independently of it.

## 34. Support files with no component of their own

Needed for the components above to work; each is one `lib/*.rb`:

| Upstream | → | Why |
|---|---|---|
| `src/backends/file.py` + `file_mutagen_{common,id3,mp4,vorbis,asf}.py` | `lib/backends/*.rb` | the tag model, `TAG_NAMES`, `EXTRA_TAGS`, `CoverType`, per-format supported-tag sets that §11 filters on |
| `src/musicbrainz.py` | `lib/musicbrainz.rb` | `MusicBrainzRecording`/`Release`/`ReleaseGroup`, cover-art fetch — the data behind §24–§29 |
| `src/utils/asynctask.py` | `lib/async_task.rb` | `progress`, `progress-pulse`, `task-done` — bound to every progress bar |
| `src/utils/limiters.py` | `lib/entry_limiters.rb` | input filtering mixed into §15 |
| `src/utils/validation.py` | `lib/validation.rb` | `VALID_AUDIO_MIMES` for the file filters |
| `src/utils/extracttags.py` | `lib/extract_tags.rb` | the §23 pattern engine |
| `src/utils/previewselector.py` (shared bits) | with §20/§21 | |
| `src/utils/queuedl.py`, `src/utils/misc.py`, `src/_async.py`, `src/logger.py` | `lib/*.rb` | download queue, helpers, event loop, the log buffer `EartagErrorDialog` shows |
| `src/config.py` + `data/app.drey.EarTag.gschema.xml.in` | `lib/settings.rb` | 7 keys: `open-folders-recursively`, `rename-placeholder`, `rename-base-folder`, `musicbrainz-confidence-treshold` (85), `acoustid-confidence-treshold` (85), `musicbrainz-cover-size` (enum, "1200 px"), `extract-pattern`, `extract-strip-common-suffixes` |
| `src/assets/icons/*.svg` (6) | `data/icons/` | `file-modified-symbolic`, `view-queue-symbolic` + `-rtl`, `selection-mode-symbolic`, `edit-select-none-symbolic`, `external-link-symbolic` — referenced by §2, §7, §26, §29 |
| `po/` (36 locales, 50 POTFILES entries) | `po/` | no catalogue on `ruby` yet; `C_("shortcut window", …)` contexts and `ngettext` plurals are used throughout |

---

## Blockers and things to settle before writing code

1. **`EartagModelExpanderRow` (§18) reaches into `AdwExpanderRow`'s internal `list` template child.** `get_template_child` on a non-template subclass is the single most binding-sensitive thing in the app, and §24 and §26 both depend on it. Prove it in the Ruby bindings before planning the identify dialog.
2. **No `.blp` on the port side by design.** 23 templates become memoized methods; `custom:` menu slots (§9's `type_switcher`) and `bind` expressions (§2's two collapsed-only buttons) have no declarative equivalent and need explicit wiring.
3. **`app.shortcuts` is implicit upstream** (libadwaita loads `shortcuts-dialog.ui` from the GResource). The port has no GResource, so the action must be installed by hand or the menu item and the shortcuts window's own entry both dangle.
4. **`Adwaita::Application` is noted as broken in the existing port scaffold**, so `HANDLES_OPEN` and the `open` signal in §1 need a `Gtk::Application` route — the CLI/`%U` path behaviour has to be re-derived.
5. **Async everywhere.** Upstream is `asyncio`-based (`src/_async.py`, `utils/asynctask.py`); `EartagDiscardWarningDialog` is *awaited* for its response. Ruby GTK has no equivalent, so the dialog flow in `show_file_chooser_async` has to be restructured into callbacks without changing what the user sees.
6. **Dead upstream artifacts** — the three orphaned failure dialogs (§30), the unapplied `.unidentified-status` / `.more-item.compact` / `.listview-boxed-list` CSS (§32), the trash icon on "_Save Image…" (§9), and `default-response: "save"` on a dialog with no `save` response (§30). None should be reproduced; all are recorded so a later parity pass does not read them as gaps.
7. **Backends are the bulk of the work and are not UI.** ~105 KB of mutagen-specific Python across six files, with no Ruby equivalent of `mutagen`, `Pillow`, `filetype.py`, `aiohttp` or `xxhash` on hand. Settle the tag-reading strategy before any editor component, because §8, §11, §12, §15 and §33 are all shaped by the backend's property lists.
