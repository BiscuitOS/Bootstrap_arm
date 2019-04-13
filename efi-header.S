/*
 * Copyright (C) 2013-2017 Linaro Ltd
 * Authors: Roy Franz <roy.franz@linaro.org>
 *          Ard Biesheuvel <ard.biesheuvel@linaro.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/pe.h>
#include <linux/sizes.h>

	.macro __nop
 AR_CLASS(	mov	r0, r0	)
	.endm

	.macro	__EFI_HEADER
	.endm
