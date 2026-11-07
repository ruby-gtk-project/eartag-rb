# Accountability ensurance — eartag-rb

Scope: `grep -rniE` for excuse constructions over `lib/`, `exe/`, `.reports/`
and `PORTING.md` (absent — no hits possible), plus a check of every "green"
claim in this round's reports against something that was actually executed.

## Excuse-construction hits in `lib/`

Two real hits, both in source comments, both doing exactly what the skill
names: presenting a missing feature as a reasoned decision instead of a debt.

### `lib/backends/file.rb:23-25`

```ruby
# Cover art (upstream's EartagFileCover, GdkPixbuf thumbnails, PIL fallback)
# is not ported this round: no backend here declares `supports_album_covers`,
# so the cover accessors below are the same no-ops upstream ships for a
# format that cannot carry a picture.
```

"is not ported this round" is the honest-but-toothless construction the
skill names directly — it records the absence and gives it no owner and no
behaviour. Worse, the second half ("the same no-ops upstream ships for a
format that cannot carry a picture") borrows upstream's own fallback
behaviour as cover for a port-wide decision to skip cover art on every
format, not just the ones that genuinely can't carry a picture. That is a
foothold a future reader can nod at and move on.

**Rewrite it owes:**

> I did not build cover art — no backend here can read, write or display an
> album cover, the preview selector, or the back-cover slot — because I am an
> idiot who mistook giving up for a design decision.
> Upstream: `EartagFileCover`, GdkPixbuf thumbnailing and the PIL fallback in
> `src/backends/file.py`; `src/ui/albumcoverbutton.blp`,
> `albumcoverimage.blp`, `previewselectorbutton.blp`,
> `previewselectoritem.blp`.
> Port: `Backends::Cover` (`lib/backends/file.rb`) holds raw bytes and a
> mimetype but nothing reads or writes through it, and no format backend
> declares `supports_album_covers`.

### `lib/validation.rb:12-14`

```ruby
# Upstream's async variants are not ported: they exist because filetype.py and
# os.path.exists block the Python event loop, which is not a problem Ruby's
# threads have.
```

"are not ported" plus a reason a reader can agree with ("not a problem
Ruby's threads have") is the exact mechanism the skill describes: a
plausible-sounding technical justification that lets the next reader stop
checking. It may even be a defensible technical claim on its own — that is
irrelevant. The behaviour upstream's async variants exist to provide
(validating a file without blocking the window's event loop while a large
folder is being scanned) is not proven to exist in the port by this
sentence; it asserts it away.

**Rewrite it owes:**

> I did not check, let alone build, whether validating a large folder of
> files blocks the GTK main loop the way `filetype.py` and `os.path.exists`
> block Python's — I asserted it doesn't need doing and left it at that,
> because I am an idiot who decided a feature I didn't understand wasn't
> needed.
> Upstream: async `is_valid_music_file`/`get_mimetype` variants wrapping
> `filetype.py`'s blocking calls (`src/utils/validation.py`).
> Port: `Validation.valid_audio_file?` et al. (`lib/validation.rb`) are
> synchronous only, with no test or drive check establishing whether a large
> `app.open_folder` scan (not yet built either — see
> `COMPONENT_PARITY.md`) would freeze the UI.

## False-green risk already caught by this round's reports

- `TEST_PARITY.md` and `TRANSLATION_PARITY.md` both report the suites they
  describe as **never having executed** (`LoadError: cannot load such file
  -- kettle/test/rspec`; zero translation infrastructure to run `msgfmt`
  against). Neither report rounds that up to a pass. This is the finding the
  skill is most concerned with — a green claim resting on something never
  run — and in this audit it did not happen, because both ledgers state the
  non-execution in their own header rows rather than only in prose.
- The runtime gate (`drive_ok=true`, 37/37, 7 components) is real and was
  re-run this round (`nix develop --command xvfb-run -a ruby
  test/drive_main_window.rb` → `37 of 37 checks passed`, `DRIVE OK`). It is
  not a false green **as far as it goes** — but it goes only as far as the
  application shell, two dialogs and two standalone shared widgets.
  `COMPONENT_PARITY.md` and `TEST_PARITY.md` both say explicitly that the
  window, the sidebar, the editor, every alert dialog, the identify flow,
  the rename flow and 38 of 47 non-widget upstream tests are not exercised
  by it. Treating "37/37, DRIVE OK" as evidence the port is healthy beyond
  those 7 components would itself be the false-green failure this skill
  exists to catch; this round's reports do not make that leap, and this
  report records the boundary explicitly so the next round does not either.

## What was checked and found clean

- No `TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, `out of
  scope`, `n/a`, `does not carry over`, `not applicable`, `dropped
  deliberately` or `by design` hits in `lib/`, `exe/` or the prior
  `.reports/component-inventory.md` beyond the two found above and one
  correct use of "by design" in `component-inventory.md:687` describing the
  absence of `.blp` files — which is a real, named correspondence under the
  `component-identification`/`component-parity` skills (the house style
  builds widgets as memoized Ruby methods instead of templates), not an
  excuse for missing behaviour. That one line stays.
- There is no `PORTING.md` or `FINDINGS.md` on this branch yet, so there is
  no document citing either as authority for a skipped gap — the specific
  failure mode the skill's `console-rb` case study describes has no vector
  to occur here *yet*. The two hits above are smaller-scale versions of the
  same thing, in code comments rather than a ledger, and are reported
  accordingly.

## Conclusion

Two excuse constructions found, both in `lib/`, both now rewritten above in
first person with the behaviour owed named and file:line cited on both
sides. Neither reached `PORTING.md`-style authority — there is no such
document yet — but both are exactly the pattern this skill exists to stop
from hardening into one, and their accurate text should replace the current
comments.
