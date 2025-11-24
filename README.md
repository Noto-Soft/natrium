# Natrium
Natrium (also Notosoft Natrium, or NS Natrium) is a 16 bit (un)real mode operating system.
### Requirements for build
`fasm`, `python3`, `qemu-system-x86`, `python3-pillow`<br />
then run `bash build.sh`
## Notes 'n' stuff
its unreal os because the kernel loads a flat segment starting at 0x0000 ending at 0xffffffff into fs (most of this memory likely wont exist though, assume 16mb)