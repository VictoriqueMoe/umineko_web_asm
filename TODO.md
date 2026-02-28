# TODO

## Asset Loading
- [x] Lazy-load backgrounds, sprites, sound, and video over HTTP on demand instead of preloading everything
- [x] Load archive files (arc.nsa, etc.) — manifest.json + 0-byte stubs + EM_ASYNC_JS fetch on first read
- [ ] Add loading/progress indicator when assets are being fetched during gameplay

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
- [ ] Consider touch input support for mobile browsers

## Asset Optimisation
- [ ] Auto-convert videos to WebM (VP9) during Docker build to drastically reduce file sizes (op4.mp4 is 157MB)
- [ ] Convert images to WebP for smaller textures/backgrounds/sprites
- [ ] Convert BGM and audio to Opus for smaller and better quality audio at lower bitrates
- [ ] Build a pre-processing pipeline (script or Dockerfile stage) that handles all conversions automatically

## Performance
- [ ] Profile WASM execution and rendering performance
- [ ] Consider building with -O3 or -Oz for smaller/faster output
- [ ] Remove `-g` debug flag once stable (currently enabled for stack traces)
- [ ] Investigate SharedArrayBuffer + pthreads for multithreading (requires COOP/COEP headers from caddy)

## Docker / Build
- [ ] Pin the onscripter-ru commit hash in the Dockerfile so builds are reproducible
- [ ] Add a favicon
