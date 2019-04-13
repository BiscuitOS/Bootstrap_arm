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

cache_on:

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
















