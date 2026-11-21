#!/bin/bash
# Build the kiev shim and wrap it in a boot.img v2 that mirrors the stock header.
set -euo pipefail
cd "$(dirname "$0")"
CC=aarch64-linux-gnu-gcc
OBJCOPY=aarch64-linux-gnu-objcopy
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -Wall -Wextra"
mkdir -p out
for f in start.S shim_kiev.c console_kiev.c mmu_kiev.c fdt.c loader_kiev.c ufs_kiev.c; do
	$CC $CFLAGS -c $f -o out/${f%.*}.o
done
# The image runs wherever ABL puts it with no relocation pass: only the
# header's image_size (start.o, linked at 0) may be an absolute address.
abs=$(aarch64-linux-gnu-readelf -r out/shim_kiev.o out/console_kiev.o out/mmu_kiev.o out/fdt.o out/loader_kiev.o out/ufs_kiev.o | grep -c ABS64 || true)
[ "$abs" = 0 ] || { echo "error: $abs absolute relocations in C objects" >&2; exit 1; }
$CC $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
	out/start.o out/shim_kiev.o out/console_kiev.o out/mmu_kiev.o out/fdt.o out/loader_kiev.o out/ufs_kiev.o -o out/shim_kiev.elf
$OBJCOPY -O binary out/shim_kiev.elf out/Image_kiev
# ABL copies the file; pad to image_size so .bss/stacks exist as zeroed bytes.
size=$(aarch64-linux-gnu-nm out/shim_kiev.elf | awk '$3=="_end"{print strtonum("0x"$1)}')
truncate -s "$size" out/Image_kiev
# Ramdisk: an xnu payload (tools/mkpayload.py) if given as $1, else an empty
# newc cpio (ABL dislikes a zero-size ramdisk on some builds) -> diagnostics.
if [ -n "${1:-}" ]; then
	cp "$1" out/ramdisk_kiev.bin
else
	(cd out && rm -rf rd && mkdir rd && cd rd && find . | cpio -o -H newc --quiet | gzip -9 > ../ramdisk_kiev.bin)
fi
mkbootimg --header_version 2 --kernel out/Image_kiev --ramdisk out/ramdisk_kiev.bin \
	--dtb ../dtb/boot_unpacked/dtb --base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
	--tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
	--os_version 17.0.0 --os_patch_level 2035-06 \
	--cmdline "console=null" -o out/shim-boot-kiev.img
# Host render of the console layout.
gcc -O1 -Wall -o out/host_test console.c host_test.c && ./out/host_test
ls -l out/Image_kiev out/shim-boot-kiev.img