	.module picoRTOS_portasm

	.include "generated/picoRTOS_device.S"

	.globl _picoRTOS_tick
	.globl _picoRTOS_syscall

	.globl _arch_timer_ack

	.globl _vn
	.globl __start__stack

	ar7 = 0x07
	ar6 = 0x06
	ar5 = 0x05
	ar4 = 0x04
	ar3 = 0x03
	ar2 = 0x02
	ar1 = 0x01
	ar0 = 0x00

	.macro SAVE_CONTEXT_STEP1
	push a
	push dpl
	push dph
	push b
	push ar0
	push ar1
	push ar2
	push ar3
	push ar4
	push ar5
	push ar6
	push ar7
	push psw
	mov  psw, #0
	.endm

	;; dptr = *(u16*)__start_stack
	.macro DPTR_FROM_SP
	mov r0, #__start__stack
	mov dpl, @r0
	inc r0
	mov dph, @r0
	mov b, #0
	.endm

	.macro SAVE_CONTEXT_STEP2 ?loop
	DPTR_FROM_SP
loop:
	;; emtpy stack to dptr++
	pop a
	movx @dptr, a
	inc dptr
	;; until sp is back to "zero"
	mov a, sp
	cjne a, #__start__stack - 1, loop
	.endm

	.macro SAVE_CONTEXT
	SAVE_CONTEXT_STEP1
	SAVE_CONTEXT_STEP2
	.endm

	;; --dptr
	.macro DEC_DPTR ?nborrow
	dec dpl
	mov a, dpl
	cjne a, #0xff, nborrow
	dec dph
nborrow:
	.endm

	;; *sp-- = *--dptr;
	.macro PUSH_xxDPTR
	DEC_DPTR
	movx a, @dptr
	push a
	.endm

	.macro RESTORE_CONTEXT_STEP1 ?loop
	;; reset stack
	mov sp, #__start__stack - 1
	;; fill stack with --dptr
	PUSH_xxDPTR
	mov r6, a		; r6 is SP_L
	PUSH_xxDPTR
	mov r7, a		; r7 is SP_H
loop:
	PUSH_xxDPTR
	mov a, r6
	cjne a, dpl, loop
	mov a, r7
	cjne a, dph, loop
	.endm

	.macro RESTORE_CONTEXT_STEP2
	pop psw
	pop ar7
	pop ar6
	pop ar5
	pop ar4
	pop ar3
	pop ar2
	pop ar1
	pop ar0
	pop b
	pop dph
	pop dpl
	pop a
	.endm

	.macro RESTORE_CONTEXT
	RESTORE_CONTEXT_STEP1
	RESTORE_CONTEXT_STEP2
	.endm

	;; *dptr++ = rS;
	.macro MOVX_DPTRxx rS
	mov a, rS
	movx @dptr, a
	inc dptr
	.endm

	;; dptr += num;
	.macro ADD_DPTR num
	mov a, dpl
	add a, num
	mov dpl, a
	mov a, dph
	addc a, #0
	mov dph, a
	.endm

	.area CSEG (CODE)

	.globl SysTick_Handler
SysTick_Handler:
	SAVE_CONTEXT_STEP1
	lcall _arch_timer_ack
	SAVE_CONTEXT_STEP2
	lcall _picoRTOS_tick
	RESTORE_CONTEXT
	reti

	.globl Default_Handler
Default_Handler:
	SAVE_CONTEXT_STEP1
	;; point to the right entry
	mov a, _vn
	mov b, #5
	mul ab
	mov dptr, #_ISR_TABLE
	add a, dpl
	mov dpl, a
	mov a, dph
	addc a, #0
	mov dph, a
	;; get fn to r3:r4
	movx a, @dptr
	mov r3, a
	inc dptr
	movx a, @dptr
	mov r4, a
	inc dptr
	;; get priv in r5:r6:r7
	movx a, @dptr
	mov r5, a
	inc dptr
	movx a, @dptr
	mov r6, a
	;; inc dptr
	;; movx a, @dptr
	;; mov r7, a
	;; prepare to call fn(priv)
	lcall fn_priv
	sjmp epilogue
