<p align="center">
  <img src="assets/booksy-icon.png" alt="Booksy Logo" width="128" height="128" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
</p>

<h1 align="center">Booksy</h1>

<p align="center">
  <strong>A TTS-native macOS e-reader — read and listen to any book, 100% offline.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue?style=flat-square&logo=apple" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/TTS-Kokoro%2082M-purple?style=flat-square" alt="Kokoro TTS" />
  <img src="https://img.shields.io/badge/NLP-Qwen%202.5-green?style=flat-square" alt="Qwen 2.5" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square" alt="MIT License" />
</p>

---

## ⚡ Quick Download

Download the native macOS installer package:

📦 **[Download Booksy-Installer.pkg (Latest)](Booksy-Installer.pkg)**

> Double-click `Booksy-Installer.pkg` to install `Booksy.app` directly into `/Applications`. Runs natively on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## 📖 The Booksy Experience

<p align="center">
  <img src="assets/booksy-story.png" alt="Booksy Product Walkthrough" width="900" style="border-radius: 12px; box-shadow: 0 10px 35px rgba(0,0,0,0.2);" />
</p>

### 1. A More Immersive Way to Read
Beautiful books brought to life with natural, expressive voices. Designed to combine the visual elegance of Apple Books with a local neural speech engine.

### 2. Listen with Booksy
Our open-source voice engine, powered by Kokoro, brings stories to life with refined intonation, emotion, and human pacing.

### 3. Stories for Every Mood
From timeless classics in the Gutenberg library to modern favorites in your own EPUB & PDF collection, discover books that fit your moment.

### 4. Read and Listen, Together
Text is highlighted in sync with the audio so you can read, listen, or do both simultaneously.

---

## 📸 In-App Reading View

<p align="center">
  <img src="assets/booksy-reader-spread.png" alt="Booksy Two-Page Spread Reader" width="850" style="border-radius: 8px; border: 1px solid rgba(0,0,0,0.1);" />
  <br/>
  <em>Two-page spread with dynamic aspect ratio adaptation, floating neural audio player, and integrated Apple-grade annotation suite.</em>
</p>

---

## 🌟 Key Features

### 🎙️ Read From Exactly Where You Are
When you hit Play, Booksy **doesn't jump back to the chapter start**. It performs coordinate-aware layout analysis to detect the exact paragraph currently visible in your active viewport (prioritizing the left reading column and filtering out 1-line spillover fragments) and starts speaking right where your eyes are.

### 🧠 Offline Neural Intonation & Context Direction
- **Local Context Director**: A quantized Qwen 2.5 model and Lingua language detector run locally to analyze sentence structure, subtext, foreign language quotes (e.g. Italian phrases in English novels), and dialogue vs. narrative tones.
- **Kokoro 82M Speech Engine**: Studio-grade, human-paced speech synthesis without robot voice artifacts or cloud latency.
- **11 Expressive Voices**: Choose between `af_heart`, `am_adam`, `bf_alice`, `bm_fable`, and more with variable speed controls (0.75x to 2.0x).

### 📐 Adaptive Dynamic Layout & Pagination
- **Aspect Ratio Awareness**: Automatically collapses between an immersive 2-page spread and a clean, centered single-page layout when resizing windows or working in vertical/portrait splits.
- **Zero Spread Bleeding**: Calculated column gaps ensure adjacent page text never leaks into margins.
- **Live Page Recalculation**: View accurate page counts, pages left in chapter, and estimated total book progress.

### 🎨 Complete Apple-Grade Reader Suite
- **Customizable Typography**: Change fonts (Original, SF Pro, New York, Georgia, Palatino), font size, line height, letter spacing, word spacing, and text justification.
- **Reading Themes**: Clean White, Warm Sepia, Soft Gray, and True OLED Night Mode.
- **Rich Annotation Bar**: Select any passage to highlight in 5 pastel shades, underline, add notes, or copy clean text.
- **Find in Page**: Instant in-book search with keyboard navigation (`Cmd+F`).

### 📚 Gutenberg "Want to Read" Catalog
Browse, search, and download thousands of public domain classics directly through Project Gutenberg & Gutendex without leaving the app.

---

## 🏛️ Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Booksy macOS App                     │
│         SwiftUI UI • AppKit Core • WKWebView Reader    │
└───────────────────────────┬────────────────────────────┘
                            │ Process Pipe / JSON IPC
┌───────────────────────────▼────────────────────────────┐
│                    Python Subsystem                    │
│   • speak_chapter.py    - Kokoro Neural TTS Synthesis  │
│   • context_director.py - Language Detection & Routing │
│   • epub_metadata.py    - Spine & TOC Extraction       │
│   • read_chapter.py     - Clean Content Extraction     │
└────────────────────────────────────────────────────────┘
```

- **100% Private**: No cloud telemetry, no analytics, no external servers.
- **Instant Response**: Audio streams concurrently in chunks while speech is generated in the background.

---

## 🛠️ Building From Source

### Prerequisites
- macOS 13.0 (Ventura) or newer
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+ (recommended in `~/aperture-epub-reader/.venv` or system path)

### Python TTS Dependencies
```bash
pip install kokoro sounddevice beautifulsoup4 lingua-language-detector torch numpy
```

### One-Command Build & Package
```bash
git clone https://github.com/youssefbouhaik/Booksy.git
cd Booksy

# Make packaging script executable and build
chmod +x package_app.sh
./package_app.sh
```

The script will:
1. Compile all Swift modules into `Booksy_bin`.
2. Construct the macOS bundle at `/Applications/Booksy.app`.
3. Code-sign and attach full-bleed Finder icons.
4. Output the standalone installer: `Booksy-Installer.pkg`.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Right Arrow` / `Space` / `Page Down` | Next Page / Spread |
| `Left Arrow` / `Page Up` | Previous Page / Spread |
| `Cmd + F` | Search within Chapter |
| `Cmd + B` | Bookmark Current Page |
| `Cmd + T` | Open Table of Contents |
| `Cmd + ,` | Open Reader Theme & Typography Settings |

---

## 📜 Acknowledgements & Licenses

- **Matthew Andrea D'Alessio** — Original Swift macOS Apple Books clone foundation.
- **Kokoro TTS** — Lightweight open-weights neural speech synthesis model.
- **Qwen 2.5 Team** — Language understanding and context extraction.
- **Project Gutenberg & Gutendex** — Open public domain digital literature.

This project is open-source software licensed under the **[MIT License](LICENSE)**.
