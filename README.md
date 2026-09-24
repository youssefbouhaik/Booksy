# Booksy

<p align="center">
  <strong>A TTS-native macOS books app — read and listen to anything, offline</strong>
</p>

---

## what is booksy

Booksy is a TTS-native books app built on top of Matthew Andrea D'Alessio's Apple Books clone. We took the Swift shell and combined it with the text-to-speech capabilities of Kokoro's e-reader engine. What came out of it is a layer that can account for intonation and subtext to provide for a seamless reading and listening experience.

We have explicitly removed audiobooks from this version, because we don't see a use for them anymore with the Kokoro layer — every book in your library is already an audiobook on demand.

---

## what we bring to the table

### offline neural intonation
A quantized Qwen 2.5 model (~800MB) lives on your laptop, fully offline, no updates needed. It handles language detection and context direction so Kokoro knows *how* to read each sentence — dialogue, narration, foreign language spans — not just what to read.

### better design than Apple's
We kept the Apple Books aesthetic that feels native to macOS but pushed it further. Dark and light modes, fluid two-page spreads, live typography preview, a proper annotation suite with highlights, underlines, and squared note cards. The customize panel gives you full control — line spacing, character spacing, word spacing, margins, columns, justify text — everything you'd want from a serious reader.

### a proper annotation suite
Floating toolbar on text selection. Five highlight colors, underline, note-taking with markdown preview, per-page bookmarks. All stored locally, no sync needed.

### read from where you are
When you hit play, Booksy reads from the page you're actually looking at, not from the beginning of the chapter. It extracts visible text from the current spread and tells Kokoro to pick up right there.

### want to read, fueled by gutenberg
The "Want to Read" section is fueled by Project Gutenberg's open-source selection of books. Browse, search, and download thousands of public-domain literary classics directly into your library. No accounts, no DRM.

### dynamic pagination
Page count recalculates live as you resize the window. Estimated page numbers across the full book, multi-level table of contents with progress markers, chapter-level page tracking.

---

## architecture

```
┌────────────────────────────────────────────────────────┐
│                      macOS App                         │
│       SwiftUI UI • WKWebView Reader • AppKit Core      │
└───────────────────────────┬────────────────────────────┘
                            │ Process Pipe / IPC
┌───────────────────────────▼────────────────────────────┐
│                    Python Subsystem                    │
│   • speak_chapter.py   - Neural Kokoro TTS Engine      │
│   • context_director.py - Language Detection + Routing │
│   • epub_metadata.py   - Spine & TOC Extraction        │
│   • read_chapter.py    - EPUB Parsing & Sanitization   │
└────────────────────────────────────────────────────────┘
```

- **100% offline & private** — no telemetry, no accounts, zero cloud dependencies
- **low latency** — audio streams as sentences are synthesized in the background
- **11 Kokoro voices** — from af_heart to bm_fable, pick the voice that suits you

---

## installation & building

### prerequisites
- macOS 13.0 (Ventura) or newer
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+ with `kokoro`, `ebooklib`, `sounddevice`, `beautifulsoup4`, `lingua`

### quick build & install

```bash
git clone https://github.com/booksy-app/booksy.git
cd booksy

# compile native binary and package Booksy.app
chmod +x package_app.sh
./package_app.sh
```

The script compiles all Swift modules, constructs the `.app` bundle with UTI file associations for EPUB and PDF, signs with ad-hoc signatures, and deploys `Booksy.app` directly into `/Applications`.

---

## acknowledgements

- **Matthew Andrea D'Alessio** — foundation Swift macOS Books UI clone
- **Kokoro TTS** — high-quality open-weight neural text-to-speech model
- **Qwen 2.5** — language detection and context direction model
- **Project Gutenberg & Gutendex** — open-access digital library of classic books
- **Open Library** — bibliographic database and book cover catalog

---

## license

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