fn_priv:
	push ar3
	push ar4
	mov dpl, r5
	mov dph, r6
	;; mov b, r7
	mov b, #0
	ret			; call fn(priv)
epilogue:
	RESTORE_CONTEXT_STEP2
	reti

	.globl _arch_save_first_context
_arch_save_first_context:
	dec sp			; ignore ret_h
	dec sp			; ignore ret_l
	;; get stacked params
	pop ar4		; fn >> 8
	pop ar3		; fn
	dec sp		; priv >> 16: ignore
	pop ar2		; priv >> 8
	pop ar1		; priv
	;; put stack addr on top
	;; mov dpl, r5 -> already set
	;; mov dph, r6 -> already set
	MOVX_DPTRxx #0		; psw
	MOVX_DPTRxx #7		; r7
	MOVX_DPTRxx #6		; r6
	MOVX_DPTRxx #5		; r5
	MOVX_DPTRxx #4		; r4
	MOVX_DPTRxx #3		; r3
	MOVX_DPTRxx #2		; r2
	MOVX_DPTRxx #1		; r1
	MOVX_DPTRxx #0		; r0
	MOVX_DPTRxx #0		; b   : 0xff & (priv >> 16)
	MOVX_DPTRxx r2		; dph : 0xff & (priv >> 8)
	MOVX_DPTRxx r1		; dpl : 0xff & priv
	MOVX_DPTRxx #65		; a
	MOVX_DPTRxx r4		; reti_h : 0xff & (fn >> 8)
	MOVX_DPTRxx r3		; reti_l : 0xff & fn
	;; default stack is empty
	;; task-specific data will be stored here
	MOVX_DPTRxx r6		; xsp_h : 0xff & (stack >> 8)
	MOVX_DPTRxx r5		; xsp_l : 0xff & stack
	;; restore sp & ret
	mov a, sp
	add a, #7
	mov sp, a
	ret

	.globl _arch_start_first_task
_arch_start_first_task:
	RESTORE_CONTEXT
	setb ea
	ret

	.globl _arch_syscall
_arch_syscall:
	clr ea			; simulate interrupt entrance
	SAVE_CONTEXT_STEP1
	;; reserve space on xstack
	DPTR_FROM_SP
	mov a, sp
	clr c
	subb a, #__start__stack - 1
	mov r0, a
	ADD_DPTR r0
	;; fish for caller params
	;; priv on stack
	mov a, sp
	add a, #0xef
	mov r0, a
	mov a, @r0		; priv
	push a
	inc r0
	mov a, @r0		; priv
	push a
	inc r0
	mov a, @r0		; priv
	push a
	;; dpl on stack
	mov a, r0
	add a, #0x4
	mov r0, a
	mov a, @r0		; syscall
	push a
	lcall _picoRTOS_syscall
	;; restore caller stack
	mov a, sp
	add a, #0xfc
	mov sp, a
	;; post-treatment
	mov r5, dpl		; save next dptr
	mov r6, dph
	SAVE_CONTEXT_STEP2
	mov dpl, r5		; load back next dptr
	mov dph, r6
	RESTORE_CONTEXT
	setb ea
	ret

	.globl _arch_compare_and_swap
_arch_compare_and_swap:
	clr ea
	mov a, sp
	add a, #0xfe
	mov r0, a		; r0: &old
	dec a
	mov r1, a		; r1: &new
	movx a, @dptr	; a: *var
	xrl a, @r0
	jnz _arch_compare_and_swap_fail
	mov a, @r1
	movx @dptr, a
	mov dpl, @r0
	sjmp _arch_compare_and_swap_exit
_arch_compare_and_swap_fail:
	mov dpl, @r1
_arch_compare_and_swap_exit:
	setb ea
	ret

	;; r0-7
	.area REG_BANK_0 (REL,OVR,DATA)
	.ds 8
	
	.area DSEG (DATA)
	.globl _vn
_vn:
	.ds 1 ; vector number

	.area SSEG
	.globl __start__stack
__start__stack:
	.ds	1
	
	.area XSEG (XDATA)
	.globl _ISR_TABLE
_ISR_TABLE:
	.rept DEVICE_INTERRUPT_VECTOR_COUNT
	.ds 2 ; fn
	.ds 3 ; priv
	.endm
