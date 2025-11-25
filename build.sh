#!/usr/bin/env bash

chmod +x ./tools/nfs
chmod +x ./tools/nsbmp

fasm src/bootloader/boot.asm build/boot.bin
fasm src/kernel/kernel.asm build/kernel.sys
fasm src/kernel/command.asm build/command.sys
fasm src/kernel/unreal.asm build/unreal.sys
fasm src/other/hello.asm build/hello.exe
fasm src/other/bitmap.asm build/bitmap.exe
fasm src/other/hijack.asm build/hijack.exe

./tools/nsbmp -r assets/bliss.bmp build/bliss.bmp
./tools/nsbmp -l assets/i386.bmp build/i386.bmp

mkdir natrium/
mkdir natrium/System/
mkdir natrium/Documents/
cp build/kernel.sys natrium/
cp build/command.sys natrium/System/
cp build/unreal.sys natrium/System/
cp assets/logo.txt natrium/System/logo.sys.txt
cp assets/boot.txt natrium/System/boot.sys.txt
cp assets/reminder.txt natrium/Documents/
cp assets/yep.txt natrium/Documents/
cp build/hello.exe natrium/
cp build/bitmap.exe natrium/
cp build/bliss.bmp natrium/
cp build/i386.bmp natrium/
cp build/hijack.exe natrium/
./tools/nfs natrium.img pack --size-kb 1440 --volume NATRIUM natrium
rm -rf natrium

dd if=build/boot.bin of=natrium.img conv=notrunc

qemu-system-i386 -drive file=natrium.img,if=floppy,format=raw -monitor stdio