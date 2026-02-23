/**
 *  web_stubs.cpp
 *  Umineko Web
 *
 *  Stubs for libraries not yet ported to Emscripten.
 */

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

extern "C" {

#include <stddef.h>
#include <stdarg.h>
#include <stdint.h>

struct ass_library {};
struct ass_renderer {};
struct ass_track {};

typedef struct ass_image {
    int w, h;
    int stride;
    unsigned char *bitmap;
    uint32_t color;
    int dst_x, dst_y;
    struct ass_image *next;
    int type;
} ASS_Image;

typedef struct ass_library ASS_Library;
typedef struct ass_renderer ASS_Renderer;
typedef struct ass_track ASS_Track;

ASS_Library *ass_library_init(void) {
    return NULL;
}

void ass_library_done(ASS_Library *) {}

void ass_set_message_cb(ASS_Library *, void (*)(int, const char *, va_list, void *), void *) {}

void ass_set_fonts_dir(ASS_Library *, const char *) {}

ASS_Renderer *ass_renderer_init(ASS_Library *) {
    return NULL;
}

void ass_renderer_done(ASS_Renderer *) {}

void ass_set_frame_size(ASS_Renderer *, int, int) {}

void ass_set_fonts(ASS_Renderer *, const char *, const char *, int, const char *, int) {}

ASS_Track *ass_read_memory(ASS_Library *, char *, size_t, const char *) {
    return NULL;
}

void ass_free_track(ASS_Track *) {}

void ass_process_data(ASS_Track *, char *, int) {}

ASS_Image *ass_render_frame(ASS_Renderer *, ASS_Track *, long long, int *) {
    return NULL;
}

} // extern "C"

#include <exception>
#include <cstdio>

extern int __real_main(int argc, char **argv);

extern "C" int __wrap_main(int argc, char **argv) {
    try {
        return __real_main(argc, argv);
    } catch (const std::exception &e) {
        fprintf(stderr, "EXCEPTION: %s\n", e.what());
        return 1;
    } catch (int i) {
        fprintf(stderr, "EXCEPTION (int): %d\n", i);
        return 1;
    } catch (...) {
        fprintf(stderr, "EXCEPTION (unknown type)\n");
        return 1;
    }
}
