FROM emscripten/emsdk:5.0.2

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
    curl -sL https://raw.githubusercontent.com/umineko-project/onscripter-deps/master/archives/ffmpeg-3.3.9.tar.bz2 | tar xj && \
    cd ffmpeg-3.3.9 && \
    emconfigure ./configure \
        --cc=emcc --cxx=em++ --ar=emar --ranlib=emranlib \
        --prefix=/build/umineko-web/deps/ffmpeg-install \
        --enable-cross-compile --target-os=none --arch=x86 \
        --disable-yasm --disable-inline-asm \
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

RUN echo '#include <ft2build.h>' | emcc -sUSE_FREETYPE=1 -x c - -c -o /dev/null && \
    cd deps && \
    curl -sL https://raw.githubusercontent.com/umineko-project/onscripter-deps/master/archives/fribidi-1.0.5.tar.bz2 | tar xj && \
    cd fribidi-1.0.5 && \
    emconfigure ./configure \
        --prefix=/build/umineko-web/deps/fribidi-install \
        --disable-shared --disable-debug --with-glib=no && \
    emmake make -j$(nproc) && \
    emmake make install

RUN cd deps && \
    curl -sL https://raw.githubusercontent.com/umineko-project/onscripter-deps/master/archives/harfbuzz-2.5.2.tar.xz | tar xJ && \
    cd harfbuzz-2.5.2 && \
    FREETYPE_CFLAGS="-I$(em-config CACHE)/sysroot/include/freetype2" \
    FREETYPE_LIBS="-sUSE_FREETYPE=1" \
    CXXFLAGS="-DHB_NO_MT -DHB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR -O2" \
    CFLAGS="-O2" \
    emconfigure ./configure \
        --prefix=/build/umineko-web/deps/harfbuzz-install \
        --disable-dependency-tracking --disable-shared \
        --with-glib=no --with-cairo=no --with-gobject=no --with-icu=no && \
    emmake make -j$(nproc) CXXFLAGS="-DHB_NO_MT -DHB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR -O2 -Wno-error=cast-function-type-strict -Wno-error=unused-but-set-variable" && \
    emmake make install

RUN cd deps && \
    curl -sL https://raw.githubusercontent.com/umineko-project/onscripter-deps/master/archives/libass-0.14.0.tar.xz | tar xJ && \
    cd libass-0.14.0 && \
    sed -i 's/\$as_echo "#define CONFIG_ICONV 1" >>confdefs.h/\$as_echo "Ignoring iconv"/' configure && \
    FREETYPE_CFLAGS="-I$(em-config CACHE)/sysroot/include/freetype2" \
    FREETYPE_LIBS="-sUSE_FREETYPE=1" \
    FRIBIDI_CFLAGS="-I/build/umineko-web/deps/fribidi-install/include/fribidi" \
    FRIBIDI_LIBS="-L/build/umineko-web/deps/fribidi-install/lib -lfribidi" \
    HARFBUZZ_CFLAGS="-I/build/umineko-web/deps/harfbuzz-install/include/harfbuzz" \
    HARFBUZZ_LIBS="-L/build/umineko-web/deps/harfbuzz-install/lib -lharfbuzz" \
    CFLAGS="-I/build/umineko-web/deps/fribidi-install/include/fribidi -O2" \
    emconfigure ./configure \
        --prefix=/build/umineko-web/deps/libass-install \
        --disable-shared --disable-fontconfig \
        --disable-dependency-tracking \
        --disable-require-system-font-provider && \
    emmake make -j$(nproc) && \
    emmake make install

RUN cd deps && \
    curl -sL https://github.com/webmproject/libwebp/archive/refs/tags/v1.6.0.tar.gz | tar xz && \
    cd libwebp-1.6.0 && \
    mkdir build-wasm && cd build-wasm && \
    emcmake cmake .. \
        -DCMAKE_INSTALL_PREFIX=/build/umineko-web/deps/libwebp-install \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DWEBP_BUILD_CWEBP=OFF \
        -DWEBP_BUILD_DWEBP=OFF \
        -DWEBP_BUILD_GIF2WEBP=OFF \
        -DWEBP_BUILD_IMG2WEBP=OFF \
        -DWEBP_BUILD_VWEBP=OFF \
        -DWEBP_BUILD_WEBPINFO=OFF \
        -DWEBP_BUILD_WEBPMUX=OFF \
        -DWEBP_BUILD_EXTRAS=OFF \
        -DWEBP_BUILD_ANIM_UTILS=OFF && \
    emmake make -j$(nproc) && \
    emmake make install && \
    cp -r /build/umineko-web/deps/libwebp-install/include/webp $(em-config CACHE)/sysroot/include/ && \
    cp /build/umineko-web/deps/libwebp-install/lib/*.a $(em-config CACHE)/sysroot/lib/wasm32-emscripten/

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
RUN apk add --no-cache ffmpeg libwebp-tools
COPY --from=0 /build/umineko-web/build/umineko-web.html /usr/share/nginx/html/index.html
COPY --from=0 /build/umineko-web/build/umineko-web.js /usr/share/nginx/html/umineko-web.js
COPY --from=0 /build/umineko-web/build/umineko-web.wasm /usr/share/nginx/html/umineko-web.wasm
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY scripts/generate-manifest.sh /usr/local/bin/generate-manifest.sh
COPY scripts/convert-assets.sh /usr/local/bin/convert-assets.sh
COPY scripts/convert-one-image.sh /usr/local/bin/convert-one-image.sh
COPY scripts/convert-one-video.sh /usr/local/bin/convert-one-video.sh
COPY scripts/convert-one-audio.sh /usr/local/bin/convert-one-audio.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/generate-manifest.sh /usr/local/bin/convert-assets.sh \
    /usr/local/bin/convert-one-image.sh /usr/local/bin/convert-one-video.sh /usr/local/bin/convert-one-audio.sh \
    && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/generate-manifest.sh /usr/local/bin/convert-assets.sh \
    /usr/local/bin/convert-one-image.sh /usr/local/bin/convert-one-video.sh /usr/local/bin/convert-one-audio.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
