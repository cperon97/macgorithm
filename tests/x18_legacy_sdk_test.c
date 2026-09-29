// Test: when the binary is marked with SDK < 13.0, the macOS kernel preserves x18 across syscalls and signals.
// Build: clang -O1 -ffixed-x18 -o t x18_legacy_sdk_test.c -Wl,-platform_version,macos,11.0,12.3   (expected: bad=0)
// Without -Wl,-platform_version (current SDK): bad=3000

#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
static inline uint64_t rd(void){ uint64_t v; __asm__ volatile("mov %0, x18":"=r"(v)); return v; }
static void h(int s){ }
int main(){ signal(SIGALRM,h); long bad=0;
 for(uint64_t i=0xFEEDB0B000000000ULL;i<0xFEEDB0B000000000ULL+3000;i++){ __asm__ volatile("mov x18, %0"::"r"(i)); usleep(10); if(i%500==0) raise(SIGALRM); if(rd()!=i) bad++; }
 fprintf(stderr,"legacy bad=%ld\n",bad); }
