/* Test-only pngmem.c malloc/free wrappers. No callbacks into Odin. */
#include <stddef.h>
#include <stdlib.h>
#include <assert.h>
typedef union { max_align_t align; size_t n; } Header;
static size_t requests, refusal, live_blocks, live_bytes;
void atlas_test_reset(size_t fail_at) {
    assert(live_blocks == 0 && live_bytes == 0);
    requests = 0; refusal = fail_at;
}
size_t atlas_test_calls(void) { return requests; }
size_t atlas_test_blocks(void) { return live_blocks; }
size_t atlas_test_bytes(void) { return live_bytes; }
void *atlas_test_malloc(size_t n) {
    ++requests;
    if (refusal && requests == refusal) return NULL;
    if (n > (size_t)-1 - sizeof(Header)) return NULL;
    Header *p = malloc(sizeof *p + n);
    if (!p) return NULL;
    p->n = n; ++live_blocks; live_bytes += n;
    return p + 1;
}
void atlas_test_free(void *v) {
    if (!v) return;
    Header *p = (Header*)v - 1;
    assert(live_blocks && live_bytes >= p->n);
    --live_blocks; live_bytes -= p->n; free(p);
}
