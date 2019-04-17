# SPDX-License-Identifier: GPL-2.0
#
# linux/arch/arm/boot/compressed/Makefile
#
# create a compressed vmlinuz image from the original vmlinux
#

OBJS		=

AFLAGS_head.o += -DTEXT_OFFSET=$(TEXT_OFFSET)
HEAD	= head.o
OBJS	+= misc.o decompress.o

# string library code (-Os is enforecd to keep it much smaller)
OBJS		+= string.o
CFLAGS_string.o := -Os

ifeq ($(CONFIG_ARM_VIRT_EXT),y)
OBJS            += hyp-stub.o
endif

GCOV_PROFILE		:= n

# Prevents link failures: __sanitizer_cov_trace_pc() is not linked in.
KCOV_INSTRUMENT		:= n

#
# We now have a PIC decompressor implementation.  Decompressors running
# from RAM should not define ZTEXTADDR.  Decompressors running directly
# from ROM or Flash must define ZTEXTADDR (preferably via the config)
# FIXME: Previous assignment to ztextaddr-y is lost here. See SHARK
ZTEXTADDR	:= 0
ZBSSADDR	:= ALIGN(8)

CPPFLAGS_vmlinux.lds := -DTEXT_START="$(ZTEXTADDR)" -DBSS_START="$(ZBSSADDR)"

compress-$(CONFIG_KERNEL_GZIP) = gzip

targets       := vmlinux vmlinux.lds piggy_data piggy.o \
		 head.o $(OBJS)

clean-files += piggy_data hyp-stub.S

KBUILD_CFLAGS += -DDISABLE_BRANCH_PROFILING
KBUILD_CFLAGS += $(DISABLE_ARM_SSP_PER_TASK_PLUGIN)

# -fstack-protector-strong triggers protection checks in this code,
# but it is being used too early to link to meaningful stack_chk logic.
nossp_flags := $(call cc-option, -fno-stack-protector)

ccflags-y := -fpic $(call cc-option,-mno-single-pic-base,) -fno-builtin -I$(obj)
asflags-y := -DZIMAGE

# Supply kernel BSS size to the decompressor via a linker symbol.
KBSS_SZ = $(shell echo $$(($$($(CROSS_COMPILE)nm $(obj)/../../../../vmlinux | \
		sed -n -e 's/^\([^ ]*\) [AB] __bss_start$$/-0x\1/p' \
		       -e 's/^\([^ ]*\) [AB] __bss_stop$$/+0x\1/p') )) )
LDFLAGS_vmlinux = --defsym _kernel_bss_size=$(KBSS_SZ)
# Supply ZRELADDR to the decompressor via a linker symbol.
ifneq ($(CONFIG_AUTO_ZRELADDR),y)
LDFLAGS_vmlinux += --defsym zreladdr=$(ZRELADDR)
endif
# ?
LDFLAGS_vmlinux += -p
# Report unresolved symbol references
LDFLAGS_vmlinux += --no-undefined
# Delete all temporary local symbols
LDFLAGS_vmlinux += -X
# Next argument is a linker script
LDFLAGS_vmlinux += -T

# We need to prevent any GOTOFF relocs being used with references
# to symbols in the .bss section since we cannot relocate them
# independently from the rest at run time.  This can be achieved by
# ensuring that no private .bss symbols exist, as global symbols
# always have a GOT entry which is what we need.
# The .data section is already discarded by the linker script so no need
# to bother about it here.
check_for_bad_syms = \
bad_syms=$$($(CROSS_COMPILE)nm $@ | sed -n 's/^.\{8\} [bc] \(.*\)/\1/p') && \
[ -z "$$bad_syms" ] || \
  ( echo "following symbols must have non local/private scope:" >&2; \
    echo "$$bad_syms" >&2; false )

check_for_multiple_zreladdr = \
if [ $(words $(ZRELADDR)) -gt 1 -a "$(CONFIG_AUTO_ZRELADDR)" = "" ]; then \
        echo 'multiple zreladdrs: $(ZRELADDR)'; \
        echo 'This needs CONFIG_AUTO_ZRELADDR to be set'; \
        false; \
fi

$(obj)/vmlinux: $(obj)/vmlinux.lds $(obj)/$(HEAD) $(obj)/piggy.o \
		$(addprefix $(obj)/, $(OBJS)) FORCE
	@$(check_for_multiple_zreladdr)
	$(call if_changed,ld)
	@$(check_for_bad_syms)

$(obj)/piggy_data: $(obj)/../Image FORCE
	$(call if_changed,$(compress-y))

$(obj)/piggy.o: $(obj)/piggy_data

AFLAGS_hyp-stub.o := -Wa,-march=armv7-a

$(obj)/hyp-stub.S: $(srctree)/arch/$(SRCARCH)/kernel/hyp-stub.S
	$(call cmd,shipped)
