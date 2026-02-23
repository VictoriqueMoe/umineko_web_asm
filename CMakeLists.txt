cmake_minimum_required(VERSION 3.16)
project(umineko-web LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_C_STANDARD 11)

set(ONS_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../onscripter-ru")
set(SDL_GPU_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/sdl-gpu")
set(FFMPEG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/ffmpeg-install")

set(ENGINE_SOURCES
    ${ONS_SRC_DIR}/Engine/Components/Async.cpp
    ${ONS_SRC_DIR}/Engine/Components/Dialogue.cpp
    ${ONS_SRC_DIR}/Engine/Components/DynamicProperty.cpp
    ${ONS_SRC_DIR}/Engine/Components/Fonts.cpp
    ${ONS_SRC_DIR}/Engine/Components/GlyphAtlas.cpp
    ${ONS_SRC_DIR}/Engine/Components/Joystick.cpp
    ${ONS_SRC_DIR}/Engine/Components/TextWindow.cpp
    ${ONS_SRC_DIR}/Engine/Components/Window.cpp
    ${ONS_SRC_DIR}/Engine/Core/Animation.cpp
    ${ONS_SRC_DIR}/Engine/Core/Command.cpp
    ${ONS_SRC_DIR}/Engine/Core/CommandExt.cpp
    ${ONS_SRC_DIR}/Engine/Core/Effect.cpp
    ${ONS_SRC_DIR}/Engine/Core/EffectBreakup.cpp
    ${ONS_SRC_DIR}/Engine/Core/EffectTrig.cpp
    ${ONS_SRC_DIR}/Engine/Core/Event.cpp
    ${ONS_SRC_DIR}/Engine/Core/File.cpp
    ${ONS_SRC_DIR}/Engine/Core/Image.cpp
    ${ONS_SRC_DIR}/Engine/Core/Lips.cpp
    ${ONS_SRC_DIR}/Engine/Core/Loader.cpp
    ${ONS_SRC_DIR}/Engine/Core/ONScripter.cpp
    ${ONS_SRC_DIR}/Engine/Core/Parser.cpp
    ${ONS_SRC_DIR}/Engine/Core/ParserCommand.cpp
    ${ONS_SRC_DIR}/Engine/Core/Sound.cpp
    ${ONS_SRC_DIR}/Engine/Core/Text.cpp
    ${ONS_SRC_DIR}/Engine/Entities/Animation.cpp
    ${ONS_SRC_DIR}/Engine/Entities/ConstantRefresh.cpp
    ${ONS_SRC_DIR}/Engine/Entities/Font.cpp
    ${ONS_SRC_DIR}/Engine/Entities/Glyph.cpp
    ${ONS_SRC_DIR}/Engine/Entities/StringTree.cpp
    ${ONS_SRC_DIR}/Engine/Graphics/Common.cpp
    ${ONS_SRC_DIR}/Engine/Graphics/GLES2.cpp
    ${ONS_SRC_DIR}/Engine/Graphics/GPU.cpp
    ${ONS_SRC_DIR}/Engine/Graphics/PNG.cpp
    ${ONS_SRC_DIR}/Engine/Graphics/Pool.cpp
    ${ONS_SRC_DIR}/Engine/Handlers/LUA.cpp
    ${ONS_SRC_DIR}/Engine/Handlers/Script.cpp
    ${ONS_SRC_DIR}/Engine/Layers/Furu.cpp
    ${ONS_SRC_DIR}/Engine/Layers/Layer.cpp
    ${ONS_SRC_DIR}/Engine/Layers/Media.cpp
    ${ONS_SRC_DIR}/Engine/Layers/ObjectFall.cpp
    ${ONS_SRC_DIR}/Engine/Layers/Subtitle.cpp
    ${ONS_SRC_DIR}/Engine/Media/AudioDecoder.cpp
    ${ONS_SRC_DIR}/Engine/Media/Controller.cpp
    ${ONS_SRC_DIR}/Engine/Media/Demux.cpp
    ${ONS_SRC_DIR}/Engine/Media/HardwareDecoder.cpp
    ${ONS_SRC_DIR}/Engine/Media/SubtitleDecoder.cpp
    ${ONS_SRC_DIR}/Engine/Media/SubtitleDriver.cpp
    ${ONS_SRC_DIR}/Engine/Media/VideoDecoder.cpp
    ${ONS_SRC_DIR}/Engine/Readers/Direct.cpp
    ${ONS_SRC_DIR}/Engine/Readers/Nsa.cpp
    ${ONS_SRC_DIR}/Engine/Readers/Sar.cpp
    ${ONS_SRC_DIR}/Support/AudioBridge.cpp
    ${ONS_SRC_DIR}/Support/Cache.cpp
    ${ONS_SRC_DIR}/Support/DirPaths.cpp
    ${ONS_SRC_DIR}/Support/DirtyRect.cpp
    ${ONS_SRC_DIR}/Support/FileIO.cpp
    ${ONS_SRC_DIR}/Support/Unicode.cpp
    ${ONS_SRC_DIR}/External/slre.c
)

set(PLATFORM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/web_stubs.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Resources.cpp
)

add_executable(umineko-web
    ${ENGINE_SOURCES}
    ${PLATFORM_SOURCES}
)

target_include_directories(umineko-web PRIVATE
    ${ONS_SRC_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/stubs
    ${SDL_GPU_DIR}/include
    ${FFMPEG_DIR}/include
)

target_compile_definitions(umineko-web PRIVATE
    LINUX
    PUBLIC_RELEASE
)

# Static libraries
set(STATIC_LIBS "")

if(EXISTS "${SDL_GPU_DIR}/build-wasm/SDL_gpu-0.11.0/lib/libSDL2_gpu.a")
    list(APPEND STATIC_LIBS "${SDL_GPU_DIR}/build-wasm/SDL_gpu-0.11.0/lib/libSDL2_gpu.a")
endif()

foreach(fflib avformat avcodec swscale swresample avutil)
    if(EXISTS "${FFMPEG_DIR}/lib/lib${fflib}.a")
        list(APPEND STATIC_LIBS "${FFMPEG_DIR}/lib/lib${fflib}.a")
    endif()
endforeach()

target_link_libraries(umineko-web PRIVATE ${STATIC_LIBS})

# Emscripten-specific settings
if(EMSCRIPTEN)
    set(EM_PORTS
        -sUSE_SDL=2
        -sUSE_SDL_IMAGE=2
        -sSDL2_IMAGE_FORMATS=["png","jpg"]
        -sUSE_SDL_MIXER=2
        -sUSE_FREETYPE=1
        -sUSE_ZLIB=1
        -sUSE_LIBPNG=1
        -sUSE_LIBJPEG=1
        -sUSE_OGG=1
        -sUSE_VORBIS=1
        -sUSE_BZIP2=1
    )

    target_compile_options(umineko-web PRIVATE ${EM_PORTS})
    target_link_options(umineko-web PRIVATE ${EM_PORTS})

    target_link_options(umineko-web PRIVATE
        -sASYNCIFY
        -sASYNCIFY_STACK_SIZE=65536
        -sALLOW_MEMORY_GROWTH
        -sINITIAL_MEMORY=268435456
        -sFORCE_FILESYSTEM
        -lidbfs.js
        -sEXPORTED_FUNCTIONS=["_main","_malloc","_free"]
        -sEXPORTED_RUNTIME_METHODS=["ccall","cwrap","FS"]
        -sABORTING_MALLOC=0
        -sDISABLE_EXCEPTION_CATCHING=0
        -sEXIT_RUNTIME=0
        -sASSERTIONS=1
        -Wl,--wrap=main
        --shell-file=${CMAKE_CURRENT_SOURCE_DIR}/web/index.html
    )

    set_target_properties(umineko-web PROPERTIES SUFFIX ".html")
endif()
