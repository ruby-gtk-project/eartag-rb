# Test parity — eartag-rb

| | |
|---|---|
| Upstream | `main` @ `ad8eadd6a98251a2e6386372486b577c22cf19fa` |
| Port | `ruby` @ `4454814` |
| Upstream tests | 47 |
| Ported | 0 |
| Gaps | 47 |
| Test command | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` (per the dev-shell banner) |

## The suite does not run

```
An error occurred while loading spec_helper.
Failure/Error: require "kettle/test/rspec"
LoadError: cannot load such file -- kettle/test/rspec
0 examples, 0 failures, 2 errors occurred outside of examples
```

`spec/` contains only `spec_helper.rb` and `spec/README.md` — zero spec files.
`spec_helper.rb` itself cannot load, because `kettle-test` (declared in
`eartag-rb.gemspec` as a dev dependency) is not present in the dev shell's
bundle. This is not "0 tests ported, suite green" — it is 0 tests ported and
the harness that would run them does not start. A suite that has never
executed is a gap in its own right, independent of the 47 rows below.

The 37-check `test/drive_main_window.rb` script (verified this round: 37/37,
`DRIVE OK`) is a different thing entirely — it drives GTK widgets headlessly
and is not a port of any upstream test. Upstream's 47 tests are plain
`unittest` functions over pure logic (tag backends, MusicBrainz identify,
filename cleanup/validation, extract-tags patterns); none of them exercise a
widget, and none of them has a Ruby counterpart anywhere in `lib/`, `spec/` or
`test/`.

## Suite: tests/backends/test_backends.py (4 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_backend_mutagen_id3` | round-trips every tag through the ID3/MP3 backend against the fixture file | — | **gap** |
| 2 | `test_backend_mutagen_mp4` | round-trips every tag through the MP4/M4A backend | — | **gap** |
| 3 | `test_backend_mutagen_vorbis` | round-trips every tag through the FLAC/OGG Vorbis backend | — | **gap** |
| 4 | `test_backend_mutagen_asf` | round-trips every tag through the ASF/WMA backend | — | **gap** |

Behaviour still owed: `lib/backends/file_id3.rb`, `file_mp4.rb` and
`file_vorbis.rb` exist but have no test pinning that reading and writing a tag
round-trips correctly against a real file; `file_asf.rb` does not exist at
all (see `.reports/component-inventory.md`), so its row cannot even be
targeted yet.

## Suite: tests/test_musicbrainz.py (5 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_acoustid_identify` | AcoustID fingerprint lookup resolves a file to a recording | — | **gap** |
| 2 | `test_musicbrainz_onerel` | a MusicBrainz release with one matching relation is applied correctly | — | **gap** |
| 3 | `test_musicbrainz_multirel` | a release with multiple relations picks the right one | — | **gap** |
| 4 | `test_musicbrainz_file_set` | identify flow resolves a whole batch of files at once | — | **gap** |
| 5 | `test_musicbrainz_covers` | cover art is fetched and attached from the matched release | — | **gap** |

Behaviour still owed: the entire identify flow (`src/identify.py`,
`src/musicbrainz.py` upstream) has no Ruby file at all — not `lib/identify.rb`,
not `lib/musicbrainz.rb`. There is nothing in the port these rows could even
be ported against yet.

## Suite: tests/utils/test_cleanup_filename.py (9 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_strip_spaces` | leading/trailing spaces are stripped from a generated filename | — | **gap** |
| 2 | `test_replace_banned_character_with_underscore` | one banned character (e.g. `/`) becomes `_` | — | **gap** |
| 3 | `test_replace_two_different_banned_characters_with_underscore` | two distinct banned characters both become `_` | — | **gap** |
| 4 | `test_replace_point_point_with_underscores` | a `..` sequence becomes `__` | — | **gap** |
| 5 | `test_replace_last_point_point_with_underscores` | a trailing `..` becomes `__` | — | **gap** |
| 6 | `test_replace_last_point_with_underscores` | a trailing single `.` becomes `_` | — | **gap** |
| 7 | `test_add_underscore_prefix_to_banned_file_name` | a filename matching a banned name (e.g. `con`) gets a `_` prefix | — | **gap** |
| 8 | `test_trim_too_long_file_name` | a filename longer than the OS limit is trimmed, preserving the extension | — | **gap** |
| 9 | `test_trim_too_long_file_path` | a full path longer than the OS limit is trimmed component-wise | — | **gap** |

Behaviour still owed: there is no `cleanup_filename` equivalent anywhere in
`lib/` — this is part of upstream's rename flow (`src/rename.py`), which has
no port file.

