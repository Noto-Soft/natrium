org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21

    retf

msg db "Hello, world!", endl, 0