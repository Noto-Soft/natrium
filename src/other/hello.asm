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

    test si, si
    jz world

    mov ax, es
    mov ds, ax

    xor ah, ah
    int 0x21

    inc ah
    mov al, "!"
    int 0x21
    mov al, endl
    int 0x21

    jmp exit

world:
    xor ah, ah
    mov bl, 0x7
    lea si, [msg_2]
    int 0x21

exit:
    retf

msg db "Hello, ", 0
msg_2 db "world!", endl, 0