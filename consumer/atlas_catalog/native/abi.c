#include <png.h>
#include <zlib.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#if !defined(PNG_SIMPLIFIED_READ_SUPPORTED) || !defined(PNG_SETJMP_SUPPORTED)
#error Required libpng features missing
#endif
#if PNG_LIBPNG_VER != 10659 || ZLIB_VERNUM != 0x1400
#error Required accepted codec headers missing
#endif
int main(void) {
    printf("headers libpng=%s zlib=%s\n", PNG_LIBPNG_VER_STRING, ZLIB_VERSION);
    printf("libpng=%s numeric=%lu zlib=%s png_image=%zu offsets=%zu,%zu,%zu\n",
        png_get_libpng_ver(NULL), (unsigned long)png_access_version_number(),
        zlibVersion(), sizeof(png_image), offsetof(png_image, width),
        offsetof(png_image, warning_or_error), offsetof(png_image, message));
    return strcmp(png_get_libpng_ver(NULL), "1.6.59") || png_access_version_number()!=10659 ||
        strcmp(zlibVersion(), "1.4") || sizeof(png_image)!=104 ||
        offsetof(png_image,width)!=12 || offsetof(png_image,warning_or_error)!=32 ||
        offsetof(png_image,message)!=36;
}
