// Compile the actual stream implementation; avoid unsafe writes in the negative test.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "src/stream.c"

static unsigned allocation_calls;
avifResult avifRWDataRealloc(avifRWData *raw, size_t size)
{
    (void)raw;
    (void)size;
    allocation_calls++;
    return AVIF_RESULT_OK;
}

int main(void)
{
    uint8_t bytes[16] = {0};
    avifRWData raw = {bytes, sizeof bytes};
    avifRWStream stream;
    avifRWStreamStart(&stream, &raw);
    if (avifRWStreamWrite(&stream, "ok", 2) != AVIF_RESULT_OK || memcmp(bytes, "ok", 2)) {
        fputs("normal stream write failed\n", stderr);
        return 2;
    }
    stream.offset = SIZE_MAX - 1;
    allocation_calls = 0;
    avifResult result = makeRoom(&stream, 4);
    if (result != AVIF_RESULT_OUT_OF_MEMORY || allocation_calls != 0) {
        fprintf(stderr, "overflow accepted (result=%d, allocation calls=%u)\n", result, allocation_calls);
        return 1;
    }
    puts("normal write preserved; size_t overflow rejected before allocation");
    return 0;
}
