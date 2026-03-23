# Umineko Web

ONScripter-RU compiled to WebAssembly via Emscripten.
Runs [Umineko no Naku Koro ni](https://store.steampowered.com/app/406550/Umineko_When_They_Cry__Question_Arcs/) (
PS3/Umineko Project build) entirely in the browser - no plugins, no downloads, no native binaries.

## Table of Contents

- [Features](#features)
- [Known Issues](#known-issues)
- [Building and Running](#building-and-running)
    - [Prerequisites](#prerequisites)
    - [Quick Start](#quick-start)
    - [Game Assets](#game-assets)
    - [Build Options](#build-options)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
    - [Architecture Overview](#architecture-overview)
    - [Compiling a Native C++ Engine to WebAssembly](#compiling-a-native-c-engine-to-webassembly)
    - [The Threading Problem](#the-threading-problem)
    - [Virtual Filesystem and Lazy Asset Loading](#virtual-filesystem-and-lazy-asset-loading)
    - [Video Playback Pipeline](#video-playback-pipeline)
    - [Subtitle Rendering](#subtitle-rendering)
    - [Persistent Save System](#persistent-save-system)
    - [Graphics Pipeline](#graphics-pipeline)
    - [Audio Pipeline](#audio-pipeline)
    - [Asset Optimisation](#asset-optimisation)
    - [Classic Art Swap](#classic-art-swap)
- [Native Library Build Chain](#native-library-build-chain)
- [Engine Modifications](#engine-modifications)

## Features

The game is fully playable in the browser. All core functionality works:

- **Full Script Execution** - the complete ONScripter-RU game script runs, including branching, variables, jumps, and
  all NScripter commands
- **Text Rendering** - dialogue, name tags, and all text display with FreeType font rendering (10+ font faces supported)
- **Image Display** - backgrounds, sprites, character portraits, and all visual layers render through WebGL
- **Visual Effects** - transitions, fades, screen shakes, breakup effects, and all engine-level effects
- **Video Cutscenes** - H.264/MPEG-2 video playback via FFmpeg decoded synchronously in WASM
- **Alpha-Masked Video** - MPEG-2 overlay videos (.m2v) with per-pixel alpha mask compositing for animated effects
- **Subtitled Cutscenes** - .ass subtitle rendering on video cutscenes via libass, HarfBuzz, and FriBidi compiled to
  WASM
- **Asset Optimisation** - automatic PNG→WebP, MP4→WebM/VP9, and OGG re-encoding at container startup (~60% size
  reduction with transparent fallback)
- **Audio** - BGM, sound effects, and voice lines via SDL2_mixer and the Web Audio API (OGG/Vorbis)
- **Save/Load System** - game saves and settings persist across browser sessions via IndexedDB
- **Settings Menu** - interactive settings with clickable buttons, sliders, and configuration
- **Keyboard and Mouse Input** - full input handling through SDL2 events
- **On-Demand Asset Loading** - 101,000+ game files loaded lazily over HTTP, only fetching what the engine actually
  reads
- **GPU-Accelerated Rendering** - SDL2_gpu GLES2 backend rendering through WebGL with GLSL shaders
- **Classic Art Swap** - press **G** in-game to hot-swap between PS3 redrawn sprites and Ryukishi07's original
  classic art. Toggle takes effect on the next sprite load (advance dialogue or change scene). See
  [Classic Art Swap](#classic-art-swap) for details

## Known Issues

- **Do not change resolution on mobile** - Changing the "Window size" in the Config menu will break the display on
  mobile/tablet browsers. Leave it at the default setting. On desktop browsers, you can set it to your display's
  resolution for sharper rendering.
- **Fullscreen cursor misalignment** - In fullscreen mode, the mouse cursor may be offset by a few pixels from menu
  items. This is a DPR/CSS scaling rounding issue with Emscripten's fullscreen API.

## Building and Running

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

That's it. The entire toolchain (Emscripten SDK, cross-compiled libraries, nginx) is containerised.

### Quick Start

```bash
git clone https://github.com/VictoriqueMoe/umineko_web_asm.git
cd umineko_web_asm
```

Place your Umineko game files in the `game/` directory (or specify a custom path during setup), then run the setup
script:

**Mac / Linux:**

```bash
./setup/setup.sh
```

**Windows:**
Double-click `setup\setup.bat`, or run from a terminal:

```
setup\setup.bat
```

The script will ask you:

1. **Hosting mode**:
    - **Local** - Serves original game files directly (fast startup)
    - **Production** - Converts assets for smaller file sizes (PNG→WebP, MP4→WebM, OGG re-encoding)
    - **Remote** - No game files on the server. Visitors select their own Umineko game folder via the browser using the
      File System Access API (Chrome/Edge) or folder input fallback (Firefox)
2. **Game files path** - Where your Umineko files are (default: `./game`). Skipped in remote mode.
3. **Port** - Which port to serve on (default: `8080`)
4. **Classic art** (optional) - If you have extracted `arc~.nsa` archives from the original PC release, the setup
   script will process the Ryukishi07 sprites and enable the in-game art toggle (press G). Requires ImageMagick.

It generates a `.env` file, builds the container, and starts the server.

If you've already run setup before, re-running the script will offer to **update** (pull latest changes and rebuild) or
**reconfigure** (change settings).

> **Note:** In production mode, asset conversion runs in the background on first launch and can take a long time
> depending on your hardware. The game is playable immediately. Check progress with:
>
> ```bash
> docker compose logs -f
> ```

**Manual setup** (without the script):

```bash
docker compose up --build
```

This uses defaults: port 8080, `./game` directory, local mode. Set `HOSTING_MODE=remote` in `.env` to run without game
files on the server.

### Game Assets

The engine expects game files at `game/` in the project root (mounted into the container at
`/usr/share/nginx/html/game/`). Your game directory should contain:

```
game/
├── en.file              # Compiled game script (episodes 1-8)
├── chiru.file           # Image coordinate mappings for sprite/background positioning
├── default.cfg          # Engine configuration
├── game.hash            # Asset integrity hash
├── fonts/               # TrueType/OpenType fonts (default.ttf required)
├── backgrounds/         # Background images
├── sprites/             # Character sprites
├── graphics/            # UI elements, effects
├── sound/               # BGM, SFX, voice files (OGG/Vorbis)
├── video/
│   ├── 720p/            # Video cutscenes (MP4)
│   ├── masked/          # Alpha-masked overlay videos (M2V)
│   └── sub/             # .ass subtitle files for cutscene songs
└── dlls/                # Plugin configuration
```

You can customise the volume mount in `docker-compose.yml`:

```yaml
services:
  umineko-web:
    build: .
    ports:
      - "8080:80"
    restart: unless-stopped
    volumes:
      - /path/to/your/umineko/game:/usr/share/nginx/html/game:ro
```

### Build Options

The Docker build uses a cache-busting argument for the engine source layer. To force a rebuild of the engine without
rebuilding all dependencies:

```bash
docker compose build --build-arg ONS_CACHE_BUST=$(date +%s)
```

To rebuild everything from scratch (including FFmpeg, libass, etc.):

```bash
docker compose build --no-cache
```

## Project Structure

```
umineko-web/
├── CMakeLists.txt              # Emscripten build config (links 60+ source files, 9 static libraries)
├── Dockerfile                  # Multi-stage build: emscripten/emsdk:5.0.2 → nginx:alpine
├── docker-compose.yml          # Container orchestration with game asset volume mount
├── nginx.conf                  # Serves WASM with correct MIME types, gzip, caching, .hau content negotiation
├── build.sh                    # Build helper with cache-bust support
├── setup/
│   ├── setup.sh                # Interactive setup script (Mac/Linux)
│   └── setup.bat               # Windows wrapper (calls setup.sh via WSL)
├── scripts/
│   ├── entrypoint.sh           # Writes config.json, generates manifest, launches asset conversion, starts nginx
│   ├── generate-manifest.sh    # Walks game directory → manifest.json
│   ├── convert-assets.sh       # Orchestrates background asset conversion with progress logging
│   ├── convert-one-image.sh    # Worker: PNG → WebP (cwebp, atomic write)
│   ├── convert-one-video.sh    # Worker: MP4 → WebM/VP9 (ffmpeg, error logging)
│   └── convert-one-audio.sh    # Worker: OGG re-encode at lower bitrate (skips if larger)
├── src/
│   ├── Resources.cpp           # Embedded GLSL shaders (auto-generated from engine)
│   ├── platform/
│   │   └── web_stubs.cpp       # Exception-safe main wrapper
│   └── stubs/
│       └── smpeg2/smpeg.h      # Stub header for unused smpeg2 dependency
├── web/
│   ├── index.html              # HTML shell: canvas, Module definition, script loading
│   ├── favicon/                # Favicon and web manifest files
│   └── js/
│       ├── fetch-indicator.js  # Loading overlay shown during lazy asset fetches
│       ├── idbfs-sync.js       # Periodic IDBFS sync (saves to IndexedDB)
│       ├── vfs.js              # VFS population: eager file fetch + lazy 0-byte stubs
│       ├── remote-files.js     # Browser folder picker (File System Access API + fallback)
│       ├── game-files.js       # Hosting mode router: fetches manifest or triggers remote mode
│       └── canvas.js           # Canvas scaling, touch input, fullscreen handling
├── tools/
│   └── setup-classic-sprites.sh  # Maps + pre-processes classic Ryukishi07 sprites (bash + ImageMagick)
├── classic/                    # Pre-processed classic sprites (generated, .gitignored)
└── game/                       # Game assets (mounted volume, not committed)
```

The engine source (~60 C++ files) comes from
the [forked ONScripter-RU repo](https://github.com/VictoriqueMoe/onscripter-ru-wasm), cloned during the Docker build.

## How It Works

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Browser                                   │
│                                                                     │
│  ┌──────────┐   ┌──────────────┐   ┌─────────────────────────────┐ │
│  │  Canvas   │◄──│   WebGL      │◄──│  SDL2_gpu (GLES2 backend)  │ │
│  │ (display) │   │              │   │  + GLSL shaders             │ │
│  └──────────┘   └──────────────┘   └──────────┬──────────────────┘ │
│                                                │                    │
│  ┌──────────┐   ┌──────────────┐   ┌──────────┴──────────────────┐ │
│  │Web Audio │◄──│  SDL2_mixer  │◄──│                             │ │
│  │  API     │   │              │   │   ONScripter-RU Engine      │ │
│  └──────────┘   └──────────────┘   │   (compiled to WASM)        │ │
│                                    │                              │ │
│  ┌──────────┐   ┌──────────────┐   │  ┌───────┐ ┌─────────────┐ │ │
│  │ IndexedDB│◄──│   IDBFS      │◄──│  │FFmpeg │ │libass       │ │ │
│  │ (saves)  │   │              │   │  │(video)│ │+HarfBuzz    │ │ │
│  └──────────┘   └──────────────┘   │  └───────┘ │+FriBidi     │ │ │
│                                    │             └─────────────┘ │ │
│  ┌──────────┐   ┌──────────────┐   │                             │ │
│  │  nginx   │──►│ Lazy fetch   │──►│  Emscripten VFS            │ │
│  │ (assets) │   │ (on demand)  │   │  (101k+ file stubs)        │ │
│  └──────────┘   └──────────────┘   └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Compiling a Native C++ Engine to WebAssembly

ONScripter-RU is a C++14 visual novel engine originally built for Windows, macOS, Linux, iOS, and Android. It was never
designed for the browser. The engine depends on threading, synchronous file I/O, GPU rendering, and a dozen native
libraries.

The compilation uses [Emscripten](https://emscripten.org/) (SDK 5.0.2) which provides:

- **emcc/em++** - drop-in replacements for gcc/g++ that emit WASM instead of native code
- **Emscripten ports** - pre-built browser-compatible versions of SDL2, SDL2_image, SDL2_mixer, FreeType, zlib, libpng,
  libjpeg, libogg, and libvorbis
- **ASYNCIFY** - a compiler transform that allows synchronous C code to yield to the browser's event loop

Libraries NOT available as Emscripten ports (FFmpeg, SDL2_gpu, libass, HarfBuzz, FriBidi) are cross-compiled from source
using `emconfigure` and `emmake`.

The final WASM binary links 9 static libraries and 60+ engine source files into a single `umineko-web.wasm` (~15MB).

### The Threading Problem

The native engine uses multiple threads extensively:

- **Video decoding** - demuxer, video decoder, and audio decoder run on separate threads
- **Subtitle rendering** - .ass subtitles are decoded on a background thread
- **Async I/O** - file loading happens off the main thread

Emscripten supports `pthreads` via `SharedArrayBuffer`, but this requires `Cross-Origin-Opener-Policy` and
`Cross-Origin-Embedder-Policy` headers, and has compatibility issues. Instead, this port uses **single-threaded
synchronous execution** with [ASYNCIFY](https://emscripten.org/docs/porting/asyncify.html):

- **Video frames** are decoded synchronously on the main thread via `pumpSynchronous()`, which replaces the native
  demuxer/decoder thread pipeline. A frame queue (capped at 6 frames to stay within WASM's 2GB memory limit) feeds the
  renderer.
- **Subtitle rendering** is done inline during video frame processing - each video frame has subtitles blended onto it
  immediately after decoding, rather than on a separate thread.
- **File I/O** uses `EM_ASYNC_JS` to `await fetch()` transparently, so the C code sees synchronous `fopen()`/`fread()`
  while the browser performs async HTTP requests.
- **The main loop** yields to the browser via `emscripten_sleep()`, preventing the tab from freezing while maintaining
  the engine's synchronous `while(true)` event loop.

### Virtual Filesystem and Lazy Asset Loading

Umineko has 101,000+ game files (backgrounds, sprites, audio, video). Loading all of them at startup would require
gigabytes of downloads. Instead:

Startup Flow (local/production mode):

```
  1. Browser fetches manifest.json (list of all files)
                    │
                    ▼
  2. Create directory tree in Emscripten VFS
                    │
          ┌────────┴────────┐
          ▼                 ▼
  3a. Eager files       3b. Lazy files
      (scripts,             (101k+ assets)
       fonts, cfg)          Written as 0-byte stubs
      Fetched via XHR       into VFS
      before engine                 │
      starts                        ▼
                            4. Engine opens file
                                    │
                                    ▼
                            5. EM_ASYNC_JS intercepts
                               fopen(), fetches real
                               data via HTTP
                                    │
                                    ▼
                            6. File contents written
                               to VFS, fopen() returns
```

Startup Flow (remote mode):

```
  1. User selects their Umineko game folder via
     File System Access API (Chrome/Edge) or
     <input webkitdirectory> fallback (Firefox)
                    │
                    ▼
  2. Browser scans the folder to build a manifest
     (directory tree + file list)
                    │
                    ▼
  3. Folder is validated (must contain default.cfg
     and chiru.file)
                    │
                    ▼
  4. Same VFS population as above (eager + lazy stubs)
                    │
                    ▼
  5. Lazy file reads go through window.readLocalFile()
     which reads from the browser's file handle
     instead of fetching from the server
```

In **local/production mode**, the manifest is generated at container startup by walking the game directory. In **remote
mode**, the manifest is built client-side by scanning the user's selected folder.

**Eager files** (scripts, fonts, config) are fetched before `main()` runs via Emscripten's `addRunDependency` mechanism.
**Lazy files** exist as 0-byte stubs - when the engine tries to read one, a patched `FileIO::openFile()` detects the
empty stub and triggers either an async HTTP fetch (local/production) or a local file read via the File System Access
API (remote).

This means the game starts in seconds, downloading only ~2MB of essential files (or reading them from disk in remote
mode), with assets streaming in as gameplay progresses.

### Video Playback Pipeline

Video cutscenes are decoded entirely in WASM using FFmpeg 3.3.9 (cross-compiled with only the needed decoders enabled):

```
┌──────────┐    ┌───────────┐    ┌──────────────┐    ┌─────────┐
│  .mp4    │───►│  FFmpeg   │───►│ Video frame  │───►│  libass │
│  file    │    │  demuxer  │    │  decoder     │    │  blend  │
│ (HTTP)   │    │           │    │  (H.264)     │    │  subs   │
└──────────┘    └───────────┘    └──────────────┘    └────┬────┘
                                                          │
                                                          ▼
                              ┌─────────────┐    ┌────────────────┐
                              │   WebGL     │◄───│  SDL2_gpu      │
                              │   canvas    │    │  texture upload │
                              └─────────────┘    └────────────────┘
```

On native platforms, the demuxer, decoder, and renderer run on separate threads communicating via semaphore-gated
queues. On Emscripten, `pumpSynchronous()` runs the entire pipeline in a single function call:

1. Read packets from the container via `av_read_frame()`
2. Route video packets to the H.264 decoder
3. Convert decoded frames from YUV to RGB via `sws_scale()`
4. Blend .ass subtitles onto the frame via libass
5. Push the finished frame into a bounded queue (max 6 frames)
6. The renderer pulls frames and uploads them as GPU textures

Alpha-masked videos (.m2v) use a special compositing path where the bottom half of each frame is an alpha mask, blended
onto the game scene in real time.

### Subtitle Rendering

Cutscene songs display timed .ass subtitles (e.g., Italian lyrics + English translation). This requires a full text
shaping and rendering stack compiled to WASM:

| Library      | Version           | Purpose                                   |
|--------------|-------------------|-------------------------------------------|
| **libass**   | 0.14.0            | SSA/ASS subtitle parser and renderer      |
| **HarfBuzz** | 2.5.2             | Complex text shaping (ligatures, kerning) |
| **FriBidi**  | 1.0.5             | Unicode bidirectional text algorithm      |
| **FreeType** | (Emscripten port) | Font rasterisation                        |

Building HarfBuzz 2.5.2 for Emscripten required disabling its internal `#pragma GCC diagnostic error` directives (via
`-DHB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR`) because newer Clang versions introduced warnings that the old pragmas would
promote to hard errors.

The native engine renders subtitles on a background thread. On Emscripten, subtitle frames are blended directly onto
video frames during the synchronous decode pass, before they enter the frame queue.

### Persistent Save System

Game saves and settings are stored in the browser's IndexedDB via Emscripten's IDBFS filesystem driver:

1. At startup, `/home/web_user/.onscripter` is mounted as an IDBFS volume
2. Existing saves are synced from IndexedDB into the virtual filesystem
3. The engine reads/writes save files using normal C `fopen()`/`fwrite()` calls
4. A periodic sync (every 5 seconds) and a `beforeunload` handler flush changes back to IndexedDB

This means save data survives page refreshes, tab closures, and browser restarts.

### Graphics Pipeline

The engine uses SDL2_gpu's GLES2 backend, which maps to WebGL in the browser:

- **Rendering** - all sprites, backgrounds, and UI elements are uploaded as GPU textures and rendered via GLSL shaders
- **Effects** - transitions, fades, and visual effects use the engine's custom GLSL shader pipeline
- **Canvas** - Emscripten's SDL2 port creates a `<canvas>` element and binds a WebGL context to it
- **Frame management** - `preserveDrawingBuffer` is enabled to prevent WebGL from clearing between frames (required for
  the engine's partial-redraw dirty rect system)

### Audio Pipeline

Audio flows through SDL2_mixer → Emscripten's SDL2 audio backend → the Web Audio API:

- **BGM** - OGG/Vorbis background music streamed through SDL2_mixer channels
- **Sound effects** - loaded and played on demand via `dwaveload`/`dwaveplay` commands
- **Voice lines** - character voice audio played synchronously with text display
- **Output** - 48kHz 32-bit float stereo via `ScriptProcessorNode` (Web Audio)

### Asset Optimisation

The game ships with ~12GB of unoptimised assets (5.6GB PNG images, 2.2GB MP4 video, 4.1GB OGG audio). The container
automatically converts assets to modern formats at startup, reducing total served size to ~5GB (~60% reduction):

| Asset type                 | Original   | Format      | Optimised   | Format            | Reduction |
|----------------------------|------------|-------------|-------------|-------------------|-----------|
| Images (9,450 files)       | 5.6 GB     | PNG         | ~2.8 GB     | WebP (q90)        | ~50%      |
| Video (74 files)           | 2.2 GB     | MP4/H.264   | ~0.8 GB     | WebM/VP9 (CRF 30) | ~64%      |
| Audio BGM (218 files >1MB) | 2.0 GB     | OGG 256kbps | ~0.7 GB     | OGG ~128kbps (q4) | ~67%      |
| Voice/SFX (92k files <1MB) | 2.1 GB     | OGG         | 2.1 GB      | unchanged         | 0%        |
| **Total**                  | **~12 GB** |             | **~6.4 GB** |                   | **~47%**  |

```
Container startup:
  1. entrypoint.sh generates manifest.json
  2. convert-assets.sh launches in background
  3. nginx starts serving immediately (game is playable right away)

Background conversion (convert-assets.sh):
  PNG → WebP (cwebp, quality 90, 8 parallel workers)
  MP4 → WebM/VP9 (ffmpeg, CRF 30, Opus audio 128k, 4 parallel workers)
  OGG → OGG (re-encoded at ~128kbps for files >1MB, skipped if larger than original)
  Results cached in /cache/game/ (Docker named volume)

Serving (content negotiation via .hau):
  Client rewrites .png/.mp4 → .hau in the fetch URL
  nginx try_files resolves .hau → .webp/.webm (cached) or .png/.mp4 (original)
  Single request per asset, no 404 fallback needed
  Engine always sees original filenames in the VFS
```

Converted files are stored in a Docker named volume (`asset-cache`), so conversion only runs once. The original game
files on disk are never modified (mounted read-only).

Large OGG/Vorbis audio files (>1MB, mainly BGM tracks encoded at 256kbps) are re-encoded at a lower bitrate (~128kbps,
Vorbis quality 4) to reduce transfer sizes while keeping the same OGG format for SDL2_mixer compatibility. If
re-encoding produces a larger file than the original, the file is skipped. Small files like voice lines and sound
effects are left untouched.

### Classic Art Swap

Press **G** during gameplay to toggle between the PS3 redrawn character sprites and Ryukishi07's original classic art
from the PC release. The toggle persists across page reloads via `localStorage`.

**How it works:**

The game script (`en.txt`) and coordinate file (`chiru.file`) are user-supplied and read-only. The swap is implemented
entirely at the engine and web layer without modifying any game files.

```
Press G
  -> window.classicMode = true
  -> classicModeToggle() clears the engine's image cache
     and resets all sprite VFS files to 0-byte stubs
  -> next sprite load triggers a fresh fetch

Engine requests: /game/sprites/but/1/but_b11_defo1.png
  -> FileIO.cpp checks window.classicMode
  -> HEAD request to /classic/sprites/but/1/but_b11_defo1.png
  -> exists, so fetch redirects there
  -> nginx serves the pre-processed classic sprite
  -> engine renders Ryukishi07 art at the correct position
```

Classic sprites are pre-processed to match the exact pixel dimensions of their PS3 counterparts. This ensures the
existing hotspot coordinates in `chiru.file` position the characters correctly without any coordinate modifications.

Lip-sync overlays (`sprites/{char}/2/`) are disabled in classic mode because the original art has no separate lip
layers. The engine's `fileexist` check handles this gracefully.

**Expression mapping:**

The PS3 and classic sprites use different naming conventions. PS3 sprites have outfit prefixes
(e.g., `but_b11_defo1.png` - Battler, outfit b11, default expression 1). Classic sprites have no outfit codes but
append a variant letter (e.g., `but_defa1.png` - default expression, variant a, number 1).

The mapping algorithm:

1. Strip the outfit prefix: `b11_defo1` -> `defo1`
2. Split into base expression and number: `defo` + `1`
3. Special case: `defo` -> `def`
4. Insert `a` before the number: `defa1`
5. Look up the classic file; if not found, fall back to PS3 sprite

All PS3 outfit variants (a11, b11, b22, d11, etc.) for the same expression map to the same classic sprite since the
original art has only one outfit per character.

**Sprite pre-processing (`tools/setup-classic-sprites.sh`):**

Classic sprites from `arc~.nsa` (~830x960, with transparent padding) need to be resized to match PS3 sprite
dimensions (~756x1219, tightly cropped). The setup script runs ImageMagick on each mapped sprite:

```bash
magick "$classic_file" \
    -trim +repage \                    # remove transparent padding
    -resize "${ps3_w}x${ps3_h}" \      # scale to fit within PS3 dimensions
    -background none \                 # transparent padding
    -gravity south \                   # anchor character at bottom
    -extent "${ps3_w}x${ps3_h}" \      # pad to exact PS3 canvas size
    "$output_file"
```

This produces a sprite with the classic art scaled to fill as much of the PS3 canvas as possible, anchored at the
bottom (where feet meet the ground), with transparent padding above. The result has identical dimensions to the PS3
sprite, so the engine's hotspot math works without modification.

**Coverage:** 2,756 of 2,946 PS3 sprite expressions mapped (96.7%). 3 PS3-only characters (`cla`, `ka2`, `s55`)
and 50 PS3-exclusive expressions (e.g., `ero`, `hohoemi`) fall back to PS3 sprites.

**Setup:** Run `setup/setup.sh` and select "Yes" when asked about classic art files. Point it to your extracted
`arc~.nsa` archives directory. Requires ImageMagick. The script processes all sprites automatically.

## Native Library Build Chain

The Dockerfile builds 7 native libraries from source for Emscripten, plus uses 10 Emscripten ports:

```
Cross-compiled from source          Emscripten ports (pre-built)
─────────────────────────            ─────────────────────────────
SDL2_gpu ──────────────────────────► SDL2
FFmpeg 3.3.9 ──────────────────────► SDL2_image (PNG, JPG, WebP)
libwebp 1.6.0 ────────────────────► SDL2_mixer
FriBidi 1.0.5 ─────┐               FreeType
HarfBuzz 2.5.2 ────┤               zlib, libpng, libjpeg
libass 0.14.0 ◄────┘               libogg, libvorbis
                                    bzip2
```

All dependencies are sourced from [umineko-project/onscripter-deps](https://github.com/umineko-project/onscripter-deps)
for reproducibility.

## Engine Modifications

The [forked ONScripter-RU engine](https://github.com/VictoriqueMoe/onscripter-ru-wasm) includes Emscripten-specific
changes across 18 source files, all gated behind `#ifdef __EMSCRIPTEN__`:

| File                            | Change                                                                                                                                                                                                                                                                                       |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Support/FileIO.cpp`            | Async HTTP fetch via `EM_ASYNC_JS` with .hau content negotiation for optimised assets. Classic art swap: redirects sprite fetches to `/classic/sprites/` when `window.classicMode` is true, blocks lip overlay fetches in classic mode, exports `classicModeToggle()` for cache invalidation |
| `Engine/Core/ONScripter.hpp`    | Public `clearImageCache()` method for classic mode toggle                                                                                                                                                                                                                                    |
| `Engine/Media/Controller.cpp`   | `pumpSynchronous()` - single-threaded video decode replacing threaded pipeline                                                                                                                                                                                                               |
| `Engine/Media/Controller.cpp`   | Subtitle blending in synchronous decode path                                                                                                                                                                                                                                                 |
| `Engine/Media/VideoDecoder.cpp` | Adjusted colour space conversion for browser rendering                                                                                                                                                                                                                                       |
| `Engine/Layers/Subtitle.cpp`    | Synchronous subtitle decoding on main thread                                                                                                                                                                                                                                                 |
| `Engine/Layers/Media.cpp`       | Synchronous media layer frame pumping                                                                                                                                                                                                                                                        |
| `Engine/Components/Async.cpp`   | Thread creation skipped (single-threaded)                                                                                                                                                                                                                                                    |
| `Engine/Core/Event.cpp`         | Periodic IDBFS sync for save persistence                                                                                                                                                                                                                                                     |
| `Engine/Core/Image.cpp`         | Frame queue management adjustments                                                                                                                                                                                                                                                           |
| `Engine/Core/ONScripter.cpp`    | Startup path adjustments for browser environment                                                                                                                                                                                                                                             |
| `Engine/Graphics/GPU.cpp`       | WebGL-compatible GPU initialisation                                                                                                                                                                                                                                                          |
| `Engine/Graphics/GLES2.cpp`     | GLES2 shader compatibility                                                                                                                                                                                                                                                                   |
