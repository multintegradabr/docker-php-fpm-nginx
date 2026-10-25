#define _GNU_SOURCE
#include <avif/avif.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

/* Sparse mappings cross the 32-bit arithmetic boundary without allocating
 * gigabytes of physical RAM. Every address the old arithmetic could compute
 * remains mapped, so an incorrect conversion fails by comparison, not a crash.
 * Linux 64-bit build-time regression only; never linked into the final image. */
static const uint32_t stride = UINT32_MAX - 15;
static uint8_t * sparse(size_t length)
{
    void * p = mmap(NULL, length, PROT_READ | PROT_WRITE,
                    MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
    if (p == MAP_FAILED) {
        perror("mmap");
        exit(2);
    }
    return p;
}

static int check(unsigned depth, avifRGBFormat format, int sparseInput)
{
    const unsigned width = 2, height = 3;
    const unsigned bytes = depth > 8 ? 2 : 1;
    const unsigned channels = format == AVIF_RGB_FORMAT_RGBA ? 4 : 3;
    const unsigned row = width * channels * bytes;
    uint8_t pixels[3 * 2 * 4 * 2] = { 0 };
    for (unsigned y = 0; y < height; ++y) {
        for (unsigned x = 0; x < width; ++x) {
            for (unsigned c = 0; c < channels; ++c) {
                unsigned value = (c == y || c == 3) ? (1u << depth) - 1 : 0;
                size_t offset = y * row + (x * channels + c) * bytes;
                if (bytes == 2) {
                    uint16_t sample = value;
                    memcpy(pixels + offset, &sample, 2);
                } else {
                    pixels[offset] = value;
                }
            }
        }
    }
    avifImage * reference = avifImageCreate(width, height, depth, AVIF_PIXEL_FORMAT_YUV444);
    avifImage * actual = avifImageCreate(width, height, depth, AVIF_PIXEL_FORMAT_YUV444);
    if (!reference || !actual) exit(2);
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, reference);
    rgb.format = format;
    rgb.avoidLibYUV = AVIF_TRUE;
    rgb.pixels = pixels;
    rgb.rowBytes = row;
    if (avifImageRGBToYUV(reference, &rgb) != AVIF_RESULT_OK) exit(2);

    const size_t length = (size_t)stride * (height - 1) + row;
    uint8_t * mappings[3] = { NULL, NULL, NULL };
    if (sparseInput) {
        mappings[0] = sparse(length);
        for (unsigned y = 0; y < height; ++y)
            memcpy(mappings[0] + (size_t)y * stride, pixels + y * row, row);
        rgb.pixels = mappings[0];
        rgb.rowBytes = stride;
    } else {
        for (unsigned c = 0; c < 3; ++c) {
            mappings[c] = sparse(length);
            actual->yuvPlanes[c] = mappings[c];
            actual->yuvRowBytes[c] = stride;
        }
    }
    int failed = avifImageRGBToYUV(actual, &rgb) != AVIF_RESULT_OK;
    for (unsigned c = 0; c < 3; ++c) {
        for (unsigned y = 0; y < height; ++y) {
            if (memcmp(reference->yuvPlanes[c] + (size_t)y * reference->yuvRowBytes[c],
                       actual->yuvPlanes[c] + (size_t)y * actual->yuvRowBytes[c], width * bytes))
                failed = 1;
        }
    }
    /* AllocatePlanes marks supplied planes as owned; they are mmap mappings. */
    if (!sparseInput) actual->imageOwnsYUVPlanes = AVIF_FALSE;
    avifImageDestroy(actual);
    avifImageDestroy(reference);
    for (unsigned c = 0; c < 3; ++c)
        if (mappings[c]) munmap(mappings[c], length);
    printf("%s: %s strides, depth %u, %s\n", failed ? "FAIL" : "PASS",
           sparseInput ? "RGB input" : "Y/U/V output", depth,
           format == AVIF_RGB_FORMAT_RGBA ? "RGBA" : "RGB");
    return failed;
}

int main(void)
{
    if (sizeof(size_t) < 8) {
        fputs("Row-stride regression requires a 64-bit Linux builder\n", stderr);
        return 2;
    }
    int failed = 0;
    for (unsigned depth = 8; depth <= 12; depth += 4) {
        for (int input = 0; input <= 1; ++input) {
            failed |= check(depth, AVIF_RGB_FORMAT_RGB, input);
            failed |= check(depth, AVIF_RGB_FORMAT_RGBA, input);
        }
    }
    return failed;
}
