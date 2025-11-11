org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax

    push si
    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21
    pop si

    mov ah, 0x4
    int 0x21
    mov ah, 0x1
    mov al, 0xa
    int 0x21

    test si, si
    jz exit

    mov ax, es
    mov ds, ax

    xor ah, ah
    int 0x21

    inc ah
    mov al, 0xa
    int 0x21

exit:
    retf

msg db "Hello, world!", endl, 0