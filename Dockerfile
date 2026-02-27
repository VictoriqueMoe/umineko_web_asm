FROM emscripten/emsdk:3.1.51

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/umineko-web

RUN git clone https://github.com/umineko-project/sdl-gpu.git deps/sdl-gpu && \
    mkdir -p deps/sdl-gpu/build-wasm && \
    cd deps/sdl-gpu/build-wasm && \
    echo '#include <SDL2/SDL.h>' | emcc -sUSE_SDL=2 -x c - -c -o /dev/null && \
    emcmake cmake .. \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DSDL_gpu_DISABLE_OPENGL=ON \
        -DSDL_gpu_DISABLE_GLES=OFF \
        -DSDL_gpu_DISABLE_GLES_1=ON \
        -DSDL_gpu_DISABLE_GLES_3=ON \
        -DSDL_gpu_USE_SYSTEM_EPOXY=OFF \
        -DSDL_gpu_BUILD_DEMOS=OFF \
        -DSDL_gpu_BUILD_TESTS=OFF \
        -DSDL_gpu_BUILD_TOOLS=OFF \
        -DSDL_gpu_BUILD_SHARED=OFF \
        -DSDL_gpu_BUILD_STATIC=ON \
        -DSDL2_INCLUDE_DIR="$(em-config CACHE)/sysroot/include/SDL2" \
        -DSDL2_LIBRARY=SDL2 \
        -DCMAKE_C_FLAGS="-sUSE_SDL=2" \
        -DCMAKE_BUILD_TYPE=Release && \
    emmake make -j$(nproc) && \
    mkdir -p /build/umineko-web/deps/sdl-gpu/include/SDL2 && \
    cd /build/umineko-web/deps/sdl-gpu/include && \
    for f in SDL_gpu*.h; do ln -sf "../$f" "SDL2/$f"; done

RUN cd deps && \
    curl -sL https://ffmpeg.org/releases/ffmpeg-3.3.9.tar.bz2 | tar xj && \
    cd ffmpeg-3.3.9 && \
    emconfigure ./configure \
        --cc=emcc --cxx=em++ --ar=emar --ranlib=emranlib \
        --prefix=/build/umineko-web/deps/ffmpeg-install \
        --enable-cross-compile --target-os=none --arch=x86 \
        --disable-yasm --disable-inline-asm --disable-stripping \
        --disable-programs --disable-doc \
        --disable-network --disable-everything \
        --enable-avcodec --enable-avformat --enable-avutil \
        --enable-swscale --enable-swresample \
        --enable-decoder=h264,vp9,vp8,mpeg2video,aac,opus,vorbis,ass,ssa,mp3,pcm_s16le \
        --enable-demuxer=matroska,mov,mp4,mpegvideo,ogg,ass,ssa,avi,wav,mp3 \
        --enable-parser=h264,vp9,mpegvideo,aac,opus,vorbis,mpegaudio \
        --enable-protocol=file \
        --disable-pthreads --enable-small \
        --extra-cflags="-O2" --extra-ldflags="-O2" && \
    emmake make -j$(nproc) && \
    emmake make install

ARG ONS_CACHE_BUST=0
RUN git clone https://github.com/VictoriqueMoe/onscripter-ru.git /build/onscripter-ru

RUN cc -o /build/embed /build/onscripter-ru/Tools/embed/embed.c && \
    cd /build/onscripter-ru && \
    mkdir -p /build/umineko-web/src && \
    bash -c 'source Scripts/resources.sh && /build/embed "${RESOURCE_LIST[@]}" /build/umineko-web/src/Resources.cpp'

COPY CMakeLists.txt /build/umineko-web/CMakeLists.txt
COPY src/platform /build/umineko-web/src/platform
COPY src/stubs /build/umineko-web/src/stubs
COPY web /build/umineko-web/web

RUN mkdir -p build && cd build && \
    emcmake cmake .. -DCMAKE_BUILD_TYPE=Release && \
    emmake make -j$(nproc)

FROM nginx:alpine
COPY --from=0 /build/umineko-web/build/umineko-web.html /usr/share/nginx/html/index.html
COPY --from=0 /build/umineko-web/build/umineko-web.js /usr/share/nginx/html/umineko-web.js
COPY --from=0 /build/umineko-web/build/umineko-web.wasm /usr/share/nginx/html/umineko-web.wasm
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY scripts/generate-manifest.sh /usr/local/bin/generate-manifest.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/generate-manifest.sh \
    && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/generate-manifest.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
