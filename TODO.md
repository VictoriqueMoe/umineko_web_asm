# TODO

## Asset Loading
- [x] Lazy-load backgrounds, sprites, sound, and video over HTTP on demand instead of preloading everything
- [x] Load archive files (arc.nsa, etc.) -- manifest.json + 0-byte stubs + EM_ASYNC_JS fetch on first read
- [x] Add loading/progress indicator when assets are being fetched during gameplay

## Save System
- [x] Integrate Emscripten IDBFS for persistent save file storage in the browser
- [x] Sync saves to IndexedDB so progress survives page reloads (operate_config save, game saves, relaunch)

## Subtitle Rendering
- [x] Build libass (+ harfbuzz, fribidi) with Emscripten and replace the current stubs in web_stubs.cpp
- [x] Synchronous subtitle decoding on main thread for Emscripten (no pthreads)
- [x] .ass subtitle rendering working in browser (tested with op56 opening)

## Video Playback
- [x] FFmpeg-based video decoding works in browser (synchronous frame pumping replaces async threads)
- [x] Frame queue capped at 6 to prevent OOM (1080p RGB24 ~6MB/frame, WASM 2GB limit)
- [x] MPEG-2 overlay videos (.m2v) with alpha masking render correctly
- [x] Fix: `commitVisualState()` before `waitvideo` loop to resolve dirty rect / frame advancement issues

## Audio
- [x] Test OGG/Vorbis audio playback through SDL2 audio in the browser
- [x] Verify BGM, sound effects, and voice lines all work

## Input
- [x] Test keyboard and mouse input through SDL2 events
- [x] Touch input support for mobile browsers (normalized coords, on-screen fullscreen/menu buttons)

## Asset Optimisation
- [x] Auto-convert videos to WebM (VP9) at container startup to reduce file sizes
- [x] Convert images to WebP for smaller textures/backgrounds/sprites
- [x] Build a background conversion pipeline (convert-assets.sh) with caching
- [x] Transparent fetch rewrite in JS layer (.png -> .webp, .mp4 -> .webm) with fallback
- [x] nginx try_files serves optimised assets when available, falls back to originals
- [x] Re-encode large OGG audio (>1MB) at lower bitrate to reduce BGM file sizes

## Performance
- [ ] Profile WASM execution and rendering performance
- [ ] Consider building with -O3 or -Oz for smaller/faster output
- [x] Remove `-g` debug flag and disable assertions
- [x] Upgrade Emscripten from 3.1.51 to 5.0.2
- [ ] Investigate SharedArrayBuffer + pthreads for multithreading (requires COOP/COEP headers)

## Docker / Build
- [x] Interactive setup scripts (setup.sh + setup.ps1) with local/production mode, custom game path, port
- [ ] Pin the onscripter-ru commit hash in the Dockerfile so builds are reproducible
- [ ] Add a favicon
