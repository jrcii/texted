# TextEd

A modern Swift rewrite of [Jeena's TextEd.app](https://git.jeena.net/jeena/TextEd.app)
(2014): the leanest, fastest plain-text-only editor possible. No rich text, no
iCloud, no substitutions, no spellcheck — it just opens text, fast.

The original icon is kept (© Jeena); the code is a from-scratch reimplementation.

## What makes it fast

- **~120 KB binary, 232 KB app bundle.** Programmatic AppKit, no xibs, no
  storyboards, no frameworks beyond the system.
- **TextKit 2** (`NSTextView(usingTextLayoutManager: true)`): layout is done
  per viewport, so opening a 100 MB file doesn't lay out 100 MB of text.
- **AVX-512 file scanning** (`Sources/CSimd`): on open, one pass over the raw
  bytes counts lines, detects ASCII, and validates UTF-8 at ~15 GB/s
  (64 bytes/iteration via `AVX-512BW` compare-to-mask + popcount). Falls back
  to scalar on CPUs without AVX-512 (including arm64), selected at runtime —
  the window subtitle shows `AVX-512` when the vector kernel ran.
- **Single-copy ingest**: ASCII files (the common case for large ones) are
  wrapped in a zero-copy `CFString` straight off the read buffer — no decode
  pass, no intermediate Swift String. NSTextStorage makes the only copy, in
  1-byte-per-char internal storage, and the document never retains its own
  copy of the text. A 73 MB file opens with ~133 MB RSS instead of ~214 MB.
- **Encoding fallback**: valid UTF-8 is decoded as-is; anything else falls back
  to Latin-1 instead of refusing to open (the 2014 original crashed on
  non-UTF-8 files).

Everything else is stock `NSDocument`: autosave-in-place, versions, undo
through the document's undo manager, Open Recent, the find bar (⌘F), and the
monospace font size persisted in the same `fontSize` user default the original
used (⌘+ / ⌘−).

## Build

```sh
make          # swift build -c release + assemble TextEd.app
make run      # build and open it
```

Requires macOS 12+ and a Swift toolchain. No Xcode project needed.

## Layout

```
Sources/CSimd/     C target: te_scan() — AVX-512 + scalar byte scanner
Sources/TextEd/    Document, menu, app delegate, main (4 small files)
Resources/         Info.plist + the original Icon.icns
original/          clone of the 2014 Objective-C original, for reference
```
