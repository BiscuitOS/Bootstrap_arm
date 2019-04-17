// SPDX-License-Identifier: GPL-2.0
#define _LINUX_STRING_H_

#include <linux/compiler.h>	/* for inline */
#include <linux/types.h>	/* for size_t */
#include <linux/stddef.h>	/* for NULL */
#include <linux/linkage.h>
#include <asm/string.h>
#include "misc.h"

#define STATIC static
#define STATIC_RW_DATA	/* non-static please */

#define Assert(cond,msg)
#define Trace(x)
#define Tracev(x)
#define Tracevv(x)
#define Tracec(x)
#define Tracecv(c,v)

/* Not needed, but used in some headers pulled in by decompressors */
extern char *strstr(const char *s1, const char *s2);
extern size_t strlen(const char *s);
extern int memcmp(const void *cs, const void *ct, size_t count);

#ifdef CONFIG_KERNEL_GZIP
#include "../../../../lib/decompress_inflate.c"
#endif

int do_decompress(u8 *input, int len, u8 *output, void (*error)(char *x))
{
	return __decompress(input, len, NULL, NULL, output, 0, NULL, error);
}
