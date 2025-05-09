#ifndef PICORTOS_TYPES_H
#define PICORTOS_TYPES_H

#include <stdint.h>

/* optimize for speed */
typedef unsigned char picoRTOS_stack_t;
typedef unsigned int picoRTOS_tick_t;
typedef uint8_t picoRTOS_priority_t;
typedef uint8_t picoRTOS_pid_t;
typedef unsigned char picoRTOS_atomic_t;
typedef uint8_t picoRTOS_irq_t;
typedef unsigned int picoRTOS_cycles_t;

typedef int picoRTOS_intptr_t;
typedef unsigned int picoRTOS_uintptr_t;

#define ARCH_INTIAL_STACK_COUNT 17
#define ARCH_MIN_STACK_COUNT    (ARCH_INTIAL_STACK_COUNT + 5)

/* no cache */
#define ARCH_L1_DCACHE_LINESIZE 1

/* splint cannot check inline assembly */
#ifdef S_SPLINT_S
# define ASM(x) {}
#else
# define ASM(x) { __asm__ (x); }
# define arch_break() ASM(" sjmp .") /* branch to self */

/*
 * Ugly hack to prevent SDCC from generating
 * the startup sequence for the main
 */
# define main main_no_sdcc_init
#endif

/* very-specific */
void arch_timer_ack(void);

#endif
