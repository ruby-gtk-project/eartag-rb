# Ear Tag — component inventory (upstream `origin/main` vs. `ruby`)

Survey only — no app code was written for this report. Order follows how a
user meets each piece: application → main window → file list/view → the
small widgets the file view is built from → the three modal workflows
(extract / rename / identify) → the warning/error dialogs → preferences /
shortcuts / settings → the backend/support layer → data files.

Legend: ✅ exists on `ruby` · ⚠️ partial · ❌ missing

| # | Upstream file(s) | Kind | → `lib/` path | Status |
|---|---|---|---|---|
| 1 | `src/main.py` | Application (`Adw.Application`) | `lib/eartag/application.rb` | ⚠️ partial — actions, menu, about/shortcuts/preferences wiring, style/icon loading all present; but it builds a placeholder `Adw.StatusPage` as the window content instead of the real `EartagWindow` |
| 2 | `src/window.py` (`EartagWindow`) + `src/ui/window.blp` | Window (`Adw.ApplicationWindow`, template) | `lib/window.rb` | ❌ missing — the split view (sidebar file list + content), header bars, save button, drag-and-drop overlay, search bar, selection action bar, loading progress bar, and the `primary_menu` (Open File/Folder, Rename, Extract, Identify, Undo, Remove tags, Shortcuts, Preferences, About) all live here |
| 3 | `src/window.py` (`EartagNoFile`) + `src/ui/nofile.blp` | Bin, template | `lib/no_file.rb` | ✅ exists and is wired into `application.rb`'s `no_file` method (driven) — "Open File"/"Open Folder" buttons, the recursive-open checkbox bound to the `open-folders-recursively` GSetting, and the `SizeGroup`. `application.rb`'s separate `status_page` is still a second, unrelated stand-in for the real file-view stack child (see row 7) |
| 4 | `src/filemanager.py` (`EartagFileManager`) | Model (`GObject.Object`) | `lib/file_manager.rb` | ✅ exists |
| 5 | `src/filelist.py` (`EartagFileListItem`) + `src/ui/filelistitem.blp` | Row (`Gtk.Box`, template) | `lib/file_list_item.rb` | ❌ missing |
| 6 | `src/filelist.py` (`EartagFileList`) | `Gtk.ListView` subclass | `lib/file_list.rb` | ❌ missing — sidebar list, multi-select mode, search filter |
| 7 | `src/fileview.py` (`EartagFileView`) + `src/ui/fileview.blp` | Stack, template | `lib/file_view.rb` | ❌ missing — the tag-editing page shown once files are open |
| 8 | `src/fileview.py` (`EartagAlbumCoverButton`) + `src/ui/albumcoverbutton.blp` | Bin, template | `lib/album_cover_button.rb` | ❌ missing — cover art popover menu (remove/set from file/download), file filter |
| 9 | `src/utils/widgets.py` (`EartagAlbumCoverImage`) + `src/ui/albumcoverimage.blp` | `Gtk.Stack` subclass, template | `lib/album_cover_image.rb` | ✅ exists and driven standalone (binds a file with no cover → placeholder; binds a file with front-cover bytes → decodes a pixbuf and shows it; unbind → back to placeholder). Not yet wired into any real caller — `EartagAlbumCoverButton` (row 8) that would use it still does not exist |
| 10 | `src/fileview.py` (`EartagFilenameRow`) + `src/ui/filenamerow.blp` | `Adw.EntryRow` subclass, template | `lib/filename_row.rb` | ❌ missing |
| 11 | `src/fileview.py` (`EartagExtraTagRow`, subclasses `EartagTagEntryRow`) | Row | folds into `lib/tag_entry.rb` | ❌ missing |
| 12 | `src/fileview.py` (`EartagMoreTagsGroup`) + `src/ui/moretagsgroup.blp` + `src/ui/moretagsgroupfactory.ui` | `Gtk.Box` subclass, template + `GtkListItem` factory | `lib/more_tags_group.rb` | ❌ missing — the "more tags" expander that lists tags not shown by default, built per-filetype from `allowed_tags_for_filetype`; **uses** `ModelExpanderRow` (#16), is not the same component as it |
| 13 | `src/fileview.py` (`EartagFileInfoLabel`) | `Gtk.Label` subclass | `lib/file_info_label.rb` | ✅ exists |
| 14 | `src/tagentry.py` (`EartagTagEntryManager`, `EartagTagEntryBase`, `EartagTagEntry`, `EartagTagEntryRow`, `EartagTagEditableLabel`) | Mixins + `Gtk.Entry`/`Adw.EntryRow`/editable-label subclasses | `lib/tag_entry.rb` | ❌ missing — every tag field in the file view is built from this |
| 15 | `src/utils/widgets.py` (`EartagEditableLabel`) | `Gtk.Overlay`+`Gtk.Editable` composite | `lib/editable_label.rb` | ✅ exists and driven standalone (shows the label when not focused, swaps to the entry and hides the label while editing, typing updates the entry/label/`on_changed` callback together). Not yet wired into any real caller — `EartagTagEditableLabel` (row 14, part of `tagentry.py`) that would use it still does not exist |
| 16 | `src/utils/widgets.py` (`EartagPopoverButton`) | `Gtk.Box` subclass | `lib/popover_button.rb` | ✅ exists |
| 17 | `src/utils/widgets.py` (`EartagModelExpanderRow`) | `Adw.ExpanderRow` subclass | `lib/model_expander_row.rb` | ✅ exists |
| 18 | `src/utils/tagselector.py` (`EartagTagSelectorButton`) + `src/ui/tagselectorbutton.blp` | `Gtk.MenuButton` subclass, template | `lib/tag_selector_button.rb` | ❌ missing — lets a user add one of the tags not currently shown |
| 19 | `src/utils/previewselector.py` (`EartagPreviewSelectorButton`, `EartagPreviewSelectorItem`) + `src/ui/previewselectorbutton.blp` + `src/ui/previewselectoritem.blp` | `Gtk.MenuButton`/`Gtk.Box` subclasses, templates | `lib/preview_selector.rb` | ❌ missing — used by rename/extract to preview the filename pattern against each selected file |
| 20 | `src/utils/queuedl.py` (`EartagQueuedDownloader`, `EartagDownloaderMode`) | Helper (no widget) | `lib/queued_downloader.rb` | ❌ missing — serialises cover-art downloads from identify |
| 21 | `src/extract.py` (`EartagExtractTagsDialog`) + `src/ui/extract.blp` | `Adw.Dialog` subclass, template | `lib/extract_dialog.rb` | ❌ missing — not the same thing as `lib/extract_tags.rb`, which only ports the pattern-matching engine (`src/utils/extracttags.py`) |
| 22 | `src/rename.py` (`EartagRenameDialog`) + `src/ui/rename.blp` | `Adw.Dialog` subclass, template | `lib/rename_dialog.rb` | ❌ missing |
| 23 | `src/identify.py` (`EartagIdentifyDialog`) + `src/ui/identify/identify.blp` | `Adw.Dialog` subclass, template | `lib/identify_dialog.rb` | ❌ missing |
| 24 | `src/identify.py` (`EartagIdentifyCoverImage`) + `src/ui/identify/coverimage.blp` | `Gtk.Stack` subclass, template | `lib/identify_cover_image.rb` | ❌ missing |
| 25 | `src/identify.py` (`EartagIdentifyReleaseRow`, subclasses `EartagModelExpanderRow`) | Row | `lib/identify_release_row.rb` | ❌ missing |
| 26 | `src/identify.py` (`EartagIdentifyAltReleaseRow`) + `src/ui/identify/altreleaserow.blp` | `Adw.ActionRow` subclass, template | `lib/identify_alt_release_row.rb` | ❌ missing |
| 27 | `src/identify.py` (`EartagIdentifyFileRow`) + `src/ui/identify/filerow.blp` | `Adw.ActionRow` subclass, template | `lib/identify_file_row.rb` | ❌ missing |
| 28 | `src/identify.py` (`EartagIdentifyRecordingRow`) + `src/ui/identify/recordingrow.blp` | `Adw.ActionRow` subclass, template | `lib/identify_recording_row.rb` | ❌ missing |
| 29 | `src/musicbrainz.py` (`MusicBrainzRecording`, `MusicBrainzRelease`, `MusicBrainzReleaseGroup`, `EartagCAACover`) | Backend models (no widget) | `lib/musicbrainz.rb` | ❌ missing — drives all of #23–28 |
| 30 | `src/dialogs.py` (`EartagCloseWarningDialog`) + `src/ui/dialogs/closewarning.blp` | `Adw.AlertDialog` subclass, template | `lib/dialogs.rb` | ❌ missing |
| 31 | `src/dialogs.py` (`EartagDiscardWarningDialog`) + `src/ui/dialogs/discardwarning.blp` | `Adw.AlertDialog` subclass, template | `lib/dialogs.rb` | ❌ missing |
| 32 | `src/dialogs.py` (`EartagRemovalDiscardWarningDialog`) + `src/ui/dialogs/removaldiscardwarning.blp` | `Adw.AlertDialog` subclass, template | `lib/dialogs.rb` | ❌ missing |
| 33 | `src/dialogs.py` (`EartagErrorDialog`, `EartagErrorType`) + `src/ui/dialogs/error.blp` | `Adw.AlertDialog` subclass, template | `lib/dialogs.rb` | ❌ missing — generic error presentation (used for save/load/rename failures; see note below) |
| 34 | `src/dialogs.py` (`EartagTagDeleteWarningDialog`) + `src/ui/dialogs/tagdeletewarning.blp` | `Adw.AlertDialog` subclass, template | `lib/dialogs.rb` | ❌ missing |
| 35 | `src/window.py` (`EartagPreferencesDialog`) + `src/ui/settings.blp` | `Adw.PreferencesDialog` subclass, template | `lib/preferences_dialog.rb` | ✅ exists |
| 36 | `src/ui/shortcuts.blp` (`Adw.ShortcutsDialog`, no backing `.py`) | Standalone template object | `lib/shortcuts_dialog.rb` | ✅ exists |
| 37 | `src/config.py` | Settings/GSettings wrapper | `lib/settings.rb` | ✅ exists |
| 38 | `data/app.drey.EarTag.gschema.xml.in` | GSettings schema | (keys consumed by `lib/settings.rb`) | ✅ keys covered — `open-folders-recursively`, `rename-placeholder`, `rename-base-folder`, `musicbrainz-confidence-treshold`, `acoustid-confidence-treshold`, `musicbrainz-cover-size`, `extract-pattern`, `extract-strip-common-suffixes` |
| 39 | `src/style.css`, `src/style-dark.css`, `src/style-hc.css` | Stylesheet | `lib/style.rb` | ✅ exists |
| 40 | `src/logger.py` | Support | `lib/logger.rb` | ✅ exists |
| 41 | `src/backends/file.py` (tag tables: `BASIC_TAGS`, `EXTRA_TAGS`, `VALID_TAGS`, `CoverType`, `TAG_NAMES`) | Support | `lib/tags.rb` | ✅ exists |
| 42 | `src/backends/file.py` (`EartagFile` base) + `file_mutagen_common.py` | Backend | `lib/backends/file.rb` | ✅ exists |
| 43 | `src/backends/file_mutagen_id3.py` | Backend | `lib/backends/file_id3.rb` | ✅ exists |
| 44 | `src/backends/file_mutagen_mp4.py` | Backend | `lib/backends/file_mp4.rb` | ✅ exists |
| 45 | `src/backends/file_mutagen_vorbis.py` | Backend | `lib/backends/file_vorbis.rb` | ✅ exists |
| 46 | `src/backends/file_mutagen_asf.py` (`EartagFileMutagenASF`, WMA) | Backend | `lib/backends/file_wma.rb` (does not exist yet) | ❌ missing |
| 47 | `src/utils/validation.py` | Support | `lib/validation.rb` | ✅ exists |
| 48 | `src/utils/misc.py` | Support | `lib/misc.rb` | ✅ exists |
| 49 | `src/_async.py` / `src/utils/asynctask.py` (`EartagAsyncTask`) | Support | `lib/async_task.rb` | ✅ exists |
| 50 | `src/utils/limiters.py` | Support | `lib/entry_limiters.rb` | ✅ exists |
| 51 | `src/utils/extracttags.py` | Support (pattern engine) | `lib/extract_tags.rb` | ✅ exists |
| 52 | `src/utils/tagsyntaxhighlight.py` | Support | `lib/placeholder_syntax_highlighter.rb` | ✅ exists |
| — | `src/ui/dialogs/loadingfailure.blp`, `renamefailure.blp`, `savefailure.blp` | Dead blueprint files | — | **Do not port.** No backing Python class references them, and `src/eartag.gresource.xml.in` does not list them — they are compiled by nothing and loaded by nothing in upstream. `EartagErrorDialog` (#33) is what upstream actually uses for these failure cases. |
| — | `po/*.po`, `po/POTFILES.in`, `po/LINGUAS` | Translation catalogue | — | out of scope for this report; see `translation-parity` skill |

## Totals

- Upstream component-bearing files/classes identified: **46** (across window,
  dialogs, file list/view, the three tool dialogs, identify's MusicBrainz
  rows, and the small reusable widgets), plus the support/backend layer and
  one backend format (WMA) with no port file.
- On `ruby`: **21** of those are present (support layer, three of four
  backends, settings, style, logger, preferences, shortcuts, the four generic
  reusable widgets `PopoverButton`/`ModelExpanderRow`/`EditableLabel`/
  `AlbumCoverImage`, `FileInfoLabel`, and the empty-state view `NoFile`).
  `Application` is partially wired (actions/menu/about work and it now builds
  the real `NoFile` empty state; it does not yet build the real window or
  file view).
- **Not started at all:** the main window and its split view, the sidebar
  file list, the tag-editing file view and everything else it is built from
  (album cover *button*, filename row, more-tags group, tag entries — note
  `EditableLabel` and `AlbumCoverImage` themselves are now ported, but their
  callers are not), the extract/rename/identify dialogs and all of identify's
  MusicBrainz-backed rows, the five warning/error alert dialogs, the
  preview-selector and tag-selector popovers, the queued downloader, the
  MusicBrainz backend model, and the WMA file backend.

## Notes for the next pass

- `lib/eartag/application.rb`'s `window`/`toolbar_view`/`header_bar`/
  `status_page` methods are a temporary stand-in for the real `EartagWindow`
  + `EartagNoFile`. When `lib/window.rb` and `lib/no_file.rb` are built,
  `Application#build` should hand off to them instead of building its own
  placeholder shell.
- `EartagTagEntryRow`/`EartagTagEntry`/`EartagTagEditableLabel` (upstream
  `tagentry.py`) are the base every tag field in the file view, the
  more-tags group, and the filename row builds on — port this before the
  widgets that depend on it.
- `EartagModelExpanderRow` is already ported and is a dependency of both
  `EartagMoreTagsGroup` (#12) and `EartagIdentifyReleaseRow` (#25); neither
  of those two is itself ported yet.
