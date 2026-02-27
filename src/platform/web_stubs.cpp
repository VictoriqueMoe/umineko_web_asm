/**
 *  web_stubs.cpp
 *  Umineko Web
 *
 *  Stubs for libraries not available in Emscripten.
 */

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
