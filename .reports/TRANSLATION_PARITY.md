# Translation parity — eartag-rb

| | |
|---|---|
| Upstream | `main` @ `ad8eadd6a98251a2e6386372486b577c22cf19fa` |
| Port | `ruby` @ `30a394c` |
| Domain | `eartag` (upstream app id `app.drey.EarTag`; confirm against `po/meson.build` before binding) |
| Upstream messages | 214 distinct `(ctxt, id)` keys |
| Ported | 0 |
| Gaps | 214 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 266 across 214 messages (38 reused) |
| Port occurrences | 0 |
| Upstream languages | 36 `.po` files, 7,088 translated, 41 untranslated, 50 fuzzy (over 7,179 total entries) |
| Languages shipped by the port | 0 |
| Unresolved markers (upstream) | 4 — all `ngettext(` calls whose plural form is built from a format string rather than a literal (e.g. `src/extract.py:238`); censused by reading the call sites, not closed here |
| Build/runtime check | **not run** — no gettext dependency, no `po/`, nothing to `msgfmt` |

Generated via `.claude/skills/translation-parity/scripts/catalogue.rb` against
an `origin/main` worktree (upstream) and the `ruby` branch checkout (port),
this round.

## The port has no translation layer at all

```
grep -rn "gettext\|_(" lib exe   →  no matches
find . -iname po -o -iname '*.po' →  nothing (outside .git)
grep -i gettext eartag-rb.gemspec →  no match
```

There is no `po/` directory, no `gettext` (or `ruby-gettext`) dependency
declared in `eartag-rb.gemspec`, and not one of the 214 upstream strings is
marked for translation anywhere in `lib/` or `exe/`. Every user-visible
string the port has built so far — the status page title/description, the
three menu item labels, the four preferences rows' labels, the eight
shortcuts entries, the about dialog's strings — is a bare Ruby literal.
English only, and no `.po` file for a translator to work against.

This is **not** 0 messages because 0 widgets exist: the application shell,
preferences dialog, shortcuts dialog and about dialog that are built and
driven this round (see `COMPONENT_PARITY.md`) already show real upstream
strings on screen — "Preferences", "Keyboard Shortcuts", "Open or drag in
some audio files to edit their metadata.", the shortcuts section headers —
none of them through a translation marker.

## Representative gaps (strings already on screen, unmarked)

| msgctxt | msgid | Upstream site | Port site | State |
|---|---|---|---|---|
| — | `Preferences` | `src/ui/window.blp` (menu item) | `lib/eartag/application.rb` (literal) | **gap** |
| — | `Keyboard Shortcuts` | `src/ui/window.blp` | `lib/eartag/application.rb` (literal) | **gap** |
| — | `About Ear Tag` | `src/ui/window.blp` | `lib/eartag/application.rb` (literal) | **gap** |
| — | `Open or drag in some audio files to edit their metadata.` | `src/ui/nofile.blp` | `lib/eartag/application.rb` (literal, status page description) | **gap** |
| — | `Search for files in subfolders` | `src/ui/settings.blp` | `lib/preferences_dialog.rb` (literal) | **gap** |
| shortcut window | `Open files` | `src/ui/shortcuts.blp` | `lib/shortcuts_dialog.rb` (literal) | **gap** |
| shortcut window | `Save all modified files` | `src/ui/shortcuts.blp` | `lib/shortcuts_dialog.rb` (literal) | **gap** |
| — | `Open File` | `src/ui/nofile.blp` | `lib/no_file.rb` (literal) | **gap** |
| — | `Open Folder` | `src/ui/nofile.blp` | `lib/no_file.rb` (literal) | **gap** |
| — | `Include Files from Subfolders` | `src/ui/nofile.blp` | `lib/no_file.rb` (literal) | **gap** |
| — | `When opening a folder, include files from its subfolders` | `src/ui/nofile.blp` | `lib/no_file.rb` (literal tooltip) | **gap** |

(Full 214-row table is reproducible from the generated catalogues; these
rows are the ones already verified on screen by this round's drive run and
stand for the pattern repeated across the other 207.)

## Languages

Upstream ships 36 `.po` files (`bg ca cs de el en_GB eo es eu fa fi fr fur he
hi hr hu id is it ka kk nb nl oc pl pt pt_BR ru sl sr sv tr uk uz zh_CN`) with
7,088 translated strings, 41 untranslated, 50 fuzzy (counted correctly as
untranslated-in-practice, per `rmsgfmt`'s default `ignore_fuzzy`). The port
ships **0 of 36**. Every one of upstream's donated translations — fourteen
languages above 90% complete — is currently unreachable from the port, not
because it was dropped, but because there is no catalogue infrastructure for
any of it to attach to.

## Conclusion

**0/214 messages, 0/266 occurrences, 0/36 languages, 0/7,088 translated
strings.** This is not a partial translation gap to close string-by-string;
it is the complete absence of the i18n layer upstream treats as part of the
app. The widgets that exist today are English-only by construction, and
nothing in the port's dependency list (`eartag-rb.gemspec`) or file layout
suggests a plan to add it.
