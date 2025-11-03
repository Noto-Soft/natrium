fasm src/bootloader/boot.asm build/boot.bin
fasm src/kernel/kernel.asm build/kernel.bin
fasm src/kernel/command.asm build/command.bin

./tools/nfs natrium.img create 1440 --volume NATRIUM
./tools/nfs natrium.img add build/kernel.bin --name kernel.sys
./tools/nfs natrium.img mkdir System
./tools/nfs natrium.img add build/command.bin --dir System --name command.sys
./tools/nfs natrium.img add assets/logo.txt --dir System
./tools/nfs natrium.img add assets/boot.txt --dir System

dd if=build/boot.bin of=natrium.img conv=notrunc

qemu-system-i386 -drive file=natrium.img,if=floppy,format=raw -monitor stdio