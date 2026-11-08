# Component parity — eartag-rb

| | |
|---|---|
| Upstream | `main` @ `ad8eadd6a98251a2e6386372486b577c22cf19fa` |
| Port | `ruby` @ `30a394c` |
| Units with full parity | 5 / 35 (see Totals) |

Updated this round from the prior pass (`ruby` @ `4454814`): two commits
landed since — `lib/no_file.rb` (the empty state) and `lib/editable_label.rb`
/ `lib/album_cover_image.rb` were ported and driven, taking
`test/drive_main_window.rb` from 37/37 to **59/59**. The sections below are
amended in place rather than rewritten from scratch.

This ledger reads `.reports/component-inventory.md` (this round's
`component-identification` deliverable) as the per-unit map and checks each
unit the port has actually started against upstream on all four axes
(count/style/behaviour/text). Spot-checked against upstream source this round
(§1 actions, §2 window, §4 preferences, §5 shortcuts, §17/§18 shared widgets)
and found accurate; it is treated as ground truth for everything this ledger
does not re-derive.

## Totals

| Axis | Upstream | Port | Gap |
|---|---:|---:|---:|
| Widget classes (own `Gtk.Widget` subclass) | 24 | 7 | 17 |
| `.blp`/`.ui` template roots | 23 + 1 | 0 (correspondence — house style, see below) | — |
| `app.*` actions | 16 | 4 | 12 |
| `win.*` actions | 1 | 0 | 1 |
| Widget-local action groups | 1 (3 items) | 0 | 1 |
| Accelerators | 9 | 2 | 7 |
| Alert/confirmation dialogs | 5 live | 0 | 5 |
| Backend format modules | 4 (id3, mp4, vorbis, asf) | 3 (id3, mp4, vorbis) | 1 (asf/WMA) |

The 0 `.blp`/`.ui` count is **not** a style gap — the house shape builds
widgets as memoized Ruby methods instead of declarative templates, which is
the correspondence `component-parity` names explicitly. Every other row in
this table is a real gap: a widget, action, accelerator or format the port
has not built, not a difference in how it is expressed.

## Unit: application shell — `src/main.py` → `lib/eartag/application.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| `app.*` actions | 16 (table below) | 4 (`preferences`, `shortcuts`, `about`, `quit`) | **gap** — 12 missing |
| `win.*` actions | 1 (`show-error-dialog`) | 0 | **gap** |
| Accelerators | 9 | 2 (`<Ctrl>q`, shortcuts) | **gap** — 7 missing |
| `HANDLES_OPEN` / CLI file args | yes | not present | **gap** |
| `Adw.AboutDialog` | 1, full debug-info block | 1 | parity (driven, confirmed this round) |

| Action | Upstream accel | In port? |
|---|---|---|
| `app.open_file` | `<Ctrl>o` | no |
| `app.open_folder` | `<Ctrl>d` | no |
| `app.save` | `<Ctrl>s` | no |
| `app.next_file` | `<Alt>Right` | no |
| `app.previous_file` | `<Alt>Left` | no |
| `app.close_selected` | `<Ctrl>w` | no |
| `app.select_all` | `<Ctrl><Shift>a` | no |
| `app.toggle_sidebar` | `F9` | no |
| `app.open_menu` | `F10` | no |
| `app.quit` | `<Ctrl>q` | **yes** |
| `app.preferences` | — | **yes** |
| `app.about` | — | **yes** |
| `app.shortcuts` | — | **yes** |
| `app.rename` | — | no |
| `app.extract` | — | no |
| `app.identify` | — | no |
| `app.undo_all` | — | no |
| `app.delete_all_tags` | — | no |

Driven this round: `ruby test/drive_main_window.rb` under
`nix develop -- xvfb-run -a` — 59/59 checks pass, including the 4 implemented
actions firing from the menu and `<Ctrl>q` closing the window. The 12 missing
actions and 7 missing accelerators are not drivable because nothing installs
them; that is the gap, not an untested pass.

## Unit: preferences dialog — `src/window.py` (`EartagPreferencesDialog`) + `src/ui/settings.blp` → `lib/preferences_dialog.rb`

| Widget | Up × | Port × | CSS | Behaviour | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.PreferencesDialog` | 1 | 1 | — | ✓ | — | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | — | — | parity |
| `Adw.SwitchRow` (recursive) | 1 | 1 | — | ✓ two-way `open-folders-recursively` | — | parity |
| `Adw.SpinRow` (MB confidence) | 1 | 1 | — | ✓ | — | parity |
| `Adw.SpinRow` (AcoustID confidence) | 1 | 1 | — | ✓ | — | parity |
| `Adw.ComboRow` (cover size) | 1 | 1 | — | ✓ bidirectional int property | — | parity |

Driven this round: opens from the menu action, shows all four rows with the
GSettings-backed values, writes a changed row back to GSettings, and the
value survives a reload (checks 2–3 in the drive output). **Unit has full
component parity.**

## Unit: shortcuts dialog — `src/ui/shortcuts.blp` → `lib/shortcuts_dialog.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| Sections | 3 (Files, Sidebar, Other) | 3, in upstream order | parity |
| Items | 8, all `C_("shortcut window", …)` | 8 (driven: "eight items total") | parity |
| Items naming an action the app actually binds | 8 (upstream binds all 9 accels, 3 outside this dialog by design) | 8, "every item names an action the app actually binds an accel display to" (drive check) | parity |

**Unit has full component parity** as far as the dialog's own contents go.
Its items describe actions (`app.open_file`, `app.save`, `app.select_all`,
etc.) that §"application shell" above shows are themselves not installed —
the dialog correctly lists shortcuts for actions that do not yet exist to
fire. That is a gap in the application shell, already counted there; it is
not counted twice here.

