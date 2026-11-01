// memhog — alloca N MB e li riempie con dati controllabili, poi aspetta.
// Ogni pagina da 4 KiB: 2 KiB pseudo-casuali (incomprimibili) + 2 KiB ripetuti
// (comprimibili), così zram comprime circa 2:1, come dati "reali" e non come zeri.
// Con SIGUSR1 rilegge tutta la memoria e controlla che sia intatta.
// Uscita (stdout): "ok: N MB" a riempimento finito, "verify ok: N MB in T ms" o "verify FAIL ...".
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define PAGE 4096
#define HALF (PAGE / 2)

static volatile sig_atomic_t want_verify = 0;
static void on_usr1(int s) { (void)s; want_verify = 1; }

static uint64_t next(uint64_t *x) {  // xorshift64
  *x ^= *x << 13; *x ^= *x >> 7; *x ^= *x << 17; return *x;
}

static void fill_page(unsigned char *p, size_t i) {
  uint64_t x = 0x9E3779B97F4A7C15ULL ^ (i + 1);
  for (size_t k = 0; k < HALF; k += 8) {
    uint64_t v = next(&x);
    for (int b = 0; b < 8; b++) p[k + b] = (unsigned char)(v >> (8 * b));
  }
  for (size_t k = HALF; k < PAGE; k++) p[k] = (unsigned char)i;
}

static long ms_since(struct timespec t0) {
  struct timespec t1; clock_gettime(CLOCK_MONOTONIC, &t1);
  return (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000;
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "uso: memhog MB\n"); return 2; }
  setvbuf(stdout, NULL, _IOLBF, 0);
  size_t mb = strtoul(argv[1], NULL, 10), pages = mb * 256;
  unsigned char *buf = malloc(pages * PAGE);
  if (!buf) { printf("ERRORE malloc %zu MB\n", mb); return 1; }
  signal(SIGUSR1, on_usr1);

  for (size_t i = 0; i < pages; i++) fill_page(buf + i * PAGE, i);
  printf("ok: %zu MB\n", mb);

  unsigned char ref[PAGE];
  for (;;) {
    while (!want_verify) pause();
    want_verify = 0;
    struct timespec t0; clock_gettime(CLOCK_MONOTONIC, &t0);
    size_t bad = pages;
    for (size_t i = 0; i < pages && bad == pages; i++) {
      fill_page(ref, i);
      for (size_t k = 0; k < PAGE; k++)
        if (buf[i * PAGE + k] != ref[k]) { bad = i; break; }
    }
    if (bad == pages) printf("verify ok: %zu MB in %ld ms\n", mb, ms_since(t0));
    else printf("verify FAIL alla pagina %zu\n", bad);
  }
}
