fasm src/bootloader/boot.asm build/boot.bin
fasm src/kernel/kernel.asm build/kernel.sys
fasm src/kernel/command.asm build/command.sys
fasm src/kernel/unreal.asm build/unreal.sys
fasm src/other/hello.asm build/hello.exe

mkdir natrium/
mkdir natrium/System/
mkdir natrium/Documents/
cp build/kernel.sys natrium/
cp build/command.sys natrium/System/
cp build/unreal.sys natrium/System/
cp assets/logo.txt natrium/System/logo.sys.txt
cp assets/boot.txt natrium/System/boot.sys.txt
cp assets/reminder.txt natrium/Documents/
./tools/nfs natrium.img pack --size-kb 1440 --volume NATRIUM natrium
rm -rf natrium

mkdir disk2
cp build/hello.bin disk2/hello.exe
cp assets/yep.txt disk2/
./tools/nfs disk2.img pack --size-kb 1440 --volume STUFF disk2
rm -rf disk2

dd if=build/boot.bin of=natrium.img conv=notrunc

qemu-system-i386 -drive file=natrium.img,if=floppy,format=raw -drive file=disk2.img,if=floppy,format=raw -monitor stdio