## Unit: shared widgets — `src/utils/*` → `lib/popover_button.rb`, `lib/model_expander_row.rb`

Per the inventory's §17/§18, both are ported and both were driven standalone
this round (checks 8–13: popover opens/closes via its toggle button; the
expander row fills exactly N rows from an N-item list model, no extra row).
**Both have component parity in isolation.** Neither is wired into a real
caller yet — nothing in the running app constructs either one — so "parity"
here means "the widget itself is correct", not "the feature that uses it
works", because that feature (the window, the sidebar) does not exist.

## Unit: empty state (`EartagNoFile`) — `src/window.py` + `src/ui/nofile.blp` → `lib/no_file.rb`

Full widget set, built and wired this round: `Adw.StatusPage` with upstream's
title/description, the two `pill`/`suggested-action` buttons (`Open File`,
`Open Folder`), the `Gtk.CheckButton` ("Include Files from Subfolders") bound
two-way to the `open-folders-recursively` GSetting, and the `Gtk.SizeGroup`
equalising the two buttons. `lib/eartag/application.rb` now constructs this
as `no_file` and adds it to the container stack under the `no_file` child
name — it is the real component, not a stand-in.

Driven this round (checks 14–18 approx.): `app.no_file.is_a?(NoFile)`, the
checkbox starts in sync with the GSetting, and flipping the checkbox's
`active` flips the GSetting back. **Unit has full component parity** on the
empty state's own widgets.

Still a gap, and not claimed otherwise: `lib/eartag/application.rb` also
keeps a *second*, separate `Adw.StatusPage` (`status_page`) as the
placeholder for the "files open" stack child, since the real file view
(§"units not started" below) does not exist yet. The two are different
things — `no_file` is the real `EartagNoFile` port, `status_page` is still a
stand-in for `EartagFileView`.

## Unit: shared widgets, round 2 — `src/utils/widgets.py` → `lib/editable_label.rb`, `lib/album_cover_image.rb`

| Widget | Upstream | Port | Verdict |
|---|---|---|---|
| `EartagEditableLabel` | `Gtk.Overlay` + `Gtk.Editable` composite: label visible when unfocused, entry visible and focused on click/tap, commits on Enter/focus-out | `lib/editable_label.rb`, same behaviour | parity on the widget itself |
| `EartagAlbumCoverImage` | `Gtk.Stack` switching between a placeholder page and a decoded cover `Gtk.Picture`, driven by `bind_to_file`/unbind | `lib/album_cover_image.rb`, same stack/bind/unbind behaviour, pixbuf decoded from front-cover bytes | parity on the widget itself |

Driven this round (checks 19–28): typing into the entry updates the entry,
the label text and fires the `on_changed` callback together; the label stays
hidden while editing. The cover image starts empty/placeholder, stays on the
placeholder when bound to a file with no cover bytes, switches to a decoded
picture when bound to a file with real front-cover bytes, and returns to the
placeholder on unbind.

Same caveat as `PopoverButton`/`ModelExpanderRow` above: **both widgets have
component parity in isolation**, and neither is wired into a real caller
yet — `EartagTagEditableLabel` (which would use `EditableLabel` for every tag
field) and `EartagAlbumCoverButton` (which would use `AlbumCoverImage`) do
not exist. "Parity" here means the widget itself matches upstream's widget,
not that the feature that would use it works.

## Units not started

Everything else in the inventory is **absent**, not merely untested — there
is no port file to drive:

- **The main window** (`lib/window.rb`) — 34 template children, 3 breakpoints,
  the sidebar list, the drop-target overlay, toasts, the 11-item primary menu.
- **The editor pane / file view** and every tag-entry row (`EditableLabel`
  and `AlbumCoverImage` are now ported per the unit above, but nothing in the
  running app constructs either one yet — their callers are in this list).
- **The file list model/filter/selection chain** (`Gio::ListStore` →
  `Gtk::SortListModel` → `Gtk::FilterListModel` → `Gtk::MultiSelection`) and
  the 3-worker async load/save/rename queue.
- **All 5 alert dialogs** (close-warning, discard-warning,
  removal-discard-warning, rename-failure, save-failure, tag-delete-warning,
  loading-failure — 7 `.blp` files, 5 "live" per the inventory) plus the
  error dialog (`win.show-error-dialog`).
- **The identify flow** (MusicBrainz/AcoustID): `identify.py`,
  `musicbrainz.py`, and every widget under `src/ui/identify/*.blp`
  (file row, recording row, alt-release row, cover image).
- **The rename flow** (`rename.py`, `filenamerow.blp`) and the extract-tags
  dialog (`extract.py`, `extract.blp`), including the pattern syntax
  highlighter wiring (the highlighter class itself is ported per the
  inventory, but nothing calls it).
- **The ASF/WMA backend.**

None of this is covered by the 59-check drive script, by design — its own
header comment says so. A unit this ledger has not reached is a gap, not an
unverified pass.

## Conclusion

5 of 35 identified units (preferences, shortcuts, empty state, and the two
shared-widget units covering 4 widgets total) have full four-axis parity on
the widgets themselves. 1 more (application shell) is partially built and
partially driven, with named, counted gaps above (12 of 16 `app.*` actions
and 7 of 9 accelerators missing, the `win.*` action missing, no
`HANDLES_OPEN`). The remaining ~29 units — the window, the sidebar, the
editor pane and every widget it is built from beyond the two now-ported
leaf widgets, every dialog, the identify flow, the rename flow, the ASF
backend — do not exist in the port at all. No unit claimed as "parity" here
exercises a real upstream user flow end to end; the app still cannot open a
file and show its tags.
