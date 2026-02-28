# Umineko Web

ONScripter-RU compiled to WebAssembly via Emscripten. Runs Umineko no Naku Koro ni in the browser.

## Prerequisites

- Docker and Docker Compose

## Building and Running

```bash
docker compose up --build
```

This will:
1. Clone the [patched ONScripter-RU engine](https://github.com/VictoriqueMoe/onscripter-ru)
2. Build SDL2_gpu, FFmpeg 3.3.9, libass, HarfBuzz, and FriBidi from source with Emscripten
3. Compile the engine to WebAssembly
4. Serve the result with nginx on port 8080

Open `http://localhost:8080` once the container is running.

## Game Assets

The engine expects game files (scripts, images, audio, etc.) to be available at `/usr/share/nginx/html/game/` inside the container. Mount your local game directory as a volume in `docker-compose.yml`:

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

Replace `/path/to/your/umineko/game` with the path to your game directory containing `0.txt`, `nscript.dat`, or whichever script format your version uses, along with the arc/nsa/sar archives.

A `manifest.json` is generated at build time listing all game files. On startup, the browser creates 0-byte stubs for each file and fetches them on demand over HTTP when the engine reads them.

## Project Structure

```
umineko web/
├── CMakeLists.txt          # Emscripten build configuration
├── Dockerfile              # Multi-stage build (emscripten → nginx)
├── docker-compose.yml
├── nginx.conf              # nginx config with CORS and caching headers
├── src/
│   ├── Resources.cpp       # Embedded GLSL shaders (generated)
│   ├── platform/
│   │   └── web_stubs.cpp   # Stub implementations for smpeg2, libusb, etc.
│   └── stubs/
│       └── smpeg2/smpeg.h  # smpeg2 stub header
└── web/
    └── index.html          # HTML shell with canvas, manifest loader, IDBFS setup
```

The actual engine source (~55 C++ files) comes from the [forked ONScripter-RU repo](https://github.com/VictoriqueMoe/onscripter-ru), which is cloned during the Docker build.

## Current Status

What works:
- Full engine compiles to WebAssembly with ASYNCIFY
- SDL2_gpu GLES2 backend rendering via WebGL
- Game script execution, text rendering, image display
- Settings menu (interactive, buttons respond to clicks)
- Lazy asset loading over HTTP (101k+ files loaded on demand via manifest.json)
- Persistent storage via IDBFS (settings and saves stored in browser IndexedDB)
- Keyboard and mouse input via SDL2 events
- Audio playback (BGM, sound effects, voice via SDL2_mixer and Web Audio API)
- Video playback (cutscenes via FFmpeg synchronous decoding in WASM)
- MPEG-2 overlay videos (.m2v) with alpha mask compositing
- .ass subtitle rendering on video cutscenes (libass + HarfBuzz + FriBidi compiled to WASM)

What doesn't work yet:
- Touch input for mobile browsers
