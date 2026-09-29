// Test: os_set_custom_x18_abi_enabled API (macOS 26.4+). Without the entitlement the mode is lost at the first context switch;
// signed with com.apple.security.custom-x18-abi-toggle (resources/wine.entitlements) it stays enabled.
// Build: clang -O1 -mmacosx-version-min=26.4 -o t x18_toggle_test.c && ./t 1

#include <os/arch/arm64.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
static inline uint64_t rd(void){ uint64_t v; __asm__ volatile("mov %0, x18":"=r"(v)); return v; }
static inline uint64_t tp(void){ uint64_t v; __asm__ volatile("mrs %0, tpidr_el0":"=r"(v)); return v; }
int main(int argc,char**argv){
  int touch=argv[1][0]-'0';
  char *p = mmap(0, 1<<26, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
  os_set_custom_x18_abi_enabled(true);
  __asm__ volatile("mov x18, %0"::"r"(0x1122334455667788ULL));
  long i, lost_i=-1, x18_i=-1; uint64_t t_before=tp(), t_lost=0, x_lost=0;
  for (i=0;i<(1<<26);i+=4096){ if(touch) p[i]=1; for(volatile int j=0;j<20000;j++);
    uint64_t t=tp(), x=rd();
    if(x18_i<0 && x!=0x1122334455667788ULL){x18_i=i;x_lost=x;}
    if(lost_i<0 && !(t>>48&1)){lost_i=i;t_lost=t;} }
  int on=os_custom_x18_abi_enabled(); if(on) os_set_custom_x18_abi_enabled(false);
  fprintf(stderr,"touch=%d on_at_end=%d tp_before=%llx mode_lost_at=%ld tp=%llx x18_lost_at=%ld x18=%llx\n",touch,on,t_before,lost_i/4096,t_lost,x18_i/4096,x_lost);
}
