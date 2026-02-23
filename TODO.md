# TODO

## Asset Loading
- [ ] Lazy-load backgrounds, sprites, sound, and video over HTTP on demand instead of preloading everything
- [ ] Load archive files (arc.nsa, etc.) — either fetch whole archives or intercept file reads and fetch individual assets
- [ ] Add loading/progress indicator when assets are being fetched during gameplay

## Save System
- [ ] Integrate Emscripten IDBFS for persistent save file storage in the browser
- [ ] Sync saves to IndexedDB so progress survives page reloads

## Subtitle Rendering
- [ ] Build libass (+ harfbuzz, fribidi) with Emscripten and replace the current stubs in web_stubs.cpp
- [ ] Only affects video cutscene subtitles, not core gameplay

## Video Playback
- [ ] Test FFmpeg-based video decoding in browser (linked but untested)
- [ ] May need to fall back to browser-native video APIs if performance is too poor

## Audio
- [ ] Test OGG/Vorbis audio playback through SDL2 audio in the browser
- [ ] Verify BGM, sound effects, and voice lines all work

## Input
- [ ] Test keyboard and mouse input through SDL2 events
- [ ] Consider touch input support for mobile browsers

## Performance
- [ ] Profile WASM execution and rendering performance
- [ ] Consider building with -O3 or -Oz for smaller/faster output
- [ ] Investigate SharedArrayBuffer + pthreads for multithreading (requires COOP/COEP headers from caddy)

## Docker / Build
- [ ] Pin the onscripter-ru commit hash in the Dockerfile so builds are reproducible
- [ ] Add a favicon
