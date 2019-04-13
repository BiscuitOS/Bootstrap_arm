/*
 *  linux/arch/arm/boot/compressed/head.S
 *
 *  Copyright (C) 1996-2002 Russell King
 *  Copyright (C) 2004 Hyok S. Choi (MPU support)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
#include <linux/linkage.h>
#include <asm/assembler.h>
#include <asm/v7m.h>

#include "efi-header.S"

 AR_CLASS(	.arch	armv7-a	)

		.align
		/*
		 * Always enter in ARM state for CPUs that support the ARM ISA.
		 * As of today (2014) that's exactly the members of the A and R
		 * classes.
		 */
 AR_CLASS(	.arm	)
start:
		.type	start,#function
		.rept	7
		__nop
		.endr
		mov	r0, r0
		W(b)	1f

		.word	_magic_sig	@ Magic numbers to help the loader
		.word	_magic_start	@ absolute load/run zImage address
		.word	_magic_end	@ zImage end address
		.word	0x04030201	@ endianness flag
		.word	0x45454545	@ another magic number to indicate
		.word	_magic_table	@ additional data table

		__EFI_HEADER
1:
 AR_CLASS(	mrs	r9, cpsr	)
#ifdef CONFIG_ARM_VIRT_EXT
		bl	__hyp_stub_install	@ get into SVC mode, reversibly
#endif
		mov	r7, r1			@ save architecture ID
		mov	r8, r2			@ save atags pointer

#ifndef CONFIG_CPU_V7M
		/*
		 * Booting from Angel - need to enter SVC mode and disable
		 * FIQs/IRQs (numeric definitions from angel arm.h source).
		 * We only do this if we were in user mode on entry.
		 */
		mrs	r2, cpsr		@ get current mode
		tst 	r2, #3			@ not user?
		bne	not_angel
		mov	r0, #0x17		@ angle_SWIreason_EnterSVC
 ARM(		swi	0x123456	)	@ angel_SWI_ARM
not_angel:
		safe_svcmode_maskall r0
		msr	spsr_cxsf, r9		@ Save the CPU boot mode in
						@ SPSR	
#endif
		/*
		 * Note that some cache flushing and other stuff may
		 * be needed here - is there an Angel SWI call for this?
		 */

		/*
		 * some architecture specific code can be inserted
		 * by the linker here, but it should preserve r7, r8, and r9
		 */
		.text

#ifdef CONFIG_AUTO_ZRELADDR
		/*
		 * Find the start of physical memory. AS we are executing
		 * without the MMU on, we are in the physical address space.
		 * We just need to get rid of any offset by aligning the
		 * address.
		 *
		 * This alignment is a balance between the requiremnets of
		 * different platforms - we have chosen 128MB to allow
		 * platforms which align the start of their physical memory
		 * to 128MB to use this feature, while allowing the zImage
		 * to be placed within the first 128MB of memory on other
		 * platforms. Increasing the alignment means we place
		 * stricter alignment requirements on the start of physical
		 * memory, but relaxing it means that we break people who
		 * are already placing their zImage in (eg) the top 64MB
		 * of this range.
		 */
		mov	r4, pc
		and 	r4, r4, #0xf8000000
		/* Determine final kernel image address. */
		add	r4, r4, #TEXT_OFFSET
#endif

		/*
		 * Set up a page table only if it won't overwrite ourself
		 * That means r4 < PC || r4 - 16K page directory > &_end.
		 * Given that r4 > &_end is most unfrequent, we add a rough
		 * additional 1MB of room for a possible appended DTB.
		 */
		mov	r0, pc
		cmp	r0, r4
		ldrcc	r0, LC0+32
		addcc	r0, r0, pc
		cmpcc	r4, r0
		orrcc	r4, r4, #1		@ remember we skipped cache_on
		blcs	cache_on

restart:

ENTRY(BS_debug)
__armv7_mmu_cache_on:
		mov	r1, #0x91

__armv7_mmu_cache_off:

__armv7_mmu_cache_flush:

/*
 * Trun on the cache. We need to setup some page tables so that we
 * can have both the I and D caches on.
 *
 * We place the page tables 16K down from the kernel execution address,
 * and we hope that nothing else is using it. If we're using it, we
 * will go pop!
 *
 * On entry,
 *  r4 = kernel execution address
 *  r7 = architecture number
 *  r8 = atags pointer
 * On exit,
 *  r0, r1, r2, r3, r9, r10, r12 corrupted
 * This routine must preserve:
 *  r4, r7, r8
 */
		.align	5
cache_on:	mov	r3, #8			@ cache_on function
		b	call_cache_fn

#define PROC_ENTRY_SIZE (4*5)
/*
 * Here follow the relocatable cache support functions for the
 * various processors. This is a generic hook for locating an
 * entry and jumping to an instruction at the specified offset
 * from the start of the block. Please not this is all position
 * independent code.
 *
 *  r1  = corrupted
 *  r2  = corrupted
 *  r3  = block offset
 *  r9  = corrupted
 *  r12 = corrupted
 */
call_cache_fn:	adr	r12, proc_types
#ifdef CONFIG_CPU_CP15
		mrc	p15, 0, r9, c0, c0	@ get processor ID
#endif
1:		ldr	r1, [r12, #0]		@ get value
		ldr	r2, [r12, #4]		@ get mask
		eor	r1, r1, r9		@ (real ^ mask)
		tst	r1, r2			@ 	& mask
 ARM(		addeq	pc, r12, r3		) @ call cache function
		add	r12, r12, #PROC_ENTRY_SIZE
		b	1b

/*
 * Table for cache operations. This is basically:
 *   - CPU ID match
 *   - CPU ID mask
 *   - 'cache on' method instruction
 *   - 'cache off' method instruction
 *   - 'cache flush' method instruction
 *
 * We match an entry using: ((real_id ^ match) & mask) == 0
 *
 * Writethrough caches generally only need 'on' and 'off'
 * methods. Writeback caches _must_ have the flush method
 * defined.
 */
		.align	2
		.type	proc_types,#object
proc_types:
		.word	0x000f0000		@ new CPU Id
		.word	0x000f0000
		W(b)	__armv7_mmu_cache_on
		W(b)	__armv7_mmu_cache_off
		W(b)	__armv7_mmu_cache_flush

		.word	0			@ unrecognised type
		.word	0
		mov	pc, lr
		mov	pc, lr
		mov	pc, lr

		.size	proc_types, . - proc_types

		/*
		 * If you get a "non-constant expression in ".if" statement"
		 * error from the assembler on this line, check that you have
		 * not accidentally written a "b" instruction where you should
		 * have written W(b).
		 */
		.if (. - proc_types) % PROC_ENTRY_SIZE != 0
		.error "This size of one or more proc_types entries is wrong."
		.endif

		.align	2
		.type	LC0, #object
LC0:		.word	LC0			@ r1
		.word	__bss_start		@ r2
		.word	_end			@ r3
		.word	_edata			@ r6
		.word	input_data_end - 4	@ r10 (inflated size location)
		.word	_got_start		@ r11
		.word	_got_end		@ ip
		.word	.L_user_stack_end	@ sp
		.word	_end - restart + 16384 + 1024*1024
		.size	LC0, . - LC0


		.align
		.section ".stack", "aw", %nobits
.L_user_stack:	.space	4096
.L_user_stack_end:
















