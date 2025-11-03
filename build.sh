fasm src/bootloader/boot.asm build/boot.bin
fasm src/kernel/kernel.asm build/kernel.bin

./tools/nfs natrium.img create 1440 --volume NATRIUM
./tools/nfs natrium.img add build/kernel.bin --name kernel.sys
./tools/nfs natrium.img mkdir natrium
./tools/nfs natrium.img add assets/logo.txt --dir natrium
# ./tools/nfs natrium.img add assets/boot.txt --dir natrium

dd if=build/boot.bin of=natrium.img conv=notrunc

qemu-system-i386 -drive file=natrium.img,if=floppy,format=raw -monitor stdio