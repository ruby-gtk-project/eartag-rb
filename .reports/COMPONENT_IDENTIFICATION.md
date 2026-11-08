# Component identification — eartag-rb

This round's `component-identification` work is `.reports/component-inventory.md`
(committed in a prior round, `9ab4215 Inventory upstream components`), which
already does what this skill asks: it reads upstream's `.blp`/`.ui` files
first, unions each upstream file onto its port counterpart, and lists every
widget with its CSS classes, signals and notes, file by file, in the order a
user meets them. This document records this round's verification of it
rather than re-deriving a parallel inventory.

## Spot checks performed this round

| Claim in `component-inventory.md` | Verified how | Result |
|---|---|---|
| "asf/WMA has no Ruby backend" | `find lib/backends -name '*.rb'` | confirmed — `file.rb`, `file_id3.rb`, `file_mp4.rb`, `file_vorbis.rb` only, no `file_asf.rb` |
| "po/ catalogue 36 locales" | `git ls-tree -r --name-only origin/main \| grep '^po/.*\.po$' \| wc -l` | confirmed — 36 |
| §1 action table (16 `app.*`, 1 `win.*`, 9 accelerators) | `git show origin/main:src/main.py` read directly | confirmed, including the two actions the table correctly marks "no" for an initially-disabled state (`app.rename`, `app.delete_all_tags`) |
| §2 window widget table (34 template children, 3 breakpoints) | `git show origin/main:src/window.py` and `src/ui/window.blp` read directly | confirmed |
| §4/§5 preferences and shortcuts tables | `git show origin/main:src/ui/settings.blp` and `src/ui/shortcuts.blp` | confirmed, and cross-checked live against the running port via `test/drive_main_window.rb` (see `COMPONENT_PARITY.md`) |
| "`lib/*.rb` covers 19 files" | `find lib -name '*.rb'` | **stale as of this round** — now 26 files under `lib/` (excluding `eartag/rb/version.rb`, packaging only); `no_file.rb`, `editable_label.rb` and `album_cover_image.rb` were added and wired/driven since the commit this inventory was written against. `component-inventory.md` has been updated in place this round (rows 3, 9, 15 and the Totals section) rather than re-derived from scratch |

No discrepancy was found between the inventory's claims and upstream source
or the running port in any of the above. The inventory's own "still absent"
list (window, sidebar, editor pane, all task dialogs, the identify flow, the
ASF backend, `po/`) matches what `COMPONENT_PARITY.md` and
`TRANSLATION_PARITY.md` independently find this round.

## What this round adds beyond the existing inventory

- Confirmed upstream's real message count via the `translation-parity`
  census rather than the inventory's "50 POTFILES entries" estimate: **214
  distinct messages, 266 occurrences, 4 unresolved** (see
  `TRANSLATION_PARITY.md`) — POTFILES line count and distinct-message count
  are different numbers, and the inventory's "50" was the former.
- Confirmed upstream's real test count via the `test-parity` census: **47**,
  not estimated anywhere in the prior inventory (which does not cover tests
  at all — out of this skill's scope and correctly left to `TEST_PARITY.md`).

## Conclusion

The existing per-file component inventory is accurate and current against
`origin/main` @ `ad8eadd6a98251a2e6386372486b577c22cf19fa`. It remains the
canonical unit list and file mapping for `COMPONENT_PARITY.md` and should be
kept, re-verified, and extended in place in future rounds rather than
rewritten from scratch.