## Suite: tests/utils/test_extracttags.py (7 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_empty_filename` | an empty filename against a pattern yields no matches | — | **gap** |
| 2 | `test_match_track_number_and_title` | `{tracknumber} {title}` extracts both fields from a simple name | — | **gap** |
| 3 | `test_tags_with_positions` | repeated placeholders at different positions resolve independently | — | **gap** |
| 4 | `test_tag_include_curly_braces` | a literal `{`/`}` in the filename is not mistaken for a placeholder | — | **gap** |
| 5 | `test_malformed_placeholder` | an unclosed or unknown placeholder fails without raising | — | **gap** |
| 6 | `test_unicode_characters` | non-ASCII filenames extract correctly | — | **gap** |
| 7 | `test_unicode_characters_with_positions` | non-ASCII filenames with positional placeholders extract correctly | — | **gap** |

Behaviour still owed: `lib/extract_tags.rb` exists (per the component
inventory) and implements the pattern engine, but none of these seven cases
is pinned against it. This is the one suite in the ledger where the port file
to write the test against already exists today.

## Suite: tests/utils/test_filename_valid.py (17 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_empty_filename` | an empty filename is invalid | — | **gap** |
| 2 | `test_filename_without_path` | a bare filename (no path) validates on its own rule set | — | **gap** |
| 3 | `test_filename_containing_banned_character` | a banned character makes the filename invalid | — | **gap** |
| 4 | `test_filename_containing_banned_character_when_paths_are_allowed` | same, but the "paths allowed" mode changes which characters are banned | — | **gap** |
| 5 | `test_filename_ending_with_period` | a trailing `.` is invalid on the platforms that forbid it | — | **gap** |
| 6 | `test_filename_ending_with_period_when_paths_are_allowed` | same check under "paths allowed" | — | **gap** |
| 7 | `test_filename_not_normalized` | a filename that is not Unicode-normalized is rejected | — | **gap** |
| 8 | `test_filename_not_normalized_when_paths_are_allowed` | same check under "paths allowed" | — | **gap** |
| 9 | `test_filename_starting_with_relative_parent_directory` | a filename starting with `../` is rejected | — | **gap** |
| 10 | `test_filename_with_path_separator_when_fullpath_is_disallowed` | a path separator is invalid when full paths are not allowed | — | **gap** |
| 11 | `test_filename_with_path_separator_when_paths_are_allowed` | a path separator is valid when full paths are allowed | — | **gap** |
| 12 | `test_filename_with_spaces` | spaces alone do not make a filename invalid | — | **gap** |
| 13 | `test_filename_with_spaces_when_paths_are_allowed` | same, under "paths allowed" | — | **gap** |
| 14 | `test_banned_filename` | a reserved OS filename (e.g. `con`, `nul`) is invalid | — | **gap** |
| 15 | `test_banned_filename_when_paths_are_allowed` | same check under "paths allowed" | — | **gap** |
| 16 | `test_filename_with_path_deeper_than_255_levels` | a path with more than 255 components is rejected | — | **gap** |
| 17 | `test_filename_with_path_deeper_than_255_levels_when_paths_are_allowed` | same check under "paths allowed" | — | **gap** |

Behaviour still owed: a `filename_valid?`-equivalent exists nowhere in
`lib/`. This is part of the rename flow, same as the cleanup-filename suite
above.

## Suite: tests/utils/test_validation.py (5 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_valid_music_file` | a real audio file is accepted by mimetype sniffing | — | **gap** |
| 2 | `test_valid_image_file` | a real image file (cover art) is accepted | — | **gap** |
| 3 | `test_file_type_not_in_valid_mime_types` | a recognised-but-unsupported mimetype is rejected | — | **gap** |
| 4 | `test_magic_returns_no_file_type` | an unrecognisable file is rejected without raising | — | **gap** |
| 5 | `test_path_not_found` | a nonexistent path is rejected without raising | — | **gap** |

Behaviour still owed: `lib/validation.rb` exists and implements the sniffing
rules the component inventory describes, but none of upstream's five cases is
pinned against it — the one Ruby file in this ledger whose logic the port
already wrote and never tested.

## Extra

- `test/drive_main_window.rb` — 37 checks driving the window shell, the
  preferences dialog, the shortcuts dialog, the about dialog, `PopoverButton`
  and `ModelExpanderRow`. Verified this round: `ruby test/drive_main_window.rb`
  under `nix develop … xvfb-run -a` reports **37 of 37 checks passed, DRIVE
  OK**. None of these checks maps to an upstream test — upstream has no
  widget-level test suite at all — so they are extra, not parity.

## Conclusion

**0 / 47.** Every upstream test is a gap, and the RSpec harness that would
eventually hold the Ruby equivalents does not load. The one green signal this
round (`DRIVE OK`, 37/37) covers the application shell and two shared
widgets; it says nothing about the model/backend layer, the identify flow, or
the rename/filename-validation logic that the 38 non-widget upstream tests
exist to pin, and three of those five suites (`test_musicbrainz`,
`test_cleanup_filename`, `test_filename_valid`) have no port file at all to
write a test against yet.
